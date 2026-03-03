# 03 -- Data Exfiltration Risk Analysis

## Purpose

Tests whether an attacker who has achieved command execution inside the OpenClaw
container can steal sensitive data -- credentials, API keys, user files, or
cloud metadata -- and transmit it to an external server.

## OWASP Alignment

Supports multiple OWASP ASI categories:

- **ASI01 (Prompt Injection)** -- Exfiltration is the typical end goal of a
  successful prompt injection.
- **ASI03 (Insufficient Sandboxing)** -- A sandbox that allows outbound network
  access fails to contain data theft.

## What the Script Tests

The `exfil.sh` script checks the following:

| # | Check | What It Reveals |
|---|-------|-----------------|
| 1 | Sensitive file access (`/etc/shadow`, SSH keys, cloud creds) | Whether high-value files are readable |
| 2 | OpenClaw config file secrets | Whether `~/.openclaw/openclaw.json` contains exposed API keys |
| 3 | Network exfiltration paths (DNS, HTTP, raw TCP) | Whether data can leave the container |
| 4 | Cloud metadata endpoints (AWS, GCP, Azure at 169.254.169.254) | Whether cloud credentials can be stolen via SSRF |
| 5 | Process memory and environment leakage (`/proc/*/environ`) | Whether secrets in memory are accessible |
| 6 | OpenClaw skill/plugin data access patterns | Whether installed skills can read arbitrary files |

## Usage

```bash
docker compose run --rm sandbox bash /home/openclaw/tests/03-data-exfiltration/exfil.sh
```

Results are written to `/tmp/results/03-exfil/` inside the container.

## Key Findings

| Finding | Detail |
|---------|--------|
| `/etc/shadow` | Not readable (permission denied) |
| SSH keys | None present in the container |
| Cloud credentials | No AWS, GCP, or Azure credential files exist |
| DNS resolution (isolated network) | Blocked -- no DNS server reachable |
| HTTP outbound (isolated network) | Blocked -- `curl` to external hosts times out |
| Raw TCP (isolated network) | Blocked |
| Cloud metadata (169.254.169.254) | Unreachable |
| `/proc/self/environ` | Readable (expected -- same UID) |

## Interpretation

When the container is run on the `sandbox-isolated` Docker network, all
network exfiltration paths are fully blocked. DNS, HTTP, HTTPS, and raw TCP
connections to external hosts all fail. The cloud metadata endpoint is
unreachable, preventing credential theft in cloud environments.

No sensitive files beyond OpenClaw's own configuration are present in the
container. The primary residual risk is that environment variables of the
main process are readable via `/proc/self/environ` -- if API keys are passed
as environment variables, any code running in the container can read them.

**Critical caveat:** If the container is run on the default Docker bridge
network instead of `sandbox-isolated`, all outbound network paths are open
and `curl`/`perl` can freely exfiltrate data.

## Files

- `exfil.sh` -- The data exfiltration test script

## See Also

- [Container Security Results](../../results/container-security.md)
- [Prompt Injection Results](../../results/prompt-injection.md)
