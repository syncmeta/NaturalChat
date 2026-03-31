#!/usr/bin/env bash
# nctl.sh — NaturalChat control panel
#
# Usage:
#   bash nctl.sh              Interactive menu
#   bash nctl.sh status       Show status
#   bash nctl.sh start        Start all services
#   bash nctl.sh stop         Stop all services
#   bash nctl.sh restart      Restart all services
#   bash nctl.sh logs [svc]   View logs (bot, conduit, memobase-api, etc.)
#   bash nctl.sh config       Edit configuration
#   bash nctl.sh matrix       Matrix account management

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── Locate installation ─────────────────────────────────────────────────────

BASE_DIR=""
if [[ -f "main.py" ]] && [[ -d "src" ]]; then
    BASE_DIR="$(pwd)"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/main.py" ]]; then
        BASE_DIR="$SCRIPT_DIR"
    fi
fi

if [[ -z "$BASE_DIR" ]] || [[ ! -f "$BASE_DIR/main.py" ]]; then
    echo "Error: NaturalChat not found. Run from the project directory."
    exit 1
fi

# ── Language ─────────────────────────────────────────────────────────────────

LANG_UI="en"
# Auto-detect from system locale
if [[ "${LANG:-}" == zh* ]] || [[ "${LC_ALL:-}" == zh* ]]; then
    LANG_UI="zh"
fi

i18n() {
    local key="$1"
    case "$LANG_UI:$key" in
        # ── Generic ──
        en:yes) echo "Yes" ;; zh:yes) echo "是" ;;
        en:no) echo "No" ;; zh:no) echo "否" ;;
        en:default_label) echo "default" ;; zh:default_label) echo "默认" ;;
        en:arrow_help) echo "arrow keys to move, Enter to select" ;; zh:arrow_help) echo "方向键移动，回车确认" ;;
        en:choice_label) echo "Choice" ;; zh:choice_label) echo "选择" ;;
        en:back) echo "← Back to main menu" ;; zh:back) echo "← 返回主菜单" ;;
        en:press_enter) echo "Press Enter to continue..." ;; zh:press_enter) echo "按回车继续..." ;;

        # ── Title ──
        en:title) echo "NaturalChat Control Panel" ;; zh:title) echo "NaturalChat 控制面板" ;;

        # ── Main menu ──
        en:menu_status) echo "Status — View current running state" ;;
        zh:menu_status) echo "状态 — 查看当前运行状态" ;;
        en:menu_start) echo "Start — Start all services" ;;
        zh:menu_start) echo "启动 — 启动所有服务" ;;
        en:menu_stop) echo "Stop — Stop all services" ;;
        zh:menu_stop) echo "停止 — 停止所有服务" ;;
        en:menu_restart) echo "Restart — Restart all services" ;;
        zh:menu_restart) echo "重启 — 重启所有服务" ;;
        en:menu_logs) echo "Logs — View real-time logs" ;;
        zh:menu_logs) echo "日志 — 查看实时日志" ;;
        en:menu_config) echo "Config — View / edit configuration" ;;
        zh:menu_config) echo "配置 — 查看 / 编辑配置" ;;
        en:menu_matrix) echo "Matrix — Manage Matrix accounts" ;;
        zh:menu_matrix) echo "Matrix — 管理 Matrix 账号" ;;
        en:menu_bots) echo "Bots — Manage bot instances" ;;
        zh:menu_bots) echo "机器人 — 管理机器人实例" ;;
        en:menu_exit) echo "Exit" ;; zh:menu_exit) echo "退出" ;;

        # ── Status ──
        en:status_title) echo "System Status" ;; zh:status_title) echo "系统状态" ;;
        en:run_mode) echo "Run mode" ;; zh:run_mode) echo "运行模式" ;;
        en:run_mode_docker) echo "Docker container" ;; zh:run_mode_docker) echo "Docker 容器" ;;
        en:run_mode_host) echo "Host (venv + nohup)" ;; zh:run_mode_host) echo "宿主机（venv + nohup）" ;;
        en:docker_services) echo "Docker Services" ;; zh:docker_services) echo "Docker 服务" ;;
        en:no_containers) echo "No running containers" ;; zh:no_containers) echo "没有运行中的容器" ;;
        en:web_panel) echo "Web Panel" ;; zh:web_panel) echo "网页面板" ;;
        en:endpoints) echo "Service Endpoints" ;; zh:endpoints) echo "服务地址" ;;

        # ── Start / Stop ──
        en:starting) echo "Starting services..." ;; zh:starting) echo "正在启动服务..." ;;
        en:started) echo "All services started" ;; zh:started) echo "所有服务已启动" ;;
        en:stopping) echo "Stopping services..." ;; zh:stopping) echo "正在停止服务..." ;;
        en:stopped) echo "All services stopped" ;; zh:stopped) echo "所有服务已停止" ;;
        en:restarting) echo "Restarting services..." ;; zh:restarting) echo "正在重启服务..." ;;
        en:restarted) echo "All services restarted" ;; zh:restarted) echo "所有服务已重启" ;;

        # ── Logs ──
        en:logs_which) echo "Which service logs to view?" ;; zh:logs_which) echo "查看哪个服务的日志？" ;;
        en:logs_all) echo "All services" ;; zh:logs_all) echo "全部服务" ;;
        en:logs_hint) echo "Press Ctrl+C to stop viewing logs" ;; zh:logs_hint) echo "按 Ctrl+C 停止查看日志" ;;

        # ── Config ──
        en:config_title) echo "Configuration" ;; zh:config_title) echo "配置管理" ;;
        en:config_view) echo "View current config" ;; zh:config_view) echo "查看当前配置" ;;
        en:config_edit_bot) echo "Edit bot config (config.yaml)" ;; zh:config_edit_bot) echo "编辑机器人配置（config.yaml）" ;;
        en:config_edit_secrets) echo "Edit secrets (secrets.yaml)" ;; zh:config_edit_secrets) echo "编辑密钥（secrets.yaml）" ;;
        en:config_edit_prompt) echo "Edit system prompt (prompts/main.md)" ;; zh:config_edit_prompt) echo "编辑系统提示词（prompts/main.md）" ;;
        en:config_edit_env) echo "Edit Docker env (.env)" ;; zh:config_edit_env) echo "编辑 Docker 环境变量（.env）" ;;
        en:config_edit_panel) echo "Edit web panel credentials" ;; zh:config_edit_panel) echo "编辑网页面板凭据" ;;
        en:config_apply) echo "Changes saved. Restart services to apply." ;; zh:config_apply) echo "更改已保存。重启服务以生效。" ;;
        en:config_restart_now) echo "Restart now?" ;; zh:config_restart_now) echo "现在重启？" ;;

        # ── Matrix ──
        en:matrix_title) echo "Matrix Account Management" ;; zh:matrix_title) echo "Matrix 账号管理" ;;
        en:matrix_not_configured) echo "Matrix/Conduit is not configured in this installation" ;;
        zh:matrix_not_configured) echo "当前安装未配置 Matrix/Conduit" ;;
        en:matrix_list) echo "List registered users" ;; zh:matrix_list) echo "列出已注册用户" ;;
        en:matrix_add) echo "Add a new user" ;; zh:matrix_add) echo "添加新用户" ;;
        en:matrix_reset_pw) echo "Reset user password" ;; zh:matrix_reset_pw) echo "重置用户密码" ;;
        en:matrix_info) echo "Server info" ;; zh:matrix_info) echo "服务器信息" ;;
        en:matrix_username_prompt) echo "Username (without @ and :server):" ;; zh:matrix_username_prompt) echo "用户名（不含 @ 和 :服务器）：" ;;
        en:matrix_password_prompt) echo "Password (leave empty for random):" ;; zh:matrix_password_prompt) echo "密码（留空自动生成）：" ;;
        en:matrix_user_created) echo "User created" ;; zh:matrix_user_created) echo "用户已创建" ;;
        en:matrix_user_exists) echo "User already exists" ;; zh:matrix_user_exists) echo "用户已存在" ;;
        en:matrix_user_failed) echo "Failed to create user" ;; zh:matrix_user_failed) echo "创建用户失败" ;;
        en:matrix_server_offline) echo "Conduit server is not responding" ;; zh:matrix_server_offline) echo "Conduit 服务器未响应" ;;

        # ── Bots ──
        en:bots_title) echo "Bot Management" ;; zh:bots_title) echo "机器人管理" ;;
        en:bots_list) echo "List bots" ;; zh:bots_list) echo "列出机器人" ;;
        en:bots_add) echo "Add a new bot" ;; zh:bots_add) echo "添加新机器人" ;;
        en:bots_remove) echo "Remove a bot" ;; zh:bots_remove) echo "删除机器人" ;;
        en:bots_export) echo "Export a bot" ;; zh:bots_export) echo "导出机器人" ;;

        *) echo "$key" ;;
    esac
}

# ── Helpers ──────────────────────────────────────────────────────────────────

info()  { printf "  ${CYAN}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "  ${GREEN}  OK${NC}    %s\n" "$*"; }
warn()  { printf "  ${YELLOW}[WARN]${NC}  %s\n" "$*"; }
err()   { printf "  ${RED}[ERR]${NC}   %s\n" "$*"; }

random_chars() {
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c "${1:-12}"
}

pause() {
    echo ""
    printf "  ${DIM}$(i18n press_enter)${NC}"
    read -r </dev/tty 2>/dev/null || read -r
}

# ── Arrow-key selector ───────────────────────────────────────────────────────

term_cols() {
    local cols="${COLUMNS:-}"
    if [[ -z "$cols" ]] && command -v tput &>/dev/null; then
        cols="$(tput cols 2>/dev/null || true)"
    fi
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
    (( cols < 48 )) && cols=48
    echo "$cols"
}

ask_choice() {
    local prompt="$1" default="$2"
    shift 2
    local options=("$@")
    local count=${#options[@]}
    local selected=$((default - 1))
    local cols
    cols="$(term_cols)"

    if (( cols < 72 )) || ! [[ -t 0 ]] && [[ ! -e /dev/tty ]]; then
        echo "" >&2
        printf "  %s\n" "$prompt" >&2
        local i=1
        for opt in "${options[@]}"; do
            if [[ $i -eq $default ]]; then
                printf "    [%d] %s (%s)\n" "$i" "$opt" "$(i18n default_label)" >&2
            else
                printf "    [%d] %s\n" "$i" "$opt" >&2
            fi
            ((i++))
        done
        printf "\n  %s (%s: %d): " "$(i18n choice_label)" "$(i18n default_label)" "$default" >&2
        read -r choice </dev/tty 2>/dev/null || choice="$default"
        choice="${choice:-$default}"
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
            echo "$choice"
        else
            echo "$default"
        fi
        return
    fi

    echo "" >&2
    printf "  %s  ${DIM}(%s)${NC}\n\n" "$prompt" "$(i18n arrow_help)" >&2
    printf "\033[?25l" >&2

    _draw() {
        local i
        for ((i = 0; i < count; i++)); do
            if [[ $i -eq $selected ]]; then
                printf "\r\033[2K  ${GREEN}${BOLD}> %s${NC}\n" "${options[$i]}" >&2
            else
                printf "\r\033[2K    %s\n" "${options[$i]}" >&2
            fi
        done
    }
    _draw

    while true; do
        IFS= read -rsn1 key </dev/tty
        case "$key" in
            $'\x1b')
                IFS= read -rsn2 rest </dev/tty
                case "$rest" in
                    '[A') ((selected > 0)) && ((selected--)) ;;
                    '[B') ((selected < count - 1)) && ((selected++)) ;;
                esac ;;
            'k') ((selected > 0)) && ((selected--)) ;;
            'j') ((selected < count - 1)) && ((selected++)) ;;
            '') break ;;
        esac
        printf "\033[%dA" "$count" >&2
        _draw
    done
    printf "\033[?25h" >&2
    echo $(( selected + 1 ))
}

ask_yn() {
    local prompt="$1" default="${2:-y}"
    local def_idx=1
    [[ "$default" != "y" ]] && def_idx=2
    local choice
    choice="$(ask_choice "$prompt" "$def_idx" "$(i18n yes)" "$(i18n no)")"
    [[ "$choice" == "1" ]]
}

ask_input() {
    local prompt="$1" default="${2:-}"
    if [[ -n "$default" ]]; then
        printf "  ${BOLD}%s${NC} [%s]: " "$prompt" "$default" >&2
    else
        printf "  ${BOLD}%s${NC}: " "$prompt" >&2
    fi
    local val
    read -r val </dev/tty 2>/dev/null || read -r val
    echo "${val:-$default}"
}

port_in_use() {
    local port="$1"
    if command -v lsof &>/dev/null; then
        lsof -iTCP:"$port" -sTCP:LISTEN &>/dev/null 2>&1
    elif command -v ss &>/dev/null; then
        ss -tlnH "sport = :$port" 2>/dev/null | grep -q .
    elif command -v netstat &>/dev/null; then
        netstat -tln 2>/dev/null | grep -q ":$port "
    else
        return 1
    fi
}

random_port() {
    local port
    while true; do
        port=$(( RANDOM % 39000 + 10000 ))
        if ! port_in_use "$port"; then
            echo "$port"
            return
        fi
    done
}

update_env() {
    local key="$1" val="$2"
    if [[ -f "$ENV_FILE" ]] && grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        sed -i.bak "s/^${key}=.*/${key}=${val}/" "$ENV_FILE"
        rm -f "$ENV_FILE.bak"
    else
        echo "${key}=${val}" >> "$ENV_FILE"
    fi
}

# ── Load environment ─────────────────────────────────────────────────────────

ENV_FILE="$BASE_DIR/.env"
COMPOSE_FILE="$BASE_DIR/docker/docker-compose.yml"

# Read .env values
load_env() {
    local key="$1" default="${2:-}"
    if [[ -f "$ENV_FILE" ]]; then
        local val
        val="$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-)" || true
        echo "${val:-$default}"
    else
        echo "$default"
    fi
}

COMPOSE_PROJECT="$(load_env COMPOSE_PROJECT_NAME naturalchat)"
PROJECT_FLAG="-p $COMPOSE_PROJECT"
CONDUIT_PORT="$(load_env CONDUIT_PORT 6167)"
CONDUIT_SERVER_NAME="$(load_env CONDUIT_SERVER_NAME localhost)"
MEMOBASE_PORT="$(load_env MEMOBASE_PORT 8019)"
CRAWL4AI_PORT="$(load_env CRAWL4AI_PORT 11235)"
RSSHUB_PORT="$(load_env RSSHUB_PORT 1200)"

# Detect run mode
detect_run_mode() {
    # Check if bot container is running in compose
    if dc ps --status running --format '{{.Name}}' 2>/dev/null | grep -q "bot"; then
        echo "docker"
    elif [[ -f "$BASE_DIR/.naturalchat.pid" ]]; then
        local pid
        pid="$(cat "$BASE_DIR/.naturalchat.pid" 2>/dev/null)" || true
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "host"
        else
            echo "stopped"
        fi
    else
        echo "stopped"
    fi
}

# Get active profiles
get_active_profiles() {
    local profiles=""
    local running
    running="$(docker compose $PROJECT_FLAG --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps --status running --format '{{.Name}}' 2>/dev/null)" || true
    echo "$running" | grep -q "conduit" && profiles="$profiles --profile matrix"
    echo "$running" | grep -q "memobase" && profiles="$profiles --profile memobase"
    echo "$running" | grep -q "crawl4ai" && profiles="$profiles --profile crawl4ai"
    echo "$running" | grep -q "rsshub" && profiles="$profiles --profile rsshub"
    echo "$running" | grep -q "\-bot-" && profiles="$profiles --profile bot"
    # If nothing running, detect from compose config
    if [[ -z "$profiles" ]]; then
        profiles="$(get_configured_profiles)"
    fi
    echo "$profiles"
}

get_configured_profiles() {
    local profiles=""

    # Method 1: Check from existing containers (running or stopped) — most reliable
    local all_containers
    all_containers="$(dc ps -a --format '{{.Name}}' 2>/dev/null)" || true

    if echo "$all_containers" | grep -q "bot"; then
        profiles="$profiles --profile bot"
    fi
    if echo "$all_containers" | grep -q "conduit"; then
        profiles="$profiles --profile matrix"
    fi
    if echo "$all_containers" | grep -q "memobase"; then
        profiles="$profiles --profile memobase"
    fi
    if echo "$all_containers" | grep -q "crawl4ai"; then
        profiles="$profiles --profile crawl4ai"
    fi
    if echo "$all_containers" | grep -q "rsshub"; then
        profiles="$profiles --profile rsshub"
    fi

    # Method 2: Fallback to .env if no containers exist
    if [[ -z "$profiles" ]]; then
        [[ -n "$(load_env CONDUIT_PORT "")" ]] && profiles="$profiles --profile matrix"
        [[ -n "$(load_env MEMOBASE_DB_PASSWORD "")" ]] && profiles="$profiles --profile memobase"
        [[ -n "$(load_env CRAWL4AI_PORT "")" ]] && profiles="$profiles --profile crawl4ai"
        [[ -n "$(load_env RSSHUB_PORT "")" ]] && profiles="$profiles --profile rsshub"
        # Default: include bot profile if Dockerfile exists
        [[ -f "$BASE_DIR/docker/Dockerfile" ]] && profiles="$profiles --profile bot"
    fi

    echo "$profiles"
}

# Detect editor
EDITOR="${EDITOR:-${VISUAL:-}}"
if [[ -z "$EDITOR" ]]; then
    for e in nano vim vi; do
        if command -v "$e" &>/dev/null; then
            EDITOR="$e"
            break
        fi
    done
fi

# Python path
PY=""
if [[ -f "$BASE_DIR/.venv/bin/python" ]]; then
    PY="$BASE_DIR/.venv/bin/python"
elif command -v python3 &>/dev/null; then
    PY="python3"
fi

# ── Docker compose wrapper ───────────────────────────────────────────────────

dc() {
    docker compose $PROJECT_FLAG --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

dc_all() {
    local profiles
    profiles="$(get_configured_profiles)"
    docker compose $PROJECT_FLAG $profiles --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMANDS
# ══════════════════════════════════════════════════════════════════════════════

# ── Status ───────────────────────────────────────────────────────────────────

cmd_status() {
    echo ""
    printf "  ${BOLD}── $(i18n status_title) ──${NC}\n"
    echo ""

    # Run mode
    local mode
    mode="$(detect_run_mode)"
    case "$mode" in
        docker) printf "  ${BOLD}$(i18n run_mode):${NC}  ${GREEN}$(i18n run_mode_docker)${NC}\n" ;;
        host)   printf "  ${BOLD}$(i18n run_mode):${NC}  ${GREEN}$(i18n run_mode_host)${NC} (PID: $(cat "$BASE_DIR/.naturalchat.pid" 2>/dev/null))\n" ;;
        *)      printf "  ${BOLD}$(i18n run_mode):${NC}  ${RED}Stopped${NC}\n" ;;
    esac
    echo ""

    # Docker services
    if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
        printf "  ${BOLD}$(i18n docker_services):${NC}\n"
        local containers
        containers="$(dc ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null)" || true
        if [[ -n "$containers" ]] && [[ "$(echo "$containers" | wc -l)" -gt 1 ]]; then
            echo "$containers" | while IFS= read -r line; do
                printf "    %s\n" "$line"
            done
        else
            printf "    ${DIM}$(i18n no_containers)${NC}\n"
        fi
        echo ""
    fi

    # Web panel
    if [[ -f "$BASE_DIR/web_panel.yaml" ]]; then
        local panel_port panel_user panel_pass
        panel_port="$(sed -n 's/^port: *\(.*\)/\1/p' "$BASE_DIR/web_panel.yaml" 2>/dev/null | head -1)" || true
        panel_user="$(sed -n 's/^username: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/p' "$BASE_DIR/web_panel.yaml" 2>/dev/null | head -1)" || true
        panel_pass="$(sed -n 's/^password: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/p' "$BASE_DIR/web_panel.yaml" 2>/dev/null | head -1)" || true
        if [[ -n "$panel_port" ]]; then
            printf "  ${BOLD}$(i18n web_panel):${NC}\n"
            echo "    URL:      http://127.0.0.1:${panel_port}"
            echo "    Username: $panel_user"
            echo "    Password: $panel_pass"
            echo ""
        fi
    fi

    # Service endpoints — extract actual host port from docker ps
    printf "  ${BOLD}$(i18n endpoints):${NC}\n"
    local has_endpoint=false
    local running_info
    running_info="$(dc ps --status running 2>/dev/null)" || true

    _get_host_port() {
        # Extract host port mapping for a container port, e.g. "0.0.0.0:27915->6167/tcp" → 27915
        local svc_name="$1" cport="$2"
        local line
        line="$(echo "$running_info" | grep "$svc_name" || true)"
        if [[ -n "$line" ]]; then
            echo "$line" | sed -n "s/.*0\.0\.0\.0:\([0-9]*\)->${cport}\/tcp.*/\1/p" | head -1
        fi
    }

    if echo "$running_info" | grep -q "conduit"; then
        local p; p="$(_get_host_port conduit 6167)"
        echo "    Matrix (Conduit): http://127.0.0.1:${p:-$CONDUIT_PORT}"
        has_endpoint=true
    fi
    if echo "$running_info" | grep -q "memobase-api"; then
        local p; p="$(_get_host_port memobase-api 8000)"
        echo "    Memobase API:     http://127.0.0.1:${p:-$MEMOBASE_PORT}"
        has_endpoint=true
    fi
    if echo "$running_info" | grep -q "crawl4ai"; then
        local p; p="$(_get_host_port crawl4ai 11235)"
        echo "    Crawl4AI:         http://127.0.0.1:${p:-$CRAWL4AI_PORT}"
        has_endpoint=true
    fi
    if echo "$running_info" | grep -q "rsshub"; then
        local p; p="$(_get_host_port rsshub 1200)"
        echo "    RSSHub:           http://127.0.0.1:${p:-$RSSHUB_PORT}"
        has_endpoint=true
    fi
    if [[ "$has_endpoint" == "false" ]]; then
        printf "    ${DIM}(none running)${NC}\n"
    fi
    echo ""

    # Disk usage
    printf "  ${BOLD}Disk:${NC}\n"
    printf "    Project:  %s\n" "$(du -sh "$BASE_DIR" 2>/dev/null | cut -f1)"
    local vol_size
    vol_size="$(docker system df -v 2>/dev/null | grep "$COMPOSE_PROJECT" | awk '{sum += $4} END {if(sum>0) printf "%.1fMB", sum; else print "0MB"}')" || vol_size="N/A"
    printf "    Volumes:  %s\n" "$vol_size"
    echo ""
}

# ── Port conflict resolution ─────────────────────────────────────────────────

_resolve_port_conflicts() {
    local changed=false
    local port_vars=(CONDUIT_PORT PANEL_PORT MEMOBASE_PORT CRAWL4AI_PORT RSSHUB_PORT)
    for var in "${port_vars[@]}"; do
        local port="${!var:-}"
        [[ -z "$port" ]] && continue
        if port_in_use "$port"; then
            local new_port
            new_port="$(random_port)"
            warn "Port $port ($var) is occupied, switching to $new_port"
            eval "$var=$new_port"
            update_env "$var" "$new_port"
            changed=true
        fi
    done
    if [[ "$changed" == "true" ]]; then
        # Reload relevant vars for this session
        CONDUIT_PORT="$(load_env CONDUIT_PORT 6167)"
    fi
}

# ── Start ────────────────────────────────────────────────────────────────────

cmd_start() {
    echo ""
    info "$(i18n starting)"
    local mode
    mode="$(detect_run_mode)"

    if [[ "$mode" == "docker" ]] || [[ "$mode" == "host" ]]; then
        warn "Services are already running"
        return
    fi

    # Resolve port conflicts before starting
    _resolve_port_conflicts

    # Start Docker services
    if [[ -f "$COMPOSE_FILE" ]] && command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
        local profiles
        profiles="$(get_configured_profiles)"
        if [[ -n "$profiles" ]]; then
            dc_all up -d --build 2>&1 | sed 's/^/    /'
        fi
    fi

    # If bot is NOT in docker profiles (host mode), start via nohup
    if ! echo "$(get_configured_profiles)" | grep -q "bot" 2>/dev/null; then
        if [[ -n "$PY" ]]; then
            local log_dir="$BASE_DIR/logs"
            mkdir -p "$log_dir"
            local log_file="$log_dir/naturalchat.log"
            nohup "$PY" "$BASE_DIR/main.py" >> "$log_file" 2>&1 &
            local pid=$!
            echo "$pid" > "$BASE_DIR/.naturalchat.pid"
            ok "Bot started (PID: $pid)"
        fi
    fi

    echo ""
    ok "$(i18n started)"
}

# ── Stop ─────────────────────────────────────────────────────────────────────

cmd_stop() {
    echo ""
    info "$(i18n stopping)"

    # Stop host-mode bot
    if [[ -f "$BASE_DIR/.naturalchat.pid" ]]; then
        local pid
        pid="$(cat "$BASE_DIR/.naturalchat.pid" 2>/dev/null)" || true
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            ok "Bot stopped (PID: $pid)"
        fi
        rm -f "$BASE_DIR/.naturalchat.pid"
    fi

    # Stop Docker services
    if [[ -f "$COMPOSE_FILE" ]] && command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
        dc_all stop 2>&1 | sed 's/^/    /'
    fi

    echo ""
    ok "$(i18n stopped)"
}

# ── Restart ──────────────────────────────────────────────────────────────────

cmd_restart() {
    echo ""
    info "$(i18n restarting)"

    # Stop Docker services first so port checks don't see our own containers
    if [[ -f "$COMPOSE_FILE" ]] && command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
        dc_all stop 2>&1 | sed 's/^/    /'
    fi

    # Now resolve port conflicts while ports are free
    _resolve_port_conflicts

    # Start Docker services
    if [[ -f "$COMPOSE_FILE" ]] && command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
        local profiles
        profiles="$(get_configured_profiles)"
        if [[ -n "$profiles" ]]; then
            dc_all up -d --build --force-recreate 2>&1 | sed 's/^/    /'
        fi
    fi

    # Restart host-mode bot
    if ! echo "$(get_configured_profiles)" | grep -q "bot" 2>/dev/null; then
        if [[ -f "$BASE_DIR/.naturalchat.pid" ]]; then
            local pid
            pid="$(cat "$BASE_DIR/.naturalchat.pid" 2>/dev/null)" || true
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                sleep 1
            fi
            rm -f "$BASE_DIR/.naturalchat.pid"
        fi
        if [[ -n "$PY" ]]; then
            local log_dir="$BASE_DIR/logs"
            mkdir -p "$log_dir"
            nohup "$PY" "$BASE_DIR/main.py" >> "$log_dir/naturalchat.log" 2>&1 &
            echo "$!" > "$BASE_DIR/.naturalchat.pid"
            ok "Bot restarted (PID: $!)"
        fi
    fi

    echo ""
    ok "$(i18n restarted)"
}

# ── Logs ─────────────────────────────────────────────────────────────────────

cmd_logs() {
    local service="${1:-}"

    if [[ -z "$service" ]]; then
        # Build service list from running containers
        local services=()
        local running
        running="$(dc ps --status running --format '{{.Service}}' 2>/dev/null)" || true

        services+=("$(i18n logs_all)")
        while IFS= read -r svc; do
            [[ -n "$svc" ]] && services+=("$svc")
        done <<< "$running"

        # Also offer host log if exists
        if [[ -f "$BASE_DIR/logs/naturalchat.log" ]] && ! printf '%s\n' "${services[@]}" | grep -qx "bot"; then
            services+=("host-log (naturalchat.log)")
        fi
        services+=("$(i18n back)")

        local choice
        choice="$(ask_choice "$(i18n logs_which)" 1 "${services[@]}")"

        if [[ "$choice" == "${#services[@]}" ]]; then
            return  # back
        fi

        if [[ "$choice" == "1" ]]; then
            service="all"
        else
            service="${services[$((choice - 1))]}"
        fi
    fi

    echo ""
    info "$(i18n logs_hint)"
    echo ""

    if [[ "$service" == "host-log"* ]]; then
        tail -f "$BASE_DIR/logs/naturalchat.log" 2>/dev/null || warn "No log file found"
    elif [[ "$service" == "all" ]]; then
        dc logs -f --tail 100 2>/dev/null || true
    else
        dc logs -f --tail 100 "$service" 2>/dev/null || true
    fi
}

# ── Config ───────────────────────────────────────────────────────────────────

cmd_config() {
    while true; do
        echo ""
        printf "  ${BOLD}── $(i18n config_title) ──${NC}\n"

        # Find the first bot dir
        local bot_dir=""
        if [[ -d "$BASE_DIR/bots" ]]; then
            bot_dir="$(ls -d "$BASE_DIR/bots"/*/ 2>/dev/null | head -1)"
        fi

        local options=()
        local actions=()

        options+=("$(i18n config_view)")
        actions+=("view")

        if [[ -n "$bot_dir" ]]; then
            options+=("$(i18n config_edit_bot)")
            actions+=("edit_bot")
            options+=("$(i18n config_edit_secrets)")
            actions+=("edit_secrets")
            options+=("$(i18n config_edit_prompt)")
            actions+=("edit_prompt")
        fi

        if [[ -f "$ENV_FILE" ]]; then
            options+=("$(i18n config_edit_env)")
            actions+=("edit_env")
        fi

        if [[ -f "$BASE_DIR/web_panel.yaml" ]]; then
            options+=("$(i18n config_edit_panel)")
            actions+=("edit_panel")
        fi

        options+=("$(i18n back)")
        actions+=("back")

        local choice
        choice="$(ask_choice "$(i18n config_title)" 1 "${options[@]}")"
        local action="${actions[$((choice - 1))]}"

        case "$action" in
            view)
                echo ""
                printf "  ${BOLD}─── .env ───${NC}\n"
                if [[ -f "$ENV_FILE" ]]; then
                    sed 's/^/    /' "$ENV_FILE"
                else
                    printf "    ${DIM}(not found)${NC}\n"
                fi

                if [[ -n "$bot_dir" ]]; then
                    echo ""
                    printf "  ${BOLD}─── %s/config.yaml ───${NC}\n" "$(basename "$bot_dir")"
                    if [[ -f "$bot_dir/config.yaml" ]]; then
                        sed 's/^/    /' "$bot_dir/config.yaml"
                    fi
                fi

                if [[ -f "$BASE_DIR/web_panel.yaml" ]]; then
                    echo ""
                    printf "  ${BOLD}─── web_panel.yaml ───${NC}\n"
                    sed 's/^/    /' "$BASE_DIR/web_panel.yaml"
                fi
                pause
                ;;

            edit_bot)
                "$EDITOR" "$bot_dir/config.yaml" </dev/tty
                _after_edit
                ;;

            edit_secrets)
                "$EDITOR" "$bot_dir/secrets.yaml" </dev/tty
                _after_edit
                ;;

            edit_prompt)
                local prompt_file="$bot_dir/prompts/main.md"
                if [[ ! -f "$prompt_file" ]]; then
                    mkdir -p "$bot_dir/prompts"
                    echo "You are a helpful assistant." > "$prompt_file"
                fi
                "$EDITOR" "$prompt_file" </dev/tty
                _after_edit
                ;;

            edit_env)
                "$EDITOR" "$ENV_FILE" </dev/tty
                _after_edit
                ;;

            edit_panel)
                "$EDITOR" "$BASE_DIR/web_panel.yaml" </dev/tty
                _after_edit
                ;;

            back) return ;;
        esac
    done
}

_after_edit() {
    echo ""
    ok "$(i18n config_apply)"
    if ask_yn "$(i18n config_restart_now)" "n"; then
        cmd_restart
    fi
}

# ── Matrix ───────────────────────────────────────────────────────────────────

cmd_matrix() {
    # Detect actual Conduit port from running container
    local actual_conduit_port="$CONDUIT_PORT"
    local running_ports
    running_ports="$(dc ps --status running --format '{{.Name}} {{.Ports}}' 2>/dev/null | grep conduit)" || true
    if [[ -n "$running_ports" ]]; then
        local extracted
        extracted="$(echo "$running_ports" | grep -oE "0\.0\.0\.0:[0-9]+->6167/tcp" | head -1 | grep -oE ':[0-9]+' | head -1 | tr -d ':')"
        [[ -n "$extracted" ]] && actual_conduit_port="$extracted"
    fi
    local conduit_api="http://127.0.0.1:${actual_conduit_port}"

    # Check if Conduit is configured or running
    if [[ -z "$(load_env CONDUIT_PORT "")" ]] && ! dc ps --status running --format '{{.Name}}' 2>/dev/null | grep -q "conduit"; then
        echo ""
        warn "$(i18n matrix_not_configured)"
        pause
        return
    fi

    # Check if Conduit is running
    if ! curl -sf "${conduit_api}/_matrix/client/versions" &>/dev/null; then
        echo ""
        warn "$(i18n matrix_server_offline)"
        info "Start services first: nctl.sh start"
        pause
        return
    fi

    # Export for sub-functions
    MATRIX_API="$conduit_api"
    MATRIX_PORT="$actual_conduit_port"

    while true; do
        echo ""
        printf "  ${BOLD}── $(i18n matrix_title) ──${NC}\n"
        printf "  ${DIM}Server: ${MATRIX_API}  Name: ${CONDUIT_SERVER_NAME}${NC}\n"

        local choice
        choice="$(ask_choice "$(i18n matrix_title)" 1 \
            "$(i18n matrix_list)" \
            "$(i18n matrix_add)" \
            "$(i18n matrix_reset_pw)" \
            "$(i18n matrix_info)" \
            "$(i18n back)")"

        case "$choice" in
            1) _matrix_list ;;
            2) _matrix_add ;;
            3) _matrix_reset_pw ;;
            4) _matrix_info ;;
            5) return ;;
        esac
    done
}

_matrix_list() {
    echo ""
    printf "  ${BOLD}Registered users:${NC}\n"
    echo ""

    # Conduit doesn't have a standard admin API for listing users.
    # We need an admin token. Let's try to get one or use the federation admin endpoint.
    # For Conduit, we can use /_synapse/admin/v2/users (partial compatibility)
    # First, we need an admin access token. Try to login with the bot user.

    local bot_secrets=""
    local bot_dir
    bot_dir="$(ls -d "$BASE_DIR/bots"/*/ 2>/dev/null | head -1)"
    if [[ -n "$bot_dir" ]] && [[ -f "$bot_dir/secrets.yaml" ]]; then
        # Extract matrix access token or password
        local access_token
        access_token="$(grep 'access_token:' "$bot_dir/secrets.yaml" 2>/dev/null | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/')" || true

        if [[ -n "$access_token" ]]; then
            local users_result
            users_result="$(curl -sf "${MATRIX_API}/_synapse/admin/v2/users?limit=100" \
                -H "Authorization: Bearer ${access_token}" 2>&1)" || true

            if echo "$users_result" | grep -q "users"; then
                echo "$users_result" | "$PY" -c "
import sys, json
data = json.load(sys.stdin)
users = data.get('users', [])
if not users:
    print('    (no users)')
else:
    for u in users:
        name = u.get('name', u.get('user_id', '?'))
        admin = '  [admin]' if u.get('admin') else ''
        print(f'    {name}{admin}')
" 2>/dev/null || echo "    (could not parse response)"
            else
                # Fallback: just show known users from config
                warn "Admin API not available. Showing known users from config:"
                echo ""
                # Bot user
                local matrix_uid
                matrix_uid="$(grep 'user_id:' "$bot_dir/config.yaml" 2>/dev/null | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/')" || true
                [[ -n "$matrix_uid" ]] && echo "    $matrix_uid  (bot)"
                # Test user from install state
                echo "    @admin:${CONDUIT_SERVER_NAME}  (test account, if created)"
            fi
        else
            warn "No access token found. Run install.sh first."
        fi
    else
        warn "No bot configuration found."
    fi
    pause
}

_matrix_add() {
    echo ""
    local username
    username="$(ask_input "$(i18n matrix_username_prompt)" "")"
    if [[ -z "$username" ]]; then
        return
    fi

    local password
    password="$(ask_input "$(i18n matrix_password_prompt)" "")"
    if [[ -z "$password" ]]; then
        password="$(random_chars 12)"
        info "Generated password: $password"
    fi

    local result
    result="$(curl -sf -X POST "${MATRIX_API}/_matrix/client/r0/register" \
        -H "Content-Type: application/json" \
        -d "{\"username\": \"${username}\", \"password\": \"${password}\", \"auth\": {\"type\": \"m.login.dummy\"}}" 2>&1)" || true

    echo ""
    if echo "$result" | grep -q "access_token"; then
        ok "$(i18n matrix_user_created)"
        echo ""
        printf "    User ID:   ${BOLD}@%s:%s${NC}\n" "$username" "$CONDUIT_SERVER_NAME"
        printf "    Password:  ${BOLD}%s${NC}\n" "$password"
        echo ""
        echo "    Element login:"
        echo "      Homeserver → ${MATRIX_API}"
        echo "      Username   → $username"
        echo "      Password   → $password"
    elif echo "$result" | grep -q "M_USER_IN_USE"; then
        warn "$(i18n matrix_user_exists): @${username}:${CONDUIT_SERVER_NAME}"
    else
        err "$(i18n matrix_user_failed)"
        echo "    $result" | head -3
    fi
    pause
}

_matrix_reset_pw() {
    echo ""
    local username
    username="$(ask_input "$(i18n matrix_username_prompt)" "")"
    if [[ -z "$username" ]]; then
        return
    fi

    local password
    password="$(ask_input "$(i18n matrix_password_prompt)" "")"
    if [[ -z "$password" ]]; then
        password="$(random_chars 12)"
        info "Generated password: $password"
    fi

    # Get admin token from bot secrets
    local bot_dir
    bot_dir="$(ls -d "$BASE_DIR/bots"/*/ 2>/dev/null | head -1)"
    local access_token=""
    if [[ -n "$bot_dir" ]] && [[ -f "$bot_dir/secrets.yaml" ]]; then
        access_token="$(grep 'access_token:' "$bot_dir/secrets.yaml" 2>/dev/null | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/')" || true
    fi

    if [[ -z "$access_token" ]]; then
        err "No admin access token found. Cannot reset password."
        pause
        return
    fi

    local user_id="@${username}:${CONDUIT_SERVER_NAME}"
    local result
    result="$(curl -sf -X PUT "${MATRIX_API}/_synapse/admin/v2/users/${user_id}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${access_token}" \
        -d "{\"password\": \"${password}\"}" 2>&1)" || true

    echo ""
    if echo "$result" | grep -q "error\|errcode"; then
        err "Failed to reset password"
        echo "    $result" | head -3
    else
        ok "Password reset for $user_id"
        printf "    New password: ${BOLD}%s${NC}\n" "$password"
    fi
    pause
}

_matrix_info() {
    echo ""
    printf "  ${BOLD}Server:${NC}       %s\n" "$MATRIX_API"
    printf "  ${BOLD}Server name:${NC}  %s\n" "$CONDUIT_SERVER_NAME"
    printf "  ${BOLD}Federation:${NC}   port %s\n" "$(load_env CONDUIT_FED_PORT 8448)"

    echo ""
    printf "  ${BOLD}Supported versions:${NC}\n"
    local versions
    versions="$(curl -sf "${MATRIX_API}/_matrix/client/versions" 2>&1)" || true
    if [[ -n "$versions" ]]; then
        echo "$versions" | "$PY" -c "
import sys, json
data = json.load(sys.stdin)
for v in data.get('versions', []):
    print(f'    {v}')
" 2>/dev/null || echo "    $versions"
    else
        warn "Could not fetch server info"
    fi

    echo ""
    printf "  ${BOLD}Element login:${NC}\n"
    echo "    Homeserver → ${MATRIX_API}"
    local lan_ip
    lan_ip="$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}')" || true
    if [[ -n "$lan_ip" ]]; then
        echo "    (LAN: http://${lan_ip}:${MATRIX_PORT})"
    fi
    pause
}

# ── Bots ─────────────────────────────────────────────────────────────────────

cmd_bots() {
    while true; do
        echo ""
        printf "  ${BOLD}── $(i18n bots_title) ──${NC}\n"

        local choice
        choice="$(ask_choice "$(i18n bots_title)" 1 \
            "$(i18n bots_list)" \
            "$(i18n bots_add)" \
            "$(i18n bots_remove)" \
            "$(i18n bots_export)" \
            "$(i18n back)")"

        case "$choice" in
            1) _bots_list ;;
            2) _bots_add ;;
            3) _bots_remove ;;
            4) _bots_export ;;
            5) return ;;
        esac
    done
}

_run_manage() {
    # Run manage.py either via docker exec or venv
    local mode
    mode="$(detect_run_mode)"
    if [[ "$mode" == "docker" ]]; then
        local container
        container="$(dc ps --status running --format '{{.Name}}' 2>/dev/null | grep bot | head -1)" || true
        if [[ -n "$container" ]]; then
            docker exec -it "$container" python manage.py "$@"
            return
        fi
    fi
    if [[ -n "$PY" ]]; then
        (cd "$BASE_DIR" && "$PY" manage.py "$@")
    else
        err "Python not found"
    fi
}

_bots_list() {
    echo ""
    _run_manage list 2>&1 | sed 's/^/  /'
    pause
}

_bots_add() {
    echo ""
    local name
    name="$(ask_input "Bot name" "")"
    if [[ -z "$name" ]]; then
        return
    fi
    _run_manage add "$name" </dev/tty 2>&1 | sed 's/^/  /'
    pause
}

_bots_remove() {
    echo ""
    local name
    name="$(ask_input "Bot name to remove" "")"
    if [[ -z "$name" ]]; then
        return
    fi
    _run_manage remove "$name" </dev/tty 2>&1 | sed 's/^/  /'
    pause
}

_bots_export() {
    echo ""
    local name
    name="$(ask_input "Bot name to export" "")"
    if [[ -z "$name" ]]; then
        return
    fi
    _run_manage export "$name" </dev/tty 2>&1 | sed 's/^/  /'
    pause
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN MENU / CLI DISPATCH
# ══════════════════════════════════════════════════════════════════════════════

# CLI mode: handle command-line arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        status)  cmd_status ;;
        start)   cmd_start ;;
        stop)    cmd_stop ;;
        restart) cmd_restart ;;
        logs)    shift; cmd_logs "$@" ;;
        config)  cmd_config ;;
        matrix)  cmd_matrix ;;
        bots)    cmd_bots ;;
        help|--help|-h)
            echo ""
            printf "  ${BOLD}nctl.sh${NC} — NaturalChat Control Panel\n"
            echo ""
            echo "  Usage: bash nctl.sh [command]"
            echo ""
            echo "  Commands:"
            echo "    status     Show current running state"
            echo "    start      Start all services"
            echo "    stop       Stop all services"
            echo "    restart    Restart all services"
            echo "    logs [svc] View logs (optional: bot, conduit, memobase-api...)"
            echo "    config     Edit configuration"
            echo "    matrix     Matrix account management"
            echo "    bots       Manage bot instances"
            echo ""
            echo "  No arguments: interactive menu"
            echo ""
            ;;
        *)
            err "Unknown command: $1"
            echo "  Run: bash nctl.sh help"
            exit 1
            ;;
    esac
    exit 0
fi

# Interactive mode: main menu loop
while true; do
    clear 2>/dev/null || true
    echo ""
    printf "  ${BOLD}╭──────────────────────────────────────────╮${NC}\n"
    printf "  ${BOLD}│       $(i18n title)       │${NC}\n"
    printf "  ${BOLD}╰──────────────────────────────────────────╯${NC}\n"
    printf "  ${DIM}  %s${NC}\n" "$BASE_DIR"

    # Quick status line
    local mode
    mode="$(detect_run_mode)"
    case "$mode" in
        docker) printf "  ${GREEN}●${NC} Running (Docker)\n" ;;
        host)   printf "  ${GREEN}●${NC} Running (Host)\n" ;;
        *)      printf "  ${RED}●${NC} Stopped\n" ;;
    esac

    local has_matrix=false
    if [[ -n "$(load_env CONDUIT_PORT "")" ]] || dc ps --status running --format '{{.Name}}' 2>/dev/null | grep -q "conduit"; then
        has_matrix=true
    fi

    local menu_items=()
    menu_items+=("$(i18n menu_status)")
    menu_items+=("$(i18n menu_start)")
    menu_items+=("$(i18n menu_stop)")
    menu_items+=("$(i18n menu_restart)")
    menu_items+=("$(i18n menu_logs)")
    menu_items+=("$(i18n menu_config)")
    [[ "$has_matrix" == "true" ]] && menu_items+=("$(i18n menu_matrix)")
    menu_items+=("$(i18n menu_bots)")
    menu_items+=("$(i18n menu_exit)")

    local total=${#menu_items[@]}
    local choice
    choice="$(ask_choice "" 1 "${menu_items[@]}")"

    # Map choice to action, accounting for optional Matrix menu
    local idx=$((choice - 1))
    local actions=("status" "start" "stop" "restart" "logs" "config")
    [[ "$has_matrix" == "true" ]] && actions+=("matrix")
    actions+=("bots" "exit")

    local action="${actions[$idx]}"

    case "$action" in
        status)  cmd_status; pause ;;
        start)   cmd_start; pause ;;
        stop)    cmd_stop; pause ;;
        restart) cmd_restart; pause ;;
        logs)    cmd_logs ;;
        config)  cmd_config ;;
        matrix)  cmd_matrix ;;
        bots)    cmd_bots ;;
        exit)    echo ""; break ;;
    esac
done
