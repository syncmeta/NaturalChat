#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="${1:-/opt/naturalchat4}"
BOT_DIR="${2:-$PROJECT_DIR/bots/bot1}"
MEMOBASE_DIR="$PROJECT_DIR/memobase"
PYTHON_BIN="${PYTHON_BIN:-$PROJECT_DIR/venv/bin/python}"

mkdir -p "$MEMOBASE_DIR/postgres" "$MEMOBASE_DIR/redis"

if [ ! -d "$BOT_DIR" ]; then
  echo "bot dir not found: $BOT_DIR" >&2
  exit 1
fi

"$PYTHON_BIN" "$PROJECT_DIR/deploy/render_memobase_config.py" "$BOT_DIR" "$MEMOBASE_DIR"

docker compose \
  --env-file "$MEMOBASE_DIR/.env" \
  -f "$PROJECT_DIR/deploy/memobase-compose.yml" \
  pull

docker compose \
  --env-file "$MEMOBASE_DIR/.env" \
  -f "$PROJECT_DIR/deploy/memobase-compose.yml" \
  up -d

echo "memobase deployed at http://127.0.0.1:8019"
