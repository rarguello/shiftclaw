#!/usr/bin/env bash
# run.sh — Run shiftclaw locally with Podman (no OpenShift required).
#
# Usage:
#   cp .env.example .env   # fill in your real values
#   ./run.sh [IMAGE]
#
# If IMAGE is not provided, the published GHCR image is used.
# Pass a locally built image name to test your own build:
#   ./run.sh localhost/shiftclaw:dev

set -euo pipefail

IMAGE="${1:-ghcr.io/rarguello/shiftclaw:2026.5.7}"
CONTAINER_NAME="shiftclaw"
STATE_DIR="$HOME/.local/share/shiftclaw"
ENV_FILE="$(dirname "$0")/.env"
CONFIG_SRC="$(dirname "$0")/config/openclaw.json"

# --- check .env exists ---
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env file not found."
  echo "  cp .env.example .env   # then fill in the values"
  exit 1
fi

# --- seed state directory with config on first run ---
mkdir -p "$STATE_DIR"
if [[ ! -f "$STATE_DIR/openclaw.json" ]]; then
  echo "First run: copying config/openclaw.json → $STATE_DIR/openclaw.json"
  cp "$CONFIG_SRC" "$STATE_DIR/openclaw.json"
fi

# --- start the container ---
echo "Starting $CONTAINER_NAME ($IMAGE)..."
exec podman run \
  --name "$CONTAINER_NAME" \
  --replace \
  --restart=on-failure \
  --env-file "$ENV_FILE" \
  --env XDG_CONFIG_HOME=/var/lib/openclaw \
  --env OPENCLAW_CONFIG_PATH=/var/lib/openclaw/openclaw.json \
  --env NODE_ENV=production \
  --env NPM_CONFIG_CACHE=/tmp/.npm \
  --env HOME=/var/lib/openclaw \
  --volume "$STATE_DIR:/var/lib/openclaw:Z" \
  --tmpfs /tmp:rw \
  --publish 18789:18789 \
  --publish 1455:1455 \
  --userns=keep-id:uid=1001,gid=1001 \
  "$IMAGE"
