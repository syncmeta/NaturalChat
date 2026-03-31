"""
bot_packager.py - Export and import bot packages for cross-machine cloning.

A bot package is a .tar.gz containing config (secrets stripped), prompts,
skills, and provenance metadata. The receiving machine imports it and
provides local credentials.
"""

import hashlib
import json
import logging
import os
import shutil
import tarfile
import tempfile
from datetime import datetime
from typing import Optional

import yaml

logger = logging.getLogger(__name__)

# Files to include in export (relative to bot directory)
EXPORT_FILES = [
]

# Directories to include
EXPORT_DIRS = [
    "prompts",
    "skills",
]

# Files in bot_data/ to include (personality, not user data)
EXPORT_BOT_DATA = [
    "bot_meta.json",
    "bot_self_reflection.json",
    "friends_impressions.md",
]

# Sensitive keys to strip from config
SENSITIVE_KEYS = {
    "password", "api_key", "app_secret", "token",
    "verification_token", "encrypt_key",
}


def _strip_secrets(config: dict) -> dict:
    """Recursively strip sensitive keys from config, replacing with placeholder."""
    result = {}
    for key, val in config.items():
        if key.startswith("_"):
            continue  # Skip internal keys
        if key in SENSITIVE_KEYS:
            result[key] = "__FILL_ME__"
        elif isinstance(val, dict):
            result[key] = _strip_secrets(val)
        elif isinstance(val, list):
            result[key] = [
                _strip_secrets(item) if isinstance(item, dict) else item
                for item in val
            ]
        else:
            result[key] = val
    return result


def _find_common_skills_used(bot_dir: str, common_skills_dir: str) -> list:
    """Find which common skills the bot relies on (by checking if it has overrides)."""
    if not os.path.isdir(common_skills_dir):
        return []
    return sorted(os.listdir(common_skills_dir))


def export_bot(bot_dir: str, output_path: str = None, common_skills_dir: str = None) -> str:
    """
    Export a bot as a .tar.gz package.

    Args:
        bot_dir: Path to the bot directory (e.g., bots/bot1)
        output_path: Output file path. If None, auto-generates in same parent dir.
        common_skills_dir: Path to common_skills/ for dependency listing.

    Returns:
        Path to the created .tar.gz file.
    """
    bot_name = os.path.basename(bot_dir)

    if not output_path:
        output_path = os.path.join(
            os.path.dirname(bot_dir),
            f"{bot_name}_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.tar.gz"
        )

    with tempfile.TemporaryDirectory() as tmpdir:
        pkg_dir = os.path.join(tmpdir, bot_name)
        os.makedirs(pkg_dir)

        # Copy config as-is (non-sensitive config should already live here)
        config_path = os.path.join(bot_dir, "config.yaml")
        if os.path.isfile(config_path):
            with open(config_path, "r", encoding="utf-8") as f:
                config = yaml.safe_load(f) or {}
            with open(os.path.join(pkg_dir, "config.yaml"), "w", encoding="utf-8") as f:
                yaml.dump(config, f, default_flow_style=False, allow_unicode=True)

        secrets_path = os.path.join(bot_dir, "secrets.yaml")
        if os.path.isfile(secrets_path):
            with open(secrets_path, "r", encoding="utf-8") as f:
                secrets = yaml.safe_load(f) or {}
            stripped_secrets = _strip_secrets(secrets)
            with open(os.path.join(pkg_dir, "secrets.yaml"), "w", encoding="utf-8") as f:
                yaml.dump(stripped_secrets, f, default_flow_style=False, allow_unicode=True)

        # Copy prompt and ability files
        for filename in EXPORT_FILES:
            src = os.path.join(bot_dir, filename)
            if os.path.isfile(src):
                shutil.copy2(src, os.path.join(pkg_dir, filename))

        # Copy skill directories
        for dirname in EXPORT_DIRS:
            src = os.path.join(bot_dir, dirname)
            if os.path.isdir(src) and os.listdir(src):
                shutil.copytree(src, os.path.join(pkg_dir, dirname))

        # Copy select bot_data files
        bot_data_dir = os.path.join(bot_dir, "bot_data")
        pkg_data_dir = os.path.join(pkg_dir, "bot_data")
        os.makedirs(pkg_data_dir, exist_ok=True)

        for filename in EXPORT_BOT_DATA:
            src = os.path.join(bot_data_dir, filename)
            if os.path.isfile(src):
                shutil.copy2(src, os.path.join(pkg_data_dir, filename))

        # Create manifest
        manifest = {
            "package_version": 1,
            "source_bot_name": bot_name,
            "export_timestamp": datetime.now().isoformat(),
            "required_common_skills": _find_common_skills_used(
                bot_dir, common_skills_dir or ""
            ),
        }

        # Compute checksum of included files
        file_hashes = {}
        for root, dirs, files in os.walk(pkg_dir):
            for fname in sorted(files):
                fpath = os.path.join(root, fname)
                rel = os.path.relpath(fpath, pkg_dir)
                with open(fpath, "rb") as f:
                    file_hashes[rel] = hashlib.sha256(f.read()).hexdigest()
        manifest["file_checksums"] = file_hashes

        with open(os.path.join(pkg_dir, "package_manifest.json"), "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=2)

        # Create tar.gz
        with tarfile.open(output_path, "w:gz") as tar:
            tar.add(pkg_dir, arcname=bot_name)

    logger.info(f"Exported bot '{bot_name}' to {output_path}")
    return output_path


def import_bot(
    package_path: str,
    bots_dir: str,
    new_name: str,
    overrides: Optional[dict] = None,
) -> str:
    """
    Import a bot package.

    Args:
        package_path: Path to the .tar.gz package.
        bots_dir: Path to the bots/ directory.
        new_name: Name for the imported bot.
        overrides: Dict of config overrides (jid, password, api_key, etc.)

    Returns:
        Path to the imported bot directory.
    """
    new_bot_dir = os.path.join(bots_dir, new_name)
    if os.path.exists(new_bot_dir):
        raise FileExistsError(f"Bot directory {new_bot_dir} already exists.")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Extract package
        with tarfile.open(package_path, "r:gz") as tar:
            tar.extractall(tmpdir)

        # Find the bot directory inside the archive
        extracted = os.listdir(tmpdir)
        if len(extracted) != 1:
            raise ValueError(f"Expected one directory in package, found: {extracted}")

        src_dir = os.path.join(tmpdir, extracted[0])

        # Verify manifest
        manifest_path = os.path.join(src_dir, "package_manifest.json")
        if os.path.isfile(manifest_path):
            with open(manifest_path, "r", encoding="utf-8") as f:
                manifest = json.load(f)
            logger.info(
                f"Importing bot from '{manifest.get('source_bot_name')}' "
                f"(exported at {manifest.get('export_timestamp')})"
            )

        # Copy to bots directory
        shutil.copytree(src_dir, new_bot_dir)

    # Remove manifest from final directory (not needed at runtime)
    manifest_dst = os.path.join(new_bot_dir, "package_manifest.json")
    if os.path.isfile(manifest_dst):
        os.remove(manifest_dst)

    # Apply overrides to secrets first
    secrets_path = os.path.join(new_bot_dir, "secrets.yaml")
    if os.path.isfile(secrets_path) and overrides:
        with open(secrets_path, "r", encoding="utf-8") as f:
            secrets = yaml.safe_load(f) or {}

        _deep_merge(secrets, overrides)

        with open(secrets_path, "w", encoding="utf-8") as f:
            yaml.dump(secrets, f, default_flow_style=False, allow_unicode=True)

    # Apply only non-secret overrides to config
    config_path = os.path.join(new_bot_dir, "config.yaml")
    if os.path.isfile(config_path) and overrides:
        with open(config_path, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f) or {}

        non_secret_overrides = {
            key: val for key, val in overrides.items()
            if key not in {"llm", "memobase", "transports", "password", "api_key", "token"}
        }
        _deep_merge(config, non_secret_overrides)

        with open(config_path, "w", encoding="utf-8") as f:
            yaml.dump(config, f, default_flow_style=False, allow_unicode=True)

    # Update provenance in bot_meta
    meta_path = os.path.join(new_bot_dir, "bot_data", "bot_meta.json")
    if os.path.isfile(meta_path):
        with open(meta_path, "r", encoding="utf-8") as f:
            meta = json.load(f)

        # Add import record to lineage
        provenance = meta.get("provenance", {}) or {}
        lineage = list(provenance.get("lineage", []))
        lineage.append({
            "action": "imported",
            "source_package": os.path.basename(package_path),
            "imported_at": datetime.now().isoformat(),
            "imported_as": new_name,
        })
        provenance["lineage"] = lineage
        meta["provenance"] = provenance

        # Clear stale contacts/requests
        meta["approved_contacts"] = []
        meta["pending_contact_requests"] = []
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)

    logger.info(f"Imported bot as '{new_name}' at {new_bot_dir}")
    return new_bot_dir


def update_bot_in_place(package_path: str, bot_dir: str) -> str:
    """
    Update an existing bot in place from a .tar.gz package.

    Preserves local secrets.yaml and bot_data/bot_meta.json.
    Replaces config.yaml, prompts/, skills/, and selected personality files.
    """
    if not os.path.isdir(bot_dir):
        raise FileNotFoundError(f"Bot directory not found: {bot_dir}")

    with tempfile.TemporaryDirectory() as tmpdir:
        with tarfile.open(package_path, "r:gz") as tar:
            tar.extractall(tmpdir)

        extracted = os.listdir(tmpdir)
        if len(extracted) != 1:
            raise ValueError(f"Expected one directory in package, found: {extracted}")
        src_dir = os.path.join(tmpdir, extracted[0])

        config_path = os.path.join(src_dir, "config.yaml")
        if os.path.isfile(config_path):
            shutil.copy2(config_path, os.path.join(bot_dir, "config.yaml"))

        for dirname in EXPORT_DIRS:
            src = os.path.join(src_dir, dirname)
            dst = os.path.join(bot_dir, dirname)
            if not os.path.isdir(src):
                continue
            if os.path.isdir(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)

        src_bot_data = os.path.join(src_dir, "bot_data")
        dst_bot_data = os.path.join(bot_dir, "bot_data")
        os.makedirs(dst_bot_data, exist_ok=True)
        for filename in ("bot_self_reflection.json", "friends_impressions.md"):
            src = os.path.join(src_bot_data, filename)
            if os.path.isfile(src):
                shutil.copy2(src, os.path.join(dst_bot_data, filename))

    logger.info(f"Updated bot in place from package: {package_path}")
    return bot_dir


def _deep_merge(base: dict, override: dict):
    """Recursively merge override into base dict."""
    for key, val in override.items():
        if key in base and isinstance(base[key], dict) and isinstance(val, dict):
            _deep_merge(base[key], val)
        else:
            base[key] = val
