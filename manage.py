#!/usr/bin/env python3
"""
manage.py - CLI tool for managing bots.

Usage:
  python manage.py add <name> [--jid <jid>] [--password <pass>] [--telegram-token <token>]
  python manage.py remove <name>
  python manage.py list
  python manage.py export <name> [--output <path>]
  python manage.py import <package> <name> [--jid <jid>] [--password <pass>] [--api-key <key>]
"""

import os
import sys
import argparse
import subprocess
import shutil
import yaml
from src.prompt_store import scaffold_prompt_bundle, bot_prompts_dir
from src.config_validation import deep_merge, validate_bot_config

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BOTS_DIR = os.path.join(BASE_DIR, "bots")

DEFAULT_CONFIG = {
    "reflection_delay": 30,
    "msg_wait_initial": 2.5,
    "msg_wait_after_typing_stop": 5.0,
    "typing_hard_timeout": 10.0,
    "llm": {
        "base_url": "https://openrouter.ai/api/v1",
        "model": "openrouter/auto",
        "max_history_tokens": 4000,
    },
    "token_budget": {
        "default_score": 50,
    },
    "transports": {
        "telegram": {
            "enabled": True,
        },
    },
}

DEFAULT_PROMPT = """你是一个友好的 AI 助手。

# 设定说明
- 本提示词使用中文书写，只是因为开发者使用中文维护配置
- 提示词是给开发者和模型看的，不代表用户语言
- 你回复时必须使用用户正在使用的语言；只有在无法判断时再自行选择默认语言

# 角色设定
- 你乐于助人，回复自然

# 回复风格
- 不要客服腔
- 直接回答，不要没必要的铺垫
- 简洁、自然、像即时聊天
"""


def add_bot(name: str, jid: str = None, password: str = None, telegram_token: str = None,
            feishu_app_id: str = None, feishu_app_secret: str = None):
    """Add a new bot."""
    bot_dir = os.path.join(BOTS_DIR, name)

    if os.path.exists(bot_dir):
        print(f"错误: 机器人 '{name}' 已存在!")
        sys.exit(1)

    # Generate defaults
    if jid and not password:
        import secrets
        password = secrets.token_urlsafe(12)

    # Create directory structure
    os.makedirs(bot_dir, exist_ok=True)
    os.makedirs(os.path.join(bot_dir, "skills"), exist_ok=True)

    # Write config
    config = yaml.safe_load(yaml.dump(DEFAULT_CONFIG))
    secrets_config = {"llm": {}, "transports": {}}

    if jid:
        config["transports"]["xmpp"] = {
            "enabled": True,
            "jid": jid,
            "xmpp_host": "localhost",
            "xmpp_port": 5222,
        }
        secrets_config["transports"]["xmpp"] = {"enabled": True, "password": password}

    if telegram_token:
        secrets_config["transports"]["telegram"] = {"enabled": True, "token": telegram_token}

    if feishu_app_id and feishu_app_secret:
        config["transports"]["feishu"] = {
            "enabled": True,
            "app_id": feishu_app_id,
            "webhook_port": 9000,
        }
        secrets_config["transports"]["feishu"] = {"enabled": True, "app_secret": feishu_app_secret}

    validate_bot_config(deep_merge(config, secrets_config), context=f"generated bot config for {name}")

    config_path = os.path.join(bot_dir, "config.yaml")
    with open(config_path, "w", encoding="utf-8") as f:
        yaml.dump(config, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
    secrets_path = os.path.join(bot_dir, "secrets.yaml")
    with open(secrets_path, "w", encoding="utf-8") as f:
        yaml.dump(_prune_empty(secrets_config), f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    prompts_dir = scaffold_prompt_bundle(bot_dir, main_prompt=DEFAULT_PROMPT)

    print(f"✅ 创建机器人 '{name}'")
    print(f"   目录: {bot_dir}")
    print(f"   配置: {config_path}")
    print(f"   敏感配置: {secrets_path}")
    print(f"   Prompt 目录: {prompts_dir}")

    # Register on Prosody
    if jid:
        domain = jid.split("@")[1] if "@" in jid else "localhost"
        username = jid.split("@")[0] if "@" in jid else name
        print(f"\n📡 正在 Prosody 注册账号 {username}@{domain}...")
        try:
            result = subprocess.run(
                ["prosodyctl", "register", username, domain, password],
                capture_output=True, text=True,
            )
            if result.returncode == 0:
                print(f"   ✅ Prosody 注册成功!")
            else:
                stderr = result.stderr.strip()
                if "already" in stderr.lower():
                    print(f"   ⚠️  账号已存在于 Prosody")
                else:
                    print(f"   ⚠️  Prosody 注册失败: {stderr}")
                    print(f"   手动注册: prosodyctl register {username} {domain} {password}")
        except FileNotFoundError:
            print(f"   ⚠️  找不到 prosodyctl，请手动注册:")
            print(f"   prosodyctl register {username} {domain} {password}")

    print(f"\n📝 编辑 prompt 目录: {prompts_dir}")
    print(f"⚙️  编辑配置: {config_path}")
    print(f"🔐 编辑敏感配置: {secrets_path}")


def remove_bot(name: str):
    """Remove a bot."""
    bot_dir = os.path.join(BOTS_DIR, name)

    if not os.path.exists(bot_dir):
        print(f"错误: 机器人 '{name}' 不存在!")
        sys.exit(1)

    # Load config to get JID
    config_path = os.path.join(bot_dir, "config.yaml")
    jid = None
    if os.path.isfile(config_path):
        with open(config_path, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f) or {}
            jid = config.get("transports", {}).get("xmpp", {}).get("jid", "")

    # Confirm
    confirm = input(f"确定要删除机器人 '{name}'? (y/N): ")
    if confirm.lower() != "y":
        print("取消。")
        return

    # Remove from Prosody
    if jid:
        domain = jid.split("@")[1] if "@" in jid else "localhost"
        username = jid.split("@")[0] if "@" in jid else name
        try:
            result = subprocess.run(
                ["prosodyctl", "deluser", f"{username}@{domain}"],
                capture_output=True, text=True,
            )
            if result.returncode == 0:
                print(f"✅ 已从 Prosody 删除 {username}@{domain}")
            else:
                print(f"⚠️  Prosody 删除失败: {result.stderr.strip()}")
        except FileNotFoundError:
            print(f"⚠️  找不到 prosodyctl，请手动删除: prosodyctl deluser {username}@{domain}")

    # Remove directory
    shutil.rmtree(bot_dir)
    print(f"✅ 已删除机器人 '{name}' 的目录: {bot_dir}")


def list_bots():
    """List all bots."""
    if not os.path.isdir(BOTS_DIR):
        print("没有发现任何机器人。使用 'python manage.py add <name>' 创建。")
        return

    bots = []
    for name in sorted(os.listdir(BOTS_DIR)):
        bot_dir = os.path.join(BOTS_DIR, name)
        if not os.path.isdir(bot_dir):
            continue

        config_path = os.path.join(bot_dir, "config.yaml")
        jid = "N/A"
        model = "N/A"
        if os.path.isfile(config_path):
            with open(config_path, "r", encoding="utf-8") as f:
                config = yaml.safe_load(f) or {}
                jid = config.get("transports", {}).get("xmpp", {}).get("jid", "N/A")
                model = config.get("llm", {}).get("model", "N/A")

        # Count skills
        skills_dir = os.path.join(bot_dir, "skills")
        skill_count = 0
        if os.path.isdir(skills_dir):
            for item in os.listdir(skills_dir):
                item_path = os.path.join(skills_dir, item)
                if os.path.isfile(item_path) and item.endswith(".py"):
                    skill_count += 1
                elif os.path.isdir(item_path) and os.path.isfile(os.path.join(item_path, "SKILL.md")):
                    skill_count += 1

        # Prompt size
        prompt_path = bot_prompts_dir(bot_dir)
        prompt_size = "N/A"
        if os.path.isdir(prompt_path):
            size = 0
            for root, _, files in os.walk(prompt_path):
                for filename in files:
                    size += os.path.getsize(os.path.join(root, filename))
            if size > 1024:
                prompt_size = f"{size / 1024:.1f} KB"
            else:
                prompt_size = f"{size} B"

        bots.append({
            "name": name,
            "jid": jid,
            "model": model,
            "skills": skill_count,
            "prompt_size": prompt_size,
        })

    if not bots:
        print("没有发现任何机器人。使用 'python manage.py add <name>' 创建。")
        return

    print(f"{'名称':<12} {'JID':<25} {'模型':<20} {'技能数':<8} {'Prompt 大小':<12}")
    print("-" * 77)
    for b in bots:
        print(f"{b['name']:<12} {b['jid']:<25} {b['model']:<20} {b['skills']:<8} {b['prompt_size']:<12}")
    print(f"\n共 {len(bots)} 个机器人")


def export_bot_cmd(name: str, output: str = None):
    """Export a bot as a shareable package."""
    bot_dir = os.path.join(BOTS_DIR, name)
    if not os.path.isdir(bot_dir):
        print(f"错误: 机器人 '{name}' 不存在!")
        sys.exit(1)

    from src.bot_packager import export_bot
    common_skills_dir = os.path.join(BASE_DIR, "common_skills")
    result = export_bot(bot_dir, output_path=output, common_skills_dir=common_skills_dir)
    print(f"已导出: {result}")


def import_bot_cmd(package: str, name: str, jid: str = None, password: str = None,
                   api_key: str = None, telegram_token: str = None):
    """Import a bot from a package."""
    if not os.path.isfile(package):
        print(f"错误: 包文件 '{package}' 不存在!")
        sys.exit(1)

    from src.bot_packager import import_bot

    overrides = {}
    if jid:
        overrides.setdefault("transports", {}).setdefault("xmpp", {})["jid"] = jid
        overrides["transports"]["xmpp"]["enabled"] = True
    if password:
        overrides.setdefault("transports", {}).setdefault("xmpp", {})["password"] = password
    if api_key:
        overrides.setdefault("llm", {})["api_key"] = api_key
    if telegram_token:
        overrides.setdefault("transports", {}).setdefault("telegram", {})["token"] = telegram_token
        overrides["transports"]["telegram"]["enabled"] = True

    result = import_bot(package, BOTS_DIR, name, overrides=overrides if overrides else None)
    print(f"已导入: {result}")

    # Check for unfilled placeholders in secrets
    secrets_path = os.path.join(result, "secrets.yaml")
    if os.path.isfile(secrets_path):
        with open(secrets_path, "r", encoding="utf-8") as f:
            content = f.read()
        if "__FILL_ME__" in content:
            print(f"\n⚠️  敏感配置中有未填写的凭据，请编辑: {secrets_path}")

    # Register in Prosody if JID is set
    if jid:
        domain = jid.split("@")[1] if "@" in jid else "localhost"
        username = jid.split("@")[0] if "@" in jid else name
        pwd = password or ""
        if pwd:
            try:
                res = subprocess.run(
                    ["prosodyctl", "register", username, domain, pwd],
                    capture_output=True, text=True,
                )
                if res.returncode == 0:
                    print(f"Prosody 注册成功: {username}@{domain}")
                elif "already" not in res.stderr.lower():
                    print(f"Prosody 注册失败: {res.stderr.strip()}")
            except FileNotFoundError:
                print(f"找不到 prosodyctl，请手动注册: prosodyctl register {username} {domain} {pwd}")


def main():
    parser = argparse.ArgumentParser(description="NaturalChat 本地 bot 目录管理工具")
    subparsers = parser.add_subparsers(dest="command", help="可用命令")

    # add
    add_parser = subparsers.add_parser("add", help="添加新机器人")
    add_parser.add_argument("name", help="机器人名称（将作为目录名）")
    add_parser.add_argument("--jid", help="JID (默认: <name>@chat)")
    add_parser.add_argument("--password", help="密码 (默认: 随机生成)")
    add_parser.add_argument("--telegram-token", help="Telegram Bot Token")
    add_parser.add_argument("--feishu-app-id", help="飞书 App ID")
    add_parser.add_argument("--feishu-app-secret", help="飞书 App Secret")

    # remove
    remove_parser = subparsers.add_parser("remove", help="删除机器人")
    remove_parser.add_argument("name", help="机器人名称")

    # list
    subparsers.add_parser("list", help="列出所有机器人")

    # export
    export_parser = subparsers.add_parser("export", help="导出机器人为分享包")
    export_parser.add_argument("name", help="机器人名称")
    export_parser.add_argument("--output", help="输出文件路径")

    # import
    import_parser = subparsers.add_parser("import", help="从分享包导入机器人")
    import_parser.add_argument("package", help="包文件路径 (.tar.gz)")
    import_parser.add_argument("name", help="新机器人名称")
    import_parser.add_argument("--jid", help="JID")
    import_parser.add_argument("--password", help="密码")
    import_parser.add_argument("--api-key", help="LLM API Key")
    import_parser.add_argument("--telegram-token", help="Telegram Bot Token")

    args = parser.parse_args()

    if args.command == "add":
        add_bot(args.name, args.jid, args.password,
                telegram_token=args.telegram_token,
                feishu_app_id=getattr(args, 'feishu_app_id', None),
                feishu_app_secret=getattr(args, 'feishu_app_secret', None))
    elif args.command == "remove":
        remove_bot(args.name)
    elif args.command == "list":
        list_bots()
    elif args.command == "export":
        export_bot_cmd(args.name, args.output)
    elif args.command == "import":
        import_bot_cmd(args.package, args.name, args.jid, args.password,
                       args.api_key, args.telegram_token)
    else:
        parser.print_help()

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
