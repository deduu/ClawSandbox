# Architecture

This document describes the security architecture of the ClawSandbox, including container hardening layers, network modes, the monitoring sidecar, test structure, and the rationale for using direct API calls.

---

## Overview

The ClawSandbox is a Docker-based environment designed to test the security posture of AI agents with code execution capabilities. The reference implementation targets OpenClaw, an open-source AI agent with 215k+ GitHub stars, but the sandbox infrastructure, test categories, and methodology are designed for reuse with any agent. The sandbox provides a hardened, isolated container where the target agent is installed and subjected to automated security assessments and interactive prompt injection tests.

The architecture follows a defense-in-depth approach: multiple independent security controls are layered so that the failure of any single control does not compromise the overall isolation.

---

## Container Security Layers

The container is hardened with seven independent security controls, each configured in `docker/docker-compose.yml`:

### 1. Non-Root User

```dockerfile
RUN groupadd -r openclaw && useradd -r -g openclaw -m -s /bin/bash openclaw
USER openclaw
```

The container runs as a dedicated `openclaw` user (UID 999) with no root access. There is no `sudo` installed and `su` is blocked by the no-new-privileges flag. This prevents trivial privilege escalation from within the container.

### 2. All Capabilities Dropped

```yaml
cap_drop:
  - ALL
```

All 41 Linux capabilities are dropped. The container cannot perform any privileged kernel operations: no raw sockets, no filesystem mounts, no namespace manipulation, no ptrace, no chown of arbitrary files. The effective, permitted, and bounding capability sets are all `0000000000000000`.

### 3. Read-Only Root Filesystem

```yaml
read_only: true
tmpfs:
  - /tmp:size=100M,uid=999,gid=999
  - /home/openclaw/.openclaw:size=50M,uid=999,gid=999
  - /home/openclaw/.npm:size=100M,uid=999,gid=999
```

The root filesystem is mounted read-only. The container cannot modify system binaries, install packages, or persist malware. Only three tmpfs directories are writable, each size-limited and owned by the `openclaw` user. These are the minimum required for OpenClaw to function.

### 4. No-New-Privileges

```yaml
security_opt:
  - no-new-privileges:true
```

The `no-new-privileges` flag tells the kernel to refuse to honor SUID/SGID bits when executing binaries. Even though standard SUID binaries (`passwd`, `su`, `mount`, etc.) are present in the base image, they cannot actually escalate privileges. This is a critical backstop because the `node:22-slim` base image ships with 8 SUID binaries that would otherwise be exploitable.

### 5. Resource Limits

```yaml
deploy:
  resources:
    limits:
      cpus: "2.0"
      memory: 2G
    reservations:
      memory: 512M
```

CPU and memory are capped to prevent resource exhaustion attacks (fork bombs, memory-hungry processes) from affecting the host system. The container is limited to 2 CPU cores and 2 GB of RAM.

### 6. Network Isolation

```yaml
networks:
  sandbox-isolated:
    driver: bridge
    internal: true  # No external/internet access
```

When using the `sandbox-isolated` network (the default), all outbound traffic is blocked: HTTP, HTTPS, DNS, and even cloud metadata endpoints (169.254.169.254). This is the single most effective control against data exfiltration. Without network access, even a fully compromised container cannot send stolen data anywhere.

### 7. No Host Mounts

The main sandbox service uses no named volumes or bind mounts to host directories. Writable storage is provided exclusively by tmpfs mounts (see section 3 above). The only named volume in the compose file is `network-captures`, used by the network monitor sidecar to store packet captures.

There is no access to the host filesystem, the Docker socket, or any host devices. This prevents container escape via filesystem traversal and blocks access to host secrets, SSH keys, cloud credentials, or other sensitive files.

---

## Network Modes

The sandbox defines two Docker networks. Only one should be active at a time.

### sandbox-isolated (Default)

```yaml
sandbox-isolated:
  driver: bridge
  internal: true
```

- **Purpose:** Automated security tests (categories 01-03, 05).
- **Internet access:** Fully blocked. The `internal: true` flag prevents any traffic from leaving the Docker network.
- **DNS:** Blocked. No DNS server is reachable.
- **Use when:** Running tests that do not require external API calls.

### sandbox-internet

```yaml
sandbox-internet:
  driver: bridge
```

- **Purpose:** Prompt injection tests (category 04) that call the Gemini API.
- **Internet access:** Allowed. The container can reach external HTTPS endpoints.
- **DNS:** Available via Docker's default DNS resolver.
- **Use when:** Running LLM-based prompt injection tests that need to call cloud APIs.

To switch between modes, edit the `networks` list under the `ClawSandbox` service in `docker/docker-compose.yml` and restart the container. See [docs/SETUP.md](SETUP.md) for detailed instructions.

---

## Network Monitor Sidecar

```yaml
network-monitor:
  image: nicolaka/netshoot:latest
  container_name: openclaw-netmon
  network_mode: "service:ClawSandbox"
  cap_drop:
    - ALL
  cap_add:
    - NET_RAW
    - NET_ADMIN
  command: >
    tcpdump -i any -nn -l -w /captures/openclaw-traffic.pcap
  volumes:
    - network-captures:/captures
```

A `netshoot`-based sidecar container runs alongside the main sandbox. It shares the network namespace of the `ClawSandbox` container (`network_mode: "service:ClawSandbox"`) and captures all network traffic using `tcpdump`.

**Purpose:**

- **Verify isolation:** Confirm that no outbound traffic escapes when using `sandbox-isolated`.
- **Audit API calls:** When using `sandbox-internet`, capture and inspect exactly what data is sent to external APIs.
- **Detect exfiltration:** Identify any unexpected outbound connections, DNS queries, or data transfers.

The sidecar only has `NET_RAW` and `NET_ADMIN` capabilities (required for packet capture) -- all other capabilities are dropped.

Traffic captures are written to the `network-captures` Docker volume at `/captures/openclaw-traffic.pcap`. To analyze them:

```bash
docker cp openclaw-netmon:/captures/openclaw-traffic.pcap .
tcpdump -r openclaw-traffic.pcap -nn
# or
wireshark openclaw-traffic.pcap
```

---

## Test Structure

Tests are organized in numbered directories under `tests/`. Categories 01-05 are implemented; categories 06-11 are placeholders for future contributions.

### Automated Scripts (01-03, 05)

These run entirely inside the container with no external dependencies:

| Category | Directory | Script | What It Tests |
|---|---|---|---|
| 01 | `tests/01-recon/` | `recon.sh` | Attack surface: filesystem layout, installed tools, user context, network listeners |
| 02 | `tests/02-privilege-escalation/` | `privesc.sh` | SUID binaries, capabilities, namespace isolation, Docker socket access |
| 03 | `tests/03-data-exfiltration/` | `exfil.sh` | Sensitive file access, exfiltration tools, DNS exfiltration, cloud metadata |
| 05 | `tests/05-general-audit/` | `audit.sh` | Code patterns (eval, child_process), dependency chain, TLS config, secrets |

Each script:

1. Runs a series of checks inside the container.
2. Prints results to stdout (captured by `tee`).
3. Writes detailed findings to `/tmp/results/`.

The `tests/run-all.sh` runner executes them sequentially.

### Interactive Prompt Injection Tests (04)

Category 04 is different from the automated scripts. It calls an external LLM API:

| File | Purpose |
|---|---|
| `tests/04-prompt-injection/run-via-api.sh` | Sends payloads directly to the Gemini API using curl |
| `tests/04-prompt-injection/run-via-openclaw.sh` | Sends payloads through the OpenClaw agent CLI |
| `tests/04-prompt-injection/payloads/` | Directory containing test payload files |

The `payloads/` directory contains five payload files:

| Payload | Technique |
|---|---|
| `direct-override.txt` | "Ignore all previous instructions" |
| `indirect-file.md` | Hidden HTML comment with exfiltration command |
| `malicious-agents.md` | Poisoned AGENTS.md with `curl \| bash` |
| `encoding-bypass.txt` | Base64-encoded malicious command |
| `role-hijack.txt` | Fake "SYSTEM OVERRIDE" debug mode |

### Placeholder Categories (06-11)

These directories exist but contain no scripts yet. They represent planned test categories seeking community contributions:

| Category | Directory | Planned Scope |
|---|---|---|
| 06 | `tests/06-tool-abuse/` | Abuse of OpenClaw's built-in tools (bash, file, web) |
| 07 | `tests/07-supply-chain/` | Dependency poisoning, malicious npm packages |
| 08 | `tests/08-memory-poisoning/` | Conversation history manipulation, context window attacks |
| 09 | `tests/09-session-hijacking/` | Session token theft, cross-session data leakage |
| 10 | `tests/10-network-ssrf/` | Server-side request forgery via agent web browsing |
| 11 | `tests/11-rce/` | Remote code execution beyond intended shell access |

---

## Why Direct API Calls Instead of the OpenClaw CLI

The prompt injection tests (`run-via-api.sh`) call the Gemini API directly with `curl` rather than running payloads through the `openclaw` agent CLI. This is a deliberate design choice for the following reasons:

### 1. Avoids Retry-Based Quota Waste

The OpenClaw CLI has built-in retry logic. When a request fails (due to rate limits, network timeouts, or API errors), it automatically retries -- sometimes multiple times with exponential backoff. On the Gemini free tier, each retry consumes quota. A single failed test can burn through the entire rate limit window via retries, leaving no quota for the remaining tests.

Direct `curl` calls make exactly one request per test with no retries. If it fails, the failure is recorded and the test moves on.

### 2. Reproducible System Prompt

The OpenClaw CLI constructs its system prompt dynamically based on configuration files (`SOUL.md`, `AGENTS.md`), installed tools, and runtime state. This means the exact prompt sent to the model can vary between runs, making test results harder to reproduce.

Direct API calls use a fixed, known system prompt (extracted from OpenClaw's source) that is identical across all test runs. This ensures that differences in model behavior are attributable to the payload, not to prompt variations.

### 3. Full Visibility Into Requests and Responses

With direct `curl` calls, the complete JSON request and response are captured and logged. There is no abstraction layer between the test harness and the API. This makes it straightforward to:

- Verify exactly what was sent to the model.
- Inspect the full response including metadata, safety ratings, and finish reasons.
- Share results with others for independent verification.

### 4. No Dependency on OpenClaw Being Functional

If OpenClaw has a bug, crashes, or fails to initialize, the prompt injection tests still work because they do not depend on the OpenClaw runtime. This decouples security testing from the target application's reliability.

### When to Use the OpenClaw CLI

The `run-via-openclaw.sh` script is provided for completeness. It tests the full end-to-end flow through the OpenClaw agent, including tool execution, retry logic, and response formatting. Use it when you want to verify that a vulnerability found via direct API calls is also exploitable through the actual agent interface -- but be aware that it consumes significantly more API quota.
