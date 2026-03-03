#!/bin/bash
# ============================================================
# run-all.sh — Run all automated security analysis scripts
# ============================================================
set -uo pipefail

echo "============================================"
echo " OpenClaw Security Analysis Suite"
echo " $(date -u)"
echo "============================================"
echo ""

SCRIPTS_DIR="$(dirname "$0")"
RESULTS_BASE="/tmp/results"
mkdir -p "$RESULTS_BASE"

for script in \
    "$SCRIPTS_DIR/01-recon/recon.sh" \
    "$SCRIPTS_DIR/02-privilege-escalation/privesc.sh" \
    "$SCRIPTS_DIR/03-data-exfiltration/exfil.sh" \
    "$SCRIPTS_DIR/05-general-audit/audit.sh"; do
    echo ""
    echo ">>>>>>>>>> Running: $(basename "$script") <<<<<<<<<<"
    echo ""
    bash "$script" 2>&1 | tee "$RESULTS_BASE/$(basename "$script" .sh).log"
    echo ""
    echo ">>>>>>>>>> Finished: $(basename "$script") <<<<<<<<<<"
    echo ""
done

echo ""
echo "============================================"
echo " All automated tests complete!"
echo " Results: $RESULTS_BASE/"
echo "============================================"
echo ""
echo "Summary of results:"
find "$RESULTS_BASE" -name "*.txt" -o -name "*.json" -o -name "*.log" | sort
echo ""
echo "To run prompt injection tests interactively:"
echo "  bash $SCRIPTS_DIR/04-prompt-injection/run-tests.sh"
