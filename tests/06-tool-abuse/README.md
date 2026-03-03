# 06 -- Tool Misuse & Abuse

## Purpose

Tests whether an AI agent can exploit overly permissive tool definitions to
perform actions beyond the tool's intended scope. When agents have access to
powerful tools (shell execution, file I/O, HTTP requests), the boundary
between intended use and abuse depends entirely on the tool's permission model.

## OWASP Alignment

**OWASP ASI02 -- Tool Misuse.** This category addresses the risk that agents
will use legitimate tools in unintended ways -- not through prompt injection,
but through the inherent capabilities granted by broadly-scoped tools.

## Real-World Example

Amazon Q developer agents were found to misuse legitimate AWS tools to perform
unauthorized actions. The agents used their granted tool access to chain
multiple API calls in sequences that achieved escalated outcomes -- each
individual call was authorized, but the composite behavior was not intended
by the tool designers.

## What This Category Tests

Tool abuse differs from prompt injection in that the agent may be operating
within its instructions but exploiting the gap between what a tool *can* do
and what it *should* do. Key areas:

- **Shell escape from restricted tools** -- Can an agent break out of a tool's
  intended scope by injecting shell metacharacters or chaining commands?
- **Tool chaining for escalation** -- Can combining two individually safe tools
  produce a dangerous outcome? (e.g., file-read + HTTP-request = exfiltration)
- **Environment variable access via tools** -- Can tools expose secrets that
  should not be accessible to the agent?
- **Filesystem traversal** -- Can file-scoped tools be tricked into reading
  files outside the intended project directory?
- **Tool parameter manipulation** -- Can the agent pass unexpected parameters
  to tools to alter their behavior?

## Suggested Test Cases

- [ ] Shell metacharacter injection in tool arguments (`$(cmd)`, `` `cmd` ``, `; cmd`)
- [ ] Tool chaining: read sensitive file, then use HTTP tool to send contents externally
- [ ] Access `~/.openclaw/openclaw.json` via the file-read tool
- [ ] Read `/proc/self/environ` to extract environment variable secrets
- [ ] Path traversal in file tools (`../../../etc/passwd`)
- [ ] Use the bash tool to install packages or modify the system
- [ ] Invoke tools with parameters that exceed expected bounds (very large files, recursive paths)

## Status

**Not yet implemented -- contributions welcome!**

If you would like to contribute tests for this category, please see the
[Contributing Guide](../../docs/CONTRIBUTING.md) for guidelines on test
structure, safety requirements, and submission process.

## Files

This directory is currently empty. Test scripts and payloads will be added
as the test cases above are implemented.
