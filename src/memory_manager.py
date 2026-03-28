"""
memory_manager.py - Dual-layer memory system: Memobase + local files.

Memobase handles user-related memories (profiles, conversation context).
Local files (in bots/<bot>/bot_data/) store bot-level data:
  - bot_self_reflection.json
  - friends_impressions.md
  - capabilities.md
  - autonomous_config.json
  - token_budgets.json
  - token_audit.json (managed by TokenAuditor, read-only here)
"""

import os
import json
import logging
import asyncio
from typing import Optional

logger = logging.getLogger(__name__)


class MemoryManager:
    def __init__(
        self,
        bot_data_dir: str,
        memobase_url: str = "",
        memobase_api_key: str = "",
    ):
        """
        bot_data_dir: e.g. bots/bot1/bot_data/
        memobase_url: e.g. http://localhost:8019
        memobase_api_key: API key for Memobase
        """
        self.bot_data_dir = bot_data_dir
        os.makedirs(bot_data_dir, exist_ok=True)

        # Lock for local file writes
        self.io_lock = asyncio.Lock()

        # Initialize Memobase client
        self._mb = None
        self._mb_users: dict = {}  # cache: {contact_jid: memobase User object}
        self._jid_to_uid: dict = {}  # JID -> Memobase UUID mapping
        self._uid_map_file = os.path.join(bot_data_dir, "memobase_uid_map.json")
        self._load_uid_map()
        if memobase_url:
            try:
                from memobase import MemoBaseClient
                self._mb = MemoBaseClient(
                    project_url=memobase_url,
                    api_key=memobase_api_key or "",
                )
                logger.info(f"Memobase connected: {memobase_url}")
            except ImportError:
                logger.warning("memobase package not installed, falling back to local-only memory")
            except Exception as e:
                logger.warning(f"Failed to connect to Memobase: {e}")

    # ══════════════════════════════════════════════════════════════════════════
    # Memobase (user-related memories)
    # ══════════════════════════════════════════════════════════════════════════

    def _load_uid_map(self):
        """Load JID -> Memobase UUID mapping from local file."""
        if os.path.isfile(self._uid_map_file):
            try:
                with open(self._uid_map_file, "r", encoding="utf-8") as f:
                    self._jid_to_uid = json.load(f)
            except Exception:
                self._jid_to_uid = {}

    def _save_uid_map(self):
        """Persist JID -> Memobase UUID mapping."""
        try:
            with open(self._uid_map_file, "w", encoding="utf-8") as f:
                json.dump(self._jid_to_uid, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"Failed to save uid map: {e}")

    def _get_mb_user(self, contact_jid: str):
        """Get or create a Memobase user for this contact (JID -> UUID mapping)."""
        if not self._mb:
            return None
        if contact_jid in self._mb_users:
            return self._mb_users[contact_jid]

        uid = self._jid_to_uid.get(contact_jid)
        if uid:
            try:
                user = self._mb.get_user(uid)
                self._mb_users[contact_jid] = user
                return user
            except Exception:
                # UID invalid, recreate
                logger.warning(f"Memobase user {uid} for {contact_jid} not found, recreating")

        # Create new user
        try:
            uid = self._mb.add_user()
            self._jid_to_uid[contact_jid] = uid
            self._save_uid_map()
            user = self._mb.get_user(uid)
            self._mb_users[contact_jid] = user
            logger.info(f"Created Memobase user for {contact_jid}: {uid}")
            return user
        except Exception as e:
            logger.warning(f"Failed to create Memobase user for {contact_jid}: {e}")
            return None

    def insert_chat(self, contact_jid: str, user_msg: str, assistant_msg: str):
        """Insert a chat exchange into Memobase for memory extraction."""
        if not self._mb:
            return
        user = self._get_mb_user(contact_jid)
        if not user:
            return
        try:
            from memobase import ChatBlob
            blob = ChatBlob(
                messages=[
                    {"role": "user", "content": user_msg},
                    {"role": "assistant", "content": assistant_msg},
                ]
            )
            user.insert(blob)
        except Exception as e:
            logger.warning(f"Failed to insert chat to Memobase: {e}")

    def get_user_context(self, contact_jid: str) -> str:
        """Get formatted user memory context from Memobase for system prompt injection."""
        if not self._mb:
            return ""
        user = self._get_mb_user(contact_jid)
        if not user:
            return ""
        try:
            context = user.context()
            if context:
                return f"=== User memory (from Memobase) ===\n{context}\n==="
            return ""
        except Exception as e:
            logger.warning(f"Failed to get Memobase context for {contact_jid}: {e}")
            return ""

    def get_all_user_contexts(self) -> str:
        """Get all users' contexts (for surfing planning)."""
        if not self._mb:
            return ""
        parts = []
        for jid in list(self._mb_users.keys()):
            try:
                ctx = self.get_user_context(jid)
                if ctx:
                    parts.append(f"[{jid}]\n{ctx}")
            except Exception:
                pass
        return "\n\n".join(parts)

    def flush_user(self, contact_jid: str):
        """Trigger Memobase to process buffered data for a user."""
        if not self._mb:
            return
        user = self._get_mb_user(contact_jid)
        if user:
            try:
                user.flush()
            except Exception as e:
                logger.warning(f"Failed to flush Memobase user {contact_jid}: {e}")

    def delete_user(self, contact_jid: str):
        """Delete a Memobase user and clear local mapping. For dev/testing."""
        uid = self._jid_to_uid.get(contact_jid)
        if uid and self._mb:
            try:
                self._mb.delete_user(uid)
                logger.info(f"Deleted Memobase user {uid} for {contact_jid}")
            except Exception as e:
                logger.warning(f"Failed to delete Memobase user {uid}: {e}")
        # Clear local cache
        self._mb_users.pop(contact_jid, None)
        self._jid_to_uid.pop(contact_jid, None)
        self._save_uid_map()

    # ══════════════════════════════════════════════════════════════════════════
    # Local files (bot-level data in bot_data/)
    # ══════════════════════════════════════════════════════════════════════════

    def _read_json(self, filename: str, default=None):
        path = os.path.join(self.bot_data_dir, filename)
        if not os.path.isfile(path):
            return default if default is not None else {}
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Error reading {path}: {e}")
            return default if default is not None else {}

    def _write_json(self, filename: str, data):
        path = os.path.join(self.bot_data_dir, filename)
        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"Error writing {path}: {e}")

    def _read_text(self, filename: str) -> str:
        path = os.path.join(self.bot_data_dir, filename)
        if not os.path.isfile(path):
            return ""
        try:
            with open(path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            logger.error(f"Error reading {path}: {e}")
            return ""

    def _write_text(self, filename: str, content: str):
        path = os.path.join(self.bot_data_dir, filename)
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
        except Exception as e:
            logger.error(f"Error writing {path}: {e}")

    # ── Bot self-reflection ──────────────────────────────────────────────────

    def load_bot_reflection(self) -> dict:
        return self._read_json("bot_self_reflection.json", {
            "skill_improvement_ideas": "",
            "interaction_shortcomings": "",
            "future_strategies": "",
        })

    def save_bot_reflection(self, data: dict):
        self._write_json("bot_self_reflection.json", data)

    # ── Friends impressions ──────────────────────────────────────────────────

    def load_friends_impressions(self) -> str:
        return self._read_text("friends_impressions.md")

    def save_friends_impressions(self, text: str):
        self._write_text("friends_impressions.md", text)

    # ── Capabilities ─────────────────────────────────────────────────────────

    def load_capabilities(self) -> str:
        return self._read_text("capabilities.md")

    def save_capabilities(self, content: str):
        self._write_text("capabilities.md", content)

    # ── Autonomous config ────────────────────────────────────────────────────

    def load_autonomous_config(self) -> dict:
        return self._read_json("autonomous_config.json", {
            "surfing_cooldown_per_contact": {},
            "last_proactive_msg_time": {},
            "surfing_focus_notes": "",
        })

    def save_autonomous_config(self, data: dict):
        self._write_json("autonomous_config.json", data)

    # ── Bot governance ───────────────────────────────────────────────────────

    def load_bot_meta(self) -> dict:
        return self._read_json("bot_meta.json", {
            "bot_type": "public",
            "access_mode": "open",
            "creator_jid": "",
            "admins": [],
            "blacklist": [],
            "approved_contacts": [],
            "pending_contact_requests": [],
            "pending_update_requests": [],
            "pending_package_requests": [],
            "package_download_grants": [],
            "provenance": {
                "source_bot": "",
                "source_jid": "",
                "created_at": "",
                "lineage": [],
            },
        })

    def save_bot_meta(self, data: dict):
        self._write_json("bot_meta.json", data)

    # ── Token budgets ────────────────────────────────────────────────────────

    def load_token_budgets(self) -> dict:
        return self._read_json("token_budgets.json", {})

    def save_token_budgets(self, data: dict):
        self._write_json("token_budgets.json", data)

    # ── RSS routes ───────────────────────────────────────────────────────────

    def load_rsshub_routes(self) -> list:
        data = self._read_json("rsshub_routes.json", [])
        if isinstance(data, list):
            return data
        return data.get("routes", [])

    def save_rsshub_routes(self, routes: list):
        self._write_json("rsshub_routes.json", routes)
