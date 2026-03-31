"""
command_router.py - Platform-agnostic slash command and governance NL handling.

Shared command router so all transports use the same command logic.
"""

import asyncio
import logging
import re
from typing import Callable

logger = logging.getLogger(__name__)
_CONTACT_ID_RE = re.compile(r"\b[a-z][a-z0-9_-]*:[^\s,，;；]+")


class CommandRouter:
    """Routes slash commands and governance natural-language to BotBrain."""

    def __init__(self, brain, bot_name: str, reply_fn: Callable, bot_id: str = ""):
        """
        Args:
            brain: BotBrain instance
            bot_name: Display name of the bot
            reply_fn: Callable(contact_id, text) to send a reply
            bot_id: Bot's own contact ID to exclude from NL parsing
        """
        self.brain = brain
        self.bot_name = bot_name
        self._reply = reply_fn
        self.bot_id = bot_id

    async def handle_command(self, sender_id: str, body: str) -> bool:
        """Handle slash commands. Returns True if handled."""
        parts = body.strip().split()
        cmd = parts[0].lower()

        if cmd == "/surf":
            self._reply(sender_id, "OK, going surfing now")
            asyncio.create_task(self._run_surf(sender_id))
            return True

        if cmd == "/start":
            if self.brain.claim_creator(sender_id):
                self._reply(sender_id, "You are now the creator of this bot.")
            else:
                self._reply(sender_id, "Bot is ready.")
            return True

        if cmd == "/reset":
            count = await self.brain.reset(sender_id)
            self._reply(sender_id, f"Reset complete ({count} items cleared)")
            return True

        if cmd == "/pack":
            if len(parts) > 1:
                result = await self.brain.redeem_package_grant(sender_id, parts[1])
                self._reply(sender_id, result)
                return True
            if self.brain.is_admin(sender_id):
                result = await self.brain.send_package_to(sender_id)
                self._reply(sender_id, result)
            else:
                request_id = self.brain.request_package_access(sender_id)
                await self.brain.notify_governance(
                    f"[Package Request] Contact {sender_id} requested package access for bot {self.bot_id}"
                    f"\nRequest ID: {request_id}"
                    f"\nReply /approve {request_id} to grant one-time 24h access"
                    f"\nReply /deny {request_id} to reject"
                )
                self._reply(sender_id, f"Package request submitted: {request_id}")
            return True

        if cmd == "/access":
            if len(parts) < 2:
                mode = self.brain.get_access_mode()
                mode_desc = {"open": "Open (anyone can chat)", "approval": "Approval (admin approval needed)", "private": "Private (admins only)"}
                self._reply(sender_id, f"Current access mode: {mode} — {mode_desc.get(mode, mode)}")
                return True
            if not self.brain.is_creator(sender_id):
                self._reply(sender_id, "Only the creator can change access mode.")
                return True
            new_mode = parts[1].lower()
            if self.brain.set_access_mode(new_mode, actor_jid=sender_id):
                self._reply(sender_id, f"Access mode changed to: {new_mode}")
            else:
                self._reply(sender_id, "Invalid mode. Options: open, approval, private")
            return True

        if cmd == "/approve" and len(parts) > 1:
            result = await self.brain.approve_request(sender_id, parts[1])
            self._reply(sender_id, result)
            return True

        if cmd == "/deny" and len(parts) > 1:
            result = await self.brain.deny_request(sender_id, parts[1])
            self._reply(sender_id, result)
            return True

        return False

    async def handle_governance_nl(self, sender_id: str, body: str) -> bool:
        """Handle natural-language governance commands (admin management by creator)."""
        if not self.brain.is_creator(sender_id):
            return False

        contact_ids = [c for c in _CONTACT_ID_RE.findall(body) if c != self.bot_id]
        if not contact_ids:
            return False

        if any(kw in body for kw in ("管理员", "admin")) and any(key in body for key in ("设为", "加为", "添加", "增加", "add", "set as")):
            added = self.brain.add_admins(contact_ids)
            if added:
                self._reply(sender_id, f"Admin(s) added: {', '.join(added)}")
                return True

        if any(kw in body for kw in ("管理员", "admin")) and any(key in body for key in ("移除", "取消", "删除", "remove", "delete")):
            removed = self.brain.remove_admins(contact_ids)
            if removed:
                self._reply(sender_id, f"Admin(s) removed: {', '.join(removed)}")
                return True

        return False

    async def _run_surf(self, sender_id: str):
        """Run a surfing round and share findings."""
        try:
            await self.brain.do_surf_once(triggered_by=sender_id)
        except Exception as e:
            logger.error(f"[{self.bot_name}] Manual surf error: {e}", exc_info=True)
            try:
                await self.brain._surf_reply(sender_id, f"Error during surfing: {e}")
            except Exception:
                self._reply(sender_id, f"Surfing error: {e}")
