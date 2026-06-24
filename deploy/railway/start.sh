#!/usr/bin/env bash
set -euo pipefail

: "${PORT:?PORT is required}"

export OPENCLAW_CONFIG_DIR="${OPENCLAW_CONFIG_DIR:-/data/.openclaw}"
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$OPENCLAW_CONFIG_DIR/openclaw.json}"
export OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-$OPENCLAW_CONFIG_DIR/workspace}"
export OPENCLAW_AUTH_PROFILE_SECRET_DIR="${OPENCLAW_AUTH_PROFILE_SECRET_DIR:-/data/.config/openclaw}"

mkdir -p "$OPENCLAW_CONFIG_DIR" "$OPENCLAW_WORKSPACE_DIR" "$OPENCLAW_AUTH_PROFILE_SECRET_DIR"

echo "Preparing OpenClaw Railway runtime config..."
node openclaw.mjs setup --workspace "$OPENCLAW_WORKSPACE_DIR" >/dev/null
node openclaw.mjs config set --batch-json '[{"path":"gateway.bind","value":"lan"}]' >/dev/null

auth_args=()
if [[ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  auth_args=(--auth token)
elif [[ -n "${OPENCLAW_GATEWAY_PASSWORD:-}" ]]; then
  auth_args=(--auth password)
else
  echo "OPENCLAW_GATEWAY_TOKEN or OPENCLAW_GATEWAY_PASSWORD is required for lan bind." >&2
  exit 1
fi

exec node openclaw.mjs gateway --bind lan "${auth_args[@]}" --port "$PORT"
