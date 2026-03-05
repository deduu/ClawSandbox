#!/bin/bash
# ============================================================
# llm-provider.sh — Shared LLM Provider Helper
#
# Source this file from any test script to get provider-agnostic
# LLM API calls. Auto-detects provider from environment variables.
#
# Detection order: GEMINI_API_KEY -> OPENAI_API_KEY -> ANTHROPIC_API_KEY
# Fallback: auth-profiles.json (Gemini only)
#
# Provides:
#   LLM_PROVIDER    — "gemini", "openai", or "anthropic"
#   LLM_API_KEY     — the resolved API key
#   LLM_MODEL       — model name (overridable via env vars)
#   LLM_RATE_LIMIT_PATTERN — grep pattern for rate limit errors
#   call_llm()      — send a prompt, get raw JSON response
#   extract_text()  — parse response JSON to plain text
#
# Caller should set before sourcing:
#   SYSTEM_PROMPT   — system prompt text
#   LLM_MAX_TOKENS  — max output tokens (default: 512)
# ============================================================

LLM_MAX_TOKENS="${LLM_MAX_TOKENS:-512}"

# ---- Provider auto-detection ----
LLM_PROVIDER=""
LLM_API_KEY=""

if [ -n "${GEMINI_API_KEY:-}" ]; then
    LLM_PROVIDER="gemini"
    LLM_API_KEY="$GEMINI_API_KEY"
elif [ -n "${OPENAI_API_KEY:-}" ]; then
    LLM_PROVIDER="openai"
    LLM_API_KEY="$OPENAI_API_KEY"
elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    LLM_PROVIDER="anthropic"
    LLM_API_KEY="$ANTHROPIC_API_KEY"
fi

# Fallback: try auth-profiles.json for Gemini key
if [ -z "$LLM_API_KEY" ]; then
    AUTH_PROFILES_PATHS=(
        "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
        "/home/openclaw/.openclaw/agents/main/agent/auth-profiles.json"
    )
    for auth_file in "${AUTH_PROFILES_PATHS[@]}"; do
        if [ -f "$auth_file" ]; then
            LLM_API_KEY=$(grep -o '"key": *"[^"]*"' "$auth_file" 2>/dev/null \
                | head -1 \
                | sed 's/.*"key": *"//;s/"//')
            if [ -n "$LLM_API_KEY" ]; then
                LLM_PROVIDER="gemini"
                echo "API key loaded from: $auth_file"
                break
            fi
        fi
    done
fi

if [ -z "$LLM_API_KEY" ]; then
    echo "ERROR: No API key found."
    echo "Set one of: GEMINI_API_KEY, OPENAI_API_KEY, or ANTHROPIC_API_KEY"
    exit 1
fi

# ---- Model defaults (overridable via env vars) ----
case "$LLM_PROVIDER" in
    gemini)
        LLM_MODEL="${GEMINI_MODEL:-gemini-2.5-flash}"
        LLM_RATE_LIMIT_PATTERN="RESOURCE_EXHAUSTED\|rate.limit\|quota"
        ;;
    openai)
        LLM_MODEL="${OPENAI_MODEL:-gpt-4o}"
        LLM_RATE_LIMIT_PATTERN="rate_limit\|Rate limit\|429\|Too Many Requests"
        ;;
    anthropic)
        LLM_MODEL="${ANTHROPIC_MODEL:-claude-sonnet-4-20250514}"
        LLM_RATE_LIMIT_PATTERN="rate_limit\|overloaded\|529\|Too Many Requests"
        ;;
esac

echo "Provider: $LLM_PROVIDER"
echo "API key:  ...${LLM_API_KEY: -4} (${#LLM_API_KEY} chars)"
echo "Model:    $LLM_MODEL"
echo ""

# ---- Helper: JSON-escape a string via python3 ----
_json_escape() {
    echo "$1" | tr -d '\r' | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
        || echo "\"$(echo "$1" | tr -d '\r' | sed 's/\\/\\\\/g;s/"/\\"/g' | tr '\n' ' ')\""
}

# ---- call_llm(payload) — provider-specific curl call ----
call_llm() {
    local payload="$1"
    local escaped_system escaped_payload json_payload

    escaped_system=$(_json_escape "$SYSTEM_PROMPT")
    escaped_payload=$(_json_escape "$payload")

    case "$LLM_PROVIDER" in
        gemini)
            local api_url="https://generativelanguage.googleapis.com/v1beta/models/${LLM_MODEL}:generateContent?key=${LLM_API_KEY}"
            json_payload=$(cat <<JSONEOF
{
  "system_instruction": {
    "parts": [{"text": ${escaped_system}}]
  },
  "contents": [
    {
      "role": "user",
      "parts": [{"text": ${escaped_payload}}]
    }
  ],
  "generationConfig": {
    "maxOutputTokens": ${LLM_MAX_TOKENS},
    "temperature": 0.1
  }
}
JSONEOF
)
            curl -s --max-time 30 "$api_url" \
                -H "Content-Type: application/json" \
                -d "$json_payload" 2>&1
            ;;

        openai)
            # Use Responses API — works with both OpenAI and Azure OpenAI
            local base_url="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
            # Strip trailing slash to avoid double-slash in URL
            base_url="${base_url%/}"
            local api_url="${base_url}/responses"
            json_payload=$(cat <<JSONEOF
{
  "model": "${LLM_MODEL}",
  "temperature": 0.1,
  "max_output_tokens": ${LLM_MAX_TOKENS},
  "instructions": ${escaped_system},
  "input": ${escaped_payload}
}
JSONEOF
)
            curl -s --max-time 30 "$api_url" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer ${LLM_API_KEY}" \
                -d "$json_payload" 2>&1
            ;;

        anthropic)
            json_payload=$(cat <<JSONEOF
{
  "model": "${LLM_MODEL}",
  "max_tokens": ${LLM_MAX_TOKENS},
  "system": ${escaped_system},
  "messages": [
    {"role": "user", "content": ${escaped_payload}}
  ]
}
JSONEOF
)
            curl -s --max-time 30 "https://api.anthropic.com/v1/messages" \
                -H "Content-Type: application/json" \
                -H "x-api-key: ${LLM_API_KEY}" \
                -H "anthropic-version: 2023-06-01" \
                -d "$json_payload" 2>&1
            ;;
    esac
}

# ---- extract_text(response) — parse provider-specific JSON ----
extract_text() {
    local response="$1"
    echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    provider = '${LLM_PROVIDER}'
    if provider == 'gemini':
        parts = data.get('candidates', [{}])[0].get('content', {}).get('parts', [])
        for p in parts:
            if 'text' in p:
                print(p['text'])
    elif provider == 'openai':
        # Responses API format
        output = data.get('output', [])
        for item in output:
            if item.get('type') == 'message':
                for block in item.get('content', []):
                    if block.get('type') == 'output_text':
                        print(block.get('text', ''))
    elif provider == 'anthropic':
        content = data.get('content', [])
        for block in content:
            if block.get('type') == 'text':
                print(block.get('text', ''))
except:
    print('[parse error]')
" 2>/dev/null || echo "$response" | grep -o '"text": *"[^"]*"' | head -1 | sed 's/"text": *"//;s/"$//' | sed 's/\\n/\n/g'
}
