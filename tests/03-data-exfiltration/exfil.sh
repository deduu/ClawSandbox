#!/bin/bash
# ============================================================
# 03-data-exfiltration.sh — Data Exfiltration Risk Analysis
# Tests whether OpenClaw can access or leak sensitive data
# from the container or host environment.
# ============================================================
set -uo pipefail

RESULTS_DIR="/tmp/results/03-exfil"
mkdir -p "$RESULTS_DIR"

echo "=== Data Exfiltration Risk Analysis ==="
echo "Date: $(date -u)"
echo ""

# 1. Sensitive file access
echo "[*] Checking access to sensitive files..."
{
    echo "--- /etc/shadow ---"
    cat /etc/shadow 2>&1 | head -3 || echo "Cannot read (good)"
    echo ""
    echo "--- /etc/passwd ---"
    cat /etc/passwd 2>&1
    echo ""
    echo "--- SSH keys ---"
    find /home -name "id_rsa" -o -name "id_ed25519" -o -name "*.pem" 2>/dev/null || echo "None found"
    echo ""
    echo "--- Cloud credentials ---"
    for f in ~/.aws/credentials ~/.azure/credentials ~/.config/gcloud/credentials.db; do
        if [ -r "$f" ]; then
            echo "WARNING: Readable: $f"
        else
            echo "OK: Not accessible: $f"
        fi
    done
    echo ""
    echo "--- .env files ---"
    find /home -name ".env" -o -name ".env.*" 2>/dev/null || echo "None found"
} > "$RESULTS_DIR/sensitive-files.txt"
echo "  -> Saved to sensitive-files.txt"

# 2. OpenClaw config files that might store API keys
echo "[*] Checking OpenClaw config for stored secrets..."
{
    echo "--- OpenClaw config ---"
    cat ~/.openclaw/openclaw.json 2>/dev/null || echo "No config found"
    echo ""
    echo "--- Looking for API keys in config directory ---"
    find ~/.openclaw -type f 2>/dev/null | while read -r f; do
        echo "File: $f"
        # Check if file contains anything that looks like an API key
        grep -iE '(api.?key|token|secret|password|bearer)' "$f" 2>/dev/null && echo "  ^ WARNING: Possible credential" || echo "  (clean)"
    done
} > "$RESULTS_DIR/openclaw-secrets.txt"
echo "  -> Saved to openclaw-secrets.txt"

# 3. Network exfiltration paths
echo "[*] Testing network exfiltration paths..."
{
    echo "--- DNS resolution ---"
    nslookup google.com 2>&1 || echo "DNS blocked (good for isolated network)"
    echo ""
    echo "--- HTTP outbound ---"
    curl -s --max-time 5 https://httpbin.org/ip 2>&1 || echo "HTTP outbound blocked (good for isolated network)"
    echo ""
    echo "--- Raw TCP ---"
    timeout 3 bash -c 'echo test > /dev/tcp/8.8.8.8/53' 2>&1 || echo "Raw TCP blocked (good)"
    echo ""
    echo "--- Available network interfaces ---"
    ip addr 2>/dev/null || ifconfig 2>/dev/null || echo "Cannot enumerate interfaces"
} > "$RESULTS_DIR/network-exfil.txt"
echo "  -> Saved to network-exfil.txt"

# 4. Host metadata access (cloud environments)
echo "[*] Checking cloud metadata access..."
{
    echo "--- AWS metadata ---"
    curl -s --max-time 3 http://169.254.169.254/latest/meta-data/ 2>&1 || echo "AWS metadata not accessible"
    echo ""
    echo "--- GCP metadata ---"
    curl -s --max-time 3 -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/ 2>&1 || echo "GCP metadata not accessible"
    echo ""
    echo "--- Azure metadata ---"
    curl -s --max-time 3 -H "Metadata: true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" 2>&1 || echo "Azure metadata not accessible"
} > "$RESULTS_DIR/cloud-metadata.txt"
echo "  -> Saved to cloud-metadata.txt"

# 5. Process memory / environment variable leakage
echo "[*] Checking for env/memory leakage vectors..."
{
    echo "--- /proc/self/environ ---"
    cat /proc/self/environ 2>/dev/null | tr '\0' '\n' | sed 's/\(KEY\|TOKEN\|SECRET\|PASSWORD\|API\)=.*/\1=<REDACTED>/' || echo "Cannot read"
    echo ""
    echo "--- /proc/self/cmdline ---"
    cat /proc/self/cmdline 2>/dev/null | tr '\0' ' ' || echo "Cannot read"
    echo ""
    echo "--- Can we read other processes' environ? ---"
    for pid in $(ls /proc/ 2>/dev/null | grep -E '^[0-9]+$' | head -10); do
        cat "/proc/$pid/environ" 2>/dev/null && echo "WARNING: Can read PID $pid environ" || true
    done
    echo "(End of process environ check)"
} > "$RESULTS_DIR/memory-leakage.txt"
echo "  -> Saved to memory-leakage.txt"

# 6. OpenClaw skill/plugin data access
echo "[*] Checking OpenClaw skills directory for data access patterns..."
{
    echo "--- Installed skills ---"
    ls -la ~/.openclaw/workspace/skills/ 2>/dev/null || echo "No skills directory"
    echo ""
    echo "--- Skills with filesystem access ---"
    find ~/.openclaw/workspace/skills/ -name "SKILL.md" 2>/dev/null | while read -r skill; do
        echo "Skill: $skill"
        grep -iE '(file|read|write|exec|shell|bash|system)' "$skill" 2>/dev/null | head -5
        echo "---"
    done
} > "$RESULTS_DIR/skill-data-access.txt"
echo "  -> Saved to skill-data-access.txt"

echo ""
echo "=== Data exfiltration tests complete. Results in $RESULTS_DIR ==="
ls -la "$RESULTS_DIR/"
