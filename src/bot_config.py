"""
bot_config.py - Load bot config from config.yaml + secrets.yaml with validation.
"""

from __future__ import annotations

import os

from src.config_validation import deep_merge, load_yaml_file, validate_bot_config


CONFIG_FILENAME = "config.yaml"
SECRETS_FILENAME = "secrets.yaml"


def load_bot_runtime_config(bot_dir: str) -> dict:
    config_path = os.path.join(bot_dir, CONFIG_FILENAME)
    if not os.path.isfile(config_path):
        raise FileNotFoundError(config_path)

    config = load_yaml_file(config_path)
    secrets_path = os.path.join(bot_dir, SECRETS_FILENAME)
    if os.path.isfile(secrets_path):
        secrets = load_yaml_file(secrets_path)
        config = deep_merge(config, secrets)

    return validate_bot_config(config, context=f"bot config in {bot_dir}")
