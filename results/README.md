# Results

This directory contains the findings from security testing OpenClaw v2026.2.26 in a hardened Docker sandbox environment. Testing was performed on 2026-02-27.

## Files

- **prompt-injection.md** — Prompt injection test results. Five tests against Gemini 2.5 Flash using OpenClaw's system prompt. Includes full raw API responses, verdicts, and analysis. Two tests vulnerable, one critical, two defended.
- **container-security.md** — Container isolation assessment. Documents user context, capabilities, filesystem, network, privilege escalation paths, and data exfiltration potential.
- **code-audit.md** — Static code audit findings. Covers `eval()` usage, `child_process` patterns, dependency chain risks, TLS configuration, and secrets management.
