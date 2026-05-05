#!/bin/sh
set -eu

CONFIG_DIR="${HOME:-/home/nanobot}/.nanobot"
CONFIG_FILE="$CONFIG_DIR/config.json"

mkdir -p "$CONFIG_DIR"

# Railway assigns PORT dynamically; bind gateway publicly inside the container.
export NANOBOT_GATEWAY__HOST="${NANOBOT_GATEWAY__HOST:-0.0.0.0}"
export NANOBOT_GATEWAY__PORT="${NANOBOT_GATEWAY__PORT:-${PORT:-18790}}"

if [ ! -f "$CONFIG_FILE" ]; then
  PROVIDER="${NANOBOT_PROVIDER:-openrouter}"
  API_BASE="${NANOBOT_API_BASE:-${OPENAI_API_BASE:-}}"
  DEFAULT_MODEL="${NANOBOT_DEFAULT_MODEL:-anthropic/claude-sonnet-4}"

    API_KEY="${NANOBOT_API_KEY:-}"
    if [ -z "$API_KEY" ]; then
        case "$PROVIDER" in
            openrouter) API_KEY="${OPENROUTER_API_KEY:-}" ;;
            anthropic) API_KEY="${ANTHROPIC_API_KEY:-}" ;;
            deepseek) API_KEY="${DEEPSEEK_API_KEY:-}" ;;
            zhipu) API_KEY="${ZHIPU_API_KEY:-}" ;;
            gemini) API_KEY="${GEMINI_API_KEY:-}" ;;
            groq) API_KEY="${GROQ_API_KEY:-}" ;;
            openai|azure_openai) API_KEY="${OPENAI_API_KEY:-}" ;;
            *) API_KEY="${OPENAI_API_KEY:-}" ;;
        esac
    fi

  if [ -z "$API_KEY" ]; then
        echo "Missing API key for provider '$PROVIDER'. Set NANOBOT_API_KEY or provider key (OPENROUTER_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.)." >&2
    exit 1
  fi

  SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN:-}"
  SLACK_APP_TOKEN="${SLACK_APP_TOKEN:-}"
  SLACK_ALLOW_FROM="${SLACK_ALLOW_FROM:-*}"

  python - "$CONFIG_FILE" "$PROVIDER" "$API_KEY" "$API_BASE" "$DEFAULT_MODEL" \
    "$SLACK_BOT_TOKEN" "$SLACK_APP_TOKEN" "$SLACK_ALLOW_FROM" <<'PY'
import json, sys

config_file, provider, api_key, api_base, default_model, \
    slack_bot_token, slack_app_token, slack_allow_from = sys.argv[1:]

provider_cfg = {"apiKey": api_key}
if api_base:
    provider_cfg["apiBase"] = api_base

config = {
    "providers": {provider: provider_cfg},
    "agents": {"defaults": {"provider": provider, "model": default_model}},
}

if slack_bot_token and slack_app_token:
    config["channels"] = {
        "slack": {
            "enabled": True,
            "botToken": slack_bot_token,
            "appToken": slack_app_token,
            "allowFrom": [s.strip() for s in slack_allow_from.split(",")],
        }
    }

with open(config_file, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)

print(f"Generated {config_file}")
PY
fi

exec nanobot gateway