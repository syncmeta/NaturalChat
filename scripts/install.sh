#!/usr/bin/env bash
# install.sh - NaturalChat interactive setup wizard
#
# Works on a clean Linux/macOS without Python pre-installed.
# Supports resume — if you exit midway, re-run and it picks up where you left off.
#
# One-liner install:
#   bash <(curl -fsSL https://raw.githubusercontent.com/syncmeta/naturalchat/main/install.sh)

set -euo pipefail
trap 'echo ""; echo "[CRASH] Script failed at line $LINENO (exit code $?)" >&2' ERR

# ── Colors & helpers ─────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
PURPLE='\033[1;35m'

LANG_UI="en"

i18n() {
    local key="$1"
    case "$LANG_UI:$key" in
        # ── Generic UI labels ──
        en:default_label) echo "default" ;;
        zh:default_label) echo "默认" ;;
        en:choice_label) echo "Choice" ;;
        zh:choice_label) echo "选择" ;;
        en:arrow_help) echo "Arrow keys to move, Enter to select" ;;
        zh:arrow_help) echo "方向键移动，回车确认" ;;
        en:yes_label) echo "Yes" ;;
        zh:yes_label) echo "是" ;;
        en:no_label) echo "No" ;;
        zh:no_label) echo "否" ;;

        # ── Config overview ──
        en:cfg_bot_name) echo "Bot name:" ;;
        zh:cfg_bot_name) echo "机器人名称：" ;;
        en:cfg_platforms) echo "Channels:" ;;
        zh:cfg_platforms) echo "对话渠道：" ;;
        en:cfg_llm_url) echo "BASE_URL:" ;;
        zh:cfg_llm_url) echo "BASE_URL：" ;;
        en:cfg_llm_model) echo "Model:" ;;
        zh:cfg_llm_model) echo "主模型 / Model：" ;;
        en:cfg_api_key) echo "API Key:" ;;
        zh:cfg_api_key) echo "API Key：" ;;
        en:cfg_access) echo "Who can use it:" ;;
        zh:cfg_access) echo "机器人能给谁用：" ;;
        en:cfg_components) echo "Components:" ;;
        zh:cfg_components) echo "可选组件 / Components：" ;;
        en:cfg_not_set) echo "not set" ;;
        zh:cfg_not_set) echo "未设置" ;;
        en:cfg_none) echo "none" ;;
        zh:cfg_none) echo "无" ;;
        en:cfg_comp_select) echo "Enable components:" ;;
        zh:cfg_comp_select) echo "启用组件：" ;;

        # ── System detection (silent, only for errors) ──
        en:already_done) echo "Already completed (skipping)" ;;
        zh:already_done) echo "已完成（跳过）" ;;

        # ── Platforms ──
        en:plat_select) echo "Enable platforms:" ;;
        zh:plat_select) echo "启用平台：" ;;
        en:feishu_label) echo "Feishu (Lark)" ;;
        zh:feishu_label) echo "飞书" ;;
        en:tg_howto) echo "How to get a token: open Telegram -> @BotFather -> /newbot" ;;
        zh:tg_howto) echo "获取 Token：打开 Telegram -> @BotFather -> /newbot" ;;
        en:matrix_how) echo "Matrix server:" ;;
        zh:matrix_how) echo "Matrix 服务器：" ;;
        en:matrix_docker) echo "Deploy Conduit via Docker (lightweight)" ;;
        zh:matrix_docker) echo "通过 Docker 部署 Conduit（轻量级）" ;;
        en:matrix_existing) echo "Connect to existing Matrix server" ;;
        zh:matrix_existing) echo "连接到已有的 Matrix 服务器" ;;
        en:matrix_auth) echo "Auth method:" ;;
        zh:matrix_auth) echo "认证方式：" ;;
        en:feishu_howto_1) echo "1. Create app at open.feishu.cn" ;;
        zh:feishu_howto_1) echo "1. 在 open.feishu.cn 创建应用" ;;
        en:feishu_howto_2) echo "2. Get App ID + Secret, set event callback URL" ;;
        zh:feishu_howto_2) echo "2. 获取 App ID + Secret，设置事件回调 URL" ;;
        en:no_platform_warn) echo "No external platform enabled. You can still test via the web panel." ;;
        zh:no_platform_warn) echo "未启用任何外部平台。你仍然可以通过网页面板测试。" ;;

        # ── LLM ──
        en:no_api_key) echo "No API key — fill it later in bots/<name>/secrets.yaml" ;;
        zh:no_api_key) echo "未填写 API 密钥 —— 稍后在 bots/<name>/secrets.yaml 中填写" ;;

        # ── Bot ──
        en:bot_name_hint) echo "Bot name is used as the directory name under bots/." ;;
        zh:bot_name_hint) echo "机器人名称将用作 bots/ 下的目录名。" ;;
        en:bot_name_prompt) echo "Bot name:" ;;
        zh:bot_name_prompt) echo "机器人名称：" ;;
        en:bot_name_use) echo "Use" ;;
        zh:bot_name_use) echo "使用" ;;
        en:bot_name_reroll) echo "Generate another random name" ;;
        zh:bot_name_reroll) echo "再随机生成一个" ;;
        en:bot_name_custom) echo "Enter a custom name" ;;
        zh:bot_name_custom) echo "自定义名称" ;;
        en:bot_exists_warn) echo "already exists. Its config will be preserved." ;;
        zh:bot_exists_warn) echo "已存在。其配置将被保留。" ;;
        en:access_prompt) echo "Access control:" ;;
        zh:access_prompt) echo "访问控制：" ;;
        en:access_open) echo "open     — Anyone can chat" ;;
        zh:access_open) echo "open     —— 任何人都可以聊天" ;;
        en:access_approval) echo "approval — New contacts need admin approval" ;;
        zh:access_approval) echo "approval —— 新联系人需要管理员审批" ;;
        en:access_private) echo "private  — Only admin and creator can chat" ;;
        zh:access_private) echo "private  —— 仅管理员和创建者可以聊天" ;;

        # ── Config gen ──
        en:config_generated) echo "Config files generated" ;;
        zh:config_generated) echo "配置文件生成好了" ;;

        # ── Deploy & Launch ──
        en:deploying_services) echo "Deploying Docker services..." ;;
        zh:deploying_services) echo "正在部署 Docker 服务..." ;;
        en:services_started) echo "Docker services started successfully" ;;
        zh:services_started) echo "Docker 服务启动成功" ;;
        en:services_failed) echo "Some Docker services failed to start. Check: docker compose logs" ;;
        zh:services_failed) echo "部分 Docker 服务启动失败。请检查：docker compose logs" ;;
        en:no_services) echo "No Docker services to deploy." ;;
        zh:no_services) echo "无需部署 Docker 服务。" ;;

        # ── Memobase ──
        en:memobase_docker) echo "Deploy locally via Docker (free, recommended)" ;;
        zh:memobase_docker) echo "通过 Docker 本地部署（免费，推荐）" ;;
        en:memobase_remote) echo "Connect to an existing Memobase server" ;;
        zh:memobase_remote) echo "连接到已有的 Memobase 服务器" ;;

        # ── Crawl4AI ──
        en:crawl4ai_docker) echo "Deploy locally via Docker (free, recommended)" ;;
        zh:crawl4ai_docker) echo "通过 Docker 本地部署（免费，推荐）" ;;
        en:crawl4ai_cloud) echo "Connect to an existing Crawl4AI server" ;;
        zh:crawl4ai_cloud) echo "连接到已有的 Crawl4AI 服务器" ;;

        # ── Summary ──
        en:setup_complete) echo "Setup Complete" ;;
        zh:setup_complete) echo "安装完成" ;;
        en:web_panel) echo "Web Panel" ;;
        zh:web_panel) echo "网页面板" ;;
        en:missing_creds_warn) echo "Missing credentials (fill before starting):" ;;
        zh:missing_creds_warn) echo "缺失的凭据（启动前请填写）：" ;;

        *) echo "$key" ;;
    esac
}

term_cols() {
    local cols="${COLUMNS:-}"
    if [[ -z "$cols" ]] && command -v tput &>/dev/null; then
        cols="$(tput cols 2>/dev/null || true)"
    fi
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
    (( cols < 48 )) && cols=48
    echo "$cols"
}

ui_width() {
    local cols width
    cols="$(term_cols)"
    width=$(( cols - 6 ))
    (( width > 76 )) && width=76
    (( width < 36 )) && width=36
    echo "$width"
}

repeat_char() {
    local count="$1" char="${2:-─}" out=""
    while (( ${#out} < count )); do
        out="${out}${char}"
    done
    printf '%s' "${out:0:count}"
}

wrap_print() {
    local text="$1" indent="${2:-2}" width available pad
    width="$(ui_width)"
    available=$(( width - indent ))
    (( available < 20 )) && available=20
    printf -v pad '%*s' "$indent" ''
    while IFS= read -r line; do
        printf '%s%s\n' "$pad" "$line"
    done < <(printf '%s\n' "$text" | fold -s -w "$available")
}

info()  { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}  OK${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
err()   { printf "${RED}[ERR]${NC}  %s\n" "$*"; }
die()   { err "$*"; exit 1; }
hr()    { printf "${DIM}%s${NC}\n" "$(repeat_char "$(ui_width)" "─")"; }

ask() {
    local prompt="$1" default="${2:-}"
    if [[ -n "$default" ]]; then
        printf "  %s ${DIM}(%s: %s)${NC}: " "$prompt" "$(i18n default_label)" "$default" >&2
    else
        printf "  %s: " "$prompt" >&2
    fi
    read -r answer </dev/tty
    echo "${answer:-$default}"
}

# ── Arrow-key Yes/No selector (replaces y/n typing) ─────────────────────────
ask_yn() {
    local prompt="$1" default="${2:-y}"
    local def_idx=1
    [[ "$default" != "y" ]] && def_idx=2
    local choice
    choice="$(ask_choice "$prompt" "$def_idx" "$(i18n yes_label)" "$(i18n no_label)")"
    [[ "$choice" == "1" ]]
}

# ── Arrow-key interactive selector ──────────────────────────────────────────
# Usage: ask_choice "prompt" default_index "option1" "option2" ...
# Returns the 1-based index of the selected option.
ask_choice() {
    local prompt="$1" default="$2"
    shift 2
    local options=("$@")
    local count=${#options[@]}
    local selected=$((default - 1))  # 0-based internally
    local cols
    cols="$(term_cols)"

    # Check if terminal supports interactive mode
    if (( cols < 72 )) || ! [[ -t 0 ]] && [[ ! -e /dev/tty ]]; then
        # Fallback: simple numbered list
        echo "" >&2
        wrap_print "$prompt" 2 >&2
        local i=1
        for opt in "${options[@]}"; do
            if [[ $i -eq $default ]]; then
                wrap_print "[$i] $opt ($(i18n default_label))" 4 >&2
            else
                wrap_print "[$i] $opt" 4 >&2
            fi
            ((i++))
        done
        printf "\n  %s ${DIM}(%s: %d)${NC}: " "$(i18n choice_label)" "$(i18n default_label)" "$default" >&2
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
    if [[ -n "$prompt" ]]; then
        printf "  %s  ${DIM}(%s)${NC}\n\n" "$prompt" "$(i18n arrow_help)" >&2
    else
        printf "  ${DIM}(%s)${NC}\n\n" "$(i18n arrow_help)" >&2
    fi

    # Hide cursor
    printf "\033[?25l" >&2

    # Draw options
    _draw_choices() {
        local i
        for ((i = 0; i < count; i++)); do
            if [[ $i -eq $selected ]]; then
                printf "\r\033[2K  ${GREEN}${BOLD}> %s${NC}\n" "${options[$i]}" >&2
            else
                printf "\r\033[2K    %s\n" "${options[$i]}" >&2
            fi
        done
    }

    _draw_choices

    # Read arrow keys
    while true; do
        # Read one char (raw mode)
        IFS= read -rsn1 key </dev/tty
        case "$key" in
            $'\x1b')
                # Escape sequence — read 2 more chars
                IFS= read -rsn2 rest </dev/tty
                case "$rest" in
                    '[A')  # Up arrow
                        ((selected > 0)) && ((selected--))
                        ;;
                    '[B')  # Down arrow
                        ((selected < count - 1)) && ((selected++))
                        ;;
                esac
                ;;
            'k')  # vim up
                ((selected > 0)) && ((selected--))
                ;;
            'j')  # vim down
                ((selected < count - 1)) && ((selected++))
                ;;
            '')  # Enter
                break
                ;;
        esac
        # Move cursor up to redraw
        printf "\033[%dA" "$count" >&2
        _draw_choices
    done

    # Show cursor
    printf "\033[?25h" >&2

    echo $(( selected + 1 ))
}

# Multi-select with space to toggle, Enter to confirm
# Usage: ask_multi_select "prompt" "label1:default1" "label2:default2" ...
#   default = 1 (on) or 0 (off)
# Returns space-separated list of 1-based indices that are ON
ask_multi_select() {
    local prompt="$1"
    shift
    local labels=() defaults=() toggled=()
    local i=0
    for item in "$@"; do
        labels+=("${item%%:*}")
        defaults+=("${item##*:}")
        toggled+=("${item##*:}")
        ((i++))
    done
    local count=${#labels[@]}
    local selected=0  # cursor position
    local cols
    cols="$(term_cols)"

    # Fallback for non-interactive terminals
    if (( cols < 72 )) || ! [[ -t 0 ]] && [[ ! -e /dev/tty ]]; then
        echo "" >&2
        wrap_print "$prompt" 2 >&2
        for ((i = 0; i < count; i++)); do
            local mark=" "
            [[ "${toggled[$i]}" == "1" ]] && mark="*"
            wrap_print "[$mark] $((i+1)). ${labels[$i]}" 4 >&2
        done
        printf "\n  Enter numbers to toggle (e.g. 1 3), or Enter to confirm: " >&2
        read -r nums </dev/tty 2>/dev/null || nums=""
        for n in $nums; do
            if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= count )); then
                local idx=$((n-1))
                if [[ "${toggled[$idx]}" == "1" ]]; then toggled[$idx]=0; else toggled[$idx]=1; fi
            fi
        done
        local result=""
        for ((i = 0; i < count; i++)); do
            [[ "${toggled[$i]}" == "1" ]] && result="$result $((i+1))"
        done
        echo "${result# }"
        return
    fi

    local help_en="Space: toggle, Enter: confirm"
    local help_zh="空格：切换，回车：确认"
    local help_text="$help_en"
    [[ "$LANG_UI" == "zh" ]] && help_text="$help_zh"

    echo "" >&2
    printf "  %s  ${DIM}(%s)${NC}\n\n" "$prompt" "$help_text" >&2

    printf "\033[?25l" >&2

    _draw_multi() {
        local i
        for ((i = 0; i < count; i++)); do
            local check=" "
            [[ "${toggled[$i]}" == "1" ]] && check="${GREEN}✔${NC}"
            if [[ $i -eq $selected ]]; then
                printf "\r\033[2K  ${BOLD}> [%b] %s${NC}\n" "$check" "${labels[$i]}" >&2
            else
                printf "\r\033[2K    [%b] %s\n" "$check" "${labels[$i]}" >&2
            fi
        done
    }

    _draw_multi

    while true; do
        IFS= read -rsn1 key </dev/tty
        case "$key" in
            $'\x1b')
                IFS= read -rsn2 rest </dev/tty
                case "$rest" in
                    '[A') ((selected > 0)) && ((selected--)) ;;
                    '[B') ((selected < count - 1)) && ((selected++)) ;;
                esac
                ;;
            'k') ((selected > 0)) && ((selected--)) ;;
            'j') ((selected < count - 1)) && ((selected++)) ;;
            ' ')  # Space — toggle
                if [[ "${toggled[$selected]}" == "1" ]]; then
                    toggled[$selected]=0
                else
                    toggled[$selected]=1
                fi
                ;;
            '')  # Enter — confirm
                break
                ;;
        esac
        printf "\033[%dA" "$count" >&2
        _draw_multi
    done

    printf "\033[?25h" >&2

    local result=""
    for ((i = 0; i < count; i++)); do
        [[ "${toggled[$i]}" == "1" ]] && result="$result $((i+1))"
    done
    echo "${result# }"
}

# Extract a JSON string value by key (no Python needed)
# Usage: json_val '{"key":"value"}' "key"
json_val() {
    echo "$1" | grep -o "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/'
}

random_chars() {
    local len="${1:-8}" result=""
    while (( ${#result} < len )); do
        result="${result}$(( RANDOM % 10 ))$(printf '%x' $(( RANDOM % 16 )))"
    done
    echo "${result:0:len}"
}

random_name() {
    echo "bot-$(random_chars 8)"
}

random_username() {
    echo "admin-$(random_chars 6)"
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
        return 1  # can't check, assume free
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

# ── State / Resume ───────────────────────────────────────────────────────────
# Each completed step writes a marker. On re-run, completed steps are skipped.

step_done()  { [[ -f "$STATE_DIR/step_$1" ]]; }
mark_step()  { touch "$STATE_DIR/step_$1"; }
save_var()   { echo "$2" > "$STATE_DIR/var_$1"; }
load_var()   { [[ -f "$STATE_DIR/var_$1" ]] && cat "$STATE_DIR/var_$1" || echo "${2:-}"; }

# ── Title & Language ─────────────────────────────────────────────────────────

echo ""
printf "${PURPLE}NaturalChat Setup${NC}\n"
echo ""

LANG_CHOICE="$(ask_choice "" 1 "English" "中文")"
if [[ "$LANG_CHOICE" == "2" ]]; then
    LANG_UI="zh"
fi

echo ""

# ── Step 0: Ensure we're inside the repo ─────────────────────────────────────

REPO_URL="https://github.com/syncmeta/naturalchat.git"

if [[ -f "main.py" ]] && [[ -d "src" ]] && [[ -f "requirements.txt" ]]; then
    BASE_DIR="$(pwd)"
elif [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "$(dirname "${BASH_SOURCE[0]}")/main.py" ]]; then
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    info "NaturalChat source not found in current directory."
    if ! command -v git &>/dev/null; then
        die "git is required to clone the repository. Please install git first."
    fi
    INSTALL_DIR="$(ask "Where to install NaturalChat?" "./naturalchat")"
    if [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/main.py" ]]; then
        info "Existing installation found at $INSTALL_DIR"
        BASE_DIR="$(cd "$INSTALL_DIR" && pwd)"
    else
        info "Cloning NaturalChat..."
        git clone "$REPO_URL" "$INSTALL_DIR"
        BASE_DIR="$(cd "$INSTALL_DIR" && pwd)"
        ok "Cloned to $BASE_DIR"
    fi
fi

cd "$BASE_DIR"
BOTS_DIR="$BASE_DIR/bots"
STATE_DIR="$BASE_DIR/.install_state"
mkdir -p "$STATE_DIR"

# Optional local installer defaults (ignored by git via local/).
# Copy install.defaults.example to local/install.defaults and fill in your own values.
INSTALL_DEFAULTS_FILE="${NATURALCHAT_INSTALL_DEFAULTS:-$BASE_DIR/local/install.defaults}"
if [[ -f "$INSTALL_DEFAULTS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$INSTALL_DEFAULTS_FILE"
fi

# ═════════════════════════════════════════════════════════════════════════════
# Silent system detection + Docker requirement
# ═════════════════════════════════════════════════════════════════════════════

OS="$(uname -s)"
ARCH="$(uname -m)"
DISTRO=""
PKG_MGR=""

case "$OS" in
    Linux)
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            DISTRO="$ID $VERSION_ID"
        fi
        if command -v apt-get &>/dev/null; then PKG_MGR="apt"
        elif command -v dnf &>/dev/null; then PKG_MGR="dnf"
        elif command -v yum &>/dev/null; then PKG_MGR="yum"
        elif command -v pacman &>/dev/null; then PKG_MGR="pacman"
        elif command -v apk &>/dev/null; then PKG_MGR="apk"
        elif command -v zypper &>/dev/null; then PKG_MGR="zypper"
        fi
        ;;
    Darwin)
        DISTRO="macOS $(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
        command -v brew &>/dev/null && PKG_MGR="brew"
        ;;
    *)  die "Unsupported OS: $OS" ;;
esac

HAS_GIT=false
command -v git &>/dev/null && HAS_GIT=true

# ── Docker detection & auto-install ──────────────────────────────────────────

HAS_DOCKER=false
if command -v docker &>/dev/null; then
    if docker info &>/dev/null 2>&1; then
        HAS_DOCKER=true
    fi
fi

if ! $HAS_DOCKER; then
    if [[ "$OS" == "Linux" ]]; then
        # Try installing podman as Docker-compatible alternative
        info "Docker not found. Trying to install Podman..."
        PODMAN_INSTALLED=false
        case "$PKG_MGR" in
            apt)
                if sudo apt-get update -qq && sudo apt-get install -y podman podman-docker 2>/dev/null; then
                    PODMAN_INSTALLED=true
                fi
                ;;
            dnf)
                if sudo dnf install -y podman podman-docker 2>/dev/null; then
                    PODMAN_INSTALLED=true
                fi
                ;;
            yum)
                if sudo yum install -y podman podman-docker 2>/dev/null; then
                    PODMAN_INSTALLED=true
                fi
                ;;
            pacman)
                if sudo pacman -Sy --noconfirm podman podman-docker 2>/dev/null; then
                    PODMAN_INSTALLED=true
                fi
                ;;
            zypper)
                if sudo zypper install -y podman podman-docker 2>/dev/null; then
                    PODMAN_INSTALLED=true
                fi
                ;;
            apk)
                if sudo apk add podman podman-docker 2>/dev/null; then
                    PODMAN_INSTALLED=true
                fi
                ;;
        esac

        if $PODMAN_INSTALLED; then
            # Verify it works
            if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
                HAS_DOCKER=true
                ok "Podman installed as Docker replacement"
            elif command -v podman &>/dev/null && podman info &>/dev/null 2>&1; then
                HAS_DOCKER=true
                ok "Podman installed"
            fi
        fi

        if ! $HAS_DOCKER; then
            err "Could not install Podman automatically."
            echo ""
            echo "  Please install Docker or Podman manually:"
            echo "    https://docs.docker.com/engine/install/"
            echo "    https://podman.io/docs/installation"
            echo ""
            exit 1
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        info "Docker not found. Trying to install OrbStack..."
        if command -v brew &>/dev/null; then
            if brew install --cask orbstack 2>/dev/null; then
                # Wait a moment for OrbStack to initialize
                sleep 2
                if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
                    HAS_DOCKER=true
                    ok "OrbStack installed"
                else
                    echo ""
                    echo "  OrbStack was installed but Docker is not ready yet."
                    echo "  Please open OrbStack, complete setup, then re-run this script."
                    echo ""
                    exit 1
                fi
            fi
        fi

        if ! $HAS_DOCKER; then
            echo ""
            echo "  Docker is required. Please install OrbStack:"
            echo "    https://orbstack.dev/download"
            echo ""
            exit 1
        fi
    else
        die "Docker is required but not available on this system."
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# Configuration overview (arrow-key navigation)
# ═════════════════════════════════════════════════════════════════════════════

if step_done 2; then
    USE_MEMOBASE="$(load_var USE_MEMOBASE false)"
    MEMOBASE_MODE="$(load_var MEMOBASE_MODE "")"
    MEMOBASE_URL="$(load_var MEMOBASE_URL "")"
    MEMOBASE_KEY="$(load_var MEMOBASE_KEY "")"
    MEMOBASE_PORT="$(load_var MEMOBASE_PORT "")"
    USE_CRAWL4AI="$(load_var USE_CRAWL4AI false)"
    CRAWL4AI_MODE="$(load_var CRAWL4AI_MODE "")"
    CRAWL4AI_URL="$(load_var CRAWL4AI_URL "")"
    CRAWL4AI_KEY="$(load_var CRAWL4AI_KEY "")"
    CRAWL4AI_PORT="$(load_var CRAWL4AI_PORT "")"
    RSSHUB_MODE="$(load_var RSSHUB_MODE "docker")"
    RSSHUB_URL="$(load_var RSSHUB_URL "")"
    RSSHUB_PORT="$(load_var RSSHUB_PORT "")"
    SERPER_KEY="$(load_var SERPER_KEY "")"
    TG_ENABLED="$(load_var TG_ENABLED false)"
    TG_TOKEN="$(load_var TG_TOKEN "")"
    MATRIX_ENABLED="$(load_var MATRIX_ENABLED false)"
    MATRIX_HOMESERVER="$(load_var MATRIX_HOMESERVER "")"
    MATRIX_USER_ID="$(load_var MATRIX_USER_ID "")"
    MATRIX_ACCESS_TOKEN="$(load_var MATRIX_ACCESS_TOKEN "")"
    MATRIX_PASSWORD="$(load_var MATRIX_PASSWORD "")"
    NEEDS_CONDUIT="$(load_var NEEDS_CONDUIT false)"
    CONDUIT_PORT="$(load_var CONDUIT_PORT "")"
    CONDUIT_FED_PORT="$(load_var CONDUIT_FED_PORT "")"
    CONDUIT_SERVER_NAME="$(load_var CONDUIT_SERVER_NAME "")"
    CONDUIT_BOT_USER="$(load_var CONDUIT_BOT_USER "")"
    FEISHU_ENABLED="$(load_var FEISHU_ENABLED false)"
    FEISHU_APP_ID="$(load_var FEISHU_APP_ID "")"
    FEISHU_APP_SECRET="$(load_var FEISHU_APP_SECRET "")"
    FEISHU_PORT="$(load_var FEISHU_PORT 9000)"
    XMPP_ENABLED="$(load_var XMPP_ENABLED false)"
    XMPP_JID="$(load_var XMPP_JID "")"
    XMPP_PASSWORD="$(load_var XMPP_PASSWORD "")"
    XMPP_HOST="$(load_var XMPP_HOST "")"
    XMPP_PORT="$(load_var XMPP_PORT 5222)"
    API_KEY="$(load_var API_KEY "")"
    BASE_URL="$(load_var BASE_URL "https://openrouter.ai/api/v1")"
    MODEL="$(load_var MODEL "openrouter/auto")"
    BOT_NAME="$(load_var BOT_NAME "")"
    ACCESS_MODE="$(load_var ACCESS_MODE "open")"
    CREATOR_ID="$(load_var CREATOR_ID "")"
else
    # ── Set all defaults ──────────────────────────────────────────────────
    BOT_NAME="${DEFAULT_BOT_NAME:-$(random_name)}"
    ACCESS_MODE="open"
    CREATOR_ID=""

    # LLM
    BASE_URL="${DEFAULT_BASE_URL:-https://openrouter.ai/api/v1}"
    MODEL="${DEFAULT_MODEL:-openrouter/auto}"
    API_KEY="${DEFAULT_API_KEY:-}"

    # Platforms — default: Matrix via Docker Conduit
    TG_ENABLED=false;  TG_TOKEN=""
    MATRIX_ENABLED=true; MATRIX_HOMESERVER=""; MATRIX_USER_ID=""
    MATRIX_ACCESS_TOKEN=""; MATRIX_PASSWORD=""
    FEISHU_ENABLED=false; FEISHU_APP_ID=""; FEISHU_APP_SECRET=""; FEISHU_PORT=9000
    XMPP_ENABLED=false; XMPP_JID=""; XMPP_PASSWORD=""; XMPP_HOST=""; XMPP_PORT=5222

    NEEDS_CONDUIT=true
    CONDUIT_PORT="${DEFAULT_CONDUIT_PORT:-$(random_port)}"
    CONDUIT_FED_PORT="$(random_port)"
    CONDUIT_SERVER_NAME="localhost"
    CONDUIT_BOT_USER=""
    MATRIX_PASSWORD="${DEFAULT_MATRIX_PASSWORD:-$(random_chars 16)}"
    MATRIX_HOMESERVER="http://127.0.0.1:$CONDUIT_PORT"

    # Components
    USE_MEMOBASE=true; MEMOBASE_MODE="docker"; MEMOBASE_PORT="$(random_port)"
    MEMOBASE_URL="http://127.0.0.1:$MEMOBASE_PORT"; MEMOBASE_KEY="$(random_chars 32)"
    USE_CRAWL4AI=true; CRAWL4AI_MODE="docker"; CRAWL4AI_PORT="$(random_port)"
    CRAWL4AI_URL="http://localhost:$CRAWL4AI_PORT"; CRAWL4AI_KEY=""
    SERPER_KEY=""
    RSSHUB_MODE="docker"; RSSHUB_PORT="$(random_port)"; RSSHUB_URL="http://localhost:$RSSHUB_PORT"

    # ── Helper: format display values ─────────────────────────────────────

    _plat_summary() {
        local parts=()
        [[ "$MATRIX_ENABLED" == "true" ]] && {
            if [[ "$NEEDS_CONDUIT" == "true" ]]; then
                parts+=("Matrix (Conduit Docker)")
            else
                parts+=("Matrix ($(echo "$MATRIX_HOMESERVER" | sed 's|https\?://||'))")
            fi
        }
        [[ "$TG_ENABLED" == "true" ]] && parts+=("Telegram")
        [[ "$FEISHU_ENABLED" == "true" ]] && parts+=("Feishu")
        [[ "$XMPP_ENABLED" == "true" ]] && parts+=("XMPP")
        if (( ${#parts[@]} == 0 )); then
            echo "$(i18n cfg_none)"
        else
            local IFS=", "; echo "${parts[*]}"
        fi
    }

    _comp_summary() {
        local parts=()
        if [[ "$RSSHUB_MODE" == "docker" ]]; then parts+=("RSSHub (Docker)")
        elif [[ -n "$RSSHUB_URL" ]]; then parts+=("RSSHub ($RSSHUB_URL)")
        fi
        [[ "$USE_MEMOBASE" == "true" ]] && parts+=("Memobase")
        [[ "$USE_CRAWL4AI" == "true" ]] && parts+=("Crawl4AI")
        [[ -n "$SERPER_KEY" ]] && parts+=("Serper")
        if (( ${#parts[@]} == 0 )); then
            echo "RSSHub (Docker)"
        else
            local IFS=", "; echo "${parts[*]}"
        fi
    }

    _mask_key() {
        local k="$1"
        if [[ -z "$k" ]]; then
            printf "${YELLOW}($(i18n cfg_not_set))${NC}"
        elif (( ${#k} > 8 )); then
            echo "${k:0:4}****${k: -4}"
        else
            echo "****"
        fi
    }

    # ── Display config overview with arrow-key navigation ────────────────

    # Config items: 1=bot_name 2=channels 3=base_url 4=model 5=api_key 6=access 7=components
    CFG_ITEM_COUNT=7
    # Default cursor on API Key (item 5, 0-based index 4)
    CFG_SELECTED=4

    _config_labels() {
        # Returns label for item $1 (1-based)
        case "$1" in
            1) echo "$(i18n cfg_bot_name)" ;;
            2) echo "$(i18n cfg_platforms)" ;;
            3) echo "$(i18n cfg_llm_url)" ;;
            4) echo "$(i18n cfg_llm_model)" ;;
            5) echo "$(i18n cfg_api_key)" ;;
            6) echo "$(i18n cfg_access)" ;;
            7) echo "$(i18n cfg_components)" ;;
        esac
    }

    _config_values() {
        case "$1" in
            1) echo "$BOT_NAME" ;;
            2) echo "$(_plat_summary)" ;;
            3) echo "$BASE_URL" ;;
            4) echo "$MODEL" ;;
            5) _mask_key "$API_KEY" ;;
            6) echo "$ACCESS_MODE" ;;
            7) echo "$(_comp_summary)" ;;
        esac
    }

    _draw_config() {
        # Instruction lines (always bilingual)
        echo ""
        printf "  如果没什么特殊要求，填一个 OpenRouter 的 key 就可以了。回车开始安装。\n"
        printf "  No special needs? Just fill in an OpenRouter key and press Enter to install.\n"
        echo ""

        for ((i = 1; i <= CFG_ITEM_COUNT; i++)); do
            local label="$(_config_labels "$i")"
            local value="$(_config_values "$i")"
            local idx_display="$i"
            if [[ $(( i - 1 )) -eq $CFG_SELECTED ]]; then
                printf "  ${GREEN}${BOLD}> ${PURPLE}%s${NC}  ${GREEN}${BOLD}%-22s %b${NC}\n" "$idx_display" "$label" "$value"
            else
                printf "    ${PURPLE}%s${NC}  %-22s %b\n" "$idx_display" "$label" "$value"
            fi
        done
        echo ""
    }

    # ── Edit a config item ────────────────────────────────────────────────

    _edit_item() {
        case "$1" in
        1)  # Bot name
            while true; do
                DEFAULT_NAME="$(random_name)"
                printf "\n  $(i18n bot_name_hint)\n"
                printf "  Random: ${BOLD}${GREEN}%s${NC}\n\n" "$DEFAULT_NAME"
                c="$(ask_choice "$(i18n bot_name_prompt)" 1 \
                    "$(i18n bot_name_use) \"$DEFAULT_NAME\"" \
                    "$(i18n bot_name_reroll)" \
                    "$(i18n bot_name_custom)")"
                if [[ "$c" == "1" ]]; then BOT_NAME="$DEFAULT_NAME"; break
                elif [[ "$c" == "3" ]]; then
                    BOT_NAME="$(ask "Enter bot name" "")"
                    BOT_NAME="$(echo "$BOT_NAME" | tr -cd 'a-zA-Z0-9_-')"
                    [[ -z "$BOT_NAME" ]] && BOT_NAME="$DEFAULT_NAME"
                    break
                fi
            done
            # Re-derive Conduit bot user
            if [[ "$NEEDS_CONDUIT" == "true" ]]; then
                CONDUIT_BOT_USER="$(echo "$BOT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
                CONDUIT_BOT_USER="${CONDUIT_BOT_USER:-bot}"
                MATRIX_USER_ID="@${CONDUIT_BOT_USER}:${CONDUIT_SERVER_NAME}"
            fi
            ;;
        2)  # Platforms / Channels
            plat_sel="$(ask_multi_select "$(i18n plat_select)" \
                "Matrix:$( [[ "$MATRIX_ENABLED" == "true" ]] && echo 1 || echo 0 )" \
                "Telegram:$( [[ "$TG_ENABLED" == "true" ]] && echo 1 || echo 0 )" \
                "$(i18n feishu_label):$( [[ "$FEISHU_ENABLED" == "true" ]] && echo 1 || echo 0 )" \
                "XMPP:$( [[ "$XMPP_ENABLED" == "true" ]] && echo 1 || echo 0 )")"

            # Reset then apply
            TG_ENABLED=false; MATRIX_ENABLED=false; FEISHU_ENABLED=false; XMPP_ENABLED=false
            [[ " $plat_sel " == *" 1 "* ]] && MATRIX_ENABLED=true
            [[ " $plat_sel " == *" 2 "* ]] && TG_ENABLED=true
            [[ " $plat_sel " == *" 3 "* ]] && FEISHU_ENABLED=true
            [[ " $plat_sel " == *" 4 "* ]] && XMPP_ENABLED=true

            # Matrix sub-config
            if [[ "$MATRIX_ENABLED" == "true" ]] && [[ "$NEEDS_CONDUIT" != "true" ]] && [[ -z "$MATRIX_HOMESERVER" ]]; then
                c="$(ask_choice "$(i18n matrix_how)" 1 "$(i18n matrix_docker)" "$(i18n matrix_existing)")"
                if [[ "$c" == "1" ]]; then
                    NEEDS_CONDUIT=true
                    [[ -z "$CONDUIT_PORT" ]] && CONDUIT_PORT="$(random_port)"
                    [[ -z "$CONDUIT_FED_PORT" ]] && CONDUIT_FED_PORT="$(random_port)"
                    CONDUIT_SERVER_NAME="$(ask "Server name" "${CONDUIT_SERVER_NAME:-localhost}")"
                    MATRIX_PASSWORD="${MATRIX_PASSWORD:-$(random_chars 16)}"
                    MATRIX_HOMESERVER="http://127.0.0.1:$CONDUIT_PORT"
                else
                    NEEDS_CONDUIT=false
                    MATRIX_HOMESERVER="$(ask "Homeserver URL" "https://matrix.org")"
                    MATRIX_USER_ID="$(ask "Bot User ID (e.g. @mybot:matrix.org)" "")"
                    c="$(ask_choice "$(i18n matrix_auth)" 1 "Access Token" "Password")"
                    if [[ "$c" == "1" ]]; then MATRIX_ACCESS_TOKEN="$(ask "Access Token" "")"; else MATRIX_PASSWORD="$(ask "Password" "")"; fi
                fi
            fi
            if [[ "$MATRIX_ENABLED" != "true" ]]; then
                NEEDS_CONDUIT=false; CONDUIT_PORT=""; CONDUIT_FED_PORT=""
                CONDUIT_SERVER_NAME=""; CONDUIT_BOT_USER=""
                MATRIX_HOMESERVER=""; MATRIX_USER_ID=""
                MATRIX_ACCESS_TOKEN=""; MATRIX_PASSWORD=""
            fi

            # Telegram sub-config
            if [[ "$TG_ENABLED" == "true" ]] && [[ -z "$TG_TOKEN" ]]; then
                echo ""; echo "    $(i18n tg_howto)"; echo ""
                TG_TOKEN="$(ask "Telegram Bot Token (or Enter to skip)" "")"
            fi

            # Feishu sub-config
            if [[ "$FEISHU_ENABLED" == "true" ]] && [[ -z "$FEISHU_APP_ID" ]]; then
                echo ""; echo "    $(i18n feishu_howto_1)"; echo "    $(i18n feishu_howto_2)"; echo ""
                FEISHU_APP_ID="$(ask "App ID" "")"
                [[ -n "$FEISHU_APP_ID" ]] && FEISHU_APP_SECRET="$(ask "App Secret" "")"
                FEISHU_PORT="$(ask "Webhook port" "9000")"
            fi

            # XMPP sub-config
            if [[ "$XMPP_ENABLED" == "true" ]] && [[ -z "$XMPP_JID" ]]; then
                XMPP_JID="$(ask "JID (e.g. bot@your-server.com)" "")"
                [[ -n "$XMPP_JID" ]] && XMPP_PASSWORD="$(ask "Password" "")"
                XMPP_HOST="$(ask "Server host" "localhost")"
                XMPP_PORT="$(ask "Port" "5222")"
            fi
            ;;
        3)  # LLM Base URL
            BASE_URL="$(ask "API Base URL" "$BASE_URL")"
            ;;
        4)  # LLM Model
            MODEL="$(ask "Model" "$MODEL")"
            ;;
        5)  # API Key
            API_KEY="$(ask "API Key" "$API_KEY")"
            ;;
        6)  # Access mode
            c="$(ask_choice "$(i18n access_prompt)" 1 \
                "$(i18n access_open)" "$(i18n access_approval)" "$(i18n access_private)")"
            case "$c" in 1) ACCESS_MODE="open" ;; 2) ACCESS_MODE="approval" ;; 3) ACCESS_MODE="private" ;; esac
            ;;
        7)  # Components (Memobase, Crawl4AI, RSSHub, Serper)
            comp_sel="$(ask_multi_select "$(i18n cfg_comp_select)" \
                "RSSHub (Docker):$( [[ "$RSSHUB_MODE" == "docker" ]] && echo 1 || echo 0 )" \
                "Memobase:$( [[ "$USE_MEMOBASE" == "true" ]] && echo 1 || echo 0 )" \
                "Crawl4AI:$( [[ "$USE_CRAWL4AI" == "true" ]] && echo 1 || echo 0 )" \
                "Serper (Google):$( [[ -n "$SERPER_KEY" ]] && echo 1 || echo 0 )")"

            # RSSHub
            if [[ " $comp_sel " == *" 1 "* ]]; then
                RSSHUB_MODE="docker"
                [[ -z "$RSSHUB_PORT" ]] && RSSHUB_PORT="$(random_port)"
                RSSHUB_URL="http://localhost:$RSSHUB_PORT"
            else
                RSSHUB_MODE=""; RSSHUB_URL=""; RSSHUB_PORT=""
            fi

            # Memobase
            if [[ " $comp_sel " == *" 2 "* ]]; then
                USE_MEMOBASE=true
                if [[ "$MEMOBASE_MODE" != "remote" ]]; then
                    MEMOBASE_MODE="docker"
                    [[ -z "$MEMOBASE_PORT" ]] && MEMOBASE_PORT="$(random_port)"
                    MEMOBASE_URL="http://127.0.0.1:$MEMOBASE_PORT"
                    [[ -z "$MEMOBASE_KEY" ]] && MEMOBASE_KEY="$(random_chars 32)"
                elif [[ -z "$MEMOBASE_URL" ]]; then
                    MEMOBASE_MODE="remote"
                    MEMOBASE_URL="$(ask "Memobase URL" "http://localhost:8019")"
                    MEMOBASE_KEY="$(ask "Memobase API key" "secret")"
                fi
            else
                USE_MEMOBASE=false; MEMOBASE_MODE=""; MEMOBASE_URL=""; MEMOBASE_KEY=""; MEMOBASE_PORT=""
            fi

            # Crawl4AI
            if [[ " $comp_sel " == *" 3 "* ]]; then
                USE_CRAWL4AI=true
                if [[ "$CRAWL4AI_MODE" != "remote" ]]; then
                    CRAWL4AI_MODE="docker"
                    [[ -z "$CRAWL4AI_PORT" ]] && CRAWL4AI_PORT="$(random_port)"
                    CRAWL4AI_URL="http://localhost:$CRAWL4AI_PORT"
                elif [[ -z "$CRAWL4AI_URL" ]]; then
                    CRAWL4AI_MODE="remote"
                    CRAWL4AI_URL="$(ask "Crawl4AI URL" "http://localhost:11235")"
                fi
            else
                USE_CRAWL4AI=false; CRAWL4AI_MODE=""; CRAWL4AI_URL=""; CRAWL4AI_KEY=""; CRAWL4AI_PORT=""
            fi

            # Serper
            if [[ " $comp_sel " == *" 4 "* ]]; then
                [[ -z "$SERPER_KEY" ]] && SERPER_KEY="$(ask "Serper API key (https://serper.dev)" "")"
            else
                SERPER_KEY=""
            fi
            ;;
        esac
    }

    # ── Main config loop (arrow-key navigation) ──────────────────────────

    LAST_EDITED=""
    while true; do
        # Clear screen area and draw
        _draw_config

        # Hide cursor during navigation
        printf "\033[?25l" >&2

        # Track if user moved the cursor
        MOVED=false

        # Read arrow keys for navigation
        while true; do
            IFS= read -rsn1 key </dev/tty
            case "$key" in
                $'\x1b')
                    IFS= read -rsn2 rest </dev/tty
                    case "$rest" in
                        '[A')  # Up arrow
                            ((CFG_SELECTED > 0)) && { ((CFG_SELECTED--)); MOVED=true; }
                            ;;
                        '[B')  # Down arrow
                            ((CFG_SELECTED < CFG_ITEM_COUNT - 1)) && { ((CFG_SELECTED++)); MOVED=true; }
                            ;;
                    esac
                    ;;
                'k') ((CFG_SELECTED > 0)) && { ((CFG_SELECTED--)); MOVED=true; } ;;
                'j') ((CFG_SELECTED < CFG_ITEM_COUNT - 1)) && { ((CFG_SELECTED++)); MOVED=true; } ;;
                '')  # Enter
                    printf "\033[?25h" >&2
                    break
                    ;;
            esac
            # Redraw: move cursor up and redraw the config
            # 2 instruction lines + 1 blank + CFG_ITEM_COUNT items + 2 blanks = CFG_ITEM_COUNT + 5
            printf "\033[%dA" "$(( CFG_ITEM_COUNT + 5 ))" >&2
            _draw_config
        done

        # If user didn't move and pressed Enter = confirm and start install
        if [[ "$MOVED" == "false" ]] && [[ -n "$LAST_EDITED" ]]; then
            break
        fi

        # Edit selected item (1-based)
        EDIT_NUM=$(( CFG_SELECTED + 1 ))
        _edit_item "$EDIT_NUM"
        LAST_EDITED="$EDIT_NUM"
    done

    # ── Derive Conduit bot user from BOT_NAME ──
    if [[ "$NEEDS_CONDUIT" == "true" ]] && [[ -z "${CONDUIT_BOT_USER:-}" ]]; then
        CONDUIT_BOT_USER="$(echo "$BOT_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
        CONDUIT_BOT_USER="${CONDUIT_BOT_USER:-bot}"
        MATRIX_USER_ID="@${CONDUIT_BOT_USER}:${CONDUIT_SERVER_NAME}"
    fi

    # ── Save all state ──
    for v in USE_MEMOBASE MEMOBASE_MODE MEMOBASE_URL MEMOBASE_KEY MEMOBASE_PORT \
             USE_CRAWL4AI CRAWL4AI_MODE CRAWL4AI_URL CRAWL4AI_KEY CRAWL4AI_PORT \
             RSSHUB_MODE RSSHUB_URL RSSHUB_PORT SERPER_KEY \
             TG_ENABLED TG_TOKEN MATRIX_ENABLED MATRIX_HOMESERVER MATRIX_USER_ID \
             MATRIX_ACCESS_TOKEN MATRIX_PASSWORD NEEDS_CONDUIT CONDUIT_PORT \
             CONDUIT_FED_PORT CONDUIT_SERVER_NAME CONDUIT_BOT_USER FEISHU_ENABLED \
             FEISHU_APP_ID FEISHU_APP_SECRET FEISHU_PORT XMPP_ENABLED XMPP_JID \
             XMPP_PASSWORD XMPP_HOST XMPP_PORT \
             API_KEY BASE_URL MODEL BOT_NAME ACCESS_MODE CREATOR_ID; do
        save_var "$v" "${!v}"
    done
    mark_step 2
fi

# ═════════════════════════════════════════════════════════════════════════════
# Installing
# ═════════════════════════════════════════════════════════════════════════════

echo ""
printf "${PURPLE}安装 / Installing${NC}\n"
echo ""

# ── Reload saved vars ──
USE_MEMOBASE="$(load_var USE_MEMOBASE false)"
MEMOBASE_MODE="$(load_var MEMOBASE_MODE "")"
MEMOBASE_URL="$(load_var MEMOBASE_URL "")"
MEMOBASE_KEY="$(load_var MEMOBASE_KEY "")"
MEMOBASE_PORT="$(load_var MEMOBASE_PORT "")"
USE_CRAWL4AI="$(load_var USE_CRAWL4AI false)"
CRAWL4AI_MODE="$(load_var CRAWL4AI_MODE "")"
CRAWL4AI_URL="$(load_var CRAWL4AI_URL "")"
CRAWL4AI_KEY="$(load_var CRAWL4AI_KEY "")"
CRAWL4AI_PORT="$(load_var CRAWL4AI_PORT "")"
RSSHUB_MODE="$(load_var RSSHUB_MODE "docker")"
RSSHUB_URL="$(load_var RSSHUB_URL "")"
RSSHUB_PORT="$(load_var RSSHUB_PORT "")"
SERPER_KEY="$(load_var SERPER_KEY "")"
API_KEY="$(load_var API_KEY "")"
BASE_URL="$(load_var BASE_URL "https://openrouter.ai/api/v1")"
MODEL="$(load_var MODEL "openrouter/auto")"
BOT_NAME="$(load_var BOT_NAME "")"
ACCESS_MODE="$(load_var ACCESS_MODE "open")"
CREATOR_ID="$(load_var CREATOR_ID "")"
TG_ENABLED="$(load_var TG_ENABLED false)"
TG_TOKEN="$(load_var TG_TOKEN "")"
MATRIX_ENABLED="$(load_var MATRIX_ENABLED false)"
MATRIX_HOMESERVER="$(load_var MATRIX_HOMESERVER "")"
MATRIX_USER_ID="$(load_var MATRIX_USER_ID "")"
MATRIX_ACCESS_TOKEN="$(load_var MATRIX_ACCESS_TOKEN "")"
MATRIX_PASSWORD="$(load_var MATRIX_PASSWORD "")"
NEEDS_CONDUIT="$(load_var NEEDS_CONDUIT false)"
CONDUIT_PORT="$(load_var CONDUIT_PORT "")"
CONDUIT_FED_PORT="$(load_var CONDUIT_FED_PORT "")"
CONDUIT_SERVER_NAME="$(load_var CONDUIT_SERVER_NAME "")"
CONDUIT_BOT_USER="$(load_var CONDUIT_BOT_USER "")"
FEISHU_ENABLED="$(load_var FEISHU_ENABLED false)"
FEISHU_APP_ID="$(load_var FEISHU_APP_ID "")"
FEISHU_APP_SECRET="$(load_var FEISHU_APP_SECRET "")"
FEISHU_PORT="$(load_var FEISHU_PORT 9000)"
XMPP_ENABLED="$(load_var XMPP_ENABLED false)"
XMPP_JID="$(load_var XMPP_JID "")"
XMPP_PASSWORD="$(load_var XMPP_PASSWORD "")"
XMPP_HOST="$(load_var XMPP_HOST "")"
XMPP_PORT="$(load_var XMPP_PORT 5222)"

BOT_DIR="$BOTS_DIR/$BOT_NAME"

# ── Generate config files ────────────────────────────────────────────────────

# Global config directory
mkdir -p "$BASE_DIR/config"

# config/config.yaml (non-sensitive global config)
GLOBAL_CONFIG="$BASE_DIR/config/config.yaml"
cat > "$GLOBAL_CONFIG" <<YAML
# NaturalChat 全局配置 / Global Configuration
# 对所有机器人生效 / Applies to all bots

# 界面语言 / UI Language (zh / en)
language: "$LANG_UI"

# RSSHub 服务器地址 / RSSHub server URL
rsshub_server: "$RSSHUB_URL"
YAML

# config/secrets.yaml (sensitive global config)
GLOBAL_SECRETS="$BASE_DIR/config/secrets.yaml"
cat > "$GLOBAL_SECRETS" <<YAML
# NaturalChat 全局密钥 / Global Secrets
# ⚠️ 请勿提交到版本控制 / DO NOT commit to version control

# Google 搜索 API（留空则使用 DuckDuckGo）/ Google Search API (leave empty to use DuckDuckGo)
serper_api_key: "$SERPER_KEY"

# Memobase 配置（Docker 部署时自动生成）/ Memobase config (auto-generated for Docker deployment)
memobase:
  api_key: ""
  llm_api_key: ""
  llm_base_url: ""
  llm_model: ""
YAML
chmod 600 "$GLOBAL_SECRETS"

# Remove old root config files if they exist (replaced by config/ directory)
rm -f "$BASE_DIR/config.example.yaml" "$BASE_DIR/.env.example"

# Bot directory
mkdir -p "$BOT_DIR/skills" "$BOT_DIR/bot_data"

# ── config.yaml ──
CONFIG_FILE="$BOT_DIR/config.yaml"
{
    echo "# ── Transports ──"
    echo "transports:"
    echo "  web:"
    echo "    enabled: true"
    echo ""

    if [[ "$TG_ENABLED" == "true" ]]; then
        echo "  telegram:"
        echo "    enabled: true"
    fi
    if [[ "$MATRIX_ENABLED" == "true" ]]; then
        echo "  matrix:"
        echo "    enabled: true"
        echo "    homeserver_url: \"$MATRIX_HOMESERVER\""
        echo "    user_id: \"$MATRIX_USER_ID\""
    fi
    if [[ "$FEISHU_ENABLED" == "true" ]]; then
        echo "  feishu:"
        echo "    enabled: true"
        echo "    app_id: \"$FEISHU_APP_ID\""
        echo "    webhook_port: $FEISHU_PORT"
    fi
    if [[ "$XMPP_ENABLED" == "true" ]]; then
        echo "  xmpp:"
        echo "    enabled: true"
        echo "    jid: \"$XMPP_JID\""
        echo "    xmpp_host: \"$XMPP_HOST\""
        echo "    xmpp_port: $XMPP_PORT"
    fi

    cat <<YAML

# ── Timing ──
msg_wait_initial: 2.5
msg_wait_after_typing_stop: 5.0
typing_hard_timeout: 10.0
reflection_delay: 30

# ── LLM ──
llm:
  base_url: "$BASE_URL"
  model: "$MODEL"
  max_history_tokens: 4000

token_budget:
  default_score: 50

# ── Surfing (disabled by default) ──
surfing:
  enabled: false
YAML

    # Crawl4AI
    if [[ "$USE_CRAWL4AI" == "true" ]]; then
        cat <<YAML

# ── Crawl4AI ──
crawl4ai:
  url: "$CRAWL4AI_URL"
YAML
    fi

    # Memobase
    if [[ "$USE_MEMOBASE" == "true" ]]; then
        cat <<YAML

# ── Memobase ──
memobase:
  url: "${MEMOBASE_URL:-http://localhost:8019}"
YAML
    fi

} > "$CONFIG_FILE"

# ── secrets.yaml ──
SECRETS_FILE="$BOT_DIR/secrets.yaml"
{
    echo "# Sensitive credentials — DO NOT commit"
    echo "llm:"
    echo "  api_key: \"$API_KEY\""

    # Only write transports: if there are platform secrets to put under it
    HAS_TRANSPORT_SECRETS=false
    if [[ "$TG_ENABLED" == "true" ]] || \
       { [[ "$MATRIX_ENABLED" == "true" ]] && [[ -n "$MATRIX_ACCESS_TOKEN$MATRIX_PASSWORD" ]]; } || \
       [[ "$FEISHU_ENABLED" == "true" ]] || [[ "$XMPP_ENABLED" == "true" ]]; then
        HAS_TRANSPORT_SECRETS=true
    fi

    if [[ "$HAS_TRANSPORT_SECRETS" == "true" ]]; then
        echo ""
        echo "transports:"
        if [[ "$TG_ENABLED" == "true" ]]; then
            echo "  telegram:"
            echo "    enabled: true"
            echo "    token: \"$TG_TOKEN\""
        fi
        if [[ "$MATRIX_ENABLED" == "true" ]] && [[ -n "$MATRIX_ACCESS_TOKEN$MATRIX_PASSWORD" ]]; then
            echo "  matrix:"
            echo "    enabled: true"
            if [[ -n "$MATRIX_ACCESS_TOKEN" ]]; then
                echo "    access_token: \"$MATRIX_ACCESS_TOKEN\""
            fi
            if [[ -n "$MATRIX_PASSWORD" ]]; then
                echo "    password: \"$MATRIX_PASSWORD\""
            fi
        fi
        if [[ "$FEISHU_ENABLED" == "true" ]]; then
            echo "  feishu:"
            echo "    enabled: true"
            echo "    app_secret: \"$FEISHU_APP_SECRET\""
        fi
        if [[ "$XMPP_ENABLED" == "true" ]]; then
            echo "  xmpp:"
            echo "    enabled: true"
            echo "    password: \"$XMPP_PASSWORD\""
        fi
    fi

    if [[ "$USE_CRAWL4AI" == "true" ]] && [[ -n "$CRAWL4AI_KEY" ]]; then
        echo ""
        echo "crawl4ai:"
        echo "  api_key: \"$CRAWL4AI_KEY\""
    fi

    if [[ "$USE_MEMOBASE" == "true" ]]; then
        echo ""
        echo "memobase:"
        echo "  api_key: \"${MEMOBASE_KEY:-secret}\""
    fi
} > "$SECRETS_FILE"
chmod 600 "$SECRETS_FILE"

# ── Prompts ──
if [[ ! -d "$BOT_DIR/prompts" ]]; then
    mkdir -p "$BOT_DIR/prompts"

    # Copy language-specific prompt templates (fall back to default)
    PROMPT_LANG_DIR="$BASE_DIR/prompts/$LANG_UI"
    if [[ ! -d "$PROMPT_LANG_DIR" ]]; then
        PROMPT_LANG_DIR="$BASE_DIR/prompts/default"
    fi
    if [[ -d "$PROMPT_LANG_DIR" ]]; then
        cp "$PROMPT_LANG_DIR"/*.md "$BOT_DIR/prompts/" 2>/dev/null || true
        cp "$PROMPT_LANG_DIR"/registry.yaml "$BOT_DIR/prompts/" 2>/dev/null || true
    fi

    # Only write registry.yaml if not already copied
    if [[ ! -f "$BOT_DIR/prompts/registry.yaml" ]]; then
    cat > "$BOT_DIR/prompts/registry.yaml" <<'REGISTRY'
version: 1
prompts:
  main:
    file: main.md
    purpose: Main system prompt for the chat model.
    used_by: src.bot_manager.create_bot -> LLMAgent(system_prompt)
  reflection:
    file: reflection.md
    purpose: Internal reflection prompt after silence periods.
    used_by: src.bot_brain.BotBrain._do_reflect
  profile_update:
    file: profile_update.md
    purpose: Prompt for updating user profiles and memory.
    used_by: src.bot_brain.BotBrain._do_memory_update
  history_summary:
    file: history_summary.md
    purpose: Prompt for summarizing long conversation history.
    used_by: src.llm_agent.LLMAgent._summarize_and_trim
  critic:
    file: critic.md
    purpose: Independent review prompt for main replies.
    used_by: src.bot_brain.BotBrain._do_critic_review
  correction:
    file: correction.md
    purpose: Correction prompt when review finds issues.
    used_by: src.bot_brain.BotBrain._do_critic_review
  surfing:
    file: surfing.md
    purpose: Autonomous surfing planning prompt.
    used_by: src.bot_brain.BotBrain.do_surf_once
  bot_abilities:
    file: abilities.md
    purpose: Ability descriptions injected into the main model.
    used_by: src.bot_manager.create_bot -> LLMAgent(bot_abilities)
REGISTRY
    fi
fi

# ── bot_meta.json ──
META_FILE="$BOT_DIR/bot_data/bot_meta.json"
if [[ ! -f "$META_FILE" ]]; then
    cat > "$META_FILE" <<JSON
{
  "access_mode": "$ACCESS_MODE",
  "creator_jid": "$CREATOR_ID",
  "admins": [],
  "blacklist": [],
  "approved_contacts": []
}
JSON
fi

# ── .env (always regenerate to keep in sync with install choices) ──
ENV_FILE="$BASE_DIR/.env"
{
    echo "# NaturalChat — auto-generated by install.sh"
    echo "PANEL_PORT=${PANEL_PORT:-8080}"
    if [[ "$USE_MEMOBASE" == "true" ]] && [[ "$MEMOBASE_MODE" == "docker" ]]; then
        echo "MEMOBASE_DB_PASSWORD=memobase"
        echo "MEMOBASE_REDIS_PASSWORD=memobase"
        echo "MEMOBASE_ACCESS_TOKEN=${MEMOBASE_KEY}"
        echo "MEMOBASE_PROJECT_ID=naturalchat"
    fi
    if [[ -n "${MEMOBASE_PORT:-}" ]]; then
        echo "MEMOBASE_PORT=$MEMOBASE_PORT"
    fi
    if [[ "$NEEDS_CONDUIT" == "true" ]]; then
        [[ -z "${CONDUIT_PORT:-}" ]] && CONDUIT_PORT=6167
        echo "CONDUIT_PORT=$CONDUIT_PORT"
        [[ -n "${CONDUIT_FED_PORT:-}" ]] && echo "CONDUIT_FED_PORT=$CONDUIT_FED_PORT"
        [[ -n "${CONDUIT_SERVER_NAME:-}" ]] && echo "CONDUIT_SERVER_NAME=$CONDUIT_SERVER_NAME"
    fi
    if [[ -n "${CRAWL4AI_PORT:-}" ]]; then
        echo "CRAWL4AI_PORT=$CRAWL4AI_PORT"
    fi
    if [[ -n "${RSSHUB_PORT:-}" ]]; then
        echo "RSSHUB_PORT=$RSSHUB_PORT"
    fi
    if [[ -n "${BOT_PORT:-}" ]]; then
        echo "BOT_PORT=$BOT_PORT"
    fi
} > "$ENV_FILE"

# Add COMPOSE_PROJECT_NAME to .env if not already present
if [[ -n "${COMPOSE_PROJECT:-}" ]] && ! grep -q "^COMPOSE_PROJECT_NAME=" "$ENV_FILE" 2>/dev/null; then
    echo "COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT" >> "$ENV_FILE"
fi

# Save compose project name for later use (uninstall, service restart, etc.)
save_var COMPOSE_PROJECT "${COMPOSE_PROJECT:-naturalchat}"

# ── Memobase config (LLM settings for memobase server) ──
MEMOBASE_CONFIG="$BASE_DIR/config/memobase.yaml"
# Docker creates a directory if mount target doesn't exist as a file — remove it
if [[ -d "$MEMOBASE_CONFIG" ]]; then
    rm -rf "$MEMOBASE_CONFIG"
fi
if [[ "$USE_MEMOBASE" == "true" ]] && [[ "$MEMOBASE_MODE" == "docker" ]] && [[ ! -f "$MEMOBASE_CONFIG" ]]; then
    {
        echo "# Memobase LLM configuration"
        echo "# Uses the same LLM API key as the bot"
        echo "llm_api_key: \"${API_KEY}\""
        if [[ -n "${BASE_URL:-}" ]]; then
            echo "llm_base_url: \"${BASE_URL}\""
        fi
        if [[ -n "${MODEL:-}" ]]; then
            echo "best_llm_model: \"${MODEL}\""
            echo "thinking_llm_model: \"${MODEL}\""
            echo "summary_llm_model: \"${MODEL}\""
        fi
        echo ""
        echo "# Set to false to disable embedding (saves resources)"
        echo "enable_event_embedding: false"
    } > "$MEMOBASE_CONFIG"
    chmod 600 "$MEMOBASE_CONFIG"

    # Also update config/secrets.yaml with memobase LLM settings
    cat > "$GLOBAL_SECRETS" <<YAML
# NaturalChat 全局密钥 / Global Secrets
# ⚠️ 请勿提交到版本控制 / DO NOT commit to version control

# Google 搜索 API（留空则使用 DuckDuckGo）/ Google Search API (leave empty to use DuckDuckGo)
serper_api_key: "$SERPER_KEY"

# Memobase 配置 / Memobase config
memobase:
  api_key: "${MEMOBASE_KEY:-}"
  llm_api_key: "${API_KEY}"
  llm_base_url: "${BASE_URL}"
  llm_model: "${MODEL}"
YAML
    chmod 600 "$GLOBAL_SECRETS"
fi

# Remove old memobase-config.yaml at root if it exists
rm -f "$BASE_DIR/memobase-config.yaml"

# ── Web panel credentials (random port + random username) ──
PANEL_CONFIG="$BASE_DIR/web_panel.yaml"
if [[ ! -f "$PANEL_CONFIG" ]]; then
    PANEL_PORT="$(random_port)"
    PANEL_USER="$(random_username)"
    PANEL_PASS="$(random_chars 12)"
    cat > "$PANEL_CONFIG" <<YAML
# NaturalChat Web Panel
# Access at http://localhost:$PANEL_PORT after starting the bot
username: "$PANEL_USER"
password: "$PANEL_PASS"
port: $PANEL_PORT
YAML
    chmod 600 "$PANEL_CONFIG"
else
    PANEL_USER="$(grep 'username:' "$PANEL_CONFIG" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/')"
    PANEL_PASS="$(grep 'password:' "$PANEL_CONFIG" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/')"
    PANEL_PORT="$(grep 'port:' "$PANEL_CONFIG" | head -1 | sed 's/.*: *//')"
    PANEL_PORT="${PANEL_PORT:-8080}"
fi

# Save panel port for service step
save_var PANEL_PORT "${PANEL_PORT:-8080}"

ok "$(i18n config_generated)"

# ── Deploy Docker services ──────────────────────────────────────────────────

COMPOSE_PROJECT="$(load_var COMPOSE_PROJECT "")"

DOCKER_PROFILES=("bot")
[[ "$NEEDS_CONDUIT" == "true" ]] && DOCKER_PROFILES+=("matrix")
[[ "$USE_MEMOBASE" == "true" ]] && [[ "$MEMOBASE_MODE" == "docker" ]] && DOCKER_PROFILES+=("memobase")
[[ "$USE_CRAWL4AI" == "true" ]] && [[ "$CRAWL4AI_MODE" == "docker" ]] && DOCKER_PROFILES+=("crawl4ai")
[[ "$RSSHUB_MODE" == "docker" ]] && DOCKER_PROFILES+=("rsshub")

echo ""
info "$(i18n deploying_services)"
echo ""

# Build the profile flags
PROFILE_FLAGS=""
for p in "${DOCKER_PROFILES[@]}"; do
    PROFILE_FLAGS="$PROFILE_FLAGS --profile $p"
done

# ── Docker Compose project name ──
if [[ -z "${COMPOSE_PROJECT:-}" ]]; then
    COMPOSE_PROJECT="naturalchat"
    EXISTING_PROJECTS="$(docker compose ls -q 2>/dev/null)" || EXISTING_PROJECTS=""
    if echo "$EXISTING_PROJECTS" | grep -qx "$COMPOSE_PROJECT"; then
        # Name collision — add random suffix
        while true; do
            SUFFIX="$(( RANDOM % 900 + 100 ))"
            CANDIDATE="${COMPOSE_PROJECT}-${SUFFIX}"
            if ! echo "$EXISTING_PROJECTS" | grep -qx "$CANDIDATE"; then
                COMPOSE_PROJECT="$CANDIDATE"
                break
            fi
        done
    fi
fi
PROJECT_FLAG="-p $COMPOSE_PROJECT"

# ── Pre-start port conflict resolution ──
if [[ "$NEEDS_CONDUIT" == "true" ]] && port_in_use "$CONDUIT_PORT"; then
    CONDUIT_PORT="$(random_port)"
    save_var CONDUIT_PORT "$CONDUIT_PORT"
    MATRIX_HOMESERVER="http://127.0.0.1:$CONDUIT_PORT"
    save_var MATRIX_HOMESERVER "$MATRIX_HOMESERVER"
    sed -i.bak "s/^CONDUIT_PORT=.*/CONDUIT_PORT=$CONDUIT_PORT/" "$BASE_DIR/.env" 2>/dev/null || true
    rm -f "$BASE_DIR/.env.bak"
    warn "端口冲突，Conduit 切换到端口 $CONDUIT_PORT / Port conflict, switching Conduit to port $CONDUIT_PORT"
fi

if docker compose $PROJECT_FLAG $PROFILE_FLAGS --env-file "$BASE_DIR/.env" -f "$BASE_DIR/docker/docker-compose.yml" up -d --build 2>&1; then
    ok "$(i18n services_started)"
else
    warn "$(i18n services_failed)"
fi

# ── Register Matrix bot user on Conduit ──
if [[ "$NEEDS_CONDUIT" == "true" ]] && [[ -n "${CONDUIT_BOT_USER:-}" ]]; then
    # Re-read port from .env to stay in sync with what docker compose actually uses
    _CONDUIT_PORT="$(grep "^CONDUIT_PORT=" "$BASE_DIR/.env" 2>/dev/null | cut -d= -f2)" || true
    CONDUIT_PORT="${_CONDUIT_PORT:-${CONDUIT_PORT:-6167}}"

    CONDUIT_READY=false
    for i in $(seq 15); do
        if curl -sf "http://127.0.0.1:${CONDUIT_PORT}/_matrix/client/versions" &>/dev/null; then
            CONDUIT_READY=true
            break
        fi
        sleep 1
    done

    if [[ "$CONDUIT_READY" == "true" ]]; then
        CONDUIT_API="http://127.0.0.1:${CONDUIT_PORT}"

        # ── 1. Register bot user ──
        info "注册 Matrix 机器人用户 / Registering Matrix bot user: $MATRIX_USER_ID"
        REG_RESULT="$(curl -sf -X POST "${CONDUIT_API}/_matrix/client/r0/register" \
            -H "Content-Type: application/json" \
            -d "{\"username\": \"${CONDUIT_BOT_USER}\", \"password\": \"${MATRIX_PASSWORD}\", \"auth\": {\"type\": \"m.login.dummy\"}}" 2>&1)" || true

        BOT_TOKEN=""
        if echo "$REG_RESULT" | grep -q "access_token"; then
            BOT_TOKEN="$(json_val "$REG_RESULT" "access_token")" || true
            if [[ -n "$BOT_TOKEN" ]]; then
                MATRIX_ACCESS_TOKEN="$BOT_TOKEN"
                save_var MATRIX_ACCESS_TOKEN "$MATRIX_ACCESS_TOKEN"
            fi
            ok "Matrix 机器人已注册 / Bot registered: $MATRIX_USER_ID"
        elif echo "$REG_RESULT" | grep -q "M_USER_IN_USE"; then
            # Already exists — login to get a fresh token
            LOGIN_RESULT="$(curl -sf -X POST "${CONDUIT_API}/_matrix/client/r0/login" \
                -H "Content-Type: application/json" \
                -d "{\"type\": \"m.login.password\", \"user\": \"${CONDUIT_BOT_USER}\", \"password\": \"${MATRIX_PASSWORD}\"}" 2>&1)" || true
            BOT_TOKEN="$(json_val "$LOGIN_RESULT" "access_token")" || true
            if [[ -n "$BOT_TOKEN" ]]; then
                MATRIX_ACCESS_TOKEN="$BOT_TOKEN"
                save_var MATRIX_ACCESS_TOKEN "$MATRIX_ACCESS_TOKEN"
                ok "机器人用户已存在，已登录 / Bot user exists, logged in: $MATRIX_USER_ID"
            else
                warn "机器人用户已存在但登录失败 / Bot user exists but login failed (password mismatch?)"
            fi
        else
            warn "注册 Matrix 机器人用户失败 / Failed to register Matrix bot user"
        fi

        # ── 2. Register test/admin account ──
        CONDUIT_TEST_USER="${DEFAULT_CONDUIT_TEST_USER:-creator-$(random_chars 6)}"
        CONDUIT_TEST_PASSWORD="${DEFAULT_CONDUIT_TEST_PASSWORD:-$(random_chars 12)}"
        CONDUIT_TEST_USER_ID="@${CONDUIT_TEST_USER}:${CONDUIT_SERVER_NAME}"

        info "注册测试账号 / Registering test account: $CONDUIT_TEST_USER_ID"
        TEST_REG="$(curl -sf -X POST "${CONDUIT_API}/_matrix/client/r0/register" \
            -H "Content-Type: application/json" \
            -d "{\"username\": \"${CONDUIT_TEST_USER}\", \"password\": \"${CONDUIT_TEST_PASSWORD}\", \"auth\": {\"type\": \"m.login.dummy\"}}" 2>&1)" || true

        TEST_TOKEN=""
        if echo "$TEST_REG" | grep -q "access_token"; then
            TEST_TOKEN="$(json_val "$TEST_REG" "access_token")" || true
            save_var CONDUIT_TEST_USER "$CONDUIT_TEST_USER"
            save_var CONDUIT_TEST_PASSWORD "$CONDUIT_TEST_PASSWORD"
            save_var CONDUIT_TEST_USER_ID "$CONDUIT_TEST_USER_ID"
            ok "测试账号已注册 / Test account registered: $CONDUIT_TEST_USER_ID"
        elif echo "$TEST_REG" | grep -q "M_USER_IN_USE"; then
            # Already exists — login with current password (from defaults or random)
            _saved_pw="$(load_var CONDUIT_TEST_PASSWORD "")"
            [[ -n "$_saved_pw" ]] && CONDUIT_TEST_PASSWORD="$_saved_pw"
            LOGIN_RESULT="$(curl -sf -X POST "${CONDUIT_API}/_matrix/client/r0/login" \
                -H "Content-Type: application/json" \
                -d "{\"type\": \"m.login.password\", \"user\": \"${CONDUIT_TEST_USER}\", \"password\": \"${CONDUIT_TEST_PASSWORD}\"}" 2>&1)" || true
            TEST_TOKEN="$(json_val "$LOGIN_RESULT" "access_token")" || true
            if [[ -n "$TEST_TOKEN" ]]; then
                save_var CONDUIT_TEST_USER "$CONDUIT_TEST_USER"
                save_var CONDUIT_TEST_PASSWORD "$CONDUIT_TEST_PASSWORD"
                save_var CONDUIT_TEST_USER_ID "$CONDUIT_TEST_USER_ID"
                ok "测试账号已存在，已登录 / Test account exists, logged in: $CONDUIT_TEST_USER_ID"
            else
                warn "测试账号已存在但登录失败 / Test account exists but login failed"
            fi
        else
            warn "注册测试账号失败 / Failed to register test account"
        fi

        # ── 3. Create DM room between test user and bot ──
        if [[ -n "$TEST_TOKEN" ]] && [[ -n "$BOT_TOKEN" ]]; then
            info "创建测试账号与机器人的私聊 / Creating DM room..."
            # Test user creates a DM room and invites the bot
            ROOM_RESULT="$(curl -sf -X POST "${CONDUIT_API}/_matrix/client/r0/createRoom" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer ${TEST_TOKEN}" \
                -d "{
                    \"is_direct\": true,
                    \"invite\": [\"${MATRIX_USER_ID}\"],
                    \"preset\": \"trusted_private_chat\"
                }" 2>&1)" || true

            ROOM_ID="$(json_val "$ROOM_RESULT" "room_id")" || true

            if [[ -n "$ROOM_ID" ]]; then
                # Bot accepts the invite
                curl -sf -X POST "${CONDUIT_API}/_matrix/client/r0/rooms/${ROOM_ID}/join" \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer ${BOT_TOKEN}" \
                    -d '{}' &>/dev/null || true
                ok "私聊已创建 / DM room created"
                save_var CONDUIT_TEST_ROOM_ID "$ROOM_ID"
            else
                warn "无法创建私聊 / Could not create DM room"
            fi
        fi
    else
        warn "Conduit 未能及时启动 / Conduit did not start in time"
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# Completion
# ═════════════════════════════════════════════════════════════════════════════

echo ""
printf "${PURPLE}安装完成 / Setup Complete${NC}\n"
echo ""

# ── Web Panel ──
printf "  ${BOLD}$(i18n web_panel)${NC}\n"
printf "  URL:      http://localhost:${PANEL_PORT}\n"
printf "  Username: $PANEL_USER\n"
printf "  Password: $PANEL_PASS\n"
echo ""

# ── Matrix test account (if Conduit deployed) ──
CONDUIT_TEST_USER="$(load_var CONDUIT_TEST_USER "")"
CONDUIT_TEST_PASSWORD="$(load_var CONDUIT_TEST_PASSWORD "")"
CONDUIT_TEST_USER_ID="$(load_var CONDUIT_TEST_USER_ID "")"
if [[ -n "$CONDUIT_TEST_USER" ]] && [[ -n "$CONDUIT_TEST_PASSWORD" ]]; then
    printf "  ${BOLD}Matrix (Conduit)${NC}\n"
    printf "  Homeserver: http://127.0.0.1:${CONDUIT_PORT}\n"
    printf "  Bot:        $MATRIX_USER_ID\n"
    echo ""
    printf "  ${GREEN}Test account / 测试账号 (Element):${NC}\n"
    printf "  User:     $CONDUIT_TEST_USER_ID\n"
    printf "  Password: $CONDUIT_TEST_PASSWORD\n"
    echo ""
fi

# ── Missing credentials warning ──
MISSING=()
[[ -z "$API_KEY" ]] && MISSING+=("LLM API key")
[[ "$TG_ENABLED" == "true" ]] && [[ -z "$TG_TOKEN" ]] && MISSING+=("Telegram token")

if (( ${#MISSING[@]} > 0 )); then
    printf "  ${YELLOW}$(i18n missing_creds_warn)${NC}\n"
    printf "  Edit: $SECRETS_FILE\n"
    for m in "${MISSING[@]}"; do
        printf "    - $m\n"
    done
    echo ""
fi

# ── Final management hint ──
printf "  后续管理请运行 nctl.sh / Use nctl.sh to manage, configure, start/stop, and view this info again.\n"
echo ""

# Keep install state for nctl.sh info command (already gitignored)
