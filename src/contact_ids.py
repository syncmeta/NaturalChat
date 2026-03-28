"""
contact_ids.py - Shared helpers for canonical cross-platform contact IDs.

The only valid runtime contact identifier format is:
    <platform>:<native_id>
Examples:
    telegram:1601767410
    xmpp:human@example.com
    matrix:!roomid:matrix.org
    feishu:ou_xxxxx
"""

from __future__ import annotations

import re

_CONTACT_ID_RE = re.compile(r"^([a-z][a-z0-9_-]*):(.*)$")
_NON_SLUG_RE = re.compile(r"[^A-Za-z0-9]+")


def split_contact_id(contact_id: str) -> tuple[str, str]:
    """Split a canonical contact ID into (platform, native_id)."""
    if not isinstance(contact_id, str):
        return "", ""
    match = _CONTACT_ID_RE.match(contact_id.strip())
    if not match:
        return "", ""
    platform, native_id = match.group(1), match.group(2).strip()
    if not native_id:
        return "", ""
    return platform, native_id


def is_contact_id(value: str) -> bool:
    """Return True if value is a canonical runtime contact ID."""
    platform, native_id = split_contact_id(value)
    return bool(platform and native_id)


def make_contact_id(platform: str, native_id: str) -> str:
    """Build a canonical contact ID."""
    platform = (platform or "").strip().lower()
    native_id = (native_id or "").strip()
    if not platform or not native_id:
        return ""
    return f"{platform}:{native_id}"


def strip_contact_prefix(contact_id: str) -> str:
    """Return native_id if value is canonical, otherwise return original text."""
    platform, native_id = split_contact_id(contact_id)
    return native_id if platform else (contact_id or "")


def slugify_contact_id(contact_id: str) -> str:
    """Create a stable directory-safe slug for a contact ID."""
    cleaned = _NON_SLUG_RE.sub("_", (contact_id or "").strip()).strip("_")
    return cleaned.lower() or "contact"
