# 05 -- General Security Audit

## Purpose

Broad static and runtime analysis of OpenClaw's security posture, covering
dependency vulnerabilities, dangerous code patterns, file permissions, and
TLS configuration. This test category catches systemic issues that do not
fit neatly into a single attack vector.

## OWASP Alignment

Supports multiple OWASP ASI categories:

- **ASI02 (Tool Misuse)** -- Dangerous code patterns like `eval()` and
  unsanitized `child_process` calls enable tool abuse.
- **ASI03 (Insufficient Sandboxing)** -- File permission issues and
  overly permissive configurations weaken the sandbox.

## What the Script Tests

The `audit.sh` script performs the following checks:

| # | Check | What It Reveals |
|---|-------|-----------------|
| 1 | `npm audit` on OpenClaw's dependencies | Known CVEs in the dependency tree |
| 2 | Total transitive dependency count | Supply chain attack surface size |
| 3 | Dependencies with `postinstall` scripts | Packages that execute code during installation |
| 4 | `eval()` usage in source code | Arbitrary code execution vectors |
| 5 | `child_process` usage patterns | Shell command execution without validation |
| 6 | Dynamic `require()`/`import()` calls | Module injection vectors |
| 7 | Unsafe deserialization patterns | Object injection via `JSON.parse` and similar |
| 8 | Shell injection vectors (`exec` with variable interpolation) | Command injection attack surface |
| 9 | Hardcoded secrets scan | API keys or passwords committed to source |
| 10 | Non-HTTPS URLs (excluding localhost) | Man-in-the-middle exposure |
| 11 | File permissions (world-writable files, sensitive file access) | Unauthorized read/write paths |
| 12 | TLS configuration (min/max version, cert verification) | Transport security posture |

## Usage

```bash
docker compose run --rm sandbox bash /home/openclaw/tests/05-general-audit/audit.sh
```

Results are written to `/tmp/results/05-general/` inside the container.

## Key Findings

| Finding | Severity | Detail |
|---------|----------|--------|
| `eval()` usage | HIGH | 10+ instances across `pw-ai-*.js` core pipeline files |
| `child_process` imports | HIGH | 15+ files import `child_process` with `exec()`, `execSync()`, `spawn()` |
| Dynamic execution pattern | HIGH | `params.exec(params.shell, [...])` -- both executor and shell are dynamic |
| Transitive dependencies | MEDIUM | 379 total dependencies in the package tree |
| `postinstall` scripts | MEDIUM | 3 packages run code during `npm install` (including `node-llama-cpp` which downloads external binaries) |
| TLS configuration | OK | TLSv1.2 minimum, TLSv1.3 maximum, certificate verification enabled |
| Hardcoded secrets | OK | No API keys or passwords found in source code |

## Interpretation

The most significant finding is the combination of `eval()` and unsanitized
`child_process` usage. Together, these create a direct path from prompt
injection to arbitrary code execution: the model generates a command, and
OpenClaw executes it through `child_process` without any validation,
allowlisting, or user confirmation step.

The 379 transitive dependencies represent a substantial supply chain attack
surface. The `node-llama-cpp` package is particularly concerning because it
downloads pre-compiled native binaries from external sources during
installation.

TLS and secrets management are correctly configured.

## Files

- `audit.sh` -- The general security audit script

## See Also

- [Code Audit Results](../../results/code-audit.md) -- Full analysis of
  dangerous code patterns with line-level detail
