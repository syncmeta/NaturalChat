"""
prompt_store.py - Centralized prompt bundle loading and scaffolding.

Each bot keeps all prompts in one folder:
  bots/<name>/prompts/
    registry.yaml
    *.md

The registry documents where each prompt is used and what it is for.
"""

import os
import shutil
from typing import Dict

import yaml

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_PROMPTS_DIR = os.path.join(BASE_DIR, "prompts", "default")
BOT_PROMPTS_DIRNAME = "prompts"
REGISTRY_FILENAME = "registry.yaml"

PROMPT_SPECS = {
    "main": {
        "config_key": "_prompt",
        "default_file": "main.md",
        "purpose": "机器人主系统提示词，直接作为聊天主模型的 system prompt。",
        "used_by": "src.bot_manager.create_bot -> LLMAgent(system_prompt)",
    },
    "reflection": {
        "config_key": "_reflection_prompt",
        "default_file": "reflection.md",
        "purpose": "沉默后的内部反思提示词，用于生成自我反思内容。",
        "used_by": "src.bot_brain.BotBrain._do_reflect",
    },
    "profile_update": {
        "config_key": "_profile_update_prompt",
        "default_file": "profile_update.md",
        "purpose": "更新用户画像和记忆时使用的提示词。",
        "used_by": "src.bot_brain.BotBrain._do_memory_update",
    },
    "history_summary": {
        "config_key": "_history_summary_prompt",
        "default_file": "history_summary.md",
        "purpose": "对超长历史进行摘要压缩时使用的提示词。",
        "used_by": "src.llm_agent.LLMAgent._summarize_and_trim",
    },
    "critic": {
        "config_key": "_critic_prompt",
        "default_file": "critic.md",
        "purpose": "对主回复做独立审查时使用的提示词。",
        "used_by": "src.bot_brain.BotBrain._do_critic_review",
    },
    "correction": {
        "config_key": "_correction_prompt",
        "default_file": "correction.md",
        "purpose": "审查发现问题后生成修正回复时使用的提示词。",
        "used_by": "src.bot_brain.BotBrain._do_critic_review",
    },
    "surfing": {
        "config_key": "_surfing_prompt",
        "default_file": "surfing.md",
        "purpose": "自主冲浪规划时使用的提示词。",
        "used_by": "src.bot_brain.BotBrain.do_surf_once",
    },
    "bot_abilities": {
        "config_key": "_bot_abilities",
        "default_file": "abilities.md",
        "purpose": "注入给主模型的能力说明文本，帮助模型理解可用技能。",
        "used_by": "src.bot_manager.create_bot -> LLMAgent(bot_abilities)",
    },
}


def bot_prompts_dir(bot_dir: str) -> str:
    return os.path.join(bot_dir, BOT_PROMPTS_DIRNAME)


def _load_registry(prompts_dir: str) -> dict:
    registry_path = os.path.join(prompts_dir, REGISTRY_FILENAME)
    if not os.path.isfile(registry_path):
        return {}
    with open(registry_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    prompts = data.get("prompts", {}) or {}
    return prompts if isinstance(prompts, dict) else {}


def load_prompt_bundle(bot_dir: str) -> Dict[str, str]:
    """Load prompt contents for a bot, with repo defaults as fallback."""
    bundle = {}
    entries = {}

    for prompts_dir in (DEFAULT_PROMPTS_DIR, bot_prompts_dir(bot_dir)):
        registry = _load_registry(prompts_dir)
        for name, meta in registry.items():
            if not isinstance(meta, dict):
                continue
            item = dict(meta)
            item["_prompts_dir"] = prompts_dir
            entries[name] = item

    for name, spec in PROMPT_SPECS.items():
        entry = entries.get(name, {})
        filename = entry.get("file", spec["default_file"])
        prompts_dir = entry.get("_prompts_dir", DEFAULT_PROMPTS_DIR)
        path = os.path.join(prompts_dir, filename)
        content = ""
        if os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
        bundle[spec["config_key"]] = content

    bundle["_prompt_registry"] = entries
    bundle["_prompts_dir"] = bot_prompts_dir(bot_dir)
    return bundle


def scaffold_prompt_bundle(bot_dir: str, main_prompt: str = "") -> str:
    """Create a full editable prompt bundle inside a bot directory."""
    prompts_dir = bot_prompts_dir(bot_dir)
    os.makedirs(prompts_dir, exist_ok=True)

    registry = {"version": 1, "prompts": {}}
    for name, spec in PROMPT_SPECS.items():
        registry["prompts"][name] = {
            "file": spec["default_file"],
            "purpose": spec["purpose"],
            "used_by": spec["used_by"],
        }

        source_path = os.path.join(DEFAULT_PROMPTS_DIR, spec["default_file"])
        target_path = os.path.join(prompts_dir, spec["default_file"])
        if name == "main":
            with open(target_path, "w", encoding="utf-8") as f:
                f.write(main_prompt)
            continue
        if os.path.isfile(source_path):
            shutil.copy2(source_path, target_path)
        elif not os.path.exists(target_path):
            with open(target_path, "w", encoding="utf-8") as f:
                f.write("")

    registry_path = os.path.join(prompts_dir, REGISTRY_FILENAME)
    with open(registry_path, "w", encoding="utf-8") as f:
        yaml.dump(registry, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    return prompts_dir
