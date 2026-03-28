"""
contact_migration.py - One-way migration from legacy contact references to canonical contact IDs.
"""

from __future__ import annotations

import json
import logging
import os
import re
import shutil
from typing import Dict, List

from src.contact_ids import is_contact_id, slugify_contact_id, strip_contact_prefix

logger = logging.getLogger(__name__)

_TAGGED_CONTACT_RE = re.compile(r"\[(?:JID|Contact):\s*([^\]]+)\]")

_JSON_FILES = (
    "bot_meta.json",
    "memobase_uid_map.json",
    "token_audit.json",
)
_TEXT_FILES = (
    "friends_impressions.md",
    "capabilities.md",
)
_MEMORY_TEXT_FILES = (
    "global_memo.md",
)
_MEMORY_JSON_FILES = (
    "global_profile.json",
)
_BOT_META_CONTACT_KEYS = {
    "creator_jid",
    "source_jid",
    "requester_jid",
    "approved_by",
    "denied_by",
    "detected_by",
    "uploaded_by",
}
def migrate_bot_contacts(bot_dir: str, bot_meta: dict) -> dict:
    """Migrate legacy bare contact identifiers in bot data to canonical contact IDs."""
    alias_map = _build_alias_map(bot_dir, bot_meta)
    if not alias_map:
        return {"updated": False, "alias_map": {}}

    bot_data_dir = os.path.join(bot_dir, "bot_data")
    memories_dir = os.path.join(bot_dir, "memories")

    for filename in _JSON_FILES:
        path = os.path.join(bot_data_dir, filename)
        if os.path.isfile(path):
            _rewrite_json_file(path, alias_map)

    for filename in _TEXT_FILES:
        path = os.path.join(bot_data_dir, filename)
        if os.path.isfile(path):
            _rewrite_text_file(path, alias_map)

    for filename in _MEMORY_JSON_FILES:
        path = os.path.join(memories_dir, filename)
        if os.path.isfile(path):
            _rewrite_json_file(path, alias_map)

    for filename in _MEMORY_TEXT_FILES:
        path = os.path.join(memories_dir, filename)
        if os.path.isfile(path):
            _rewrite_text_file(path, alias_map)

    _rename_legacy_memory_dirs(memories_dir, alias_map)

    logger.info("Migrated legacy contact aliases for %s: %s", os.path.basename(bot_dir), alias_map)
    return {"updated": True, "alias_map": alias_map}


def _build_alias_map(bot_dir: str, bot_meta: dict) -> Dict[str, str]:
    canonical_ids: List[str] = []

    for value in [bot_meta.get("creator_jid")] + list(bot_meta.get("admins", []) or []) + list(bot_meta.get("approved_contacts", []) or []):
        if is_contact_id(value) and value not in canonical_ids:
            canonical_ids.append(value)

    uid_map_path = os.path.join(bot_dir, "bot_data", "memobase_uid_map.json")
    if os.path.isfile(uid_map_path):
        try:
            with open(uid_map_path, "r", encoding="utf-8") as f:
                uid_map = json.load(f) or {}
            for key in uid_map.keys():
                if is_contact_id(key) and key not in canonical_ids:
                    canonical_ids.append(key)
        except Exception:
            pass

    legacy_ids = _collect_legacy_ids(bot_dir, bot_meta)
    fallback = canonical_ids[0] if len(canonical_ids) == 1 else ""
    alias_map: Dict[str, str] = {}
    for legacy in legacy_ids:
        matches = [contact_id for contact_id in canonical_ids if strip_contact_prefix(contact_id) == legacy]
        if len(matches) == 1:
            alias_map[legacy] = matches[0]
        elif fallback and legacy != fallback:
            alias_map[legacy] = fallback
    return alias_map


def _collect_legacy_ids(bot_dir: str, bot_meta: dict) -> List[str]:
    legacy_ids: List[str] = []

    def add(value: str):
        value = (value or "").strip()
        if not value or is_contact_id(value) or value in legacy_ids:
            return
        legacy_ids.append(value)

    def walk(value, key: str = ""):
        if isinstance(value, dict):
            for child_key, item in value.items():
                child_key = child_key if isinstance(child_key, str) else ""
                walk(item, child_key)
            return
        if isinstance(value, list):
            for item in value:
                walk(item, key)
            return
        if isinstance(value, str):
            if key in _BOT_META_CONTACT_KEYS:
                add(value)

    walk(bot_meta)

    for path in (
        os.path.join(bot_dir, "bot_data", "friends_impressions.md"),
        os.path.join(bot_dir, "memories", "global_memo.md"),
        os.path.join(bot_dir, "memories", "global_profile.json"),
    ):
        if not os.path.isfile(path):
            continue
        try:
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception:
            continue
        for token in _TAGGED_CONTACT_RE.findall(content):
            add(token)

    for path in (
        os.path.join(bot_dir, "bot_data", "memobase_uid_map.json"),
        os.path.join(bot_dir, "bot_data", "token_audit.json"),
    ):
        if not os.path.isfile(path):
            continue
        for token in _collect_legacy_json_keys(path):
            add(token)

    memories_dir = os.path.join(bot_dir, "memories")
    if os.path.isdir(memories_dir):
        for name in os.listdir(memories_dir):
            full_path = os.path.join(memories_dir, name)
            if not os.path.isdir(full_path):
                continue
            for candidate in legacy_ids:
                if slugify_contact_id(candidate) == name:
                    add(candidate)
    return legacy_ids


def _collect_legacy_json_keys(path: str) -> List[str]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return []

    found: List[str] = []

    def walk(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if isinstance(key, str) and "@" in key and ":" not in key and key not in found:
                    found.append(key)
                walk(item)
        elif isinstance(value, list):
            for item in value:
                walk(item)

    walk(data)
    return found


def _rewrite_json_file(path: str, alias_map: Dict[str, str]) -> None:
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        logger.warning("Skipping JSON contact migration for %s: %s", path, e)
        return

    rewritten = _rewrite_json_value(data, alias_map)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(rewritten, f, ensure_ascii=False, indent=2)


def _rewrite_json_value(value, alias_map: Dict[str, str]):
    if isinstance(value, dict):
        rewritten = {}
        for key, item in value.items():
            new_key = alias_map.get(key, key)
            rewritten[new_key] = _rewrite_json_value(item, alias_map)
        return rewritten
    if isinstance(value, list):
        return [_rewrite_json_value(item, alias_map) for item in value]
    if isinstance(value, str):
        updated = alias_map.get(value, value)
        for old, new in alias_map.items():
            updated = updated.replace(f"[JID: {old}]", f"[Contact: {new}]")
            updated = updated.replace(f"[Contact: {old}]", f"[Contact: {new}]")
            updated = updated.replace(old, new)
        return updated
    return value


def _rewrite_text_file(path: str, alias_map: Dict[str, str]) -> None:
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        logger.warning("Skipping text contact migration for %s: %s", path, e)
        return

    for old, new in alias_map.items():
        content = content.replace(f"[JID: {old}]", f"[Contact: {new}]")
        content = content.replace(f"[Contact: {old}]", f"[Contact: {new}]")
        content = content.replace(old, new)

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def _rename_legacy_memory_dirs(memories_dir: str, alias_map: Dict[str, str]) -> None:
    if not os.path.isdir(memories_dir):
        return
    for old, new in alias_map.items():
        old_dir = os.path.join(memories_dir, slugify_contact_id(old))
        new_dir = os.path.join(memories_dir, slugify_contact_id(new))
        if not os.path.isdir(old_dir):
            continue
        if os.path.isdir(new_dir):
            for name in os.listdir(old_dir):
                shutil.move(os.path.join(old_dir, name), os.path.join(new_dir, name))
            os.rmdir(old_dir)
            continue
        os.rename(old_dir, new_dir)
