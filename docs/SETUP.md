# Setup Guide

Step-by-step instructions for building and running the ClawSandbox security testing toolkit.

---

## Prerequisites

Before you begin, ensure you have the following installed:

| Requirement | Minimum Version | Notes |
|---|---|---|
| **Docker** | 20.10+ | Docker Desktop (Windows/Mac) or Docker Engine (Linux) |
| **Docker Compose** | v2.0+ | Included with Docker Desktop; verify with `docker compose version` |
| **Git** | 2.30+ | For cloning the repository |
| **LLM API Key** | -- | Only needed for prompt injection tests (category 04) |

### LLM API Key

Prompt injection tests call an LLM API directly. You need an API key from at least one provider:

- **Gemini (recommended)** -- Google AI Studio offers a free tier. Get a key at https://aistudio.google.com/apikey
- **OpenAI** -- Requires a paid account. Set `OPENAI_API_KEY` instead.
- **Anthropic** -- Requires a paid account. Set `ANTHROPIC_API_KEY` instead.

The default test scripts target the Gemini API. If you use a different provider, you will need to modify `tests/04-prompt-injection/run-via-api.sh`.

---

## Clone the Repository

```bash
git clone https://github.com/deduu/ClawSandbox.git
cd ClawSandbox
```

---

## Build the Container

All Docker configuration lives in the `docker/` directory. The Dockerfile builds a hardened container image with OpenClaw pre-installed.

```bash
cd docker && docker compose build
```

This will:

1. Pull the `node:22-slim` base image.
2. Create a non-root `openclaw` user (UID 999).
3. Install minimal system tools (`curl`, `git`, `strace`, `iproute2`, etc.).
4. Install `openclaw@latest` globally via npm.
5. Copy test scripts from `tests/` into the container.

Build time is typically 2-5 minutes depending on your network speed.

---

## Run Automated Tests (No Internet Needed)

The automated test suite (categories 01-03 and 05) runs entirely inside the container with no outbound network access. These tests assess container isolation, privilege escalation paths, data exfiltration potential, and code audit findings.

### Step 1: Ensure the Isolated Network Is Selected

Open `docker/docker-compose.yml` and verify the `networks` section under the `ClawSandbox` service uses `sandbox-isolated`:

```yaml
    networks:
      - sandbox-isolated
```

This is the default configuration. If you previously switched to `sandbox-internet`, change it back.

### Step 2: Start the Container

```bash
docker compose up -d
```

### Step 3: Run the Tests

```bash
docker exec ClawSandbox bash /home/openclaw/tests/run-all.sh
```

The test runner executes all automated scripts sequentially and writes results to `/tmp/results/` inside the container. Output is also printed to your terminal via `tee`.

### Step 4: View Results

Results are stored inside the container. To read them:

```bash
docker exec ClawSandbox cat /tmp/results/recon.log
docker exec ClawSandbox cat /tmp/results/privesc.log
docker exec ClawSandbox cat /tmp/results/exfil.log
docker exec ClawSandbox cat /tmp/results/audit.log
```

---

## Run Prompt Injection Tests (Internet Needed)

Prompt injection tests (category 04) require outbound internet access to reach the Gemini API. These tests send adversarial payloads to the LLM and analyze the responses.

### Step 1: Switch to the Internet-Enabled Network

Edit `docker/docker-compose.yml` and change the `networks` section under the `ClawSandbox` service:

```yaml
    # Change this:
    networks:
      - sandbox-isolated

    # To this:
    networks:
      - sandbox-internet
```

### Step 2: Configure Your API Key

Set your Gemini API key as an environment variable. You can either:

**Option A:** Add it to the `docker-compose.yml` under the `ClawSandbox` service:

```yaml
    environment:
      - GEMINI_API_KEY=your-key-here
```

**Option B:** Pass it at runtime via `docker exec`:

```bash
docker exec -e GEMINI_API_KEY=your-key-here ClawSandbox \
    bash /home/openclaw/tests/04-prompt-injection/run-via-api.sh
```

### Step 3: Rebuild and Restart

```bash
docker compose down
docker compose build
docker compose up -d
```

### Step 4: Run the Prompt Injection Tests

```bash
docker exec -e GEMINI_API_KEY=your-key-here ClawSandbox \
    bash /home/openclaw/tests/04-prompt-injection/run-via-api.sh
```

The script runs 5 tests with 20-second cooldowns between each to avoid rate limiting. Total runtime is approximately 3 minutes.

### Step 5: Switch Back to Isolated Network

After testing, switch `docker-compose.yml` back to `sandbox-isolated` to restore full network isolation:

```yaml
    networks:
      - sandbox-isolated
```

Then rebuild:

```bash
docker compose down && docker compose up -d
```

---

## Switching Between Network Modes

The `docker/docker-compose.yml` file defines two networks:

```yaml
networks:
  # No external/internet access -- safe for automated tests
  sandbox-isolated:
    driver: bridge
    internal: true

  # Enable this for LLM API testing (prompt injection tests)
  sandbox-internet:
    driver: bridge
```

To switch, change the `networks` list under the `ClawSandbox` service:

| Network | Use Case | Internet Access |
|---|---|---|
| `sandbox-isolated` | Automated tests (01-03, 05) | Blocked |
| `sandbox-internet` | Prompt injection tests (04) | Allowed |

After switching, always run `docker compose down && docker compose up -d` to apply the change.

---

## Troubleshooting

### Windows Line Endings (CRLF)

If scripts fail with errors like `/bin/bash^M: bad interpreter` or `syntax error near unexpected token '$'\r''`, the files have Windows-style line endings (CRLF instead of LF).

**Fix:** Convert line endings inside the container or before building:

```bash
# Inside the container
sed -i 's/\r$//' /home/openclaw/tests/**/*.sh

# Or on the host before building (requires dos2unix or sed)
find tests/ -name "*.sh" -exec sed -i 's/\r$//' {} +
```

**Prevention:** Configure Git to handle line endings automatically:

```bash
git config --global core.autocrlf input
```

### Gemini API Rate Limits

The Gemini free tier has strict rate limits. If you see `RESOURCE_EXHAUSTED` errors:

1. **Use `gemini-2.5-flash`** (the default) -- it has the highest free-tier quota.
2. **Increase cooldown delays** -- the test script uses 20-second delays between tests. You can increase these by editing the `sleep` values in `run-via-api.sh`.
3. **Create a new GCP project** -- each Google Cloud project gets its own quota. Create a fresh project at https://console.cloud.google.com and generate a new API key there.
4. **Wait and retry** -- free-tier rate limits reset within minutes. Wait 2-3 minutes and run again.

### tmpfs Permission Errors

If you see permission denied errors when the container tries to write to `/tmp`, `/home/openclaw/.openclaw`, or `/home/openclaw/.npm`, the tmpfs mounts may have incorrect ownership.

The `docker-compose.yml` configures tmpfs with `uid=999,gid=999` to match the `openclaw` user:

```yaml
    tmpfs:
      - /tmp:size=100M,uid=999,gid=999
      - /home/openclaw/.openclaw:size=50M,uid=999,gid=999
      - /home/openclaw/.npm:size=100M,uid=999,gid=999
```

If your system assigns a different UID/GID to the `openclaw` user, check with:

```bash
docker exec ClawSandbox id
```

Then update the `uid` and `gid` values in the tmpfs configuration to match.

### Gateway Not Needed for --local Mode

If you are running OpenClaw in `--local` mode (using a local model via llama.cpp instead of a cloud API), you do not need the `sandbox-internet` network. The `sandbox-isolated` network is sufficient because all inference happens inside the container.

### Container Fails to Start

If `docker compose up -d` fails:

1. Ensure Docker is running: `docker info`
2. Check for port conflicts: `docker ps`
3. Rebuild from scratch: `docker compose build --no-cache`
4. Check logs: `docker compose logs ClawSandbox`

### Tests Produce No Output

If `run-all.sh` completes but produces no log files, ensure the results directory is writable:

```bash
docker exec ClawSandbox ls -la /tmp/results/
```

The `/tmp` directory is a tmpfs mount and should be writable by the `openclaw` user.
