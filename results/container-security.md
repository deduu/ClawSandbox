# Container Security Assessment

## Overview

This document records the results of automated security testing performed against the OpenClaw v2026.2.26 Docker container. Tests were run from inside the container to evaluate isolation, privilege boundaries, and data exfiltration potential.

**Date:** 2026-02-27
**Target:** OpenClaw v2026.2.26 Docker image
**Method:** Automated shell scripts executed inside the running container

---

## Container Isolation

**Overall Rating: GOOD**

The container is configured with a defense-in-depth posture. Multiple independent controls reinforce each other.

### User Context

| Check | Result | Status |
|---|---|---|
| Running user | `openclaw` (UID 999) | GOOD |
| Root access | Not available (`su` fails, no sudo installed) | GOOD |
| User groups | `openclaw` only (no `docker`, `disk`, `adm`, etc.) | GOOD |

The container runs as a dedicated non-root user. This is the most fundamental container security control and it is correctly implemented.

### Linux Capabilities

| Check | Result | Status |
|---|---|---|
| Effective capabilities (CapEff) | `0000000000000000` | GOOD |
| Permitted capabilities (CapPrm) | `0000000000000000` | GOOD |
| Bounding set (CapBnd) | `0000000000000000` | GOOD |

All Linux capabilities have been dropped. The container cannot perform any privileged kernel operations — no raw sockets, no filesystem mounts, no namespace manipulation, no ptrace.

### Filesystem

| Check | Result | Status |
|---|---|---|
| Root filesystem | Read-only (`overlay ro`) | GOOD |
| `/tmp` | Writable (tmpfs) | EXPECTED |
| `/home/openclaw` | Writable (bind mount) | EXPECTED |
| Host filesystem | Not mounted | GOOD |

The read-only root filesystem prevents the container from modifying system binaries, installing packages, or persisting malware. Only `/tmp` and the user's home directory are writable, which is the minimum required for OpenClaw to function.

### Docker Socket

| Check | Result | Status |
|---|---|---|
| `/var/run/docker.sock` | Not mounted | GOOD |
| Docker CLI | Not installed | GOOD |

The Docker socket is not exposed inside the container. This prevents container escape via the Docker API, which is one of the most common and severe container security failures.

### Namespace and Process Isolation

| Check | Result | Status |
|---|---|---|
| PID namespace | Isolated (PID 1 is node, not host init) | GOOD |
| No-new-privileges | Enforced | GOOD |
| Seccomp profile | Default Docker profile active | GOOD |

The container has its own PID namespace (it cannot see host processes) and `no-new-privileges` is set, which prevents SUID binaries from actually escalating privileges.

### Network

| Check | Result | Status |
|---|---|---|
| Outbound HTTP (sandbox-isolated network) | Blocked | GOOD |
| Outbound HTTPS (sandbox-isolated network) | Blocked | GOOD |
| Outbound DNS (sandbox-isolated network) | Blocked | GOOD |
| Cloud metadata (169.254.169.254) | Blocked | GOOD |
| Localhost access | Available (for local services) | EXPECTED |

When using the `sandbox-isolated` Docker network, all outbound traffic is fully blocked. This is the single most important control for preventing data exfiltration. The cloud metadata endpoint (used in AWS/GCP/Azure credential theft attacks) is explicitly unreachable.

**Note:** If the container is run on the default Docker bridge network instead of `sandbox-isolated`, outbound traffic IS permitted. Network isolation is a configuration choice, not a container-level enforcement.

---

## Privilege Escalation Risks

**Overall Rating: MEDIUM**

### SUID Binaries

The following 8 SUID binaries were found in the container:

| Binary | Path | Risk |
|---|---|---|
| `passwd` | `/usr/bin/passwd` | Low (mitigated) |
| `su` | `/usr/bin/su` | Low (mitigated) |
| `mount` | `/usr/bin/mount` | Low (mitigated) |
| `umount` | `/usr/bin/umount` | Low (mitigated) |
| `chfn` | `/usr/bin/chfn` | Low (mitigated) |
| `chsh` | `/usr/bin/chsh` | Low (mitigated) |
| `gpasswd` | `/usr/bin/gpasswd` | Low (mitigated) |
| `newgrp` | `/usr/bin/newgrp` | Low (mitigated) |

**Mitigation:** The `no-new-privileges` flag is set on the container, which means the kernel will refuse to honor the SUID bit when these binaries are executed. Even though the binaries exist and have SUID permissions, they cannot actually escalate privileges.

**Recommendation:** Despite the mitigation, these binaries should be removed from the container image to reduce attack surface. If a future misconfiguration disables `no-new-privileges`, they would become exploitable. Add the following to the Dockerfile:

```dockerfile
RUN find / -perm -4000 -exec chmod u-s {} + 2>/dev/null || true
```

### PID 1 Environment

| Check | Result | Status |
|---|---|---|
| `/proc/1/environ` readable | Yes | EXPECTED |

The environment variables of PID 1 (the main node process) are readable by the container user. This is expected because the process runs as the same user (UID 999). However, if API keys or secrets are passed as environment variables, they would be exposed to any code running in the container — including AI-generated code.

**Recommendation:** Prefer Docker secrets or mounted secret files (with restrictive permissions) over environment variables for sensitive values.

---

## Data Exfiltration Assessment

**Overall Rating: LOW (in sandbox-isolated network configuration)**

### Sensitive File Access

| Target | Accessible | Status |
|---|---|---|
| `/etc/shadow` | No (permission denied) | GOOD |
| `/etc/passwd` | Yes (read-only, expected) | EXPECTED |
| `~/.ssh/` | Empty (no keys) | GOOD |
| `~/.aws/credentials` | Does not exist | GOOD |
| `~/.gcloud/` | Does not exist | GOOD |
| `~/.azure/` | Does not exist | GOOD |
| `~/.config/gcloud/` | Does not exist | GOOD |

No sensitive credentials are present in the container filesystem beyond what OpenClaw itself requires (its own config file).

### Exfiltration Tools Present

| Tool | Present | Risk |
|---|---|---|
| `curl` | Yes | HIGH if network enabled |
| `perl` | Yes | HIGH if network enabled |
| `wget` | No | — |
| `nc` / `netcat` | No | — |
| `python` | No | — |
| `ssh` / `scp` | No | — |

Both `curl` and `perl` are available in the container and could be used for data exfiltration if outbound network access is permitted.

- `curl` can make HTTP/HTTPS requests to exfiltrate data via URL parameters or POST bodies.
- `perl` can open raw sockets, construct HTTP requests, and perform DNS exfiltration.

**With the `sandbox-isolated` network, these tools are neutralized** — they have no network path to reach any external host.

**Recommendation:** If full network isolation is not feasible (e.g., the agent needs to browse the web), consider removing `curl` and `perl` from the container image and using a controlled HTTP proxy with domain allowlisting instead.

### DNS Exfiltration

| Check | Result | Status |
|---|---|---|
| DNS resolution (sandbox-isolated) | Fails — no DNS server reachable | GOOD |
| DNS resolution (default bridge) | Works | RISK |

DNS exfiltration (encoding stolen data as subdomain labels in DNS queries, e.g., `stolen-data.attacker.example`) is blocked in the isolated network but possible on the default bridge.

---

## Summary

| Category | Rating | Key Finding |
|---|---|---|
| Container Isolation | **GOOD** | Non-root, no caps, read-only rootfs, no Docker socket |
| Privilege Escalation | **MEDIUM** | 8 SUID binaries present (mitigated by no-new-privileges) |
| Data Exfiltration | **LOW** | Blocked in sandbox-isolated network; `curl`/`perl` present |
| Network Isolation | **GOOD** | Full block on sandbox-isolated; metadata endpoint unreachable |

The container security posture is strong for a sandbox environment. The primary residual risks are:

1. SUID binaries should be stripped from the image.
2. `curl` and `perl` should be removed if network isolation cannot be guaranteed.
3. Environment variables should not contain secrets.
4. The `sandbox-isolated` network must be used — the default bridge network provides no exfiltration protection.
