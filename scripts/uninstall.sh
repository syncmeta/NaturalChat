#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

# ── Find installation ────────────────────────────────────────────────────────

BASE_DIR="${1:-}"
if [[ -z "$BASE_DIR" ]]; then
    if [[ -f "main.py" ]] && [[ -d "src" ]]; then
        BASE_DIR="$(pwd)"
    elif [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "$(dirname "${BASH_SOURCE[0]}")/../main.py" ]]; then
        BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    fi
fi
if [[ -z "$BASE_DIR" ]] || [[ ! -f "$BASE_DIR/main.py" ]]; then
    echo "NaturalChat not found"; exit 1
fi
BASE_DIR="$(cd "$BASE_DIR" && pwd)"

# ── Confirm ──────────────────────────────────────────────────────────────────

printf "\n${RED}  Uninstall? 确定卸载？${NC} [Enter] "
read -r _ </dev/tty 2>/dev/null || read -r _

# ── Stop bot process ─────────────────────────────────────────────────────────

PID_FILE="$BASE_DIR/.naturalchat.pid"
if [[ -f "$PID_FILE" ]]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
fi

# ── Stop Docker ──────────────────────────────────────────────────────────────

if [[ -f "$BASE_DIR/docker/docker-compose.yml" ]] && command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    PROJECT_FLAG=""
    if [[ -f "$BASE_DIR/.env" ]]; then
        CP="$(grep '^COMPOSE_PROJECT_NAME=' "$BASE_DIR/.env" 2>/dev/null | cut -d= -f2)" || true
        [[ -n "${CP:-}" ]] && PROJECT_FLAG="-p $CP"
    fi
    docker compose $PROJECT_FLAG --profile bot --profile matrix --profile honcho --profile crawl4ai --profile rsshub \
        --env-file "$BASE_DIR/.env" -f "$BASE_DIR/docker/docker-compose.yml" \
        down -v --rmi local --remove-orphans 2>/dev/null || true
    if [[ -n "${CP:-}" ]]; then
        docker ps -a --filter "label=com.docker.compose.project=$CP" -q 2>/dev/null | xargs -r docker rm -f 2>/dev/null || true
        docker network ls --filter "label=com.docker.compose.project=$CP" -q 2>/dev/null | xargs -r docker network rm 2>/dev/null || true
        # Explicitly remove named volumes (conduit-data, honcho-pg)
        for vol in "${CP}_conduit-data" "${CP}_honcho-pg"; do
            docker volume rm "$vol" 2>/dev/null || true
        done
    fi
fi

# ── Stop system services ────────────────────────────────────────────────────

if [[ "$(uname -s)" == "Linux" ]] && command -v systemctl &>/dev/null && [[ -f /etc/systemd/system/naturalchat.service ]]; then
    sudo systemctl stop naturalchat 2>/dev/null || true
    sudo systemctl disable naturalchat 2>/dev/null || true
    sudo rm -f /etc/systemd/system/naturalchat.service
    sudo systemctl daemon-reload
fi
if [[ "$(uname -s)" == "Darwin" ]] && [[ -f "$HOME/Library/LaunchAgents/com.naturalchat.bot.plist" ]]; then
    launchctl stop com.naturalchat.bot 2>/dev/null || true
    launchctl unload "$HOME/Library/LaunchAgents/com.naturalchat.bot.plist" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/com.naturalchat.bot.plist"
fi

# ── Remove files ─────────────────────────────────────────────────────────────

if [[ "$(uname -s)" == "Darwin" ]]; then
    osascript -e "tell application \"Finder\" to delete POSIX file \"$BASE_DIR\"" &>/dev/null || mv "$BASE_DIR" "$HOME/.Trash/"
else
    trash_dir="${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files"
    mkdir -p "$trash_dir"
    mv "$BASE_DIR" "$trash_dir/naturalchat-$(date +%s)"
fi

printf "\n${GREEN}  Done. Moved to Trash. 已移到回收站。${NC}\n\n"
