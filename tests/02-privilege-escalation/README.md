# 02 -- Privilege Escalation & Container Escape

## Purpose

Tests whether OpenClaw or its container environment can be exploited to
escalate privileges (non-root to root) or escape the container entirely
to reach the host operating system.

## OWASP Alignment

**OWASP ASI03 -- Insufficient Sandboxing.** AI agents that execute code require
strict privilege boundaries. A sandbox escape converts a contained agent into
an unrestricted attacker on the host system.

## What the Script Tests

The `privesc.sh` script checks the following inside the container:

| # | Check | What It Reveals |
|---|-------|-----------------|
| 1 | Linux capabilities (`/proc/self/status`, `capsh`) | Whether the container can perform privileged kernel operations |
| 2 | Docker socket access (`/var/run/docker.sock`) | Whether the container can control the Docker daemon (full host escape) |
| 3 | `/proc` and `/sys` access | Whether sensitive kernel interfaces are readable |
| 4 | SUID/SGID binaries (`find / -perm -4000`) | Binaries that could escalate privileges if executed |
| 5 | `no-new-privileges` enforcement | Whether SUID bits are actually honored by the kernel |
| 6 | Namespace isolation (PID, network, mount, user) | Whether the container is properly isolated from the host |
| 7 | OpenClaw process capabilities | Whether the Node.js runtime runs with elevated privileges |

## Usage

```bash
docker compose run --rm sandbox bash /home/openclaw/tests/02-privilege-escalation/privesc.sh
```

Results are written to `/tmp/results/02-privesc/` inside the container.

## Key Findings

| Finding | Detail |
|---------|--------|
| Effective capabilities (CapEff) | `0000000000000000` -- all capabilities dropped |
| Permitted capabilities (CapPrm) | `0000000000000000` -- none available |
| Docker socket | Not mounted (container escape via Docker API is impossible) |
| SUID binaries | 8 found (`passwd`, `su`, `mount`, `umount`, `chfn`, `chsh`, `gpasswd`, `newgrp`) |
| SUID mitigation | `no-new-privileges` flag is set -- kernel refuses to honor SUID bits |
| PID namespace | Isolated (PID 1 is `node`, not the host init process) |
| Filesystem | Read-only root; only `/tmp` and `/home/openclaw` writable |

## Interpretation

The container's privilege escalation posture is strong. All Linux capabilities
are dropped to zero, which prevents raw socket creation, filesystem mounting,
namespace manipulation, and ptrace-based attacks. The 8 SUID binaries are
present but neutralized by the `no-new-privileges` flag -- the kernel will not
grant elevated privileges when these binaries are executed.

**Residual risk:** The SUID binaries should be stripped from the image entirely.
If a future configuration change accidentally removes the `no-new-privileges`
flag, they would become exploitable.

## Files

- `privesc.sh` -- The privilege escalation test script

## See Also

- [Container Security Results](../../results/container-security.md)
