#!/bin/bash
# ============================================================
# 02-privilege-escalation.sh — Privilege Escalation & Escape Tests
# Tests whether OpenClaw or its environment can be leveraged
# to escalate privileges or escape the container.
# ============================================================
set -uo pipefail

RESULTS_DIR="/tmp/results/02-privesc"
mkdir -p "$RESULTS_DIR"

echo "=== Privilege Escalation & Container Escape Tests ==="
echo "Date: $(date -u)"
echo ""

# 1. Check Linux capabilities
echo "[*] Checking container capabilities..."
{
    echo "--- /proc/self/status capabilities ---"
    grep -i cap /proc/self/status 2>/dev/null || echo "Cannot read capabilities"
    echo ""
    echo "--- capsh (if available) ---"
    capsh --print 2>/dev/null || echo "capsh not available"
} > "$RESULTS_DIR/capabilities.txt"
echo "  -> Saved to capabilities.txt"

# 2. Check for Docker socket access (container escape vector)
echo "[*] Checking for Docker socket access..."
{
    echo "--- Docker socket ---"
    ls -la /var/run/docker.sock 2>/dev/null && echo "WARNING: Docker socket accessible!" || echo "OK: Docker socket not accessible"
    echo ""
    echo "--- /.dockerenv ---"
    ls -la /.dockerenv 2>/dev/null || echo "No .dockerenv found"
    echo ""
    echo "--- cgroup info ---"
    cat /proc/1/cgroup 2>/dev/null | head -20 || echo "Cannot read cgroup"
} > "$RESULTS_DIR/container-escape.txt"
echo "  -> Saved to container-escape.txt"

# 3. Check /proc and /sys access
echo "[*] Probing /proc and /sys for sensitive info..."
{
    echo "--- /proc/sysrq-trigger ---"
    cat /proc/sysrq-trigger 2>&1 || echo "Cannot access (good)"
    echo ""
    echo "--- /proc/kcore ---"
    ls -la /proc/kcore 2>&1
    cat /proc/kcore 2>&1 | head -c 1 || echo "Cannot read (good)"
    echo ""
    echo "--- /sys/kernel ---"
    ls /sys/kernel/ 2>&1 | head -20
    echo ""
    echo "--- /proc/keys ---"
    cat /proc/keys 2>&1 | head -10 || echo "Cannot read (good)"
} > "$RESULTS_DIR/proc-sys-access.txt"
echo "  -> Saved to proc-sys-access.txt"

# 4. Check for setuid/setgid binaries
echo "[*] Scanning for SUID/SGID binaries..."
{
    echo "--- SUID binaries ---"
    find / -perm -4000 -type f 2>/dev/null
    echo ""
    echo "--- SGID binaries ---"
    find / -perm -2000 -type f 2>/dev/null
} > "$RESULTS_DIR/suid-sgid.txt"
echo "  -> Saved to suid-sgid.txt"

# 5. Test no-new-privileges enforcement
echo "[*] Testing no-new-privileges..."
{
    echo "--- Attempting to use setuid binary ---"
    # Try to use any found setuid binary
    su root -c "whoami" 2>&1 || echo "su blocked (expected with no-new-privileges)"
    echo ""
    echo "--- /proc/self/no_new_privs ---"
    cat /proc/self/attr/no_new_privs 2>/dev/null || cat /proc/self/status 2>/dev/null | grep -i nonewpriv || echo "Cannot determine no_new_privs status"
} > "$RESULTS_DIR/no-new-privs.txt"
echo "  -> Saved to no-new-privs.txt"

# 6. Namespace isolation check
echo "[*] Checking namespace isolation..."
{
    echo "--- PID namespace ---"
    echo "PID 1 command: $(cat /proc/1/cmdline 2>/dev/null | tr '\0' ' ' || echo 'cannot read')"
    echo ""
    echo "--- Network namespace ---"
    ip addr 2>/dev/null || echo "ip command not available"
    echo ""
    echo "--- Mount namespace ---"
    cat /proc/mounts 2>/dev/null | head -30 || echo "Cannot read mounts"
    echo ""
    echo "--- User namespace ---"
    cat /proc/self/uid_map 2>/dev/null || echo "Cannot read uid_map"
    cat /proc/self/gid_map 2>/dev/null || echo "Cannot read gid_map"
} > "$RESULTS_DIR/namespace-isolation.txt"
echo "  -> Saved to namespace-isolation.txt"

# 7. OpenClaw-specific: check if it spawns privileged processes
echo "[*] Checking OpenClaw process capabilities..."
{
    echo "--- OpenClaw binary info ---"
    file "$(which openclaw 2>/dev/null)" 2>/dev/null || echo "Cannot determine binary type"
    echo ""
    echo "--- Node.js version & capabilities ---"
    node -e "console.log('Node version:', process.version); console.log('Platform:', process.platform); console.log('Arch:', process.arch); console.log('UID:', process.getuid()); console.log('GID:', process.getgid());" 2>/dev/null || echo "Cannot query node"
} > "$RESULTS_DIR/openclaw-process.txt"
echo "  -> Saved to openclaw-process.txt"

echo ""
echo "=== Privilege escalation tests complete. Results in $RESULTS_DIR ==="
ls -la "$RESULTS_DIR/"
