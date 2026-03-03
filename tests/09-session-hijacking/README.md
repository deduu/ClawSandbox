# 09 -- Session Hijacking & Auth Bypass

## Purpose

Tests whether an attacker can hijack an active OpenClaw session, bypass
authentication controls, or steal session tokens. Because OpenClaw agents
operate with the user's full permissions, a hijacked session grants the
attacker complete control over the agent's capabilities.

## OWASP Alignment

Related to traditional web application security (OWASP Top 10 A07: Identity
and Authentication Failures) applied to the AI agent context, where session
compromise has amplified consequences due to the agent's autonomous execution
capabilities.

## Real-World Example

The ClawJacked vulnerability (disclosed February 2026) demonstrated that
OpenClaw's WebSocket-based communication channel was vulnerable to brute-force
session hijacking. The attack exploited predictable session identifiers in the
local WebSocket server, allowing an attacker on the same network to enumerate
and connect to active sessions in under one second. Once connected, the
attacker could send commands to the agent as if they were the legitimate user.

## What This Category Tests

Session hijacking targets the communication channel between the user and the
agent, rather than the agent's reasoning or tool use. Key areas:

- **WebSocket hijacking** -- Can an attacker connect to OpenClaw's local
  WebSocket server by guessing or brute-forcing the session identifier?
- **Password / token brute-force** -- Are authentication credentials
  protected against brute-force attacks with rate limiting and lockout?
- **Session token theft** -- Can session tokens be extracted from process
  memory, log files, or environment variables?
- **Localhost authentication bypass** -- Does OpenClaw assume that all
  localhost connections are trusted? Can other processes or users on the
  same machine connect without authentication?
- **Cross-origin WebSocket attacks** -- Can a malicious web page opened in
  the user's browser connect to OpenClaw's local WebSocket endpoint?
- **Session fixation** -- Can an attacker pre-set a session identifier
  that the victim will subsequently use?

## Suggested Test Cases

- [ ] Enumerate and brute-force WebSocket session identifiers on localhost
- [ ] Attempt to connect to OpenClaw's WebSocket from a different user account on the same machine
- [ ] Test whether session tokens appear in log files or `/proc/*/environ`
- [ ] Open a malicious HTML page and attempt a cross-origin WebSocket connection to OpenClaw
- [ ] Test rate limiting on authentication endpoints
- [ ] Verify session invalidation after timeout or explicit logout
- [ ] Check whether multiple simultaneous sessions are allowed and properly isolated

## Status

**Not yet implemented -- contributions welcome!**

If you would like to contribute tests for this category, please see the
[Contributing Guide](../../docs/CONTRIBUTING.md) for guidelines on test
structure, safety requirements, and submission process.

## Files

This directory is currently empty. Test scripts and payloads will be added
as the test cases above are implemented.
