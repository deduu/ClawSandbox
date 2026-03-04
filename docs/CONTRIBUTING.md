# Contributing

Thank you for your interest in contributing to ClawSandbox. This document explains how to add new tests, the safety rules for test payloads, the expected results format, and how to verify your changes.

---

## How to Add a New Test Category

The test suite is organized by category under `tests/`. Categories 06-11 are empty placeholders waiting for contributions. You can also propose entirely new categories.

### Step 1: Create the Test Directory

Each test category lives in its own numbered directory under `tests/`:

```
tests/
  06-tool-abuse/
  07-supply-chain/
  08-memory-poisoning/
  ...
```

If you are contributing to an existing placeholder, use the directory that already exists. If you are adding a new category, create a new numbered directory following the existing convention:

```bash
mkdir tests/12-your-category-name/
```

### Step 2: Add a README.md

Every test category must include a `README.md` that explains:

1. **Purpose** -- what the test category is designed to assess.
2. **OWASP Alignment** -- which OWASP ASI (Agentic Security Initiative) or LLM Top 10 category the tests map to.
3. **What the Script Tests** -- a table listing each check and what it reveals.
4. **Usage** -- the exact command to run the test.
5. **Key Findings** -- a summary table of results.
6. **Interpretation** -- what the findings mean in practice.

Use `tests/01-recon/README.md` as a reference template:

```markdown
# NN -- Category Name

## Purpose

One-paragraph description of what this category tests.

## OWASP Alignment

Which OWASP category (LLM01, LLM02, ASI-xx, etc.) this maps to.

## What the Script Tests

| # | Check | What It Reveals |
|---|-------|-----------------|
| 1 | Description of check | What you learn from it |

## Usage

\`\`\`bash
docker exec ClawSandbox bash /home/openclaw/tests/NN-category/script.sh
\`\`\`

## Key Findings

| Finding | Detail |
|---------|--------|
| Finding name | What was discovered |

## Interpretation

Paragraph explaining what the findings mean and their security implications.

## Files

- `script.sh` -- Description of the script
```

### Step 3: Add the Test Script

Write a bash script that performs the security checks. Follow these conventions:

- **Shebang:** `#!/bin/bash`
- **Error handling:** Use `set -uo pipefail` at the top.
- **Output:** Print results to stdout. The runner captures output via `tee`.
- **Results directory:** Write detailed findings to `/tmp/results/NN-category/`.
- **Self-contained:** The script should work when executed in isolation, not just through the runner.

Example skeleton:

```bash
#!/bin/bash
# ============================================================
# script-name.sh -- Description
# ============================================================
set -uo pipefail

RESULTS_DIR="/tmp/results/NN-category"
mkdir -p "$RESULTS_DIR"

echo "============================================"
echo " Category Name Tests"
echo " $(date -u)"
echo "============================================"

# --- Test 1 ---
echo "[*] Check description..."
# ... test logic ...
echo "    Result: PASS/FAIL/INFO"
```

### Step 4: Update run-all.sh

If your test category should run as part of the automated suite (no internet required), add it to `tests/run-all.sh`. Edit the `for` loop to include your new script:

```bash
for script in \
    "$SCRIPTS_DIR/01-recon/recon.sh" \
    "$SCRIPTS_DIR/02-privilege-escalation/privesc.sh" \
    "$SCRIPTS_DIR/03-data-exfiltration/exfil.sh" \
    "$SCRIPTS_DIR/05-general-audit/audit.sh" \
    "$SCRIPTS_DIR/NN-your-category/your-script.sh"; do
```

If your test requires internet access (like category 04), do NOT add it to `run-all.sh`. Instead, document how to run it manually in your `README.md`.

### Step 5: Add Payload Files (If Applicable)

If your tests use external payload files (like category 04's prompt injection payloads), create a `payloads/` subdirectory:

```
tests/NN-category/
  README.md
  script.sh
  payloads/
    payload-1.txt
    payload-2.md
```

---

## Payload Safety Rules

All test payloads in this repository must follow strict safety rules to prevent accidental harm.

### Use attacker.example for All URLs

All exfiltration URLs, webhook endpoints, and callback addresses must use the `attacker.example` domain:

```
http://attacker.example/steal
http://attacker.example/exfil?data=...
http://attacker.example/init
```

The `.example` TLD is permanently reserved by IANA (RFC 2606 / RFC 6761) and will never resolve to a real server. This ensures that even if a payload is accidentally executed outside the sandbox, no data is sent anywhere.

**Do not use:**

- Real domains (e.g., `evil.com`, `requestbin.net`)
- IP addresses (e.g., `192.168.1.100`, `10.0.0.1`)
- `localhost` or `127.0.0.1` as attack targets (these could hit real local services)

### Never Include Real Credentials

Payloads must never contain real API keys, tokens, passwords, or other secrets. If a payload needs to reference a credential, use obviously fake values:

```
# Good
sk-fake-test-key-not-real
AKIA_FAKE_ACCESS_KEY_ID

# Bad -- these look real and could cause confusion
sk-proj-abc123def456ghi789...
AKIAIOSFODNN7EXAMPLE
```

### Never Target Real Systems

Payloads must only target the sandboxed container itself or the reserved `attacker.example` domain. Never craft payloads that target:

- Real cloud services (AWS, GCP, Azure)
- Real websites or APIs
- Internal network ranges (unless testing within your own infrastructure)
- Other users' systems

### Clearly Document Payload Intent

Every payload file should be accompanied by documentation (in the category README or inline comments) that explains:

- What the payload is designed to test.
- What a vulnerable response looks like.
- What a defended response looks like.

---

## Results Format

If your tests produce results that should be included in the repository, follow the format established in the `results/` directory.

### File Format

Results are written as Markdown files in `results/`:

```
results/
  README.md                 # Index of all result files
  prompt-injection.md       # Prompt injection test results
  container-security.md     # Container isolation assessment
  code-audit.md             # Static code audit findings
  your-new-results.md       # Your contribution
```

### Structure

Each results file should include:

1. **Title** -- `# Category Name Results`
2. **Test Environment table** -- target version, container config, date, method.
3. **Individual test sections** -- one per test, each with:
   - OWASP category and technique
   - Payload (the exact input)
   - Raw response (the exact output)
   - Verdict (VULNERABLE, DEFENDED, PARTIAL, UNCLEAR)
   - Analysis (what the result means)
4. **Summary table** -- all tests with verdicts.
5. **Recommendations** -- immediate, short-term, and long-term mitigations.

See `results/prompt-injection.md` for a detailed example of this format.

### Update results/README.md

Add your new results file to the index in `results/README.md`:

```markdown
- **your-results.md** -- Brief description of what the file covers.
```

---

## Testing Your Changes

Before submitting a pull request, verify that your changes work correctly in the sandbox.

### Step 1: Build the Container

Rebuild to pick up any new or modified scripts:

```bash
cd docker && docker compose build
```

### Step 2: Run Your Tests

Start the container and run your test:

```bash
docker compose up -d

# For automated tests (sandbox-isolated):
docker exec ClawSandbox bash /home/openclaw/tests/NN-category/your-script.sh

# For tests requiring internet (sandbox-internet):
docker exec -e GEMINI_API_KEY=your-key ClawSandbox \
    bash /home/openclaw/tests/NN-category/your-script.sh
```

### Step 3: Run the Full Suite

Ensure your changes do not break existing tests:

```bash
docker exec ClawSandbox bash /home/openclaw/tests/run-all.sh
```

### Step 4: Verify Results

Check that:

- Your script exits with code 0 on success.
- Results are written to the expected location (`/tmp/results/`).
- Output is clear and follows the conventions of existing scripts.
- No real URLs, credentials, or sensitive data appear in your payloads or results.

### Step 5: Check for Line Ending Issues

If you are developing on Windows, ensure your scripts use Unix line endings (LF, not CRLF):

```bash
# Check for Windows line endings
file tests/NN-category/your-script.sh
# Should say "ASCII text", NOT "ASCII text, with CRLF line terminators"

# Fix if needed
sed -i 's/\r$//' tests/NN-category/your-script.sh
```

---

## Code of Conduct

- This project is for authorized security testing and educational purposes only.
- Never use these tools or techniques against systems you do not own or have explicit authorization to test.
- Report any real vulnerabilities you discover in OpenClaw through responsible disclosure channels, not through public issues in this repository.
- Be respectful and constructive in all interactions.
