#!/bin/bash
# ============================================================
# 01-recon.sh — Reconnaissance & Attack Surface Enumeration
# Maps out OpenClaw's filesystem footprint, processes, network
# listeners, and installed capabilities.
# ============================================================
set -euo pipefail

RESULTS_DIR="/tmp/results/01-recon"
mkdir -p "$RESULTS_DIR"

echo "=== OpenClaw Reconnaissance ==="
echo "Date: $(date -u)"
echo ""

# 1. Installed files & permissions
echo "[*] Enumerating OpenClaw installation files..."
OPENCLAW_BIN=$(which openclaw 2>/dev/null || echo "NOT_FOUND")
echo "Binary: $OPENCLAW_BIN" | tee "$RESULTS_DIR/install-info.txt"

if [ "$OPENCLAW_BIN" != "NOT_FOUND" ]; then
    echo "" >> "$RESULTS_DIR/install-info.txt"
    echo "--- Binary permissions ---" >> "$RESULTS_DIR/install-info.txt"
    ls -la "$OPENCLAW_BIN" >> "$RESULTS_DIR/install-info.txt" 2>&1

    # Find the npm global package directory
    NPM_ROOT=$(npm root -g 2>/dev/null || echo "UNKNOWN")
    echo "NPM global root: $NPM_ROOT" | tee -a "$RESULTS_DIR/install-info.txt"

    if [ -d "$NPM_ROOT/openclaw" ]; then
        echo "" >> "$RESULTS_DIR/install-info.txt"
        echo "--- Package file count ---" >> "$RESULTS_DIR/install-info.txt"
        find "$NPM_ROOT/openclaw" -type f | wc -l >> "$RESULTS_DIR/install-info.txt"

        echo "" >> "$RESULTS_DIR/install-info.txt"
        echo "--- SUID/SGID binaries in package ---" >> "$RESULTS_DIR/install-info.txt"
        find "$NPM_ROOT/openclaw" -perm /6000 -type f 2>/dev/null >> "$RESULTS_DIR/install-info.txt" || echo "None found" >> "$RESULTS_DIR/install-info.txt"

        echo "" >> "$RESULTS_DIR/install-info.txt"
        echo "--- Executable files ---" >> "$RESULTS_DIR/install-info.txt"
        find "$NPM_ROOT/openclaw" -perm /111 -type f 2>/dev/null | head -50 >> "$RESULTS_DIR/install-info.txt"
    fi
fi

# 2. Configuration files
echo "[*] Checking default configuration..."
cat ~/.openclaw/openclaw.json 2>/dev/null > "$RESULTS_DIR/default-config.json" || echo "{}" > "$RESULTS_DIR/default-config.json"
echo "Config saved to $RESULTS_DIR/default-config.json"

# 3. Environment variables
echo "[*] Dumping environment variables (redacting secrets)..."
env | sed 's/\(KEY\|TOKEN\|SECRET\|PASSWORD\|API\)=.*/\1=<REDACTED>/' | sort > "$RESULTS_DIR/env-vars.txt"

# 4. Network listeners
echo "[*] Checking network listeners..."
ss -tlnp 2>/dev/null > "$RESULTS_DIR/listeners.txt" || netstat -tlnp 2>/dev/null > "$RESULTS_DIR/listeners.txt" || echo "Could not enumerate listeners" > "$RESULTS_DIR/listeners.txt"

# 5. Running processes
echo "[*] Enumerating processes..."
ps aux > "$RESULTS_DIR/processes.txt" 2>&1

# 6. User & permission context
echo "[*] Checking user context..."
{
    echo "--- whoami ---"
    whoami
    echo ""
    echo "--- id ---"
    id
    echo ""
    echo "--- groups ---"
    groups
    echo ""
    echo "--- sudo access ---"
    sudo -l 2>&1 || echo "sudo not available"
} > "$RESULTS_DIR/user-context.txt"

# 7. Filesystem write access
echo "[*] Testing filesystem write access..."
{
    echo "--- Writable directories ---"
    for dir in / /etc /var /usr /tmp /home/openclaw; do
        if [ -w "$dir" ] 2>/dev/null; then
            echo "WRITABLE: $dir"
        else
            echo "READ-ONLY: $dir"
        fi
    done
} > "$RESULTS_DIR/fs-access.txt"

# 8. Installed tools that could be abused
echo "[*] Checking for potentially dangerous tools..."
{
    for tool in curl wget nc ncat socat python python3 perl ruby gcc make; do
        if command -v "$tool" &>/dev/null; then
            echo "FOUND: $tool ($(which $tool))"
        else
            echo "MISSING: $tool"
        fi
    done
} > "$RESULTS_DIR/available-tools.txt"

echo ""
echo "=== Recon complete. Results in $RESULTS_DIR ==="
ls -la "$RESULTS_DIR/"
