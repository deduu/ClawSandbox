# 11 -- Remote Code Execution

## Purpose

Tests whether vulnerabilities in OpenClaw itself (not the LLM) can be
exploited to achieve arbitrary code execution. While prompt injection
achieves code execution *through* the agent's intended tool-use pipeline,
RCE vulnerabilities bypass the agent entirely and exploit bugs in the
framework's code.

## OWASP Alignment

Related to traditional OWASP Top 10 A03 (Injection) and A08 (Software and
Data Integrity Failures). In the AI agent context, RCE is amplified because
the exploited process typically has access to API keys, user files, and
network connectivity.

## Real-World Examples

Multiple OpenClaw CVEs have demonstrated RCE attack vectors:

- **Command injection via unsanitized tool arguments** -- When the agent
  framework passes user or model input directly to shell commands without
  escaping, attackers can inject additional commands using shell metacharacters.
- **Deserialization of untrusted data** -- Node.js applications that
  deserialize data from untrusted sources (WebSocket messages, skill
  configurations, cached state) can be exploited via prototype pollution
  or gadget chains.
- **`eval()` on model output** -- The 10+ `eval()` instances found in
  OpenClaw's `pw-ai-*.js` files (see test 05) represent direct RCE vectors
  if attacker-controlled strings reach them.

## What This Category Tests

RCE testing targets the framework's code rather than the model's reasoning.
Key areas:

- **Command injection** -- Can shell metacharacters in user input, file
  names, skill names, or tool arguments escape the intended command and
  execute arbitrary code?
- **Deserialization attacks** -- Can crafted JSON, YAML, or serialized
  objects exploit `JSON.parse`, prototype pollution, or other deserialization
  paths to achieve code execution?
- **`eval()` injection** -- Can attacker-controlled input flow through the
  application into one of the `eval()` call sites?
- **Template injection** -- If OpenClaw uses template engines for rendering
  responses or configuration, can template syntax in user input be
  interpreted as code?
- **Prototype pollution** -- Can an attacker modify `Object.prototype`
  through a crafted input, affecting the behavior of subsequent code
  execution?
- **Path traversal to code execution** -- Can file path manipulation cause
  the application to load and execute attacker-controlled JavaScript files
  via `require()` or dynamic `import()`?

## Suggested Test Cases

- [ ] Inject shell metacharacters (`$(cmd)`, `` `cmd` ``, `; cmd`, `| cmd`) in tool arguments
- [ ] Craft a malicious JSON payload that exploits prototype pollution in `JSON.parse`
- [ ] Trace data flow from WebSocket input to `eval()` call sites
- [ ] Test for command injection in skill installation paths and skill names
- [ ] Attempt path traversal in `require()` or `import()` calls (`../../../malicious.js`)
- [ ] Test deserialization of crafted objects in session/state restoration
- [ ] Verify that template strings in user input are not interpreted as code

## Status

**Not yet implemented -- contributions welcome!**

If you would like to contribute tests for this category, please see the
[Contributing Guide](../../docs/CONTRIBUTING.md) for guidelines on test
structure, safety requirements, and submission process.

## Files

This directory is currently empty. Test scripts and payloads will be added
as the test cases above are implemented.
