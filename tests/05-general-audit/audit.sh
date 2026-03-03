#!/bin/bash
# ============================================================
# 05-general-audit.sh — General Security Audit
# Broad analysis of OpenClaw's security posture covering
# dependency vulnerabilities, code patterns, and runtime behavior.
# ============================================================
set -uo pipefail

RESULTS_DIR="/tmp/results/05-general"
mkdir -p "$RESULTS_DIR"

echo "=== General Security Audit ==="
echo "Date: $(date -u)"
echo ""

# 1. npm dependency audit
echo "[*] Running npm dependency audit..."
{
    OPENCLAW_PKG=$(npm root -g 2>/dev/null)/openclaw
    if [ -d "$OPENCLAW_PKG" ]; then
        cd "$OPENCLAW_PKG"
        echo "--- npm audit ---"
        npm audit 2>&1 || echo "npm audit encountered issues"
        echo ""
        echo "--- Total dependencies ---"
        find node_modules -name "package.json" -maxdepth 2 2>/dev/null | wc -l
        echo ""
        echo "--- Dependencies with native addons ---"
        find node_modules -name "binding.gyp" 2>/dev/null
        echo ""
        echo "--- Dependencies with install scripts ---"
        find node_modules -maxdepth 2 -name "package.json" -exec grep -l '"install"\|"preinstall"\|"postinstall"' {} \; 2>/dev/null | head -20
        cd /home/openclaw
    else
        echo "OpenClaw package directory not found"
    fi
} > "$RESULTS_DIR/dependency-audit.txt" 2>&1
echo "  -> Saved to dependency-audit.txt"

# 2. Dangerous code patterns in OpenClaw source
echo "[*] Scanning for dangerous code patterns..."
{
    OPENCLAW_PKG=$(npm root -g 2>/dev/null)/openclaw
    if [ -d "$OPENCLAW_PKG" ]; then
        echo "--- eval() usage ---"
        grep -rn "eval(" "$OPENCLAW_PKG/dist/" 2>/dev/null | head -20 || echo "None found"
        echo ""
        echo "--- child_process / exec usage ---"
        grep -rn "child_process\|\.exec(\|\.execSync(\|\.spawn(" "$OPENCLAW_PKG/dist/" 2>/dev/null | head -30 || echo "None found"
        echo ""
        echo "--- Dynamic require/import ---"
        grep -rn "require(\s*[^'\"]" "$OPENCLAW_PKG/dist/" 2>/dev/null | head -20 || echo "None found"
        echo ""
        echo "--- Unsafe deserialization ---"
        grep -rn "JSON\.parse\|deserialize\|unserialize\|pickle" "$OPENCLAW_PKG/dist/" 2>/dev/null | head -20 || echo "None found"
        echo ""
        echo "--- Shell injection vectors ---"
        grep -rn "exec.*\\\$\|exec.*\`\|spawn.*\\\$\|system(" "$OPENCLAW_PKG/dist/" 2>/dev/null | head -20 || echo "None found"
        echo ""
        echo "--- Hardcoded secrets ---"
        grep -rniE "(api.?key|secret|token|password)\s*[:=]\s*['\"][a-zA-Z0-9]" "$OPENCLAW_PKG/dist/" 2>/dev/null | head -20 || echo "None found"
        echo ""
        echo "--- HTTP (non-HTTPS) URLs ---"
        grep -rn "http://" "$OPENCLAW_PKG/dist/" 2>/dev/null | grep -v "localhost\|127.0.0.1\|0.0.0.0" | head -20 || echo "None found"
    else
        echo "OpenClaw package directory not found"
    fi
} > "$RESULTS_DIR/code-patterns.txt" 2>&1
echo "  -> Saved to code-patterns.txt"

# 3. File permissions audit
echo "[*] Auditing file permissions..."
{
    echo "--- World-writable files ---"
    find / -writable -type f 2>/dev/null | grep -v "^/proc\|^/sys\|^/dev\|^/tmp" | head -30
    echo ""
    echo "--- World-readable sensitive files ---"
    for f in /etc/shadow /etc/gshadow /root/.ssh; do
        ls -la "$f" 2>/dev/null && echo "WARNING: $f is accessible"
    done
    echo ""
    echo "--- OpenClaw file permissions ---"
    ls -laR ~/.openclaw/ 2>/dev/null | head -50
} > "$RESULTS_DIR/file-permissions.txt" 2>&1
echo "  -> Saved to file-permissions.txt"

# 4. Daemon / service behavior
echo "[*] Checking daemon behavior..."
{
    echo "--- Systemd services ---"
    systemctl list-units 2>/dev/null | grep -i openclaw || echo "No systemd services (expected in container)"
    echo ""
    echo "--- Cron jobs ---"
    crontab -l 2>&1 || echo "No cron jobs"
    ls -la /etc/cron* 2>/dev/null | head -20
    echo ""
    echo "--- Listening daemons after OpenClaw start ---"
    echo "(Run this after starting OpenClaw to see what ports it opens)"
    ss -tlnp 2>/dev/null || echo "ss not available"
} > "$RESULTS_DIR/daemon-behavior.txt" 2>&1
echo "  -> Saved to daemon-behavior.txt"

# 5. TLS/Certificate validation
echo "[*] Checking TLS configuration..."
{
    echo "--- CA certificates ---"
    ls /etc/ssl/certs/ 2>/dev/null | wc -l
    echo ""
    echo "--- Node.js TLS settings ---"
    node -e "
    const tls = require('tls');
    console.log('Min TLS version:', tls.DEFAULT_MIN_VERSION);
    console.log('Max TLS version:', tls.DEFAULT_MAX_VERSION);
    console.log('NODE_TLS_REJECT_UNAUTHORIZED:', process.env.NODE_TLS_REJECT_UNAUTHORIZED || 'not set (default: verify)');
    " 2>/dev/null || echo "Cannot query Node.js TLS"
} > "$RESULTS_DIR/tls-config.txt" 2>&1
echo "  -> Saved to tls-config.txt"

# 6. Summary report
echo "[*] Generating summary..."
{
    echo "============================================"
    echo " OpenClaw Security Audit Summary"
    echo " Date: $(date -u)"
    echo "============================================"
    echo ""
    echo "Container Security:"
    echo "  - Capabilities: $(grep -c 'Cap' /proc/self/status 2>/dev/null || echo 'unknown')"
    echo "  - Running as: $(whoami) (UID $(id -u))"
    echo "  - Docker socket: $(ls /var/run/docker.sock 2>/dev/null && echo 'EXPOSED' || echo 'Not accessible')"
    echo "  - Read-only rootfs: $(touch /testfile 2>/dev/null && echo 'NO (writable!)' && rm /testfile || echo 'Yes')"
    echo ""
    echo "Network:"
    echo "  - Outbound HTTP: $(curl -s --max-time 3 https://httpbin.org/ip 2>/dev/null && echo 'ALLOWED' || echo 'Blocked')"
    echo "  - DNS: $(nslookup google.com 2>/dev/null && echo 'ALLOWED' || echo 'Blocked')"
    echo ""
    echo "Files:"
    echo "  - /etc/shadow readable: $(cat /etc/shadow 2>/dev/null && echo 'YES (bad!)' || echo 'No (good)')"
    echo "  - SUID binaries: $(find / -perm -4000 -type f 2>/dev/null | wc -l)"
    echo ""
    echo "Detailed results in: /tmp/results/"
    echo ""
    echo "Next steps:"
    echo "  1. Review each results file for flagged issues"
    echo "  2. Run prompt injection tests with a live LLM connection"
    echo "  3. Monitor network captures: docker logs openclaw-netmon"
    echo "  4. Test OpenClaw skills with adversarial inputs"
} | tee "$RESULTS_DIR/summary.txt"

echo ""
echo "=== General audit complete. Results in $RESULTS_DIR ==="
ls -la "$RESULTS_DIR/"
