"""
memory_manager.py - Dual-layer memory system: Honcho + local files.

Honcho handles user-related memories (profiles, conversation context)
via theory-of-mind reasoning (deductive, inductive, abductive).
Local files (in bots/<bot>/bot_data/) store bot-level data:
  - bot_self_reflection.json
  - friends_impressions.md
  - capabilities.md
  - autonomous_config.json
  - token_budgets.json
  - token_audit.json (managed by TokenAuditor, read-only here)
"""

import os
import re
import json
import logging
import asyncio
from typing import Optional

logger = logging.getLogger(__name__)

# Honcho peer/session IDs only allow [a-zA-Z0-9_-]
_HONCHO_ID_RE = re.compile(r'[^a-zA-Z0-9_-]')


class MemoryManager:
    def __init__(
        self,
        bot_data_dir: str,
        honcho_url: str = "",
        honcho_api_key: str = "",
    ):
        """
        bot_data_dir: e.g. bots/bot1/bot_data/
        honcho_url: e.g. http://localhost:8080 (self-hosted Honcho base URL)
        honcho_api_key: API key for Honcho
        """
        self.bot_data_dir = bot_data_dir
        os.makedirs(bot_data_dir, exist_ok=True)

        # Lock for local file writes
        self.io_lock = asyncio.Lock()

        # Initialize Honcho client
        self._honcho = None
        self._peers: dict = {}  # cache: {contact_jid: Peer object}
        self._sessions: dict = {}  # cache: {contact_jid: Session object}
        self._session_map_file = os.path.join(bot_data_dir, "honcho_session_map.json")
        self._jid_to_session: dict = {}  # JID -> session ID mapping
        self._load_session_map()
        if honcho_url:
            try:
                from honcho import Honcho
                self._honcho = Honcho(
                    base_url=honcho_url,
                    api_key=honcho_api_key or "",
                )
                logger.info(f"Honcho connected: {honcho_url}")
            except ImportError:
                logger.warning("honcho-ai package not installed, falling back to local-only memory")
            except Exception as e:
                logger.warning(f"Failed to connect to Honcho: {e}")

    # ══════════════════════════════════════════════════════════════════════════
    # Honcho (user-related memories)
    # ══════════════════════════════════════════════════════════════════════════

    def _load_session_map(self):
        """Load JID -> Honcho session ID mapping from local file."""
        if os.path.isfile(self._session_map_file):
            try:
                with open(self._session_map_file, "r", encoding="utf-8") as f:
                    self._jid_to_session = json.load(f)
            except Exception:
                self._jid_to_session = {}

    def _save_session_map(self):
        """Persist JID -> Honcho session ID mapping."""
        try:
            with open(self._session_map_file, "w", encoding="utf-8") as f:
                json.dump(self._jid_to_session, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"Failed to save session map: {e}")

    @staticmethod
    def _sanitize_id(raw: str) -> str:
        """Sanitize a contact JID into a valid Honcho ID ([a-zA-Z0-9_-] only)."""
        return _HONCHO_ID_RE.sub('-', raw)

    def _get_peer(self, contact_jid: str):
        """Get or create a Honcho peer for this contact."""
        if not self._honcho:
            return None
        if contact_jid in self._peers:
            return self._peers[contact_jid]
        try:
            peer_id = self._sanitize_id(contact_jid)
            peer = self._honcho.peer(peer_id)
            self._peers[contact_jid] = peer
            return peer
        except Exception as e:
            logger.warning(f"Failed to get/create Honcho peer for {contact_jid}: {e}")
            return None

    def _get_session(self, contact_jid: str):
        """Get or create a persistent Honcho session for this contact."""
        if not self._honcho:
            return None
        if contact_jid in self._sessions:
            return self._sessions[contact_jid]

        session_id = self._jid_to_session.get(contact_jid)
        if session_id:
            try:
                session = self._honcho.session(session_id)
                self._sessions[contact_jid] = session
                return session
            except Exception:
                logger.warning(f"Honcho session {session_id} for {contact_jid} not found, recreating")

        # Create new session
        try:
            session_id = f"chat-{self._sanitize_id(contact_jid)}"
            session = self._honcho.session(session_id)
            peer = self._get_peer(contact_jid)
            if peer:
                session.add_peers([peer])
            self._jid_to_session[contact_jid] = session_id
            self._save_session_map()
            self._sessions[contact_jid] = session
            logger.info(f"Created Honcho session for {contact_jid}: {session_id}")
            return session
        except Exception as e:
            logger.warning(f"Failed to create Honcho session for {contact_jid}: {e}")
            return None

    def insert_chat(self, contact_jid: str, user_msg: str, assistant_msg: str):
        """Insert a chat exchange into Honcho for memory extraction."""
        if not self._honcho:
            return
        peer = self._get_peer(contact_jid)
        if not peer:
            return
        session = self._get_session(contact_jid)
        if not session:
            return
        try:
            messages = [
                peer.message(user_msg, metadata={"role": "user"}),
                peer.message(assistant_msg, metadata={"role": "assistant"}),
            ]
            session.add_messages(messages)
        except Exception as e:
            logger.warning(f"Failed to insert chat to Honcho: {e}")

    def get_user_context(self, contact_jid: str) -> str:
        """Get formatted user memory context from Honcho for system prompt injection."""
        if not self._honcho:
            return ""
        peer = self._get_peer(contact_jid)
        if not peer:
            return ""
        try:
            ctx = peer.context()
            if not ctx:
                return ""
            parts = []
            if getattr(ctx, 'representation', None):
                parts.append(ctx.representation)
            if getattr(ctx, 'peer_card', None):
                parts.append("Key facts: " + "; ".join(ctx.peer_card))
            if not parts:
                return ""
            return f"=== User memory (from Honcho) ===\n" + "\n".join(parts) + "\n==="
        except Exception as e:
            logger.warning(f"Failed to get Honcho context for {contact_jid}: {e}")
            return ""

    def get_all_user_contexts(self) -> str:
        """Get all users' contexts (for surfing planning)."""
        if not self._honcho:
            return ""
        parts = []
        for jid in list(self._peers.keys()):
            try:
                ctx = self.get_user_context(jid)
                if ctx:
                    parts.append(f"[{jid}]\n{ctx}")
            except Exception:
                pass
        return "\n\n".join(parts)

    def flush_user(self, contact_jid: str):
        """No-op: Honcho processes data asynchronously in the background."""
        pass

    def delete_user(self, contact_jid: str):
        """Delete Honcho session for a contact and clear local mapping."""
        session_id = self._jid_to_session.get(contact_jid)
        if session_id and self._honcho:
            try:
                session = self._honcho.session(session_id)
                session.delete()
                logger.info(f"Deleted Honcho session {session_id} for {contact_jid}")
            except Exception as e:
                logger.warning(f"Failed to delete Honcho session {session_id}: {e}")
        # Clear local cache
        self._peers.pop(contact_jid, None)
        self._sessions.pop(contact_jid, None)
        self._jid_to_session.pop(contact_jid, None)
        self._save_session_map()

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
