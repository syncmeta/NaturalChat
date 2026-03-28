#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="${1:-/opt/naturalchat4}"
VENV_DIR="$PROJECT_DIR/venv"
UV_BIN="${HOME}/.local/bin/uv"

needs_upgrade=1
if [ -x "$VENV_DIR/bin/python3" ]; then
  if "$VENV_DIR/bin/python3" - <<'PY'
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
  then
    needs_upgrade=0
  fi
fi

if [ "$needs_upgrade" -eq 0 ]; then
  echo "runtime already satisfies Python >= 3.11"
  exit 0
fi

if [ ! -x "$UV_BIN" ]; then
  mkdir -p "${HOME}/.local/bin"
  tmp_script="$(mktemp)"
  curl -LsSf https://astral.sh/uv/install.sh -o "$tmp_script"
  sh "$tmp_script"
  rm -f "$tmp_script"
fi

"$UV_BIN" python install 3.12
rm -rf "$VENV_DIR"
"$UV_BIN" venv --python 3.12 --seed "$VENV_DIR"

echo "bootstrapped Python runtime in $VENV_DIR"
