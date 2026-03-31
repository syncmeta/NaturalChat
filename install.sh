#!/usr/bin/env bash
# install.sh - NaturalChat interactive setup wizard
#
# Works on a clean Linux/macOS without Python pre-installed.
# Supports resume — if you exit midway, re-run and it picks up where you left off.
#
# One-liner install:
#   bash <(curl -fsSL https://raw.githubusercontent.com/syncmeta/naturalchat/main/install.sh)

set -euo pipefail

# ── Colors & helpers ─────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

LANG_UI="en"

tr() {
    local key="$1"
    case "$LANG_UI:$key" in
        en:default_label) echo "default" ;;
        zh:default_label) echo "默认" ;;
        en:choice_label) echo "Choice" ;;
        zh:choice_label) echo "选择" ;;
        en:arrow_help) echo "arrow keys to move, Enter to select" ;;
        zh:arrow_help) echo "方向键移动，回车确认" ;;
        en:step_label) echo "Step" ;;
        zh:step_label) echo "步骤" ;;
        en:resume_note) echo "Resume supported: press Ctrl+C anytime and re-run later." ;;
        zh:resume_note) echo "支持断点继续：随时 Ctrl+C 退出，之后重新运行即可继续。" ;;
        en:optional_note) echo "Most fields can be skipped now and filled in later." ;;
        zh:optional_note) echo "大多数信息现在都可以跳过，稍后再补。" ;;
        en:lang_prompt) echo "Choose installer language" ;;
        zh:lang_prompt) echo "选择安装器语言" ;;
        en:lang_en) echo "English" ;;
        zh:lang_en) echo "英文" ;;
        en:lang_zh) echo "Chinese" ;;
        zh:lang_zh) echo "中文" ;;
        en:step1) echo "System Detection" ;;
        zh:step1) echo "系统检测" ;;
        en:step2) echo "Python & Dependencies" ;;
        zh:step2) echo "Python 与依赖" ;;
        en:step3) echo "Optional Components" ;;
        zh:step3) echo "可选组件" ;;
        en:step4) echo "Messaging Platforms" ;;
        zh:step4) echo "消息平台" ;;
        en:step5) echo "LLM Configuration" ;;
        zh:step5) echo "LLM 配置" ;;
        en:step6) echo "Bot Setup" ;;
        zh:step6) echo "机器人设置" ;;
        en:step7) echo "Generating Configuration" ;;
        zh:step7) echo "生成配置" ;;
        en:step8) echo "Launch Options" ;;
        zh:step8) echo "启动选项" ;;
        en:direct_run_prompt) echo "Run NaturalChat directly after setup?" ;;
        zh:direct_run_prompt) echo "安装完成后是否直接运行 NaturalChat？" ;;
        en:systemd_prompt) echo "Install systemd service for auto-start on boot?" ;;
        zh:systemd_prompt) echo "是否安装 systemd 服务并在开机时自动启动？" ;;
        en:launchd_prompt) echo "Install launchd service for auto-start on login?" ;;
        zh:launchd_prompt) echo "是否安装 launchd 服务并在登录时自动启动？" ;;
        en:start_service_now) echo "Start the service now?" ;;
        zh:start_service_now) echo "现在要启动该服务吗？" ;;
        en:launch_intro_1) echo "You can run NaturalChat directly right now, or optionally install it as" ;;
        zh:launch_intro_1) echo "你可以在安装完成后直接运行 NaturalChat，也可以另外安装成后台服务，" ;;
        en:launch_intro_2) echo "a background service for auto-start on boot/login later." ;;
        zh:launch_intro_2) echo "用于以后开机或登录时自动启动。" ;;
        en:no_service_manager) echo "No systemd or launchd detected. Run manually:" ;;
        zh:no_service_manager) echo "未检测到 systemd 或 launchd。请手动运行：" ;;
        en:skip_direct_run) echo "Skipping direct run because NaturalChat is already starting via service." ;;
        zh:skip_direct_run) echo "已通过服务启动，跳过直接运行，避免重复启动。" ;;
        en:start_direct_run) echo "Starting NaturalChat directly in the current terminal..." ;;
        zh:start_direct_run) echo "正在当前终端直接启动 NaturalChat..." ;;
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

banner() {
    local title="$1" width line inner padding left right
    width="$(ui_width)"
    inner=$(( width - 2 ))
    (( inner < ${#title} + 2 )) && inner=$(( ${#title} + 2 ))
    padding=$(( inner - ${#title} ))
    left=$(( padding / 2 ))
    right=$(( padding - left ))
    line="$(repeat_char $(( inner + 2 )) "═")"

    echo ""
    printf "${BOLD}╔%s╗${NC}\n" "$(repeat_char "$inner" "═")"
    printf "${BOLD}║%*s%s%*s║${NC}\n" "$left" "" "$title" "$right" ""
    printf "${BOLD}╚%s╝${NC}\n" "$(repeat_char "$inner" "═")"
    echo ""
}

section() {
    local number="$1" title="$2" width
    width="$(ui_width)"
    echo ""
    printf "${BOLD}[%s/8] %s${NC}\n" "$number" "$title"
    printf "${DIM}%s${NC}\n" "$(repeat_char "$width" "─")"
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
        printf "  %s ${DIM}(%s: %s)${NC}: " "$prompt" "$(tr default_label)" "$default" >&2
    else
        printf "  %s: " "$prompt" >&2
    fi
    read -r answer </dev/tty
    echo "${answer:-$default}"
}

ask_yn() {
    local prompt="$1" default="${2:-y}"
    if [[ "$default" == "y" ]]; then
        printf "  %s ${DIM}[Y/n]${NC}: " "$prompt" >&2
    else
        printf "  %s ${DIM}[y/N]${NC}: " "$prompt" >&2
    fi
    read -r answer </dev/tty
    answer="${answer:-$default}"
    [[ "$answer" =~ ^[Yy] ]]
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
                wrap_print "[$i] $opt ($(tr default_label))" 4 >&2
            else
                wrap_print "[$i] $opt" 4 >&2
            fi
            ((i++))
        done
        printf "\n  %s ${DIM}(%s: %d)${NC}: " "$(tr choice_label)" "$(tr default_label)" "$default" >&2
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
    printf "  %s  ${DIM}(%s)${NC}\n\n" "$prompt" "$(tr arrow_help)" >&2

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

random_name() {
    local adjectives=("happy" "swift" "brave" "calm" "wise" "keen" "bold" "warm"
                      "cool" "zen" "epic" "fair" "glad" "nice" "pure" "true")
    local nouns=("panda" "falcon" "otter" "robin" "fox" "wolf" "owl" "lynx"
                 "bear" "hawk" "deer" "dove" "seal" "wren" "crow" "hare")
    local adj="${adjectives[$((RANDOM % ${#adjectives[@]}))]}"
    local noun="${nouns[$((RANDOM % ${#nouns[@]}))]}"
    echo "${adj}-${noun}"
}

random_username() {
    local prefixes=("admin" "panel" "dash" "ctrl" "ops" "mgr" "bot" "hub")
    local prefix="${prefixes[$((RANDOM % ${#prefixes[@]}))]}"
    local suffix="$(( RANDOM % 900 + 100 ))"
    echo "${prefix}${suffix}"
}

random_port() {
    # Random port in 10000-49151
    echo $(( RANDOM % 39152 + 10000 ))
}

# ── State / Resume ───────────────────────────────────────────────────────────
# Each completed step writes a marker. On re-run, completed steps are skipped.

step_done()  { [[ -f "$STATE_DIR/step_$1" ]]; }
mark_step()  { touch "$STATE_DIR/step_$1"; }
save_var()   { echo "$2" > "$STATE_DIR/var_$1"; }
load_var()   { [[ -f "$STATE_DIR/var_$1" ]] && cat "$STATE_DIR/var_$1" || echo "${2:-}"; }

# ── Banner ───────────────────────────────────────────────────────────────────

LANG_CHOICE="$(ask_choice "Choose installer language / 选择安装器语言" 1 "English" "中文")"
if [[ "$LANG_CHOICE" == "2" ]]; then
    LANG_UI="zh"
fi

banner "NaturalChat Setup"
wrap_print "$(tr resume_note)"
wrap_print "$(tr optional_note)"
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

# Check if resuming
if ls "$STATE_DIR"/step_* &>/dev/null 2>&1; then
    info "Resuming previous installation..."
    echo ""
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1: System Detection
# ═════════════════════════════════════════════════════════════════════════════

section 1 "$(tr step1)"

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

# Detect resources
MEM_TOTAL="unknown"
DISK_FREE="unknown"
if [[ "$OS" == "Linux" ]]; then
    MEM_TOTAL="$(awk '/MemTotal/{printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null || echo "unknown")"
    [[ "$MEM_TOTAL" != "unknown" ]] && MEM_TOTAL="${MEM_TOTAL} MB"
    DISK_FREE="$(df -BM --output=avail "$BASE_DIR" 2>/dev/null | tail -1 | tr -d ' M' || echo "unknown")"
    [[ "$DISK_FREE" != "unknown" ]] && DISK_FREE="${DISK_FREE} MB"
elif [[ "$OS" == "Darwin" ]]; then
    MEM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
    if (( MEM_BYTES > 0 )); then
        MEM_TOTAL="$(( MEM_BYTES / 1024 / 1024 )) MB"
    fi
    DISK_FREE="$(df -m "$BASE_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "unknown")"
    [[ "$DISK_FREE" != "unknown" ]] && DISK_FREE="${DISK_FREE} MB"
fi

HAS_DOCKER=false
DOCKER_STATUS="not installed"
if command -v docker &>/dev/null; then
    if docker info &>/dev/null 2>&1; then
        HAS_DOCKER=true
        DOCKER_STATUS="running"
    else
        DOCKER_STATUS="installed but not running"
    fi
fi

HAS_BWRAP=false
[[ "$OS" == "Linux" ]] && command -v bwrap &>/dev/null && HAS_BWRAP=true

HAS_GIT=false
command -v git &>/dev/null && HAS_GIT=true

# Find Python
find_python() {
    for cmd in python3.13 python3.12 python3.11 python3.10 python3; do
        if command -v "$cmd" &>/dev/null; then
            local ver
            ver="$("$cmd" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)" || continue
            local major minor
            major="${ver%%.*}"
            minor="${ver#*.}"
            if (( major == 3 && minor >= 10 )); then
                echo "$cmd"
                return 0
            fi
        fi
    done
    return 1
}

PYTHON_STATUS="not found (>= 3.10 required)"
PYTHON=""
if PYTHON="$(find_python)"; then
    PYTHON_STATUS="$("$PYTHON" --version 2>&1) ($(which "$PYTHON"))"
fi

# Display system info
echo ""
printf "  %-18s %s\n" "OS:" "$OS — $DISTRO"
printf "  %-18s %s\n" "Architecture:" "$ARCH"
printf "  %-18s %s\n" "Package manager:" "${PKG_MGR:-none detected}"
printf "  %-18s %s\n" "Memory:" "$MEM_TOTAL"
printf "  %-18s %s\n" "Disk free:" "$DISK_FREE"
printf "  %-18s %s\n" "Python:" "$PYTHON_STATUS"
printf "  %-18s %s\n" "Docker:" "$DOCKER_STATUS"
printf "  %-18s %s\n" "Git:" "$($HAS_GIT && echo "available" || echo "not found")"
if [[ "$OS" == "Linux" ]]; then
    printf "  %-18s %s\n" "Bubblewrap:" "$($HAS_BWRAP && echo "available" || echo "not found")"
fi
echo ""

# Warnings
if [[ "$MEM_TOTAL" != "unknown" ]]; then
    mem_num="${MEM_TOTAL%% *}"
    if (( mem_num < 512 )); then
        warn "Low memory (<512MB). NaturalChat itself is lightweight, but Docker services need more."
    fi
fi

if [[ "$DISK_FREE" != "unknown" ]]; then
    disk_num="${DISK_FREE%% *}"
    if (( disk_num < 500 )); then
        warn "Low disk space (<500MB). You may not have room for Docker images."
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2: Install Python + Dependencies
# ═════════════════════════════════════════════════════════════════════════════

section 2 "$(tr step2)"

if step_done 2; then
    ok "Already completed (skipping)"
else
    # Install Python if needed
    if [[ -z "$PYTHON" ]]; then
        warn "Python >= 3.10 not found."
        echo ""
        if [[ -z "$PKG_MGR" ]]; then
            die "No package manager detected. Please install Python >= 3.10 manually and re-run."
        fi

        if ask_yn "Install Python now?"; then
            info "Installing Python..."
            case "$PKG_MGR" in
                apt)
                    sudo apt-get update -qq
                    if sudo apt-get install -y python3.12 python3.12-venv 2>/dev/null; then true
                    elif sudo apt-get install -y python3 python3-venv 2>/dev/null; then true
                    else
                        warn "Default python3 too old. Adding deadsnakes PPA..."
                        sudo apt-get install -y software-properties-common
                        sudo add-apt-repository -y ppa:deadsnakes/ppa
                        sudo apt-get update -qq
                        sudo apt-get install -y python3.12 python3.12-venv
                    fi
                    ;;
                dnf)    sudo dnf install -y python3.12 || sudo dnf install -y python3.11 || sudo dnf install -y python3 ;;
                yum)    sudo yum install -y python3 ;;
                pacman) sudo pacman -Sy --noconfirm python ;;
                apk)    sudo apk add python3 py3-pip ;;
                zypper) sudo zypper install -y python312 || sudo zypper install -y python311 || sudo zypper install -y python3 ;;
                brew)   brew install python@3.12 ;;
            esac

            PYTHON="$(find_python)" || die "Python still < 3.10 after install. Please install manually."
            ok "Installed: $("$PYTHON" --version 2>&1)"
        else
            die "Python >= 3.10 is required."
        fi
    fi

    # Create venv
    VENV_DIR="$BASE_DIR/.venv"
    if [[ -d "$VENV_DIR" ]] && "$VENV_DIR/bin/python" --version &>/dev/null; then
        ok "Virtual environment exists"
    else
        info "Creating virtual environment..."
        "$PYTHON" -m venv "$VENV_DIR" || {
            warn "venv module missing. Installing..."
            case "$PKG_MGR" in
                apt) sudo apt-get install -y "$(basename "$PYTHON")-venv" || sudo apt-get install -y python3-venv ;;
                dnf) sudo dnf install -y python3-libs ;;
                *) die "Could not create venv. Install python3-venv for your system." ;;
            esac
            "$PYTHON" -m venv "$VENV_DIR"
        }
        ok "Created virtual environment"
    fi

    PIP="$VENV_DIR/bin/pip"
    info "Installing dependencies..."
    "$PIP" install --upgrade pip -q 2>/dev/null || true
    "$PIP" install -r "$BASE_DIR/requirements.txt" -q
    ok "Dependencies installed"
    mark_step 2
fi

# Ensure PY is set for later steps
VENV_DIR="$BASE_DIR/.venv"
PY="$VENV_DIR/bin/python"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 3: Optional Components (one by one: intro → ask → configure)
# ═════════════════════════════════════════════════════════════════════════════

section 3 "$(tr step3)"

if step_done 3; then
    ok "Already completed (skipping)"
    USE_MEMOBASE="$(load_var USE_MEMOBASE false)"
    MEMOBASE_MODE="$(load_var MEMOBASE_MODE "")"
    MEMOBASE_URL="$(load_var MEMOBASE_URL "")"
    MEMOBASE_KEY="$(load_var MEMOBASE_KEY "")"
    USE_FIRECRAWL="$(load_var USE_FIRECRAWL false)"
    FIRECRAWL_URL="$(load_var FIRECRAWL_URL "")"
    FIRECRAWL_KEY="$(load_var FIRECRAWL_KEY "")"
    RSSHUB_URL="$(load_var RSSHUB_URL "https://rsshub.app")"
    SERPER_KEY="$(load_var SERPER_KEY "")"
else
    echo ""
    echo "  NaturalChat has several optional components that enhance its capabilities."
    echo "  All are optional — the bot works fine without any of them."
    echo "  We'll go through each one."
    echo ""
    hr

    # ── Memobase ──
    echo ""
    printf "  ${BOLD}Memobase${NC} — Long-term user memory\n"
    echo ""
    echo "    Remembers each user's preferences, personality, and conversation context"
    echo "    across sessions. Without it, the bot only remembers the current conversation"
    echo "    window (like goldfish memory — once the window scrolls, it's gone)."
    printf "    ${DIM}Requires: Docker (runs PostgreSQL + Redis + Memobase API)${NC}\n"
    echo ""

    USE_MEMOBASE=false
    MEMOBASE_MODE=""
    MEMOBASE_URL=""
    MEMOBASE_KEY=""

    if ask_yn "Enable Memobase?" "n"; then
        if $HAS_DOCKER; then
            c="$(ask_choice "How to set up Memobase:" 1 \
                "Deploy locally via Docker (free, recommended)" \
                "Connect to an existing Memobase server")"
            if [[ "$c" == "1" ]]; then
                MEMOBASE_MODE="docker"
                MEMOBASE_URL="http://localhost:8019"
                MEMOBASE_KEY="secret"
                USE_MEMOBASE=true
                ok "Memobase: will deploy locally via Docker"
            else
                MEMOBASE_URL="$(ask "Memobase server URL" "http://localhost:8019")"
                MEMOBASE_KEY="$(ask "Memobase API key" "secret")"
                MEMOBASE_MODE="remote"
                USE_MEMOBASE=true
                ok "Memobase: remote server configured"
            fi
        else
            warn "Docker not available. Memobase requires Docker to run locally."
            echo ""
            if ask_yn "Connect to a remote Memobase server instead?" "n"; then
                MEMOBASE_URL="$(ask "Memobase server URL" "")"
                MEMOBASE_KEY="$(ask "Memobase API key" "")"
                if [[ -n "$MEMOBASE_URL" ]]; then
                    MEMOBASE_MODE="remote"
                    USE_MEMOBASE=true
                    ok "Memobase: remote server configured"
                else
                    info "Memobase: skipped"
                fi
            else
                info "Memobase: skipped"
            fi
        fi
    else
        info "Memobase: skipped (bot will use sliding window memory only)"
    fi

    echo ""
    hr

    # ── Firecrawl ──
    echo ""
    printf "  ${BOLD}Firecrawl${NC} — Smart web scraping\n"
    echo ""
    echo "    Renders JavaScript and extracts clean Markdown content from web pages."
    echo "    Used by the surfing feature. Without it, surfing falls back to basic"
    echo "    HTTP fetch with simple HTML stripping (works but misses JS-rendered content)."
    printf "    ${DIM}Requires: Docker (self-host) or API key (https://firecrawl.dev)${NC}\n"
    echo ""

    USE_FIRECRAWL=false
    FIRECRAWL_URL=""
    FIRECRAWL_KEY=""

    if ask_yn "Enable Firecrawl?" "n"; then
        if $HAS_DOCKER; then
            c="$(ask_choice "How to set up Firecrawl:" 1 \
                "Deploy locally via Docker (free, recommended)" \
                "Use Firecrawl cloud API (needs API key)")"
            if [[ "$c" == "1" ]]; then
                FIRECRAWL_URL="http://localhost:3002"
                USE_FIRECRAWL=true
                ok "Firecrawl: will run locally via Docker"
            else
                FIRECRAWL_URL="https://api.firecrawl.dev"
                FIRECRAWL_KEY="$(ask "Firecrawl API key" "")"
                USE_FIRECRAWL=true
                ok "Firecrawl: cloud API"
            fi
        else
            info "No Docker — using Firecrawl cloud API"
            FIRECRAWL_URL="https://api.firecrawl.dev"
            FIRECRAWL_KEY="$(ask "Firecrawl API key" "")"
            if [[ -n "$FIRECRAWL_KEY" ]]; then
                USE_FIRECRAWL=true
                ok "Firecrawl: cloud API configured"
            else
                warn "Firecrawl: skipped (no API key)"
            fi
        fi
    else
        info "Firecrawl: skipped (will use basic HTTP scraping)"
    fi

    echo ""
    hr

    # ── RSSHub ──
    echo ""
    printf "  ${BOLD}RSSHub${NC} — RSS feed aggregation\n"
    echo ""
    echo "    Provides structured RSS feeds from 1000+ sites for the surfing feature."
    echo "    The public instance (rsshub.app) works out of the box. Self-host for"
    echo "    reliability or if you need access to rate-limited routes."
    printf "    ${DIM}Requires: nothing (public) or Docker (self-hosted)${NC}\n"
    echo ""

    RSSHUB_URL="https://rsshub.app"
    c="$(ask_choice "RSSHub setup:" 1 \
        "Use public instance rsshub.app (free, no setup)" \
        "Enter a custom RSSHub URL")"
    if [[ "$c" == "2" ]]; then
        RSSHUB_URL="$(ask "RSSHub server URL" "https://rsshub.app")"
    fi
    ok "RSSHub: $RSSHUB_URL"

    echo ""
    hr

    # ── Serper ──
    echo ""
    printf "  ${BOLD}Serper${NC} — Google search API\n"
    echo ""
    echo "    Gives the web search skill access to Google results. Without it, search"
    echo "    uses DuckDuckGo (free, no key needed, slightly less reliable)."
    printf "    ${DIM}Requires: API key from https://serper.dev (free tier: 2500 searches/mo)${NC}\n"
    echo ""

    SERPER_KEY=""
    if ask_yn "Configure Serper API key?" "n"; then
        SERPER_KEY="$(ask "Serper API key" "")"
        if [[ -n "$SERPER_KEY" ]]; then
            ok "Serper: configured (Google search)"
        else
            info "Serper: skipped, will use DuckDuckGo"
        fi
    else
        info "Serper: skipped, will use DuckDuckGo"
    fi

    save_var USE_MEMOBASE "$USE_MEMOBASE"
    save_var MEMOBASE_MODE "${MEMOBASE_MODE:-}"
    save_var MEMOBASE_URL "${MEMOBASE_URL:-}"
    save_var MEMOBASE_KEY "${MEMOBASE_KEY:-}"
    save_var USE_FIRECRAWL "$USE_FIRECRAWL"
    save_var FIRECRAWL_URL "${FIRECRAWL_URL:-}"
    save_var FIRECRAWL_KEY "${FIRECRAWL_KEY:-}"
    save_var RSSHUB_URL "$RSSHUB_URL"
    save_var SERPER_KEY "$SERPER_KEY"
    mark_step 3
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 4: Platform Selection
# ═════════════════════════════════════════════════════════════════════════════

section 4 "$(tr step4)"

if step_done 4; then
    ok "Already completed (skipping)"
    TG_ENABLED="$(load_var TG_ENABLED false)"
    TG_TOKEN="$(load_var TG_TOKEN "")"
    MATRIX_ENABLED="$(load_var MATRIX_ENABLED false)"
    MATRIX_HOMESERVER="$(load_var MATRIX_HOMESERVER "")"
    MATRIX_USER_ID="$(load_var MATRIX_USER_ID "")"
    MATRIX_ACCESS_TOKEN="$(load_var MATRIX_ACCESS_TOKEN "")"
    MATRIX_PASSWORD="$(load_var MATRIX_PASSWORD "")"
    NEEDS_CONDUIT="$(load_var NEEDS_CONDUIT false)"
    FEISHU_ENABLED="$(load_var FEISHU_ENABLED false)"
    FEISHU_APP_ID="$(load_var FEISHU_APP_ID "")"
    FEISHU_APP_SECRET="$(load_var FEISHU_APP_SECRET "")"
    FEISHU_PORT="$(load_var FEISHU_PORT 9000)"
    XMPP_ENABLED="$(load_var XMPP_ENABLED false)"
    XMPP_JID="$(load_var XMPP_JID "")"
    XMPP_PASSWORD="$(load_var XMPP_PASSWORD "")"
    XMPP_HOST="$(load_var XMPP_HOST "")"
    XMPP_PORT="$(load_var XMPP_PORT 5222)"
else
    echo ""
    echo "  Choose at least one platform. You can add more later."
    echo "  (The web panel is always enabled for testing.)"
    echo ""

    # Telegram
    TG_ENABLED=false
    TG_TOKEN=""
    if ask_yn "Enable Telegram Bot?"; then
        echo ""
        echo "    How to get a token: open Telegram -> @BotFather -> /newbot"
        echo ""
        TG_TOKEN="$(ask "Telegram Bot Token (or Enter to fill later)" "")"
        TG_ENABLED=true
        if [[ -n "$TG_TOKEN" ]]; then
            ok "Telegram: configured"
        else
            ok "Telegram: enabled (fill token in secrets.yaml later)"
        fi
    fi

    # Matrix
    MATRIX_ENABLED=false
    MATRIX_HOMESERVER=""
    MATRIX_USER_ID=""
    MATRIX_ACCESS_TOKEN=""
    MATRIX_PASSWORD=""
    NEEDS_CONDUIT=false

    echo ""
    if ask_yn "Enable Matrix?" "n"; then
        if $HAS_DOCKER; then
            c="$(ask_choice "Matrix server:" 1 \
                "Deploy Conduit via Docker (lightweight)" \
                "Connect to existing Matrix server")"
            if [[ "$c" == "1" ]]; then
                NEEDS_CONDUIT=true
                local_server="$(ask "Server name" "localhost")"
                local_user="$(ask "Bot username" "bot")"
                local_pass="$(head -c 18 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)"
                MATRIX_HOMESERVER="http://localhost:6167"
                MATRIX_USER_ID="@${local_user}:${local_server}"
                MATRIX_PASSWORD="$local_pass"
                MATRIX_ENABLED=true
                ok "Conduit will be deployed. User: $MATRIX_USER_ID"
                info "Generated password: $local_pass"
            fi
        fi
        if [[ "$MATRIX_ENABLED" != "true" ]]; then
            MATRIX_HOMESERVER="$(ask "Homeserver URL" "https://matrix.org")"
            MATRIX_USER_ID="$(ask "Bot User ID (e.g. @mybot:matrix.org)" "")"
            if [[ -n "$MATRIX_USER_ID" ]]; then
                c="$(ask_choice "Auth method:" 1 "Access Token" "Password")"
                if [[ "$c" == "1" ]]; then
                    MATRIX_ACCESS_TOKEN="$(ask "Access Token" "")"
                else
                    MATRIX_PASSWORD="$(ask "Password" "")"
                fi
                MATRIX_ENABLED=true
                ok "Matrix: configured"
            fi
        fi
    fi

    # Feishu
    FEISHU_ENABLED=false
    FEISHU_APP_ID=""
    FEISHU_APP_SECRET=""
    FEISHU_PORT=9000
    echo ""
    if ask_yn "Enable Feishu (Lark)?" "n"; then
        echo ""
        echo "    1. Create app at open.feishu.cn"
        echo "    2. Get App ID + Secret, set event callback URL"
        echo ""
        FEISHU_APP_ID="$(ask "App ID" "")"
        if [[ -n "$FEISHU_APP_ID" ]]; then
            FEISHU_APP_SECRET="$(ask "App Secret" "")"
            FEISHU_PORT="$(ask "Webhook port" "9000")"
            FEISHU_ENABLED=true
            ok "Feishu: configured"
        fi
    fi

    # XMPP
    XMPP_ENABLED=false
    XMPP_JID=""
    XMPP_PASSWORD=""
    XMPP_HOST=""
    XMPP_PORT=5222
    echo ""
    if ask_yn "Enable XMPP?" "n"; then
        XMPP_JID="$(ask "JID (e.g. bot@your-server.com)" "")"
        if [[ -n "$XMPP_JID" ]]; then
            XMPP_PASSWORD="$(ask "Password" "")"
            XMPP_HOST="$(ask "Server host" "localhost")"
            XMPP_PORT="$(ask "Port" "5222")"
            XMPP_ENABLED=true
            ok "XMPP: configured"
        fi
    fi

    if [[ "$TG_ENABLED" != "true" ]] && [[ "$MATRIX_ENABLED" != "true" ]] && \
       [[ "$FEISHU_ENABLED" != "true" ]] && [[ "$XMPP_ENABLED" != "true" ]]; then
        warn "No external platform enabled. You can still test via the web panel."
    fi

    # Save state
    for v in TG_ENABLED TG_TOKEN MATRIX_ENABLED MATRIX_HOMESERVER MATRIX_USER_ID \
             MATRIX_ACCESS_TOKEN MATRIX_PASSWORD NEEDS_CONDUIT FEISHU_ENABLED \
             FEISHU_APP_ID FEISHU_APP_SECRET FEISHU_PORT XMPP_ENABLED XMPP_JID \
             XMPP_PASSWORD XMPP_HOST XMPP_PORT; do
        save_var "$v" "${!v}"
    done
    mark_step 4
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 5: LLM Configuration
# ═════════════════════════════════════════════════════════════════════════════

section 5 "$(tr step5)"

if step_done 5; then
    ok "Already completed (skipping)"
    API_KEY="$(load_var API_KEY "")"
    BASE_URL="$(load_var BASE_URL "https://openrouter.ai/api/v1")"
    MODEL="$(load_var MODEL "openrouter/auto")"
else
    echo ""
    echo "  Default provider: OpenRouter (200+ models, OpenAI-compatible)"
    echo "  Get a key at: https://openrouter.ai/keys"
    echo "  Or use any OpenAI-compatible API (OpenAI, Anthropic, local, etc.)"
    echo ""
    echo "  All fields can be left empty and filled later in config/secrets files."
    echo ""
    BASE_URL="$(ask "API Base URL" "https://openrouter.ai/api/v1")"
    MODEL="$(ask "Model" "openrouter/auto")"
    API_KEY="$(ask "API Key (or Enter to skip)" "")"

    if [[ -z "$API_KEY" ]]; then
        info "No API key — fill it later in bots/<name>/secrets.yaml"
    else
        ok "LLM: configured"
    fi

    save_var API_KEY "$API_KEY"
    save_var BASE_URL "$BASE_URL"
    save_var MODEL "$MODEL"
    mark_step 5
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 6: Bot Setup
# ═════════════════════════════════════════════════════════════════════════════

section 6 "$(tr step6)"

if step_done 6; then
    ok "Already completed (skipping)"
    BOT_NAME="$(load_var BOT_NAME "")"
    ACCESS_MODE="$(load_var ACCESS_MODE "open")"
    CREATOR_ID="$(load_var CREATOR_ID "")"
else
    echo ""

    # Bot name with random default and re-roll option
    while true; do
        DEFAULT_NAME="$(random_name)"
        echo ""
        printf "  Bot name is used as the directory name under bots/.\n"
        printf "  Random suggestion: ${BOLD}${GREEN}%s${NC}\n" "$DEFAULT_NAME"
        echo ""
        c="$(ask_choice "Bot name:" 1 \
            "Use \"$DEFAULT_NAME\"" \
            "Generate another random name" \
            "Enter a custom name")"
        if [[ "$c" == "1" ]]; then
            BOT_NAME="$DEFAULT_NAME"
            break
        elif [[ "$c" == "2" ]]; then
            continue  # loop to regenerate
        else
            BOT_NAME="$(ask "Enter bot name" "")"
            BOT_NAME="$(echo "$BOT_NAME" | tr -cd 'a-zA-Z0-9_-')"
            if [[ -z "$BOT_NAME" ]]; then
                warn "Invalid name, using random"
                BOT_NAME="$DEFAULT_NAME"
            fi
            break
        fi
    done

    ok "Bot name: $BOT_NAME"

    BOT_DIR="$BOTS_DIR/$BOT_NAME"
    if [[ -d "$BOT_DIR" ]] && [[ -f "$BOT_DIR/config.yaml" ]]; then
        warn "Bot '$BOT_NAME' already exists. Its config will be preserved."
    fi

    echo ""
    c="$(ask_choice "Access control:" 1 \
        "open     — Anyone can chat" \
        "approval — New contacts need admin approval" \
        "private  — Only admin and creator can chat")"
    case "$c" in
        1) ACCESS_MODE="open" ;; 2) ACCESS_MODE="approval" ;; 3) ACCESS_MODE="private" ;; *) ACCESS_MODE="open" ;;
    esac

    CREATOR_ID=""
    if [[ "$TG_ENABLED" == "true" ]]; then
        echo ""
        CREATOR_TG="$(ask "Your Telegram numeric user ID (admin, optional)" "")"
        [[ -n "$CREATOR_TG" ]] && CREATOR_ID="telegram:$CREATOR_TG"
    elif [[ "$MATRIX_ENABLED" == "true" ]]; then
        echo ""
        CREATOR_MX="$(ask "Your Matrix user ID (e.g. @you:matrix.org, optional)" "")"
        [[ -n "$CREATOR_MX" ]] && CREATOR_ID="matrix:$CREATOR_MX"
    fi

    save_var BOT_NAME "$BOT_NAME"
    save_var ACCESS_MODE "$ACCESS_MODE"
    save_var CREATOR_ID "$CREATOR_ID"
    mark_step 6
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 7: Generate Files
# ═════════════════════════════════════════════════════════════════════════════

section 7 "$(tr step7)"

# Reload saved vars
USE_MEMOBASE="$(load_var USE_MEMOBASE false)"
MEMOBASE_MODE="$(load_var MEMOBASE_MODE "")"
MEMOBASE_URL="$(load_var MEMOBASE_URL "")"
MEMOBASE_KEY="$(load_var MEMOBASE_KEY "")"
USE_FIRECRAWL="$(load_var USE_FIRECRAWL false)"
FIRECRAWL_URL="$(load_var FIRECRAWL_URL "")"
FIRECRAWL_KEY="$(load_var FIRECRAWL_KEY "")"
RSSHUB_URL="$(load_var RSSHUB_URL "https://rsshub.app")"
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
echo ""

# Global config.yaml
GLOBAL_CONFIG="$BASE_DIR/config.yaml"
if [[ ! -f "$GLOBAL_CONFIG" ]]; then
    cat > "$GLOBAL_CONFIG" <<YAML
# NaturalChat global config — applies to all bots

env:
  # Google search API. Leave empty to use DuckDuckGo (free).
  SERPER_API_KEY: "$SERPER_KEY"

# RSSHub server for RSS feed aggregation.
rsshub_server: "$RSSHUB_URL"
YAML
    ok "Global config: $GLOBAL_CONFIG"
fi

# Bot directory
mkdir -p "$BOT_DIR/skills" "$BOT_DIR/bot_data"

# ── config.yaml ──
CONFIG_FILE="$BOT_DIR/config.yaml"
{
    echo "# ── Transports ──"
    echo "transports:"

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

    # Firecrawl
    if [[ "$USE_FIRECRAWL" == "true" ]]; then
        cat <<YAML

# ── Firecrawl ──
firecrawl:
  url: "$FIRECRAWL_URL"
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
ok "Bot config: $CONFIG_FILE"

# ── secrets.yaml ──
SECRETS_FILE="$BOT_DIR/secrets.yaml"
{
    echo "# Sensitive credentials — DO NOT commit"
    echo "llm:"
    echo "  api_key: \"$API_KEY\""
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
        [[ -n "$MATRIX_ACCESS_TOKEN" ]] && echo "    access_token: \"$MATRIX_ACCESS_TOKEN\""
        [[ -n "$MATRIX_PASSWORD" ]] && echo "    password: \"$MATRIX_PASSWORD\""
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

    if [[ "$USE_FIRECRAWL" == "true" ]] && [[ -n "$FIRECRAWL_KEY" ]]; then
        echo ""
        echo "firecrawl:"
        echo "  api_key: \"$FIRECRAWL_KEY\""
    fi

    if [[ "$USE_MEMOBASE" == "true" ]]; then
        echo ""
        echo "memobase:"
        echo "  api_key: \"${MEMOBASE_KEY:-secret}\""
    fi
} > "$SECRETS_FILE"
chmod 600 "$SECRETS_FILE"
ok "Secrets: $SECRETS_FILE (mode 600)"

# ── Prompts ──
if [[ ! -d "$BOT_DIR/prompts" ]]; then
    info "Scaffolding prompts..."
    "$PY" -c "
from src.prompt_store import scaffold_prompt_bundle
prompt = '''You are a friendly AI assistant.

# Note
- This prompt is written in English as a default template
- Always reply in the language the user is using

# Personality
- Helpful and natural

# Response style
- No customer-service tone
- Direct answers, no unnecessary preamble
- Concise, natural, like instant messaging
'''
scaffold_prompt_bundle('$BOT_DIR', main_prompt=prompt)
"
    ok "Prompts: $BOT_DIR/prompts/"
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
    ok "Bot metadata: access=$ACCESS_MODE"
fi

# ── .env ──
ENV_FILE="$BASE_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    {
        echo "# NaturalChat"
        [[ "$USE_MEMOBASE" == "true" ]] && echo "MEMOBASE_DB_PASSWORD=memobase"
    } > "$ENV_FILE"
fi

# ── Web panel credentials (random port + random username) ──
PANEL_CONFIG="$BASE_DIR/web_panel.yaml"
if [[ ! -f "$PANEL_CONFIG" ]]; then
    PANEL_PORT="$(random_port)"
    PANEL_USER="$(random_username)"
    PANEL_PASS="$(head -c 12 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 12)"
    cat > "$PANEL_CONFIG" <<YAML
# NaturalChat Web Panel
# Access at http://localhost:$PANEL_PORT after starting the bot
username: "$PANEL_USER"
password: "$PANEL_PASS"
port: $PANEL_PORT
YAML
    chmod 600 "$PANEL_CONFIG"
    ok "Web panel credentials generated (port: $PANEL_PORT)"
else
    PANEL_USER="$(grep 'username:' "$PANEL_CONFIG" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/')"
    PANEL_PASS="$(grep 'password:' "$PANEL_CONFIG" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/')"
    PANEL_PORT="$(grep 'port:' "$PANEL_CONFIG" | head -1 | sed 's/.*: *//')"
    PANEL_PORT="${PANEL_PORT:-8080}"
fi

# Save panel port for service step
save_var PANEL_PORT "${PANEL_PORT:-8080}"

ok "All configuration files generated"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 8: Launch Options
# ═════════════════════════════════════════════════════════════════════════════

section 8 "$(tr step8)"

echo ""
wrap_print "$(tr launch_intro_1)"
wrap_print "$(tr launch_intro_2)"
echo ""

RUN_NOW=false
STARTED_VIA_SERVICE=false

if [[ "$OS" == "Linux" ]] && command -v systemctl &>/dev/null; then
    # ── systemd (Linux) ──
    if ask_yn "$(tr direct_run_prompt)" "n"; then
        RUN_NOW=true
    fi

    echo ""
    if ask_yn "$(tr systemd_prompt)" "n"; then
        SERVICE_NAME="naturalchat"
        SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
        RUN_USER="$(whoami)"
        VENV_PYTHON="$BASE_DIR/.venv/bin/python"

        # Docker pre-start commands
        PRE_START_CMDS=""
        if [[ "$NEEDS_CONDUIT" == "true" ]] || [[ "$USE_MEMOBASE" == "true" ]] || \
           ( [[ "$USE_FIRECRAWL" == "true" ]] && [[ "$FIRECRAWL_URL" == "http://localhost:3002" ]] ); then
            PRE_START_CMDS="ExecStartPre=/usr/bin/docker compose -f ${BASE_DIR}/docker-compose.yml up -d"
        fi

        info "Creating systemd service..."
        sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=NaturalChat Multi-Bot System
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$BASE_DIR
${PRE_START_CMDS}
ExecStart=$VENV_PYTHON main.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Graceful shutdown
KillSignal=SIGINT
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable "$SERVICE_NAME"
        ok "Service installed: $SERVICE_NAME"

        if ask_yn "$(tr start_service_now)" "n"; then
            sudo systemctl start "$SERVICE_NAME"
            sleep 1
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                ok "NaturalChat is running!"
                STARTED_VIA_SERVICE=true
            else
                warn "Service may have failed to start. Check: journalctl -u $SERVICE_NAME -f"
            fi
        fi

        echo ""
        printf "  ${BOLD}Service commands:${NC}\n"
        echo "    sudo systemctl status $SERVICE_NAME    # Check status"
        echo "    sudo systemctl restart $SERVICE_NAME   # Restart"
        echo "    sudo systemctl stop $SERVICE_NAME      # Stop"
        echo "    journalctl -u $SERVICE_NAME -f          # View logs"
        echo ""
    fi

elif [[ "$OS" == "Darwin" ]]; then
    # ── launchd (macOS) ──
    if ask_yn "$(tr direct_run_prompt)" "n"; then
        RUN_NOW=true
    fi

    echo ""
    if ask_yn "$(tr launchd_prompt)" "n"; then
        PLIST_NAME="com.naturalchat.bot"
        PLIST_DIR="$HOME/Library/LaunchAgents"
        PLIST_FILE="$PLIST_DIR/$PLIST_NAME.plist"
        LOG_DIR="$BASE_DIR/logs"
        mkdir -p "$PLIST_DIR" "$LOG_DIR"
        VENV_PYTHON="$BASE_DIR/.venv/bin/python"

        info "Creating launchd service..."
        cat > "$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$VENV_PYTHON</string>
        <string>main.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$BASE_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/naturalchat.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/naturalchat.err</string>
    <key>ThrottleInterval</key>
    <integer>5</integer>
</dict>
</plist>
EOF

        ok "Service installed: $PLIST_FILE"

        if ask_yn "$(tr start_service_now)" "n"; then
            launchctl load "$PLIST_FILE" 2>/dev/null || true
            launchctl start "$PLIST_NAME" 2>/dev/null || true
            sleep 1
            ok "NaturalChat is starting..."
            STARTED_VIA_SERVICE=true
        fi

        echo ""
        printf "  ${BOLD}Service commands:${NC}\n"
        echo "    launchctl list | grep naturalchat      # Check status"
        echo "    launchctl stop $PLIST_NAME              # Stop"
        echo "    launchctl start $PLIST_NAME             # Start"
        echo "    tail -f $LOG_DIR/naturalchat.log       # View logs"
        echo ""
        printf "  ${BOLD}To uninstall:${NC}\n"
        echo "    launchctl unload $PLIST_FILE"
        echo "    rm $PLIST_FILE"
        echo ""
    fi
else
    if ask_yn "$(tr direct_run_prompt)" "n"; then
        RUN_NOW=true
    fi

    echo ""
    info "$(tr no_service_manager)"
    echo "    cd $BASE_DIR && .venv/bin/python main.py"
    echo ""
fi

# Clean up install state
rm -rf "$STATE_DIR"

# ═════════════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════════════

echo ""
printf "${BOLD}╔══════════════════════════════════════════╗${NC}\n"
printf "${BOLD}║          Setup Complete!                 ║${NC}\n"
printf "${BOLD}╚══════════════════════════════════════════╝${NC}\n"
echo ""

PLATFORMS=""
[[ "$TG_ENABLED" == "true" ]] && PLATFORMS="${PLATFORMS} Telegram"
[[ "$MATRIX_ENABLED" == "true" ]] && PLATFORMS="${PLATFORMS} Matrix"
[[ "$FEISHU_ENABLED" == "true" ]] && PLATFORMS="${PLATFORMS} Feishu"
[[ "$XMPP_ENABLED" == "true" ]] && PLATFORMS="${PLATFORMS} XMPP"
PLATFORMS="${PLATFORMS:- (web panel only)}"

printf "  Bot:        ${BOLD}%s${NC}\n" "$BOT_NAME"
printf "  Platforms:  %s\n" "$PLATFORMS"
printf "  Model:      %s\n" "$MODEL"
printf "  Access:     %s\n" "$ACCESS_MODE"
[[ "$USE_MEMOBASE" == "true" ]] && printf "  Memobase:   enabled ($MEMOBASE_MODE)\n"
[[ "$USE_FIRECRAWL" == "true" ]] && printf "  Firecrawl:  enabled ($FIRECRAWL_URL)\n"
echo ""

# Pre-start services reminder (if not using systemd)
SERVICES=()
[[ "$NEEDS_CONDUIT" == "true" ]] && SERVICES+=("docker compose --profile matrix up -d")
[[ "$USE_MEMOBASE" == "true" ]] && [[ "$MEMOBASE_MODE" == "docker" ]] && SERVICES+=("docker compose --profile memobase up -d")
if [[ "$USE_FIRECRAWL" == "true" ]] && [[ "$FIRECRAWL_URL" == "http://localhost:3002" ]]; then
    SERVICES+=("docker run -d -p 3002:3002 mendableai/firecrawl")
fi

if (( ${#SERVICES[@]} > 0 )); then
    printf "${YELLOW}  Start required Docker services first:${NC}\n"
    for cmd in "${SERVICES[@]}"; do
        echo "    $cmd"
    done
    echo ""
fi

printf "${BOLD}  Run manually:${NC}\n"
echo "    cd $BASE_DIR"
echo "    .venv/bin/python main.py"
echo ""

printf "${BOLD}  Web Panel:${NC}\n"
echo "    URL:      http://localhost:${PANEL_PORT}"
echo "    Username: $PANEL_USER"
echo "    Password: $PANEL_PASS"
echo "    (credentials saved in $PANEL_CONFIG)"
echo ""

# Missing credentials warning
MISSING=()
[[ -z "$API_KEY" ]] && MISSING+=("LLM API key")
[[ "$TG_ENABLED" == "true" ]] && [[ -z "$TG_TOKEN" ]] && MISSING+=("Telegram token")

if (( ${#MISSING[@]} > 0 )); then
    printf "${YELLOW}  Missing credentials (fill before starting):${NC}\n"
    echo "    Edit: $SECRETS_FILE"
    for m in "${MISSING[@]}"; do
        echo "    - $m"
    done
    echo ""
fi

printf "${BOLD}  Key files:${NC}\n"
echo "    Config:   $CONFIG_FILE"
echo "    Secrets:  $SECRETS_FILE"
echo "    Prompts:  $BOT_DIR/prompts/main.md"
echo ""

printf "${BOLD}  Manage bots:${NC}\n"
echo "    .venv/bin/python manage.py list | add | remove | export"
echo ""

# Sandbox
if $HAS_DOCKER; then
    ok "Sandbox: Docker (best isolation)"
elif $HAS_BWRAP; then
    ok "Sandbox: bubblewrap"
elif [[ "$OS" == "Darwin" ]]; then
    ok "Sandbox: macOS sandbox-exec"
else
    warn "No sandbox. Install Docker for code execution isolation."
fi

echo ""

if [[ "$RUN_NOW" == "true" ]]; then
    if [[ "$STARTED_VIA_SERVICE" == "true" ]]; then
        info "$(tr skip_direct_run)"
    else
        info "$(tr start_direct_run)"
        exec "$BASE_DIR/.venv/bin/python" "$BASE_DIR/main.py"
    fi
fi
