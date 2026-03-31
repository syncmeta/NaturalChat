"""
bot_manager.py - Scan bots/ directory and launch all bots.

Each bot is a subdirectory with config.yaml and prompts/.
Wires together: LLMAgent <-> BotBrain <-> TransportClients (XMPP, Telegram, Feishu).
"""

import os
import asyncio
import logging
from typing import Optional, List
import yaml
from src.bot_instance import BotInstance
from src.llm_agent import LLMAgent
from src.bot_brain import BotBrain
from src.token_auditor import TokenAuditor
from src.skill_loader import load_skills, skills_to_openai_tools, get_skill_executor
from src.memory_manager import MemoryManager
from src.prompt_store import load_prompt_bundle, scaffold_prompt_bundle
from src.bot_config import load_bot_runtime_config
from src.contact_migration import migrate_bot_contacts
from src.config_validation import ConfigValidationError

logger = logging.getLogger(__name__)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOTS_DIR = os.path.join(BASE_DIR, "bots")
COMMON_SKILLS_DIR = os.path.join(BASE_DIR, "common_skills")

# Global reference exposed for skills
global_bot_manager = None


def load_bot_config(bot_dir: str) -> Optional[dict]:
    """Load a bot's config.yaml and prompt bundle."""
    try:
        config = load_bot_runtime_config(bot_dir)
    except FileNotFoundError:
        logger.warning(f"No config.yaml found in {bot_dir}, skipping.")
        return None
    except ConfigValidationError as e:
        logger.error(str(e))
        return None

    config["_dir"] = bot_dir
    config["_name"] = os.path.basename(bot_dir)
    config.update(load_prompt_bundle(bot_dir))

    return config


def _build_transports(config: dict, bot_name: str) -> dict:
    """Build transport clients from config. Returns dict[platform -> TransportClient]."""
    transports = {}
    transport_config = config.get("transports", {})

    # XMPP: only enabled if explicitly configured
    xmpp_section = transport_config.get("xmpp", {})
    xmpp_enabled = xmpp_section.get("enabled", False)

    if xmpp_enabled and xmpp_section.get("jid"):
        from src.transport.xmpp import XMPPTransport
        xmpp = XMPPTransport(
            jid=xmpp_section["jid"],
            password=xmpp_section.get("password", ""),
            bot_name=bot_name,
            msg_wait_initial=config.get("msg_wait_initial", 2.5),
            msg_wait_after_typing_stop=config.get("msg_wait_after_typing_stop", 5.0),
            typing_hard_timeout=config.get("typing_hard_timeout", 10.0),
            xmpp_host=xmpp_section.get("xmpp_host", "localhost"),
            xmpp_port=xmpp_section.get("xmpp_port", 5222),
        )
        transports["xmpp"] = xmpp

    # Telegram: enabled if transports.telegram.enabled and token present
    tg_config = transport_config.get("telegram", {})
    if tg_config.get("enabled") and tg_config.get("token"):
        try:
            from src.transport.telegram import TelegramTransport
            tg = TelegramTransport(
                token=tg_config["token"],
                bot_name=bot_name,
                msg_wait_initial=config.get("msg_wait_initial", 2.5),
            )
            transports["telegram"] = tg
        except ImportError:
            logger.warning(f"[{bot_name}] python-telegram-bot not installed, skipping Telegram transport")

    # Matrix: enabled if transports.matrix.enabled and homeserver present
    matrix_config = transport_config.get("matrix", {})
    if matrix_config.get("enabled") and matrix_config.get("homeserver_url"):
        try:
            from src.transport.matrix import MatrixTransport
            matrix = MatrixTransport(
                homeserver_url=matrix_config["homeserver_url"],
                user_id=matrix_config.get("user_id", ""),
                access_token=matrix_config.get("access_token", ""),
                password=matrix_config.get("password", ""),
                bot_name=bot_name,
                device_name=matrix_config.get("device_name", "NaturalChat"),
                msg_wait_initial=config.get("msg_wait_initial", 2.5),
                msg_wait_after_typing_stop=config.get("msg_wait_after_typing_stop", 5.0),
                typing_hard_timeout=config.get("typing_hard_timeout", 10.0),
            )
            transports["matrix"] = matrix
        except ImportError:
            logger.warning(f"[{bot_name}] matrix-nio not installed, skipping Matrix transport")

    # Feishu: enabled if transports.feishu.enabled and credentials present
    feishu_config = transport_config.get("feishu", {})
    if feishu_config.get("enabled") and feishu_config.get("app_id"):
        try:
            from src.transport.feishu import FeishuTransport
            feishu = FeishuTransport(
                app_id=feishu_config["app_id"],
                app_secret=feishu_config["app_secret"],
                verification_token=feishu_config.get("verification_token", ""),
                encrypt_key=feishu_config.get("encrypt_key", ""),
                bot_name=bot_name,
                webhook_port=feishu_config.get("webhook_port", 9000),
                msg_wait_initial=config.get("msg_wait_initial", 2.5),
            )
            transports["feishu"] = feishu
        except ImportError:
            logger.warning(f"[{bot_name}] Feishu transport not available, skipping")

    # Web: always enabled (for the admin panel)
    from src.transport.web import WebTransport
    web = WebTransport(bot_name=bot_name)
    transports["web"] = web

    return transports


def create_bot(config: dict) -> BotInstance:
    """Create a fully wired bot: LLMAgent + BotBrain + TransportClients."""
    bot_name = config["_name"]
    prompt = config["_prompt"]
    bot_dir = config["_dir"]

    llm_config = config.get("llm", {})
    api_key = llm_config.get("api_key", "")
    base_url = llm_config.get("base_url", "https://api.openai.com/v1")
    model = llm_config.get("model", "gpt-4o-mini")
    max_history_tokens = llm_config.get("max_history_tokens", 4000)

    # Load skills
    bot_skills_dir = os.path.join(bot_dir, "skills")
    skills = load_skills(COMMON_SKILLS_DIR, bot_skills_dir)
    tools = skills_to_openai_tools(skills) if skills else None
    executors = get_skill_executor(skills) if skills else {}

    # Create bot_data directory
    bot_data_dir = os.path.join(bot_dir, "bot_data")
    os.makedirs(bot_data_dir, exist_ok=True)

    # Create memory manager (Memobase + local files)
    memobase_config = config.get("memobase", {})
    memory_manager = MemoryManager(
        bot_data_dir=bot_data_dir,
        memobase_url=memobase_config.get("url", ""),
        memobase_api_key=memobase_config.get("api_key", ""),
    )
    bot_meta = memory_manager.load_bot_meta()

    # Create LLM agent (core LLM calls + chat)
    agent = LLMAgent(
        api_key=api_key,
        base_url=base_url,
        model=model,
        system_prompt=prompt,
        max_history_tokens=max_history_tokens,
        tools=tools,
        skill_executors=executors,
        memory_manager=memory_manager,
        history_summary_prompt=config.get("_history_summary_prompt", ""),
        bot_abilities=config.get("_bot_abilities", ""),
    )

    # Create token auditor
    audit_file = os.path.join(bot_data_dir, "token_audit.json")
    token_auditor = TokenAuditor(audit_file)

    # Store skill dirs in config for brain
    config["_skill_dirs"] = [d for d in [COMMON_SKILLS_DIR, bot_skills_dir] if os.path.isdir(d)]

    # Build transport clients
    transports = _build_transports(config, bot_name)

    if not transports:
        logger.error(f"No transports configured for bot '{bot_name}', skipping.")
        return None

    migration_result = migrate_bot_contacts(bot_dir, bot_meta)
    if migration_result.get("updated"):
        bot_meta = memory_manager.load_bot_meta()
    config["_bot_meta"] = bot_meta
    memory_manager.save_bot_meta(config["_bot_meta"])

    # Create brain with placeholder callbacks (BotInstance will override)
    brain = BotBrain(
        llm_agent=agent,
        memory_manager=memory_manager,
        token_auditor=token_auditor,
        send_message_fn=lambda *a: None,
        send_composing_fn=lambda *a: None,
        send_active_fn=lambda *a: None,
        config=config,
    )

    # Create BotInstance — wires brain callbacks to transport dispatch
    instance = BotInstance(name=bot_name, brain=brain, transports=transports)

    platforms = list(transports.keys())
    logger.info(
        f"Created bot '{bot_name}' (platforms: {platforms}, model: {model}, "
        f"skills: {len(skills)}, memobase: {'yes' if memobase_config.get('url') else 'no'})"
    )
    return instance


class BotManager:
    def __init__(self):
        self.bots: list[BotInstance] = []
        self.global_config: dict = {}
        global global_bot_manager
        global_bot_manager = self

    def _load_global_config(self) -> dict:
        """Load project-root config.yaml, inject env vars."""
        global_config_path = os.path.join(BASE_DIR, "config.yaml")
        if not os.path.isfile(global_config_path):
            return {}
        with open(global_config_path, "r", encoding="utf-8") as f:
            global_config = yaml.safe_load(f) or {}
        for key, val in global_config.get("env", {}).items():
            if val:
                os.environ[key] = str(val)
                logger.info(f"Global env: {key} set")
        if "rsshub_server" in global_config:
            os.environ["RSSHUB_SERVER"] = str(global_config["rsshub_server"])
        return global_config

    def discover_bots(self):
        """Scan bots/ directory and load all bot configs."""
        global_config = self._load_global_config()
        self.global_config = global_config
        if not os.path.isdir(BOTS_DIR):
            logger.error(f"Bots directory not found: {BOTS_DIR}")
            return

        for name in sorted(os.listdir(BOTS_DIR)):
            if name == "example":
                continue
            bot_dir = os.path.join(BOTS_DIR, name)
            if not os.path.isdir(bot_dir):
                continue

            config = load_bot_config(bot_dir)
            if config:
                for key in ("rsshub_server", "rss_poll_interval"):
                    if key in global_config:
                        config[key] = global_config[key]
                bot = create_bot(config)
                if bot:
                    self.bots.append(bot)

        logger.info(f"Discovered {len(self.bots)} bot(s)")

    async def start_all(self):
        """Start all bots concurrently."""
        if not self.bots:
            logger.error("No bots to start!")
            return

        tasks = [asyncio.create_task(bot.start()) for bot in self.bots]
        logger.info("All bots are starting...")
        await asyncio.gather(*tasks, return_exceptions=True)

    async def restart_bot(self, bot_name: str) -> bool:
        """Reload one bot from disk and restart it in the background."""
        for idx, bot in enumerate(self.bots):
            if bot.name != bot_name:
                continue

            bot.stop()
            config = load_bot_config(os.path.join(BOTS_DIR, bot_name))
            if not config:
                logger.error(f"Failed to reload config for bot '{bot_name}'")
                return False
            for key in ("rsshub_server", "rss_poll_interval"):
                if key in self.global_config:
                    config[key] = self.global_config[key]
            new_bot = create_bot(config)
            if not new_bot:
                logger.error(f"Failed to recreate bot '{bot_name}'")
                return False
            self.bots[idx] = new_bot
            asyncio.create_task(new_bot.start())
            logger.info(f"Restarted bot '{bot_name}'")
            return True
        return False

    async def send_message_as_bot(self, target_id: str, message: str, source_bot_name: str = None) -> bool:
        """Send a message as a bot. target_id should be prefixed."""
        if not self.bots:
            return False
        bot = next((b for b in self.bots if b.name == source_bot_name), None) if source_bot_name else self.bots[0]
        if not bot:
            return False
        bot.brain._send_message(target_id, message)
        return True
