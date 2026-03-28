#!/usr/bin/env python3
"""
install.py - NaturalChat4 交互式安装向导

无额外依赖，仅使用 Python 标准库。
引导用户选择平台、配置凭据、安装依赖。
"""

import json
from src.prompt_store import scaffold_prompt_bundle
import os
import platform
import secrets
import shutil
import subprocess
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BOTS_DIR = os.path.join(BASE_DIR, "bots")

# ── 环境检测 ──────────────────────────────────────────────────────────────

_OS = platform.system()


def _check_cmd(cmd, args=None):
    """Check if a command is available."""
    if not shutil.which(cmd):
        return False
    if args:
        try:
            result = subprocess.run(
                [cmd] + args, capture_output=True, timeout=10
            )
            return result.returncode == 0
        except (subprocess.TimeoutExpired, OSError):
            return False
    return True


def _detect_environment():
    """Detect available tools."""
    env = {
        "os": _OS,
        "python": sys.version.split()[0],
        "docker": _check_cmd("docker", ["info"]),
        "bwrap": _OS == "Linux" and _check_cmd("bwrap"),
        "wsl": _OS == "Windows" and _check_cmd("wsl", ["--status"]),
    }
    return env


# ── 输入工具 ──────────────────────────────────────────────────────────────

def ask(prompt, default=""):
    """Ask user for input with optional default."""
    if default:
        result = input(f"{prompt} (默认: {default}): ").strip()
        return result if result else default
    return input(f"{prompt}: ").strip()


def ask_choice(prompt, options, default=1):
    """Ask user to choose from numbered options."""
    print(f"\n{prompt}")
    for i, (key, desc) in enumerate(options, 1):
        marker = " (推荐)" if i == default else ""
        print(f"  [{i}] {desc}{marker}")
    choice = input(f"\n你的选择 (默认: {default}): ").strip()
    if not choice:
        return options[default - 1][0]
    try:
        idx = int(choice) - 1
        if 0 <= idx < len(options):
            return options[idx][0]
    except ValueError:
        pass
    return options[default - 1][0]


def ask_multi(prompt, options, default="1"):
    """Ask user to choose multiple options (space-separated numbers)."""
    print(f"\n{prompt}")
    for i, (key, desc) in enumerate(options, 1):
        print(f"  [{i}] {desc}")
    choice = input(f"\n你的选择（用空格分隔，默认: {default}）: ").strip()
    if not choice:
        choice = default

    selected = []
    for num in choice.split():
        try:
            idx = int(num) - 1
            if 0 <= idx < len(options):
                selected.append(options[idx][0])
        except ValueError:
            pass
    return selected if selected else [options[0][0]]


def ask_yn(prompt, default=True):
    """Ask yes/no question."""
    suffix = "(Y/n)" if default else "(y/N)"
    result = input(f"{prompt} {suffix}: ").strip().lower()
    if not result:
        return default
    return result in ("y", "yes", "是")


# ── 平台配置收集 ──────────────────────────────────────────────────────────

def collect_telegram():
    """Collect Telegram Bot config."""
    print("\n" + "=" * 50)
    print("  Telegram Bot 配置")
    print("=" * 50)
    print("""
  获取 Bot Token 步骤：
  1. 打开 Telegram，搜索 @BotFather
  2. 发送 /newbot
  3. 按提示设置 bot 的名称和用户名
  4. 复制返回的 Token
""")
    token = ask("请输入 Bot Token")
    if not token:
        print("  跳过 Telegram（未提供 Token）")
        return None
    return {"enabled": True}, {"enabled": True, "token": token}


def collect_matrix(env):
    """Collect Matrix config."""
    print("\n" + "=" * 50)
    print("  Matrix 配置")
    print("=" * 50)

    use_conduit = False
    if env["docker"]:
        choice = ask_choice("Matrix 服务器选择：", [
            ("conduit", "用 Docker 部署 Conduit（推荐新手，轻量级）"),
            ("existing", "连接已有的 Matrix 服务器"),
        ])
        use_conduit = choice == "conduit"
    else:
        print("  未检测到 Docker，需要连接已有 Matrix 服务器")

    if use_conduit:
        server_name = ask("服务器域名", "localhost")
        username = ask("Bot 用户名", "bot")
        password = secrets.token_urlsafe(16)
        print(f"\n  将使用 Conduit，启动后需要注册账号：")
        print(f"  用户名: @{username}:{server_name}")
        print(f"  密码: {password}")
        print(f"  启动命令: docker compose --profile matrix up -d")
        return {
            "enabled": True,
            "homeserver_url": f"http://localhost:6167",
            "user_id": f"@{username}:{server_name}",
        }, {
            "enabled": True,
            "password": password,
        }, True  # needs_conduit=True
    else:
        homeserver = ask("Homeserver URL", "https://matrix.org")
        user_id = ask("Bot User ID（如 @mybot:matrix.org）")
        auth_method = ask_choice("认证方式：", [
            ("token", "Access Token"),
            ("password", "密码"),
        ])
        config = {
            "enabled": True,
            "homeserver_url": homeserver,
            "user_id": user_id,
        }
        secret_config = {"enabled": True}
        if auth_method == "token":
            secret_config["access_token"] = ask("Access Token")
        else:
            secret_config["password"] = ask("密码")
        return config, secret_config, False


def collect_feishu():
    """Collect Feishu config."""
    print("\n" + "=" * 50)
    print("  飞书配置")
    print("=" * 50)
    print("""
  步骤：
  1. 在 open.feishu.cn 创建企业自建应用
  2. 获取 App ID 和 App Secret
  3. 在"事件订阅"中配置回调地址
""")
    app_id = ask("App ID")
    if not app_id:
        print("  跳过飞书（未提供 App ID）")
        return None
    app_secret = ask("App Secret")
    port = ask("Webhook 端口", "9000")
    return {
        "enabled": True,
        "app_id": app_id,
        "webhook_port": int(port),
    }, {
        "enabled": True,
        "app_secret": app_secret,
    }


def collect_xmpp():
    """Collect XMPP config."""
    print("\n" + "=" * 50)
    print("  XMPP 配置")
    print("=" * 50)
    jid = ask("JID（如 bot@your-server.com）")
    if not jid:
        print("  跳过 XMPP（未提供 JID）")
        return None
    password = ask("密码")
    host = ask("XMPP 服务器地址", "localhost")
    port = ask("XMPP 端口", "5222")
    return {
        "enabled": True,
        "jid": jid,
        "xmpp_host": host,
        "xmpp_port": int(port),
    }, {
        "enabled": True,
        "password": password,
    }


# ── 主流程 ────────────────────────────────────────────────────────────────

def main():
    print("""
╔══════════════════════════════════════════╗
║     NaturalChat4 安装向导               ║
╚══════════════════════════════════════════╝
""")

    # Detect environment
    env = _detect_environment()
    print(f"系统: {env['os']} | Python: {env['python']}")
    print(f"Docker: {'可用' if env['docker'] else '未检测到'}", end="")
    if env["bwrap"]:
        print(" | Bubblewrap: 可用", end="")
    if env["wsl"]:
        print(" | WSL2: 可用", end="")
    print()

    # ── 1. 选择平台 ──
    platforms = ask_multi("请选择要接入的平台（可多选，用空格分隔）：", [
        ("telegram", "Telegram Bot（推荐，最简单）"),
        ("matrix", "Matrix"),
        ("feishu", "飞书"),
        ("xmpp", "XMPP"),
    ])

    # ── 2. 收集平台凭据 ──
    transports = {}
    secret_transports = {}
    needs_conduit = False

    for p in platforms:
        if p == "telegram":
            result = collect_telegram()
            if result:
                cfg, secret_cfg = result
                transports["telegram"] = cfg
                secret_transports["telegram"] = secret_cfg
        elif p == "matrix":
            result = collect_matrix(env)
            if result:
                cfg, secret_cfg, needs_conduit = result
                transports["matrix"] = cfg
                secret_transports["matrix"] = secret_cfg
        elif p == "feishu":
            result = collect_feishu()
            if result:
                cfg, secret_cfg = result
                transports["feishu"] = cfg
                secret_transports["feishu"] = secret_cfg
        elif p == "xmpp":
            result = collect_xmpp()
            if result:
                cfg, secret_cfg = result
                transports["xmpp"] = cfg
                secret_transports["xmpp"] = secret_cfg

    if not transports:
        print("\n未配置任何平台，退出。")
        sys.exit(1)

    # ── 3. LLM 配置 ──
    print("\n" + "=" * 50)
    print("  LLM 配置")
    print("=" * 50)
    api_key = ask("API Key")
    base_url = ask("API Base URL", "https://api.openai.com/v1")
    model = ask("模型名称", "gpt-4o-mini")

    # ── 4. 访问模式 ──
    access_mode = ask_choice("访问控制模式：", [
        ("open", "开放 — 任何人都能聊天"),
        ("approval", "审批 — 新联系人需管理员同意"),
        ("private", "私有 — 仅管理员和 creator 可聊天"),
    ])

    # ── 5. 机器人名称 ──
    print("\n" + "=" * 50)
    print("  机器人设置")
    print("=" * 50)
    bot_name = ask("机器人名称（将作为目录名）", "mybot")

    # Creator ID (for governance)
    creator_id = ""
    if "telegram" in transports:
        creator_id = ask("你的 Telegram 用户 ID（数字，用于管理员权限，可留空后续设置）", "")
        if creator_id:
            creator_id = f"telegram:{creator_id}"
    elif "matrix" in transports:
        creator_id = ask("你的 Matrix 用户 ID（如 @you:matrix.org，可留空）", "")
        if creator_id:
            creator_id = f"matrix:{creator_id}"

    use_default_prompt = ask_yn("使用默认 prompt（可以之后再修改）？")

    # ── 6. Memobase ──
    use_memobase = False
    if env["docker"]:
        use_memobase = ask_yn("启用 Memobase 记忆系统？（需要 Docker）", False)

    # ── 7. 生成文件 ──
    print("\n" + "=" * 50)
    print("  生成配置文件...")
    print("=" * 50)

    # Global config
    global_config_path = os.path.join(BASE_DIR, "config.yaml")
    if not os.path.isfile(global_config_path):
        _write_yaml(global_config_path, {
            "env": {"SERPER_API_KEY": ""},
            "rsshub_server": "https://rsshub.app",
        })
        print(f"  创建 {global_config_path}")

    # Bot directory
    bot_dir = os.path.join(BOTS_DIR, bot_name)
    os.makedirs(bot_dir, exist_ok=True)
    os.makedirs(os.path.join(bot_dir, "skills"), exist_ok=True)
    os.makedirs(os.path.join(bot_dir, "bot_data"), exist_ok=True)

    # Bot config
    bot_config = {
        "transports": transports,
        "msg_wait_initial": 2.5,
        "msg_wait_after_typing": 3.0,
        "reflection_delay": 30,
        "llm": {
            "base_url": base_url,
            "model": model,
            "max_history_tokens": 4000,
        },
        "token_budget": {"default_score": 50},
    }
    secrets_config = {
        "transports": secret_transports,
        "llm": {"api_key": api_key},
    }

    config_path = os.path.join(bot_dir, "config.yaml")
    _write_yaml(config_path, bot_config)
    print(f"  创建 {config_path}")
    secrets_path = os.path.join(bot_dir, "secrets.yaml")
    _write_yaml(secrets_path, _prune_empty(secrets_config))
    print(f"  创建 {secrets_path}")

    prompt_text = ""
    if use_default_prompt:
        prompt_text = (
            "你是一个友好的 AI 助手。\n\n"
            "# 设定说明\n"
            "- 本提示词使用中文书写，只是因为开发者使用中文维护配置\n"
            "- 提示词是给开发者和模型看的，不代表用户语言\n"
            "- 你回复时必须使用用户正在使用的语言；只有在无法判断时再自行选择默认语言\n\n"
            "# 角色设定\n"
            "- 你乐于助人，回复自然\n\n"
            "# 回复风格\n"
            "- 不要客服腔\n"
            "- 直接回答，不要没必要的铺垫\n"
            "- 简洁、自然、像即时聊天\n"
        )
    prompts_dir = scaffold_prompt_bundle(bot_dir, main_prompt=prompt_text)
    print(f"  创建 {prompts_dir}")

    # Bot meta
    meta_path = os.path.join(bot_dir, "bot_data", "bot_meta.json")
    meta = {
        "access_mode": access_mode,
        "creator_jid": creator_id,
        "admins": [],
        "blacklist": [],
        "approved_contacts": [],
    }
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    print(f"  创建 {meta_path}")

    # .env file
    env_path = os.path.join(BASE_DIR, ".env")
    if not os.path.isfile(env_path):
        with open(env_path, "w") as f:
            f.write("# NaturalChat4 环境变量\n")
            if use_memobase:
                f.write("MEMOBASE_DB_PASSWORD=memobase\n")
        print(f"  创建 {env_path}")

    # ── 8. 安装依赖 ──
    print("\n" + "=" * 50)
    print("  安装 Python 依赖...")
    print("=" * 50)

    pip_cmd = [sys.executable, "-m", "pip", "install", "-r", "requirements.txt"]
    try:
        subprocess.run(pip_cmd, check=True)
        print("  依赖安装完成")
    except subprocess.CalledProcessError:
        print(f"  依赖安装失败，请手动运行: {' '.join(pip_cmd)}")

    # ── 9. 沙箱检测 ──
    print("\n" + "=" * 50)
    print("  沙箱检测")
    print("=" * 50)

    if env["docker"]:
        print("  Docker 可用 — 代码执行将使用 Docker 沙箱（最佳隔离）")
    elif env["bwrap"]:
        print("  bubblewrap 可用 — 代码执行将使用 bwrap 沙箱")
    elif _OS == "Darwin":
        print("  macOS — 代码执行将使用 sandbox-exec 沙箱")
    elif env["wsl"]:
        print("  WSL2 可用 — 代码执行将在 WSL 内运行")
    else:
        print("  未检测到沙箱工具 — 代码执行无隔离保护")
        print("  建议安装 Docker 以获得最佳安全性")

    # ── 10. 完成 ──
    print("\n" + "=" * 50)
    print("  安装完成！")
    print("=" * 50)

    startup_cmds = []

    if needs_conduit:
        startup_cmds.append("docker compose --profile matrix up -d")
        print(f"\n  Matrix (Conduit): 先启动 Conduit：")
        print(f"    docker compose --profile matrix up -d")

    if use_memobase:
        startup_cmds.append("docker compose --profile memobase up -d")
        print(f"\n  Memobase: 先启动记忆系统：")
        print(f"    docker compose --profile memobase up -d")

    print(f"\n  启动机器人：")
    print(f"    python main.py")

    print(f"\n  配置文件：")
    print(f"    机器人配置: {config_path}")
    print(f"    敏感配置: {secrets_path}")
    print(f"    Prompt 目录: {prompts_dir}")

    print(f"\n  修改 Prompt 来定制机器人的人设和行为。")
    print()


def _write_yaml(path, data):
    """Write YAML without importing pyyaml (may not be installed yet)."""
    try:
        import yaml
        with open(path, "w", encoding="utf-8") as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
    except ImportError:
        # Fallback: write simple YAML manually
        with open(path, "w", encoding="utf-8") as f:
            _simple_yaml_dump(f, data)


def _simple_yaml_dump(f, data, indent=0):
    """Minimal YAML writer for when pyyaml isn't installed."""
    prefix = "  " * indent
    if isinstance(data, dict):
        for key, val in data.items():
            if isinstance(val, (dict, list)):
                f.write(f"{prefix}{key}:\n")
                _simple_yaml_dump(f, val, indent + 1)
            elif isinstance(val, bool):
                f.write(f"{prefix}{key}: {'true' if val else 'false'}\n")
            elif isinstance(val, (int, float)):
                f.write(f"{prefix}{key}: {val}\n")
            elif isinstance(val, str):
                if val and any(c in val for c in ":{}[]#&*!|>'\"%@`"):
                    f.write(f'{prefix}{key}: "{val}"\n')
                else:
                    f.write(f'{prefix}{key}: "{val}"\n')
            else:
                f.write(f"{prefix}{key}: {val}\n")
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                f.write(f"{prefix}-\n")
                _simple_yaml_dump(f, item, indent + 1)
            else:
                f.write(f"{prefix}- {item}\n")


def _prune_empty(value):
    if isinstance(value, dict):
        result = {}
        for key, item in value.items():
            pruned = _prune_empty(item)
            if pruned in ({}, [], "", None):
                continue
            result[key] = pruned
        return result
    if isinstance(value, list):
        return [_prune_empty(item) for item in value]
    return value


if __name__ == "__main__":
    main()
