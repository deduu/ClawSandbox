# 01 -- Reconnaissance & Attack Surface Enumeration

## Purpose

Maps out OpenClaw's filesystem footprint, runtime environment, network posture,
and installed tools before any active exploitation. This is the first step in
any security assessment -- understanding what is present and what is reachable.

## OWASP Alignment

General reconnaissance. Supports all subsequent OWASP ASI categories by
establishing baseline knowledge of the target environment.

## What the Script Tests

The `recon.sh` script performs the following checks inside the container:

| # | Check | What It Reveals |
|---|-------|-----------------|
| 1 | OpenClaw binary location and file permissions | Installation path, ownership, SUID/SGID bits |
| 2 | NPM global package file count | Total attack surface size |
| 3 | Default configuration (`~/.openclaw/openclaw.json`) | Stored secrets, model selection, feature flags |
| 4 | Environment variables (secrets redacted) | Leaked API keys, debug flags, path manipulation |
| 5 | Network listeners (`ss -tlnp`) | Open ports, unexpected services |
| 6 | User context (`whoami`, `id`, `sudo -l`) | Privilege level, group memberships |
| 7 | Filesystem write access | Which directories the agent can modify |
| 8 | Installed tools (curl, wget, nc, python, perl, gcc, etc.) | Exfiltration and exploitation capabilities |

## Usage

```bash
docker compose run --rm sandbox bash /home/openclaw/tests/01-recon/recon.sh
```

Results are written to `/tmp/results/01-recon/` inside the container.

## Key Findings

| Finding | Detail |
|---------|--------|
| Package size | 45,104 files in the OpenClaw npm package |
| Dangerous tools present | `curl` and `perl` are available in the container image |
| Missing tools | `wget`, `nc`, `python`, `gcc`, `socat` are not installed |
| User context | Non-root user `openclaw` (UID 999), no sudo access |
| Writable paths | Only `/tmp` and `/home/openclaw` are writable |
| Network listeners | No unexpected listeners on a fresh container |

## Interpretation

The large package size (45,104 files) increases the probability that a
vulnerable or exploitable dependency is present. The availability of `curl`
and `perl` means an attacker who achieves command execution can exfiltrate
data over HTTP or open raw sockets -- unless network isolation is enforced
via the `sandbox-isolated` Docker network.

## Files

- `recon.sh` -- The reconnaissance script

## See Also

- [Container Security Results](../../results/container-security.md)
- [Code Audit Results](../../results/code-audit.md)
