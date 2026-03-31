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

LANG_UI="en"

i18n() {
    local key="$1"
    case "$LANG_UI:$key" in
        # ── Generic UI labels ──
        en:default_label) echo "default" ;;
        zh:default_label) echo "默认" ;;
        en:choice_label) echo "Choice" ;;
        zh:choice_label) echo "选择" ;;
        en:arrow_help) echo "arrow keys to move, Enter to select" ;;
        zh:arrow_help) echo "方向键移动，回车确认" ;;
        en:step_label) echo "Step" ;;
        zh:step_label) echo "步骤" ;;
        en:yes_label) echo "Yes" ;;
        zh:yes_label) echo "是" ;;
        en:no_label) echo "No" ;;
        zh:no_label) echo "否" ;;
        en:resume_note) echo "Resume supported: press Ctrl+C anytime and re-run later." ;;
        zh:resume_note) echo "支持断点继续：随时 Ctrl+C 退出，之后重新运行即可继续。" ;;
        en:optional_note) echo "Most fields can be skipped now and filled in later." ;;
        zh:optional_note) echo "大多数信息现在都可以跳过，稍后再补。" ;;
        en:lang_prompt) echo "Choose installer language" ;;
        zh:lang_prompt) echo "选择安装器语言" ;;

        # ── Step names ──
        en:step1) echo "System Detection" ;;
        zh:step1) echo "系统检测" ;;
        en:step2) echo "Configuration" ;;
        zh:step2) echo "配置" ;;
        en:step6) echo "Python & Dependencies" ;;
        zh:step6) echo "Python 与依赖" ;;
        en:deps_skip_docker) echo "Docker mode — dependencies installed inside container, skipping host install" ;;
        zh:deps_skip_docker) echo "Docker 模式 — 依赖在容器内安装，跳过宿主机安装" ;;
        en:step7) echo "Generating Configuration" ;;
        zh:step7) echo "生成配置" ;;
        en:step8) echo "Deploy & Launch" ;;
        zh:step8) echo "部署与启动" ;;

        # ── Config overview ──
        en:cfg_title) echo "Configuration Overview" ;;
        zh:cfg_title) echo "配置概览" ;;
        en:cfg_run_mode) echo "Run mode:" ;;
        zh:cfg_run_mode) echo "运行方式：" ;;
        en:cfg_recommended) echo "recommended" ;;
        zh:cfg_recommended) echo "推荐" ;;
        en:cfg_host_mode) echo "Host (venv + nohup)" ;;
        zh:cfg_host_mode) echo "宿主机（venv + nohup）" ;;
        en:cfg_bot_name) echo "Bot name:" ;;
        zh:cfg_bot_name) echo "机器人名称：" ;;
        en:cfg_platforms) echo "Platforms:" ;;
        zh:cfg_platforms) echo "消息平台：" ;;
        en:cfg_llm_url) echo "LLM API URL:" ;;
        zh:cfg_llm_url) echo "LLM API 地址：" ;;
        en:cfg_llm_model) echo "LLM Model:" ;;
        zh:cfg_llm_model) echo "LLM 模型：" ;;
        en:cfg_api_key) echo "API Key:" ;;
        zh:cfg_api_key) echo "API 密钥：" ;;
        en:cfg_access) echo "Access:" ;;
        zh:cfg_access) echo "访问控制：" ;;
        en:cfg_components) echo "Components:" ;;
        zh:cfg_components) echo "可选组件：" ;;
        en:cfg_admin_id) echo "Admin ID:" ;;
        zh:cfg_admin_id) echo "管理员 ID：" ;;
        en:cfg_not_set) echo "not set" ;;
        zh:cfg_not_set) echo "未设置" ;;
        en:cfg_none) echo "none" ;;
        zh:cfg_none) echo "无" ;;
        en:cfg_no_docker) echo "Docker not available, cannot switch to Docker mode" ;;
        zh:cfg_no_docker) echo "Docker 不可用，无法切换到 Docker 模式" ;;
        en:cfg_hint) echo "Enter numbers to edit (e.g. 3 6), or press Enter to confirm and install:" ;;
        zh:cfg_hint) echo "输入编号修改（如 3 6），直接回车确认并开始安装：" ;;
        en:cfg_confirm) echo "Proceed with installation?" ;;
        zh:cfg_confirm) echo "确认开始安装？" ;;
        en:cfg_comp_select) echo "Enable components:" ;;
        zh:cfg_comp_select) echo "启用组件：" ;;
        en:cfg_invalid_num) echo "Invalid number, try again" ;;
        zh:cfg_invalid_num) echo "无效编号，请重试" ;;

        # ── Step 1: System detection ──
        en:already_done) echo "Already completed (skipping)" ;;
        zh:already_done) echo "已完成（跳过）" ;;

        # ── Step 2: Python ──
        en:python_not_found) echo "Python >= 3.10 not found." ;;
        zh:python_not_found) echo "未找到 Python >= 3.10。" ;;
        en:install_python) echo "Install Python now?" ;;
        zh:install_python) echo "现在安装 Python？" ;;
        en:no_pkg_mgr) echo "No package manager detected. Please install Python >= 3.10 manually and re-run." ;;
        zh:no_pkg_mgr) echo "未检测到包管理器。请手动安装 Python >= 3.10 后重新运行。" ;;
        en:python_required) echo "Python >= 3.10 is required." ;;
        zh:python_required) echo "需要 Python >= 3.10。" ;;
        en:installing_python) echo "Installing Python..." ;;
        zh:installing_python) echo "正在安装 Python..." ;;
        en:creating_venv) echo "Creating virtual environment..." ;;
        zh:creating_venv) echo "正在创建虚拟环境..." ;;
        en:venv_exists) echo "Virtual environment exists" ;;
        zh:venv_exists) echo "虚拟环境已存在" ;;
        en:venv_created) echo "Created virtual environment" ;;
        zh:venv_created) echo "已创建虚拟环境" ;;
        en:installing_deps) echo "Installing dependencies..." ;;
        zh:installing_deps) echo "正在安装依赖..." ;;
        en:deps_installed) echo "Dependencies installed" ;;
        zh:deps_installed) echo "依赖已安装" ;;

        # ── Step 3: Optional Components ──
        en:opt_intro_1) echo "NaturalChat has several optional components that enhance its capabilities." ;;
        zh:opt_intro_1) echo "NaturalChat 有多个可选组件可以增强功能。" ;;
        en:opt_intro_2) echo "All are optional — the bot works fine without any of them." ;;
        zh:opt_intro_2) echo "所有组件都是可选的 —— 没有它们机器人也能正常工作。" ;;
        en:opt_intro_3) echo "We'll go through each one." ;;
        zh:opt_intro_3) echo "我们将逐一介绍。" ;;

        en:memobase_title) echo "Memobase — Long-term user memory" ;;
        zh:memobase_title) echo "Memobase —— 长期用户记忆" ;;
        en:memobase_desc_1) echo "Remembers each user's preferences, personality, and conversation context" ;;
        zh:memobase_desc_1) echo "记住每个用户的偏好、性格和对话上下文，" ;;
        en:memobase_desc_2) echo "across sessions. Without it, the bot only remembers the current conversation" ;;
        zh:memobase_desc_2) echo "跨会话持久化。没有它，机器人只能记住当前对话窗口" ;;
        en:memobase_desc_3) echo "window (like goldfish memory — once the window scrolls, it's gone)." ;;
        zh:memobase_desc_3) echo "（像金鱼记忆 —— 窗口一滚就忘了）。" ;;
        en:memobase_req) echo "Requires: Docker (runs PostgreSQL + Redis + Memobase API)" ;;
        zh:memobase_req) echo "需要：Docker（运行 PostgreSQL + Redis + Memobase API）" ;;
        en:enable_memobase) echo "Enable Memobase?" ;;
        zh:enable_memobase) echo "启用 Memobase？" ;;
        en:memobase_how) echo "How to set up Memobase:" ;;
        zh:memobase_how) echo "Memobase 部署方式：" ;;
        en:memobase_docker) echo "Deploy locally via Docker (free, recommended)" ;;
        zh:memobase_docker) echo "通过 Docker 本地部署（免费，推荐）" ;;
        en:memobase_remote) echo "Connect to an existing Memobase server" ;;
        zh:memobase_remote) echo "连接到已有的 Memobase 服务器" ;;
        en:memobase_no_docker) echo "Docker not available. Memobase requires Docker to run locally." ;;
        zh:memobase_no_docker) echo "Docker 不可用。Memobase 需要 Docker 才能本地运行。" ;;
        en:memobase_remote_instead) echo "Connect to a remote Memobase server instead?" ;;
        zh:memobase_remote_instead) echo "改为连接远程 Memobase 服务器？" ;;
        en:memobase_skipped) echo "Memobase: skipped (bot will use sliding window memory only)" ;;
        zh:memobase_skipped) echo "Memobase：已跳过（机器人将只使用滑动窗口记忆）" ;;

        en:crawl4ai_title) echo "Crawl4AI — LLM-ready web crawling" ;;
        zh:crawl4ai_title) echo "Crawl4AI —— LLM 友好的网页抓取" ;;
        en:crawl4ai_desc_1) echo "Open-source crawler that converts web pages into clean Markdown." ;;
        zh:crawl4ai_desc_1) echo "开源爬虫，将网页转换为干净的 Markdown 格式。" ;;
        en:crawl4ai_desc_2) echo "Renders JavaScript, extracts structured data. Used by the surfing" ;;
        zh:crawl4ai_desc_2) echo "支持 JavaScript 渲染和结构化数据提取。供冲浪功能使用，" ;;
        en:crawl4ai_desc_3) echo "feature. Without it, surfing falls back to basic HTTP fetch." ;;
        zh:crawl4ai_desc_3) echo "没有它冲浪将退回到基本 HTTP 抓取。" ;;
        en:crawl4ai_req) echo "Requires: Docker (recommended) or pip install" ;;
        zh:crawl4ai_req) echo "需要：Docker（推荐）或 pip 安装" ;;
        en:enable_crawl4ai) echo "Enable Crawl4AI?" ;;
        zh:enable_crawl4ai) echo "启用 Crawl4AI？" ;;
        en:crawl4ai_how) echo "How to set up Crawl4AI:" ;;
        zh:crawl4ai_how) echo "Crawl4AI 部署方式：" ;;
        en:crawl4ai_docker) echo "Deploy locally via Docker (free, recommended)" ;;
        zh:crawl4ai_docker) echo "通过 Docker 本地部署（免费，推荐）" ;;
        en:crawl4ai_cloud) echo "Connect to an existing Crawl4AI server" ;;
        zh:crawl4ai_cloud) echo "连接到已有的 Crawl4AI 服务器" ;;
        en:crawl4ai_no_docker) echo "No Docker — enter a remote Crawl4AI server URL" ;;
        zh:crawl4ai_no_docker) echo "没有 Docker —— 请输入远程 Crawl4AI 服务器地址" ;;
        en:crawl4ai_skipped) echo "Crawl4AI: skipped (will use basic HTTP scraping)" ;;
        zh:crawl4ai_skipped) echo "Crawl4AI：已跳过（将使用基本 HTTP 抓取）" ;;

        en:rsshub_title) echo "RSSHub — RSS feed aggregation" ;;
        zh:rsshub_title) echo "RSSHub —— RSS 聚合" ;;
        en:rsshub_desc_1) echo "Provides structured RSS feeds from 1000+ sites for the surfing feature." ;;
        zh:rsshub_desc_1) echo "为冲浪功能提供来自 1000+ 网站的结构化 RSS 源。" ;;
        en:rsshub_desc_2) echo "Self-hosted via Docker for reliability." ;;
        zh:rsshub_desc_2) echo "通过 Docker 自建，确保稳定性。" ;;
        en:rsshub_desc_3) echo "Or connect to your own existing RSSHub instance." ;;
        zh:rsshub_desc_3) echo "也可连接到已有的 RSSHub 实例。" ;;
        en:rsshub_req) echo "Requires: Docker (local) or existing RSSHub URL" ;;
        zh:rsshub_req) echo "需要：Docker（本地部署）或已有的 RSSHub URL" ;;
        en:rsshub_how) echo "RSSHub setup:" ;;
        zh:rsshub_how) echo "RSSHub 部署方式：" ;;
        en:rsshub_docker) echo "Deploy locally via Docker (recommended)" ;;
        zh:rsshub_docker) echo "通过 Docker 本地部署（推荐）" ;;
        en:rsshub_custom) echo "Enter a custom RSSHub URL" ;;
        zh:rsshub_custom) echo "输入自定义 RSSHub URL" ;;

        en:serper_title) echo "Serper — Google search API" ;;
        zh:serper_title) echo "Serper —— Google 搜索 API" ;;
        en:serper_desc_1) echo "Gives the web search skill access to Google results. Without it, search" ;;
        zh:serper_desc_1) echo "让网络搜索技能可以使用 Google 搜索结果。没有它，搜索" ;;
        en:serper_desc_2) echo "uses DuckDuckGo (free, no key needed, slightly less reliable)." ;;
        zh:serper_desc_2) echo "将使用 DuckDuckGo（免费，无需密钥，但稍不稳定）。" ;;
        en:serper_req) echo "Requires: API key from https://serper.dev (free tier: 2500 searches/mo)" ;;
        zh:serper_req) echo "需要：https://serper.dev 的 API 密钥（免费额度：2500 次/月）" ;;
        en:enable_serper) echo "Configure Serper API key?" ;;
        zh:enable_serper) echo "配置 Serper API 密钥？" ;;
        en:serper_skipped) echo "Serper: skipped, will use DuckDuckGo" ;;
        zh:serper_skipped) echo "Serper：已跳过，将使用 DuckDuckGo" ;;

        # ── Step 4: Platforms ──
        en:plat_intro_1) echo "Select messaging platforms to enable (web panel is always on)." ;;
        zh:plat_intro_1) echo "选择要启用的消息平台（网页面板始终可用）。" ;;
        en:plat_intro_2) echo "You can add or change platforms later via nctl.sh." ;;
        zh:plat_intro_2) echo "稍后也可以通过 nctl.sh 添加或更改平台。" ;;
        en:plat_select) echo "Enable platforms:" ;;
        zh:plat_select) echo "启用平台：" ;;
        en:feishu_label) echo "Feishu (Lark)" ;;
        zh:feishu_label) echo "飞书" ;;
        en:enable_telegram) echo "Enable Telegram Bot?" ;;
        zh:enable_telegram) echo "启用 Telegram Bot？" ;;
        en:tg_howto) echo "How to get a token: open Telegram -> @BotFather -> /newbot" ;;
        zh:tg_howto) echo "获取 Token：打开 Telegram -> @BotFather -> /newbot" ;;
        en:enable_matrix) echo "Enable Matrix?" ;;
        zh:enable_matrix) echo "启用 Matrix？" ;;
        en:matrix_how) echo "Matrix server:" ;;
        zh:matrix_how) echo "Matrix 服务器：" ;;
        en:matrix_docker) echo "Deploy Conduit via Docker (lightweight)" ;;
        zh:matrix_docker) echo "通过 Docker 部署 Conduit（轻量级）" ;;
        en:matrix_existing) echo "Connect to existing Matrix server" ;;
        zh:matrix_existing) echo "连接到已有的 Matrix 服务器" ;;
        en:matrix_auth) echo "Auth method:" ;;
        zh:matrix_auth) echo "认证方式：" ;;
        en:enable_feishu) echo "Enable Feishu (Lark)?" ;;
        zh:enable_feishu) echo "启用飞书？" ;;
        en:feishu_howto_1) echo "1. Create app at open.feishu.cn" ;;
        zh:feishu_howto_1) echo "1. 在 open.feishu.cn 创建应用" ;;
        en:feishu_howto_2) echo "2. Get App ID + Secret, set event callback URL" ;;
        zh:feishu_howto_2) echo "2. 获取 App ID + Secret，设置事件回调 URL" ;;
        en:enable_xmpp) echo "Enable XMPP?" ;;
        zh:enable_xmpp) echo "启用 XMPP？" ;;
        en:no_platform_warn) echo "No external platform enabled. You can still test via the web panel." ;;
        zh:no_platform_warn) echo "未启用任何外部平台。你仍然可以通过网页面板测试。" ;;

        # ── Step 5: LLM ──
        en:llm_intro_1) echo "Default provider: OpenRouter (200+ models, OpenAI-compatible)" ;;
        zh:llm_intro_1) echo "默认提供商：OpenRouter（200+ 模型，兼容 OpenAI）" ;;
        en:llm_intro_2) echo "Get a key at: https://openrouter.ai/keys" ;;
        zh:llm_intro_2) echo "获取密钥：https://openrouter.ai/keys" ;;
        en:llm_intro_3) echo "Or use any OpenAI-compatible API (OpenAI, Anthropic, local, etc.)" ;;
        zh:llm_intro_3) echo "也可以使用任何 OpenAI 兼容的 API（OpenAI、Anthropic、本地等）" ;;
        en:llm_intro_4) echo "All fields can be left empty and filled later in config/secrets files." ;;
        zh:llm_intro_4) echo "所有字段都可以留空，稍后在配置/密钥文件中填写。" ;;
        en:no_api_key) echo "No API key — fill it later in bots/<name>/secrets.yaml" ;;
        zh:no_api_key) echo "未填写 API 密钥 —— 稍后在 bots/<name>/secrets.yaml 中填写" ;;

        # ── Step 6: Bot ──
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
        en:creator_mx_prompt) echo "Your Matrix user ID — used as admin for bot management (e.g. @you:matrix.org, optional)" ;;
        zh:creator_mx_prompt) echo "你的 Matrix 用户 ID — 用作机器人管理员，可管理、配置机器人（如 @you:matrix.org，可选）" ;;
        en:access_prompt) echo "Access control:" ;;
        zh:access_prompt) echo "访问控制：" ;;
        en:access_open) echo "open     — Anyone can chat" ;;
        zh:access_open) echo "open     —— 任何人都可以聊天" ;;
        en:access_approval) echo "approval — New contacts need admin approval" ;;
        zh:access_approval) echo "approval —— 新联系人需要管理员审批" ;;
        en:access_private) echo "private  — Only admin and creator can chat" ;;
        zh:access_private) echo "private  —— 仅管理员和创建者可以聊天" ;;

        # ── Step 7: Config gen ──
        en:config_generated) echo "All configuration files generated" ;;
        zh:config_generated) echo "所有配置文件已生成" ;;

        # ── Step 8: Deploy & Launch ──
        en:deploying_services) echo "Deploying Docker services..." ;;
        zh:deploying_services) echo "正在部署 Docker 服务..." ;;
        en:services_started) echo "Docker services started successfully" ;;
        zh:services_started) echo "Docker 服务启动成功" ;;
        en:services_failed) echo "Some Docker services failed to start. Check: docker compose logs" ;;
        zh:services_failed) echo "部分 Docker 服务启动失败。请检查：docker compose logs" ;;
        en:no_services) echo "No Docker services to deploy." ;;
        zh:no_services) echo "无需部署 Docker 服务。" ;;
        en:bot_run_mode) echo "How would you like to run the bot?" ;;
        zh:bot_run_mode) echo "你希望如何运行机器人主程序？" ;;
        en:bot_run_docker) echo "Docker container (recommended, isolated)" ;;
        zh:bot_run_docker) echo "Docker 容器运行（推荐，隔离性好）" ;;
        en:bot_run_host) echo "Run directly on host (venv + nohup)" ;;
        zh:bot_run_host) echo "直接在宿主机运行（venv + nohup）" ;;
        en:direct_run_prompt) echo "Start NaturalChat now (runs in background)?" ;;
        zh:direct_run_prompt) echo "现在启动 NaturalChat（后台运行）？" ;;
        en:systemd_prompt) echo "Install systemd service for auto-start on boot?" ;;
        zh:systemd_prompt) echo "安装 systemd 服务并在开机时自动启动？" ;;
        en:launchd_prompt) echo "Install launchd service for auto-start on login?" ;;
        zh:launchd_prompt) echo "安装 launchd 服务并在登录时自动启动？" ;;
        en:start_service_now) echo "Start the service now?" ;;
        zh:start_service_now) echo "现在要启动该服务吗？" ;;
        en:launch_intro_1) echo "You can start NaturalChat now (background), or optionally install it as" ;;
        zh:launch_intro_1) echo "你可以现在启动 NaturalChat（后台运行），也可以另外安装成系统服务，" ;;
        en:launch_intro_2) echo "a system service for auto-start on boot/login." ;;
        zh:launch_intro_2) echo "用于开机或登录时自动启动。" ;;
        en:no_service_manager) echo "No systemd or launchd detected. Run manually:" ;;
        zh:no_service_manager) echo "未检测到 systemd 或 launchd。请手动运行：" ;;
        en:skip_direct_run) echo "Skipping — NaturalChat is already running via system service." ;;
        zh:skip_direct_run) echo "已通过系统服务启动，跳过，避免重复运行。" ;;
        en:start_direct_run) echo "Starting NaturalChat in the background..." ;;
        zh:start_direct_run) echo "正在后台启动 NaturalChat..." ;;
        en:view_logs) echo "View real-time logs" ;;
        zh:view_logs) echo "查看实时日志" ;;
        en:stop_bot) echo "Stop" ;;
        zh:stop_bot) echo "停止" ;;

        # ── Summary / Next Steps ──
        en:setup_complete) echo "Setup Complete!" ;;
        zh:setup_complete) echo "安装完成！" ;;
        en:next_steps_title) echo "What's Next" ;;
        zh:next_steps_title) echo "接下来做什么" ;;
        en:next_step_secrets) echo "Fill in missing credentials in the secrets file" ;;
        zh:next_step_secrets) echo "在密钥文件中填写缺失的凭据" ;;
        en:next_step_prompt) echo "Customize the bot's personality by editing the prompt file" ;;
        zh:next_step_prompt) echo "编辑提示词文件来自定义机器人的性格" ;;
        en:next_step_run) echo "Start NaturalChat and open the web panel to test" ;;
        zh:next_step_run) echo "启动 NaturalChat 并打开网页面板进行测试" ;;
        en:next_step_docs) echo "Read the docs: https://github.com/syncmeta/naturalchat" ;;
        zh:next_step_docs) echo "阅读文档：https://github.com/syncmeta/naturalchat" ;;
        en:next_step_add_bot) echo "Add more bots with: .venv/bin/python manage.py add" ;;
        zh:next_step_add_bot) echo "添加更多机器人：.venv/bin/python manage.py add" ;;
        en:missing_creds_warn) echo "Missing credentials (fill before starting):" ;;
        zh:missing_creds_warn) echo "缺失的凭据（启动前请填写）：" ;;
        en:key_files) echo "Key files:" ;;
        zh:key_files) echo "关键文件：" ;;
        en:manage_bots) echo "Manage bots:" ;;
        zh:manage_bots) echo "管理机器人：" ;;
        en:web_panel) echo "Web Panel:" ;;
        zh:web_panel) echo "网页面板：" ;;
        en:run_manually) echo "Run manually:" ;;
        zh:run_manually) echo "手动运行：" ;;
        en:service_commands) echo "Service commands:" ;;
        zh:service_commands) echo "服务管理命令：" ;;

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
    printf "  %s  ${DIM}(%s)${NC}\n\n" "$prompt" "$(i18n arrow_help)" >&2

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

# ── Banner ───────────────────────────────────────────────────────────────────

LANG_CHOICE="$(ask_choice "Choose installer language / 选择安装器语言" 1 "English" "中文")"
if [[ "$LANG_CHOICE" == "2" ]]; then
    LANG_UI="zh"
fi

banner "NaturalChat Setup"
wrap_print "$(i18n resume_note)"
wrap_print "$(i18n optional_note)"
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

# Check if resuming
if ls "$STATE_DIR"/step_* &>/dev/null 2>&1; then
    info "Resuming previous installation..."
    echo ""
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1: System Detection
# ═════════════════════════════════════════════════════════════════════════════

section 1 "$(i18n step1)"

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

# Only show problems — stay silent if everything looks fine
ISSUES=()
if [[ -z "$PYTHON" ]]; then
    ISSUES+=("Python:  not found (>= 3.10 required)")
fi
if [[ "$DOCKER_STATUS" == "not installed" ]]; then
    ISSUES+=("Docker:  not installed (needed for optional services)")
elif [[ "$DOCKER_STATUS" == "installed but not running" ]]; then
    ISSUES+=("Docker:  installed but not running")
fi
if ! $HAS_GIT; then
    ISSUES+=("Git:     not found")
fi
if [[ "$MEM_TOTAL" != "unknown" ]]; then
    mem_num="${MEM_TOTAL%% *}"
    if (( mem_num < 512 )); then
        ISSUES+=("Memory:  ${MEM_TOTAL} (low — Docker services need more)")
    fi
fi
if [[ "$DISK_FREE" != "unknown" ]]; then
    disk_num="${DISK_FREE%% *}"
    if (( disk_num < 500 )); then
        ISSUES+=("Disk:    ${DISK_FREE} free (low — may not fit Docker images)")
    fi
fi

if (( ${#ISSUES[@]} > 0 )); then
    echo ""
    for issue in "${ISSUES[@]}"; do
        warn "$issue"
    done
    echo ""
else
    ok "$OS — $DISTRO — $ARCH"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2: Configuration (show defaults, edit what you want, confirm once)
# ═════════════════════════════════════════════════════════════════════════════

section 2 "$(i18n step2)"

if step_done 2; then
    ok "$(i18n already_done)"
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
    BOT_RUN_MODE="$(load_var BOT_RUN_MODE "")"
else
    # ── Set all defaults ──────────────────────────────────────────────────
    BOT_NAME="${DEFAULT_BOT_NAME:-$(random_name)}"
    if $HAS_DOCKER; then BOT_RUN_MODE="docker"; else BOT_RUN_MODE="host"; fi
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

    if $HAS_DOCKER; then
        NEEDS_CONDUIT=true
        CONDUIT_PORT="${DEFAULT_CONDUIT_PORT:-$(random_port)}"
        CONDUIT_FED_PORT="$(random_port)"
        CONDUIT_SERVER_NAME="localhost"
        CONDUIT_BOT_USER=""
        MATRIX_PASSWORD="${DEFAULT_MATRIX_PASSWORD:-$(random_chars 16)}"
        MATRIX_HOMESERVER="http://127.0.0.1:$CONDUIT_PORT"
    else
        NEEDS_CONDUIT=false; CONDUIT_PORT=""; CONDUIT_FED_PORT=""
        CONDUIT_SERVER_NAME=""; CONDUIT_BOT_USER=""
        MATRIX_ENABLED=false
    fi

    # Components
    USE_MEMOBASE=true; MEMOBASE_MODE=""; MEMOBASE_URL=""; MEMOBASE_KEY=""; MEMOBASE_PORT=""
    USE_CRAWL4AI=true; CRAWL4AI_MODE=""; CRAWL4AI_URL=""; CRAWL4AI_KEY=""; CRAWL4AI_PORT=""
    if $HAS_DOCKER; then
        MEMOBASE_MODE="docker"; MEMOBASE_PORT="$(random_port)"
        MEMOBASE_URL="http://127.0.0.1:$MEMOBASE_PORT"; MEMOBASE_KEY="$(random_chars 32)"
        CRAWL4AI_MODE="docker"; CRAWL4AI_PORT="$(random_port)"
        CRAWL4AI_URL="http://localhost:$CRAWL4AI_PORT"
    fi
    SERPER_KEY=""
    if $HAS_DOCKER; then
        RSSHUB_MODE="docker"; RSSHUB_PORT="$(random_port)"; RSSHUB_URL="http://localhost:$RSSHUB_PORT"
    else
        RSSHUB_MODE="custom"; RSSHUB_PORT=""; RSSHUB_URL=""
    fi

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

    # ── Display config table ──────────────────────────────────────────────

    _show_config() {
        echo ""
        printf "  ${BOLD}$(i18n cfg_title)${NC}\n"
        echo ""
        printf "    ${CYAN} 1${NC}  %-18s %s\n" "$(i18n cfg_run_mode)" "$( [[ "$BOT_RUN_MODE" == "docker" ]] && echo "Docker ($(i18n cfg_recommended))" || echo "$(i18n cfg_host_mode)" )"
        printf "    ${CYAN} 2${NC}  %-18s %s\n" "$(i18n cfg_bot_name)" "$BOT_NAME"
        printf "    ${CYAN} 3${NC}  %-18s %s\n" "$(i18n cfg_platforms)" "$(_plat_summary)"
        printf "    ${CYAN} 4${NC}  %-18s %s\n" "$(i18n cfg_llm_url)" "$BASE_URL"
        printf "    ${CYAN} 5${NC}  %-18s %s\n" "$(i18n cfg_llm_model)" "$MODEL"
        printf "    ${CYAN} 6${NC}  %-18s %b\n" "$(i18n cfg_api_key)" "$(_mask_key "$API_KEY")"
        printf "    ${CYAN} 7${NC}  %-18s %s\n" "$(i18n cfg_access)" "$ACCESS_MODE"
        printf "    ${CYAN} 8${NC}  %-18s %s\n" "$(i18n cfg_components)" "$(_comp_summary)"
        if [[ "$MATRIX_ENABLED" == "true" ]] || [[ "$TG_ENABLED" == "true" ]]; then
            printf "    ${CYAN} 9${NC}  %-18s %s\n" "$(i18n cfg_admin_id)" "${CREATOR_ID:-($(i18n cfg_not_set))}"
        fi
        echo ""
    }

    # ── Edit a config item ────────────────────────────────────────────────

    _edit_item() {
        case "$1" in
        1)  # Run mode
            if $HAS_DOCKER; then
                c="$(ask_choice "$(i18n bot_run_mode)" "$( [[ "$BOT_RUN_MODE" == "docker" ]] && echo 1 || echo 2 )" \
                    "$(i18n bot_run_docker)" \
                    "$(i18n bot_run_host)")"
                [[ "$c" == "1" ]] && BOT_RUN_MODE="docker" || BOT_RUN_MODE="host"
            else
                warn "$(i18n cfg_no_docker)"
            fi
            ;;
        2)  # Bot name
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
        3)  # Platforms
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
                if $HAS_DOCKER; then
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
        4)  # LLM Base URL
            BASE_URL="$(ask "API Base URL" "$BASE_URL")"
            ;;
        5)  # LLM Model
            MODEL="$(ask "Model" "$MODEL")"
            ;;
        6)  # API Key
            API_KEY="$(ask "API Key" "$API_KEY")"
            ;;
        7)  # Access mode
            c="$(ask_choice "$(i18n access_prompt)" 1 \
                "$(i18n access_open)" "$(i18n access_approval)" "$(i18n access_private)")"
            case "$c" in 1) ACCESS_MODE="open" ;; 2) ACCESS_MODE="approval" ;; 3) ACCESS_MODE="private" ;; esac
            ;;
        8)  # Components (Memobase, Crawl4AI, RSSHub, Serper)
            comp_sel="$(ask_multi_select "$(i18n cfg_comp_select)" \
                "RSSHub (Docker):$( [[ "$RSSHUB_MODE" == "docker" ]] && echo 1 || echo 0 )" \
                "Memobase:$( [[ "$USE_MEMOBASE" == "true" ]] && echo 1 || echo 0 )" \
                "Crawl4AI:$( [[ "$USE_CRAWL4AI" == "true" ]] && echo 1 || echo 0 )" \
                "Serper (Google):$( [[ -n "$SERPER_KEY" ]] && echo 1 || echo 0 )")"

            # RSSHub
            if [[ " $comp_sel " == *" 1 "* ]]; then
                if $HAS_DOCKER; then
                    RSSHUB_MODE="docker"
                    [[ -z "$RSSHUB_PORT" ]] && RSSHUB_PORT="$(random_port)"
                    RSSHUB_URL="http://localhost:$RSSHUB_PORT"
                else
                    RSSHUB_MODE="custom"
                    RSSHUB_URL="$(ask "RSSHub URL" "$RSSHUB_URL")"
                fi
            else
                RSSHUB_MODE=""; RSSHUB_URL=""; RSSHUB_PORT=""
            fi

            # Memobase
            if [[ " $comp_sel " == *" 2 "* ]]; then
                USE_MEMOBASE=true
                if $HAS_DOCKER && [[ "$MEMOBASE_MODE" != "remote" ]]; then
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
                if $HAS_DOCKER && [[ "$CRAWL4AI_MODE" != "remote" ]]; then
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
        9)  # Admin ID
            if [[ "$MATRIX_ENABLED" == "true" ]]; then
                CREATOR_MX="$(ask "$(i18n creator_mx_prompt)" "")"
                [[ -n "$CREATOR_MX" ]] && CREATOR_ID="matrix:$CREATOR_MX" || CREATOR_ID=""
            elif [[ "$TG_ENABLED" == "true" ]]; then
                CREATOR_TG="$(ask "Your Telegram numeric user ID (admin, optional)" "")"
                [[ -n "$CREATOR_TG" ]] && CREATOR_ID="telegram:$CREATOR_TG" || CREATOR_ID=""
            fi
            ;;
        *)  warn "$(i18n cfg_invalid_num)" ;;
        esac
    }

    # ── Main config loop ──────────────────────────────────────────────────

    while true; do
        _show_config

        printf "  ${DIM}$(i18n cfg_hint)${NC}\n\n"
        printf "  > "
        read -r edit_nums </dev/tty 2>/dev/null || edit_nums=""

        # Enter with no input = confirm and proceed
        if [[ -z "$edit_nums" ]]; then
            # Validate critical fields
            if [[ "$MATRIX_ENABLED" != "true" ]] && [[ "$TG_ENABLED" != "true" ]] && \
               [[ "$FEISHU_ENABLED" != "true" ]] && [[ "$XMPP_ENABLED" != "true" ]]; then
                warn "$(i18n no_platform_warn)"
            fi
            echo ""
            if ask_yn "$(i18n cfg_confirm)"; then
                break
            fi
            continue
        fi

        for n in $edit_nums; do
            if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= 9 )); then
                _edit_item "$n"
            fi
        done
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
             API_KEY BASE_URL MODEL BOT_NAME ACCESS_MODE CREATOR_ID BOT_RUN_MODE; do
        save_var "$v" "${!v}"
    done
    mark_step 2
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 6: Install Python + Dependencies
# ═════════════════════════════════════════════════════════════════════════════

section 6 "$(i18n step6)"

if [[ "$BOT_RUN_MODE" == "docker" ]]; then
    # Docker mode: dependencies are installed inside the container image.
    ok "$(i18n deps_skip_docker)"
elif step_done 6; then
    ok "$(i18n already_done)"
else
    # Install Python if needed
    if [[ -z "$PYTHON" ]]; then
        warn "$(i18n python_not_found)"
        echo ""
        if [[ -z "$PKG_MGR" ]]; then
            die "$(i18n no_pkg_mgr)"
        fi

        if ask_yn "$(i18n install_python)"; then
            info "$(i18n installing_python)"
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
            die "$(i18n python_required)"
        fi
    fi

    # Create venv
    VENV_DIR="$BASE_DIR/.venv"
    if [[ -d "$VENV_DIR" ]] && "$VENV_DIR/bin/python" --version &>/dev/null; then
        ok "$(i18n venv_exists)"
    else
        info "$(i18n creating_venv)"
        "$PYTHON" -m venv "$VENV_DIR" || {
            warn "venv module missing. Installing..."
            case "$PKG_MGR" in
                apt) sudo apt-get install -y "$(basename "$PYTHON")-venv" || sudo apt-get install -y python3-venv ;;
                dnf) sudo dnf install -y python3-libs ;;
                *) die "Could not create venv. Install python3-venv for your system." ;;
            esac
            "$PYTHON" -m venv "$VENV_DIR"
        }
        ok "$(i18n venv_created)"
    fi

    PIP="$VENV_DIR/bin/pip"
    info "$(i18n installing_deps)"
    "$PIP" install --upgrade pip -q 2>/dev/null || true
    "$PIP" install -r "$BASE_DIR/requirements.txt" -q
    ok "$(i18n deps_installed)"

    mark_step 6
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 7: Generate Files
# ═════════════════════════════════════════════════════════════════════════════

section 7 "$(i18n step7)"

# Reload saved vars
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
ok "Bot config: $CONFIG_FILE"

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
ok "Secrets: $SECRETS_FILE (mode 600)"

# ── Prompts ──
if [[ ! -d "$BOT_DIR/prompts" ]]; then
    info "Scaffolding prompts..."
    mkdir -p "$BOT_DIR/prompts"

    # Copy default prompt templates
    if [[ -d "$BASE_DIR/prompts/default" ]]; then
        cp "$BASE_DIR/prompts/default"/*.md "$BOT_DIR/prompts/" 2>/dev/null || true
    fi

    # Write main prompt
    cat > "$BOT_DIR/prompts/main.md" <<'PROMPT'
You are a friendly AI assistant.

# Note
- This prompt is written in English as a default template
- Always reply in the language the user is using

# Personality
- Helpful and natural

# Response style
- No customer-service tone
- Direct answers, no unnecessary preamble
- Concise, natural, like instant messaging
PROMPT

    # Generate registry.yaml
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

# ── Memobase config.yaml (LLM settings for memobase server) ──
MEMOBASE_CONFIG="$BASE_DIR/memobase-config.yaml"
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
    ok "Memobase config: $MEMOBASE_CONFIG"
fi

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
    ok "Web panel credentials generated (port: $PANEL_PORT)"
else
    PANEL_USER="$(grep 'username:' "$PANEL_CONFIG" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/')"
    PANEL_PASS="$(grep 'password:' "$PANEL_CONFIG" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/')"
    PANEL_PORT="$(grep 'port:' "$PANEL_CONFIG" | head -1 | sed 's/.*: *//')"
    PANEL_PORT="${PANEL_PORT:-8080}"
fi

# Save panel port for service step
save_var PANEL_PORT "${PANEL_PORT:-8080}"

ok "$(i18n config_generated)"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 8: Deploy & Launch
# ═════════════════════════════════════════════════════════════════════════════

section 8 "$(i18n step8)"

# ── Deploy Docker services ──────────────────────────────────────────────────

COMPOSE_PROJECT="$(load_var COMPOSE_PROJECT "")"
BOT_RUN_MODE="$(load_var BOT_RUN_MODE "")"

DOCKER_PROFILES=()
[[ "$BOT_RUN_MODE" == "docker" ]] && DOCKER_PROFILES+=("bot")
[[ "$NEEDS_CONDUIT" == "true" ]] && DOCKER_PROFILES+=("matrix")
[[ "$USE_MEMOBASE" == "true" ]] && [[ "$MEMOBASE_MODE" == "docker" ]] && DOCKER_PROFILES+=("memobase")
[[ "$USE_CRAWL4AI" == "true" ]] && [[ "$CRAWL4AI_MODE" == "docker" ]] && DOCKER_PROFILES+=("crawl4ai")
[[ "$RSSHUB_MODE" == "docker" ]] && DOCKER_PROFILES+=("rsshub")

if (( ${#DOCKER_PROFILES[@]} > 0 )); then
    echo ""
    info "$(i18n deploying_services)"
    echo ""
    for p in "${DOCKER_PROFILES[@]}"; do
        printf "    - %s\n" "$p"
    done
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
        warn "Port conflict detected, switching Conduit to port $CONDUIT_PORT"
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
            info "Registering Matrix bot user: $MATRIX_USER_ID"
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
                ok "Matrix bot registered: $MATRIX_USER_ID"
            elif echo "$REG_RESULT" | grep -q "M_USER_IN_USE"; then
                # Already exists — login to get a fresh token
                LOGIN_RESULT="$(curl -sf -X POST "${CONDUIT_API}/_matrix/client/r0/login" \
                    -H "Content-Type: application/json" \
                    -d "{\"type\": \"m.login.password\", \"user\": \"${CONDUIT_BOT_USER}\", \"password\": \"${MATRIX_PASSWORD}\"}" 2>&1)" || true
                BOT_TOKEN="$(json_val "$LOGIN_RESULT" "access_token")" || true
                if [[ -n "$BOT_TOKEN" ]]; then
                    MATRIX_ACCESS_TOKEN="$BOT_TOKEN"
                    save_var MATRIX_ACCESS_TOKEN "$MATRIX_ACCESS_TOKEN"
                    ok "Matrix bot user already exists, logged in: $MATRIX_USER_ID"
                else
                    warn "Bot user exists but login failed (password mismatch?)"
                fi
            else
                warn "Failed to register Matrix bot user. Register manually:"
                echo "    curl -X POST ${CONDUIT_API}/_matrix/client/r0/register \\"
                echo "      -H 'Content-Type: application/json' \\"
                echo "      -d '{\"username\": \"${CONDUIT_BOT_USER}\", \"password\": \"${MATRIX_PASSWORD}\", \"auth\": {\"type\": \"m.login.dummy\"}}'"
            fi

            # ── 2. Register test/admin account ──
            CONDUIT_TEST_USER="${DEFAULT_CONDUIT_TEST_USER:-creator-$(random_chars 6)}"
            CONDUIT_TEST_PASSWORD="${DEFAULT_CONDUIT_TEST_PASSWORD:-$(random_chars 12)}"
            CONDUIT_TEST_USER_ID="@${CONDUIT_TEST_USER}:${CONDUIT_SERVER_NAME}"

            info "Registering test account: $CONDUIT_TEST_USER_ID"
            TEST_REG="$(curl -sf -X POST "${CONDUIT_API}/_matrix/client/r0/register" \
                -H "Content-Type: application/json" \
                -d "{\"username\": \"${CONDUIT_TEST_USER}\", \"password\": \"${CONDUIT_TEST_PASSWORD}\", \"auth\": {\"type\": \"m.login.dummy\"}}" 2>&1)" || true

            TEST_TOKEN=""
            if echo "$TEST_REG" | grep -q "access_token"; then
                TEST_TOKEN="$(json_val "$TEST_REG" "access_token")" || true
                save_var CONDUIT_TEST_USER "$CONDUIT_TEST_USER"
                save_var CONDUIT_TEST_PASSWORD "$CONDUIT_TEST_PASSWORD"
                save_var CONDUIT_TEST_USER_ID "$CONDUIT_TEST_USER_ID"
                ok "Test account registered: $CONDUIT_TEST_USER_ID"
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
                    ok "Test account already exists, logged in: $CONDUIT_TEST_USER_ID"
                else
                    warn "Test account exists but login failed (password mismatch?)"
                fi
            else
                warn "Failed to register test account"
            fi

            # ── 3. Create DM room between test user and bot ──
            if [[ -n "$TEST_TOKEN" ]] && [[ -n "$BOT_TOKEN" ]]; then
                info "Creating DM room between test account and bot..."
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
                    ok "DM room created — test account and bot are now friends"
                    save_var CONDUIT_TEST_ROOM_ID "$ROOM_ID"
                else
                    warn "Could not create DM room (you can message the bot manually from Element)"
                fi
            fi
        else
            warn "Conduit did not start in time. Register bot user manually after it starts."
        fi
    fi
else
    info "$(i18n no_services)"
fi

echo ""

# ── Launch options ──────────────────────────────────────────────────────────

RUN_NOW=false
STARTED_VIA_SERVICE=false

if [[ "$BOT_RUN_MODE" == "docker" ]]; then
    # ── Docker mode: bot is already running via docker compose ──
    # The bot container was started with --profile bot in the compose up above
    RUN_NOW=true
    STARTED_VIA_SERVICE=true
    ok "NaturalChat bot is running in Docker container"
    echo ""
    printf "  ${BOLD}$(i18n service_commands)${NC}\n"
    echo "    docker compose ${PROJECT_FLAG:-} -f $BASE_DIR/docker/docker-compose.yml logs -f bot   # View logs"
    echo "    docker compose ${PROJECT_FLAG:-} -f $BASE_DIR/docker/docker-compose.yml restart bot   # Restart"
    echo "    docker compose ${PROJECT_FLAG:-} -f $BASE_DIR/docker/docker-compose.yml stop bot      # Stop"
    echo "    docker compose ${PROJECT_FLAG:-} -f $BASE_DIR/docker/docker-compose.yml up -d bot     # Start"
    echo ""

else
    # ── Host mode: nohup / systemd / launchd ──
    wrap_print "$(i18n launch_intro_1)"
    wrap_print "$(i18n launch_intro_2)"
    echo ""

    if [[ "$OS" == "Linux" ]] && command -v systemctl &>/dev/null; then
        # ── systemd (Linux) ──
        if ask_yn "$(i18n direct_run_prompt)" "n"; then
            RUN_NOW=true
        fi

        echo ""
        if ask_yn "$(i18n systemd_prompt)" "n"; then
            SERVICE_NAME="naturalchat"
            SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
            RUN_USER="$(whoami)"
            VENV_PYTHON="$BASE_DIR/.venv/bin/python"

            # Docker pre-start commands (for companion services like conduit/memobase)
            PRE_START_CMDS=""
            if (( ${#DOCKER_PROFILES[@]} > 0 )); then
                PRE_START_CMDS="ExecStartPre=/usr/bin/docker compose ${PROJECT_FLAG:-} $PROFILE_FLAGS --env-file ${BASE_DIR}/.env -f ${BASE_DIR}/docker/docker-compose.yml up -d"
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

            if ask_yn "$(i18n start_service_now)" "n"; then
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
            printf "  ${BOLD}$(i18n service_commands)${NC}\n"
            echo "    sudo systemctl status $SERVICE_NAME    # Check status"
            echo "    sudo systemctl restart $SERVICE_NAME   # Restart"
            echo "    sudo systemctl stop $SERVICE_NAME      # Stop"
            echo "    journalctl -u $SERVICE_NAME -f          # View logs"
            echo ""
        fi

    elif [[ "$OS" == "Darwin" ]]; then
        # ── launchd (macOS) ──
        if ask_yn "$(i18n direct_run_prompt)" "n"; then
            RUN_NOW=true
        fi

        echo ""
        if ask_yn "$(i18n launchd_prompt)" "n"; then
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

            if ask_yn "$(i18n start_service_now)" "n"; then
                launchctl load "$PLIST_FILE" 2>/dev/null || true
                launchctl start "$PLIST_NAME" 2>/dev/null || true
                sleep 1
                ok "NaturalChat is starting..."
                STARTED_VIA_SERVICE=true
            fi

            echo ""
            printf "  ${BOLD}$(i18n service_commands)${NC}\n"
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
        if ask_yn "$(i18n direct_run_prompt)" "n"; then
            RUN_NOW=true
        fi

        echo ""
        info "$(i18n no_service_manager)"
        echo "    cd $BASE_DIR && .venv/bin/python main.py"
        echo ""
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# Summary & Next Steps
# ═════════════════════════════════════════════════════════════════════════════

echo ""
printf "${BOLD}╔══════════════════════════════════════════╗${NC}\n"
printf "${BOLD}║        $(i18n setup_complete)                  ║${NC}\n"
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
[[ "$USE_CRAWL4AI" == "true" ]] && printf "  Crawl4AI:   enabled ($CRAWL4AI_URL)\n"
[[ "$RSSHUB_MODE" == "docker" ]] && printf "  RSSHub:     enabled (Docker, $RSSHUB_URL)\n"
echo ""

# ── Web Panel (always shown) ──
printf "${BOLD}  $(i18n web_panel)${NC}\n"
echo "    URL:      http://localhost:${PANEL_PORT}"
echo "    Username: $PANEL_USER"
echo "    Password: $PANEL_PASS"
echo "    (credentials saved in $PANEL_CONFIG)"
echo ""

# ── Matrix test account (if Conduit deployed) ──
CONDUIT_TEST_USER="$(load_var CONDUIT_TEST_USER "")"
CONDUIT_TEST_PASSWORD="$(load_var CONDUIT_TEST_PASSWORD "")"
CONDUIT_TEST_USER_ID="$(load_var CONDUIT_TEST_USER_ID "")"
if [[ -n "$CONDUIT_TEST_USER" ]] && [[ -n "$CONDUIT_TEST_PASSWORD" ]]; then
    printf "${BOLD}  Matrix (Conduit)${NC}\n"
    echo "    Homeserver: http://127.0.0.1:${CONDUIT_PORT}"
    echo "    Bot:        $MATRIX_USER_ID"
    echo ""
    printf "    ${GREEN}Test account (use in Element):${NC}\n"
    echo "    User:     $CONDUIT_TEST_USER_ID"
    echo "    Password: $CONDUIT_TEST_PASSWORD"
    echo ""
    echo "    Element login: Homeserver → http://127.0.0.1:${CONDUIT_PORT}"
    echo "                   Username   → $CONDUIT_TEST_USER"
    echo "                   Password   → $CONDUIT_TEST_PASSWORD"
    echo ""
fi

# ── Missing credentials warning ──
MISSING=()
[[ -z "$API_KEY" ]] && MISSING+=("LLM API key")
[[ "$TG_ENABLED" == "true" ]] && [[ -z "$TG_TOKEN" ]] && MISSING+=("Telegram token")

if (( ${#MISSING[@]} > 0 )); then
    printf "${YELLOW}  $(i18n missing_creds_warn)${NC}\n"
    echo "    Edit: $SECRETS_FILE"
    for m in "${MISSING[@]}"; do
        echo "    - $m"
    done
    echo ""
fi

# ── Key files ──
printf "${BOLD}  $(i18n key_files)${NC}\n"
echo "    Config:   $CONFIG_FILE"
echo "    Secrets:  $SECRETS_FILE"
echo "    Prompts:  $BOT_DIR/prompts/main.md"
echo ""

# ── Run manually ──
printf "${BOLD}  $(i18n run_manually)${NC}\n"
if [[ "$BOT_RUN_MODE" == "docker" ]]; then
    echo "    cd $BASE_DIR"
    echo "    docker compose ${PROJECT_FLAG:-} --profile bot -f docker/docker-compose.yml up -d --build   # Start"
    echo "    docker compose ${PROJECT_FLAG:-} -f docker/docker-compose.yml logs -f bot                   # View logs"
    echo "    docker compose ${PROJECT_FLAG:-} -f docker/docker-compose.yml restart bot                   # Restart"
    echo "    docker compose ${PROJECT_FLAG:-} -f docker/docker-compose.yml stop bot                      # Stop"
else
    echo "    cd $BASE_DIR"
    echo "    nohup .venv/bin/python main.py >> logs/naturalchat.log 2>&1 &"
    echo "    tail -f logs/naturalchat.log    # $(i18n view_logs)"
fi
echo ""

# ── Manage bots ──
printf "${BOLD}  $(i18n manage_bots)${NC}\n"
if [[ "$BOT_RUN_MODE" == "docker" ]]; then
    echo "    docker compose ${PROJECT_FLAG:-} -f $BASE_DIR/docker/docker-compose.yml exec bot python manage.py list | add | remove | export"
else
    echo "    .venv/bin/python manage.py list | add | remove | export"
fi
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

# ═════════════════════════════════════════════════════════════════════════════
# What's Next
# ═════════════════════════════════════════════════════════════════════════════

echo ""
printf "${BOLD}╭──────────────────────────────────────────╮${NC}\n"
printf "${BOLD}│  $(i18n next_steps_title)                              │${NC}\n"
printf "${BOLD}╰──────────────────────────────────────────╯${NC}\n"
echo ""

STEP_NUM=1

if (( ${#MISSING[@]} > 0 )); then
    printf "  ${BOLD}${STEP_NUM}.${NC} $(i18n next_step_secrets)\n"
    printf "     ${DIM}vim $SECRETS_FILE${NC}\n"
    echo ""
    ((STEP_NUM++))
fi

printf "  ${BOLD}${STEP_NUM}.${NC} $(i18n next_step_prompt)\n"
printf "     ${DIM}vim $BOT_DIR/prompts/main.md${NC}\n"
echo ""
((STEP_NUM++))

if [[ "$BOT_RUN_MODE" == "docker" ]]; then
    printf "  ${BOLD}${STEP_NUM}.${NC} $(i18n next_step_run)\n"
    printf "     ${DIM}docker compose ${PROJECT_FLAG:-} -f $BASE_DIR/docker/docker-compose.yml logs -f bot${NC}\n"
    printf "     ${DIM}-> http://127.0.0.1:${PANEL_PORT}${NC}\n"
    echo ""
    ((STEP_NUM++))
elif [[ "$RUN_NOW" != "true" ]] && [[ "$STARTED_VIA_SERVICE" != "true" ]]; then
    printf "  ${BOLD}${STEP_NUM}.${NC} $(i18n next_step_run)\n"
    printf "     ${DIM}cd $BASE_DIR && nohup .venv/bin/python main.py >> logs/naturalchat.log 2>&1 &${NC}\n"
    printf "     ${DIM}tail -f logs/naturalchat.log${NC}\n"
    printf "     ${DIM}-> http://127.0.0.1:${PANEL_PORT}${NC}\n"
    echo ""
    ((STEP_NUM++))
else
    printf "  ${BOLD}${STEP_NUM}.${NC} $(i18n next_step_run)\n"
    printf "     ${DIM}tail -f $BASE_DIR/logs/naturalchat.log${NC}\n"
    printf "     ${DIM}-> http://127.0.0.1:${PANEL_PORT}${NC}\n"
    echo ""
    ((STEP_NUM++))
fi

printf "  ${BOLD}${STEP_NUM}.${NC} $(i18n next_step_add_bot)\n"
echo ""
((STEP_NUM++))

printf "  ${BOLD}${STEP_NUM}.${NC} $(i18n next_step_docs)\n"
echo ""

echo ""

if [[ "$RUN_NOW" == "true" ]]; then
    if [[ "$BOT_RUN_MODE" == "docker" ]]; then
        # Bot is already running in Docker container — just show how to view logs
        ok "NaturalChat is running in Docker"
        echo ""
        printf "  ${BOLD}$(i18n view_logs):${NC}\n"
        printf "    ${DIM}docker compose ${PROJECT_FLAG:-} -f $BASE_DIR/docker/docker-compose.yml logs -f bot${NC}\n"
        echo ""
        printf "  ${BOLD}$(i18n stop_bot):${NC}\n"
        printf "    ${DIM}docker compose ${PROJECT_FLAG:-} -f $BASE_DIR/docker/docker-compose.yml stop bot${NC}\n"
        echo ""
    elif [[ "$STARTED_VIA_SERVICE" == "true" ]]; then
        info "$(i18n skip_direct_run)"
    else
        LOG_DIR="$BASE_DIR/logs"
        mkdir -p "$LOG_DIR"
        LOG_FILE="$LOG_DIR/naturalchat.log"

        info "$(i18n start_direct_run)"
        nohup "$BASE_DIR/.venv/bin/python" "$BASE_DIR/main.py" >> "$LOG_FILE" 2>&1 &
        BOT_PID=$!
        echo "$BOT_PID" > "$BASE_DIR/.naturalchat.pid"
        ok "NaturalChat running (PID: $BOT_PID)"
        echo ""
        printf "  ${BOLD}$(i18n view_logs):${NC}\n"
        printf "    ${DIM}tail -f $LOG_FILE${NC}\n"
        echo ""
        printf "  ${BOLD}$(i18n stop_bot):${NC}\n"
        printf "    ${DIM}kill \$(cat $BASE_DIR/.naturalchat.pid)${NC}\n"
        echo ""
    fi
fi

# Clean up install state
rm -rf "$STATE_DIR"
