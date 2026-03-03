# OpenClaw Code Audit Findings

## Overview

Static analysis of the OpenClaw v2026.2.26 source code, focusing on security-relevant patterns: dangerous function usage, shell execution, dependency risk, and secrets management.

**Date:** 2026-02-27
**Target:** OpenClaw v2026.2.26 (installed in Docker container at `/home/openclaw/.npm-global/lib/node_modules/openclaw/`)
**Method:** Manual code review + automated pattern scanning (grep, npm audit)

---

## HIGH Severity

### H1 — `eval()` Usage

**Instances found:** 10+ across `pw-ai-*.js` files

The `pw-ai-*.js` modules (OpenClaw's core AI pipeline files) contain multiple uses of `eval()` to dynamically execute constructed strings. This is the most dangerous pattern in JavaScript — it converts arbitrary string data into executable code.

**Affected files include:**

```
pw-ai-core.js
pw-ai-tools.js
pw-ai-execute.js
pw-ai-response.js
```

**Risk:** If any attacker-controlled input flows into an `eval()` call (e.g., via a prompt injection that causes the model to output JavaScript rather than a shell command), the attacker achieves arbitrary code execution within the Node.js process — not just shell command execution, but full access to the Node.js runtime, including `require('fs')`, `require('child_process')`, `require('net')`, and any loaded API keys or tokens in memory.

**Recommendation:** Replace all `eval()` calls with safer alternatives. If dynamic code execution is truly required, use `vm.runInNewContext()` with a restricted sandbox object and a timeout.

---

### H2 — `child_process` Usage

**Instances found:** 15+ files import `child_process`

The `child_process` module is used extensively throughout the codebase, with all four execution functions present:

| Function | Usage | Risk |
|---|---|---|
| `exec()` | Shell command execution from model output | HIGH — full shell injection surface |
| `execSync()` | Synchronous shell commands | HIGH — same risk, blocks event loop |
| `spawn()` | Process spawning for tools | MEDIUM — no shell by default, but can be configured with `shell: true` |
| `spawnSync()` | Synchronous process spawning | MEDIUM — same as spawn |

**Key pattern identified:**

```javascript
params.exec(params.shell, [...])
```

This pattern passes a shell path and arguments from a `params` object, meaning the shell binary and command arguments are configurable at runtime. If the `params` object is influenced by model output or user input without validation, this becomes a direct code execution vector.

**Risk:** This is the mechanism by which prompt injection becomes code execution. The model generates a shell command, and OpenClaw executes it via `child_process`. There is no validation, sanitization, or allowlisting layer between the model's output and the shell.

**Recommendation:**
1. Implement a command validation layer between model output and `child_process` calls.
2. Use `spawn()` with `shell: false` instead of `exec()` wherever possible to avoid shell metacharacter injection.
3. Consider a mandatory user-confirmation step for commands that match dangerous patterns (network access, file reads outside project directory, privilege escalation).

---

### H3 — Shell Execution Pattern

**Pattern:** `params.exec(params.shell, [...])`

This is a specific instance of H2 but warrants separate attention because of its architecture. The `params.exec` pattern means that:

1. The execution function itself is passed as a parameter (could be `exec`, `execSync`, `spawn`, or `spawnSync`).
2. The shell binary is passed as a parameter (could be `/bin/bash`, `/bin/sh`, or any arbitrary path).
3. The arguments are constructed from model output.

This design is maximally flexible — and maximally dangerous. It provides no fixed point where a security check can be reliably inserted, because both the executor and the shell are dynamic.

**Recommendation:** Refactor to use a single, centralized execution function with hardcoded shell path and mandatory pre-execution validation:

```javascript
// Instead of: params.exec(params.shell, [...])
// Use:
function safeExec(command, options) {
  validateCommand(command);  // throws on dangerous patterns
  auditLog(command);         // log for forensics
  return execFile('/bin/bash', ['-c', command], options);
}
```

---

## MEDIUM Severity

### M1 — Dependency Chain Risk

**Direct dependencies:** Not counted (OpenClaw's `package.json` was not directly analyzed)
**Transitive dependencies:** 379

Of these 379 transitive dependencies, 3 have `postinstall` scripts that execute code during `npm install`:

| Package | postinstall Action | Risk |
|---|---|---|
| `protobufjs` | Compiles protocol buffer definitions | MEDIUM — executes build toolchain |
| `node-llama-cpp` | Downloads and compiles llama.cpp native binaries | HIGH — downloads external binaries |
| `discord-api-types` | Type generation | LOW — code generation only |

**Risk:** `postinstall` scripts run with the full permissions of the user executing `npm install`. A compromised version of any of these packages (via supply chain attack) could execute arbitrary code during installation.

The `node-llama-cpp` package is particularly concerning because it downloads pre-compiled native binaries from an external source during installation. If the download source is compromised, the installed binary would be a trojan.

**Recommendation:**
1. Pin all dependency versions exactly (use `npm shrinkwrap` or `package-lock.json` with integrity hashes).
2. Consider using `--ignore-scripts` during installation and running necessary build steps manually.
3. Audit `node-llama-cpp`'s download URLs and verify binary checksums.
4. Run `npm audit` regularly and address findings promptly.

---

## OK (No Issues Found)

### O1 — TLS Configuration

| Parameter | Value | Status |
|---|---|---|
| Minimum TLS version | TLSv1.2 | OK |
| Maximum TLS version | TLSv1.3 | OK |
| Certificate verification | Enabled (default) | OK |
| `NODE_TLS_REJECT_UNAUTHORIZED` | Not set (defaults to `1` / enabled) | OK |

OpenClaw's outbound HTTPS connections use secure TLS defaults. Certificate verification is enabled, which prevents man-in-the-middle attacks on API calls to Gemini, OpenAI, Anthropic, and other model providers.

No instances of `rejectUnauthorized: false` or `NODE_TLS_REJECT_UNAUTHORIZED=0` were found in the codebase.

---

### O2 — No Hardcoded Secrets

A scan for common secret patterns found no hardcoded API keys, tokens, or passwords in the source code:

| Pattern | Instances Found |
|---|---|
| `sk-proj-` (OpenAI) | 0 |
| `sk-ant-` (Anthropic) | 0 |
| `AIza` (Google) | 0 |
| `ghp_` (GitHub) | 0 |
| `password\s*=` | 0 |
| `secret\s*=` | 0 |
| `Bearer\s+[A-Za-z0-9]` | 0 (only template references) |

Secrets are loaded at runtime from `~/.openclaw/openclaw.json`, which is the expected pattern (though the file-based storage has its own risks — see prompt injection report, Test 5).

---

## LOW Severity

### L1 — HTTP URLs for Local Services

Several configuration references use plain HTTP (not HTTPS) for local service endpoints:

```
http://localhost:...
http://127.0.0.1:...
```

**Risk:** These are local-only connections and are not exposed to network interception in normal operation. However, if the container's network namespace is shared with other containers or the host, local HTTP traffic could theoretically be intercepted.

**Recommendation:** This is acceptable for local development and sandboxed use. For production deployments, consider using Unix domain sockets instead of TCP for local inter-process communication.

---

## Summary Table

| ID | Severity | Finding | Status |
|---|---|---|---|
| H1 | **HIGH** | `eval()` in 10+ `pw-ai-*.js` files | Needs remediation |
| H2 | **HIGH** | `child_process` imported in 15+ files | Needs validation layer |
| H3 | **HIGH** | `params.exec(params.shell, [...])` dynamic execution | Needs architectural fix |
| M1 | **MEDIUM** | 379 transitive deps, 3 with postinstall scripts | Needs monitoring |
| O1 | OK | TLS: v1.2 min, v1.3 max, cert verification on | No action needed |
| O2 | OK | No hardcoded secrets | No action needed |
| L1 | LOW | HTTP URLs for localhost services | Acceptable |

---

## Recommendations Summary

1. **Eliminate `eval()`** — Replace with `vm.runInNewContext()` or refactor to avoid dynamic code execution entirely.
2. **Centralize shell execution** — Replace the `params.exec(params.shell, [...])` pattern with a single audited execution function that validates commands before running them.
3. **Add a command validation layer** — Implement pre-execution checks for dangerous patterns (network exfiltration, sensitive file access, privilege escalation) between model output and `child_process` calls.
4. **Lock dependencies** — Use exact version pinning with integrity hashes. Audit `postinstall` scripts, especially `node-llama-cpp`'s binary downloads.
5. **Run `npm audit` in CI** — Catch known vulnerabilities in dependencies before deployment.
