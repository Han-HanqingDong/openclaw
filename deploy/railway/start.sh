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

origins=()
add_origin() {
  local origin="${1:-}"
  origin="${origin%/}"
  [[ -z "$origin" ]] && return
  for existing in "${origins[@]}"; do
    [[ "$existing" == "$origin" ]] && return
  done
  origins+=("$origin")
}
add_railway_origin() {
  local raw="${1:-}"
  raw="${raw%/}"
  [[ -z "$raw" ]] && return
  if [[ "$raw" == http://* || "$raw" == https://* ]]; then
    add_origin "$raw"
  else
    add_origin "https://$raw"
  fi
}

add_origin "http://localhost:$PORT"
add_origin "http://127.0.0.1:$PORT"
add_railway_origin "${RAILWAY_PUBLIC_DOMAIN:-}"
add_railway_origin "${RAILWAY_STATIC_URL:-}"
add_railway_origin "${RAILWAY_SERVICE_OPENCLAW_URL:-}"

batch_json="$(
  node - "${origins[@]}" <<'NODE'
const origins = process.argv.slice(2);
process.stdout.write(JSON.stringify([
  { path: "gateway.bind", value: "lan" },
  { path: "gateway.controlUi.allowedOrigins", value: origins },
]));
NODE
)"
node openclaw.mjs config set --batch-json "$batch_json" >/dev/null

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
