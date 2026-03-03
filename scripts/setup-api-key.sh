#!/bin/bash
# ============================================================
# setup-api-key.sh — Configure LLM API key inside the sandbox
#
# Usage:
#   bash setup-api-key.sh gemini YOUR_KEY
#   bash setup-api-key.sh openai YOUR_KEY
#   bash setup-api-key.sh anthropic YOUR_KEY
# ============================================================
set -euo pipefail

PROVIDER="${1:-}"
API_KEY="${2:-}"

if [ -z "$PROVIDER" ] || [ -z "$API_KEY" ]; then
    echo "Usage: bash setup-api-key.sh <provider> <api-key>"
    echo ""
    echo "Providers:"
    echo "  gemini     Google Gemini (recommended for free tier)"
    echo "  openai     OpenAI GPT models"
    echo "  anthropic  Anthropic Claude models"
    exit 1
fi

CONFIG_DIR="$HOME/.openclaw/agents/main/agent"
mkdir -p "$CONFIG_DIR"

case "$PROVIDER" in
    gemini)
        cat > "$CONFIG_DIR/auth-profiles.json" << EOF
{
  "version": 1,
  "profiles": {
    "google:default": {
      "type": "api_key",
      "provider": "google",
      "key": "$API_KEY"
    }
  },
  "lastGood": { "google": "google:default" }
}
EOF
        export GEMINI_API_KEY="$API_KEY"
        echo "Gemini API key configured."
        echo "Run: export GEMINI_API_KEY=$API_KEY"
        ;;
    openai)
        cat > "$CONFIG_DIR/auth-profiles.json" << EOF
{
  "version": 1,
  "profiles": {
    "openai:default": {
      "type": "api_key",
      "provider": "openai",
      "key": "$API_KEY"
    }
  },
  "lastGood": { "openai": "openai:default" }
}
EOF
        export OPENAI_API_KEY="$API_KEY"
        echo "OpenAI API key configured."
        echo "Run: export OPENAI_API_KEY=$API_KEY"
        ;;
    anthropic)
        cat > "$CONFIG_DIR/auth-profiles.json" << EOF
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "api_key",
      "provider": "anthropic",
      "key": "$API_KEY"
    }
  },
  "lastGood": { "anthropic": "anthropic:default" }
}
EOF
        export ANTHROPIC_API_KEY="$API_KEY"
        echo "Anthropic API key configured."
        echo "Run: export ANTHROPIC_API_KEY=$API_KEY"
        ;;
    *)
        echo "Unknown provider: $PROVIDER"
        echo "Supported: gemini, openai, anthropic"
        exit 1
        ;;
esac

echo ""
echo "Key stored in: $CONFIG_DIR/auth-profiles.json"
echo "Remember to revoke this key after testing."
