# How to Engage With This Project

This guide is structured by *what you want to do*. Whether you are reviewing findings, reproducing results, challenging methodology, contributing tests, or using the research in your own work — start with the section that matches your goal.

For context on what the project found and how to interpret the results, see [UNDERSTANDING.md](UNDERSTANDING.md).

---

## Ways to Engage

There are several paths into this project, and not all of them require writing code:

- **Review the findings** — read the results, form your own conclusions, identify gaps
- **Reproduce the results** — run the tests yourself and verify (or challenge) the outcomes
- **Critique the methodology** — question whether the verdicts are justified, the payloads are realistic, or the scope is sufficient
- **Contribute tests** — write new payloads, implement empty test categories, extend coverage
- **Use the findings** — cite the results in research, journalism, policy, or education
- **Report issues** — flag broken links, unclear documentation, or incorrect analysis

> [!TIP]
> Non-code contributions — documentation improvements, real-world attack scenario descriptions, policy translations, and methodological critiques — are as valuable as new test code.

---

## Reviewing and Critiquing the Findings

The test results live in [results/](../results/). Each file follows a consistent format: test environment, payload, raw response, verdict, and analysis.

### What to Look For

When reading critically, consider:

- **Are the verdicts justified?** Does the raw model response actually demonstrate the vulnerability the verdict claims? A "VULNERABLE" verdict should show the model complying with the malicious instruction, not merely acknowledging it.
- **Are the payloads realistic?** Would an attacker plausibly deliver this payload in a real-world scenario? A payload that requires physical access to the machine is a different risk class than one embedded in a web page the agent browses.
- **Is the sample size acknowledged?** Five prompt injection tests cover a narrow slice of the attack surface. Results should be read as "these specific attacks produced these specific outcomes," not as a comprehensive evaluation.
- **Is the test environment representative?** The prompt injection tests used direct API calls, not the full OpenClaw CLI. This isolates the model's behavior but does not capture defenses that the framework might add.

### How to Raise Critiques

| Format | When to Use |
|--------|-------------|
| **GitHub Issue** | Something is factually wrong, a link is broken, or a verdict appears incorrect |
| **GitHub Discussion** | You have a methodological question or want to propose a different interpretation |
| **Pull Request** | You have a concrete fix — corrected analysis, improved documentation, or additional evidence |

Good criticism is specific. Rather than "the methodology is flawed," point to a specific test and explain what the flaw is, what evidence supports your reading, and what a corrected version would look like.

---

## Reproducing the Results

Reproduction is the most direct way to validate or challenge the findings.

### What You Need

- **Docker 20.10+** and **Docker Compose v2.0+** — required for all tests
- **A Gemini API key** — required only for the prompt injection tests (category 04); all other tests run fully offline

### High-Level Steps

1. Clone the repository and build the container — see [Setup Guide](../docs/SETUP.md) for exact commands
2. Run the automated tests (categories 01–03, 05) — these require no internet access or API keys
3. Optionally run the prompt injection tests (category 04) — these require switching to `sandbox-internet` network mode and providing an API key

The [Setup Guide](../docs/SETUP.md) covers prerequisites, build instructions, and troubleshooting in detail.

### Reporting Differences

If your results differ from the published findings, open a GitHub Issue with:

- Your Docker version, OS, and container build date
- The exact test you ran and the command used
- The output you received (full raw response)
- How it differs from the published result

Differences are expected over time — model updates, framework changes, and environmental variations all affect outcomes. Documenting them strengthens the project.

---

## Contributing Tests

The project has 6 test categories that are defined but not yet implemented:

| Category | What It Covers | Impact |
|----------|---------------|--------|
| **06 — Tool Abuse** | Shell escape, tool chaining, filesystem traversal | High — directly tests the agent's most dangerous capabilities |
| **07 — Supply Chain** | Malicious skills, dependency poisoning, codebase exfiltration | High — reflects real-world software supply chain risks |
| **11 — Remote Code Execution** | Command injection, deserialization, eval injection | High — tests for the most severe exploitation outcomes |
| **08 — Memory Poisoning** | RAG poisoning, context manipulation, persistent false facts | Medium — growing concern as agents gain long-term memory |
| **10 — Network & SSRF** | DNS tunneling, SSRF, reverse shells | Medium — tests network isolation effectiveness |
| **09 — Session Hijacking** | WebSocket hijacking, auth bypass, session theft | Medium — relevant as agents gain multi-user capabilities |

Each category directory contains a `README.md` with suggested test cases, OWASP alignment, and scope. See [Contributing](../docs/CONTRIBUTING.md) for the full specification — payload safety rules, results format, and submission process.

### Non-Technical Contributions

You do not need to write exploit code to contribute meaningfully:

- **Document real-world scenarios** — describe how a specific attack technique could manifest in a realistic agent deployment
- **Translate policy requirements** — map regulatory frameworks (EU AI Act, NIST AI RMF, OWASP) to specific test cases
- **Improve documentation** — clarify explanations, fix errors, add examples
- **Review existing tests** — verify that payloads follow safety rules and verdicts match raw data

---

## Using the Findings in Your Own Work

### Researchers

Fork the repository and extend it. The container configuration, test structure, and results format are designed for reuse. If you test additional models or frameworks, consider contributing results back.

### Journalists

When citing results, include the model tested (Gemini 2.5 Flash), the date (2026-02-27), and the sample size (5 prompt injection tests). The findings demonstrate specific vulnerabilities under specific conditions — they are not a blanket assessment of AI agent safety. The [results/](../results/) directory contains the exact payloads and raw responses for verification.

### Policymakers

The test categories align with [OWASP Agentic AI Security Initiative](https://owasp.org/www-project-agentic-ai-security-initiative/) classifications (ASI01, ASI02, ASI06) and OWASP Top 10 categories (A03, A07, A08, A10). This alignment makes it possible to map findings to existing frameworks and compliance requirements.

### Educators

The sandbox runs entirely offline in its default configuration — no API keys, no external network access. This makes it suitable for classroom environments where students can observe real attack techniques and defenses without risk to external systems.

---

## Responsible Conduct

This project exists to improve AI agent security through transparent research. To that end:

- **Use reserved domains only.** All payloads must target `attacker.example` (an [RFC 6761](https://datatracker.ietf.org/doc/html/rfc6761) reserved domain), never real domains, IP addresses, or localhost.
- **Never include real credentials.** Use obviously fake values (e.g., `sk-fake-test-key-not-real`).
- **Test only in the sandbox.** Do not adapt these techniques to target systems you do not own or have explicit authorization to test.
- **Disclose responsibly.** If you discover a vulnerability in OpenClaw (the upstream project) or in a model's safety mechanisms, report it through the appropriate disclosure channel — not as a public GitHub issue in this repository.
- **Respect the community.** Critique methodology and findings, not people. Specific, evidence-based disagreement makes the project better.

See [Contributing](../docs/CONTRIBUTING.md) for the full payload safety rules and contribution guidelines.
