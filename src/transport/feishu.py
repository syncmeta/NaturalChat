"""
feishu.py - Feishu (Lark) transport implementation.

Uses Feishu Open API with webhook for receiving messages and REST API for sending.
Runs an aiohttp server to receive event callbacks from Feishu.
"""

import asyncio
import hashlib
import json
import logging
import time
from datetime import datetime
from typing import Optional

import aiohttp
from aiohttp import web

from src.transport.base import TransportClient
from src.command_router import CommandRouter

logger = logging.getLogger(__name__)

FEISHU_API_BASE = "https://open.feishu.cn/open-apis"


class FeishuTransport(TransportClient):
    """Feishu transport: receives events via webhook, sends via REST API."""

    def __init__(
        self,
        app_id: str,
        app_secret: str,
        verification_token: str = "",
        encrypt_key: str = "",
        bot_name: str = "bot",
        webhook_port: int = 9000,
        msg_wait_initial: float = 2.5,
    ):
        super().__init__(bot_name)
        self.app_id = app_id
        self.app_secret = app_secret
        self.verification_token = verification_token
        self.encrypt_key = encrypt_key
        self.webhook_port = webhook_port
        self.msg_wait_initial = msg_wait_initial
        self._command_router = None
        self._stopping = False

        # Auth token
        self._tenant_access_token: Optional[str] = None
        self._token_expires_at: float = 0

        # Dedup: Feishu may send duplicate events
        self._seen_message_ids: set = set()
        self._seen_message_ids_max = 1000

        # HTTP session
        self._session: Optional[aiohttp.ClientSession] = None

    @property
    def platform(self) -> str:
        return "feishu"

    def wire_brain(self, brain):
        """Wire brain and create command router."""
        self.brain = brain

        def _reply(contact_id, text):
            _, native_id = contact_id.split(":", 1) if ":" in contact_id else ("", contact_id)
            self.send_message_to(native_id, text)

        self._command_router = CommandRouter(
            brain=brain,
            bot_name=self.bot_name,
            reply_fn=_reply,
            bot_id=f"feishu_bot:{self.app_id}",
        )

    # ── Auth ──────────────────────────────────────────────────────────────

    async def _ensure_token(self):
        """Get or refresh tenant_access_token."""
        if self._tenant_access_token and time.time() < self._token_expires_at - 60:
            return

        url = f"{FEISHU_API_BASE}/auth/v3/tenant_access_token/internal"
        payload = {"app_id": self.app_id, "app_secret": self.app_secret}

        async with self._session.post(url, json=payload) as resp:
            data = await resp.json()
            if data.get("code") == 0:
                self._tenant_access_token = data["tenant_access_token"]
                self._token_expires_at = time.time() + data.get("expire", 7200)
                logger.info(f"[{self.bot_name}] Feishu token refreshed")
            else:
                logger.error(f"[{self.bot_name}] Feishu token error: {data}")

    async def _get_headers(self) -> dict:
        await self._ensure_token()
        return {
            "Authorization": f"Bearer {self._tenant_access_token}",
            "Content-Type": "application/json; charset=utf-8",
        }

    # ── Sending ───────────────────────────────────────────────────────────

    def send_message_to(self, contact_id: str, text: str) -> None:
        """Send message to a Feishu user. contact_id is open_id."""
        asyncio.create_task(self._async_send(contact_id, text))

    async def _async_send(self, open_id: str, text: str):
        try:
            headers = await self._get_headers()
            url = f"{FEISHU_API_BASE}/im/v1/messages"
            params = {"receive_id_type": "open_id"}
            payload = {
                "receive_id": open_id,
                "msg_type": "text",
                "content": json.dumps({"text": text}),
            }
            async with self._session.post(url, headers=headers, params=params, json=payload) as resp:
                data = await resp.json()
                if data.get("code") != 0:
                    logger.error(f"[{self.bot_name}] Feishu send error: {data}")
        except Exception as e:
            logger.error(f"[{self.bot_name}] Feishu send exception: {e}")

    def send_composing(self, contact_id: str) -> None:
        """Not supported by Feishu."""
        pass

    def send_active(self, contact_id: str) -> None:
        """Not supported by Feishu."""
        pass

    # ── Webhook server ────────────────────────────────────────────────────

    async def start(self) -> None:
        """Start webhook server to receive Feishu events."""
        self._session = aiohttp.ClientSession()

        app = web.Application()
        app.router.add_post("/feishu/event", self._handle_event)

        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, "0.0.0.0", self.webhook_port)
        await site.start()

        logger.info(f"[{self.bot_name}] Feishu webhook listening on port {self.webhook_port}")

        # Refresh token on startup
        try:
            await self._ensure_token()
        except Exception as e:
            logger.warning(f"[{self.bot_name}] Initial Feishu token fetch failed: {e}")

        # Wait until stopped
        stop_event = asyncio.Event()
        self._stop_event = stop_event
        await stop_event.wait()

        # Cleanup
        await runner.cleanup()
        await self._session.close()

    def stop(self) -> None:
        self._stopping = True
        if hasattr(self, '_stop_event'):
            self._stop_event.set()

    async def _handle_event(self, request: web.Request) -> web.Response:
        """Handle incoming Feishu event callback."""
        try:
            data = await request.json()
        except Exception:
            return web.Response(status=400)

        # URL verification challenge
        if "challenge" in data:
            return web.json_response({"challenge": data["challenge"]})

        # Verify token if configured
        if self.verification_token:
            token = data.get("token", "")
            if token != self.verification_token:
                return web.Response(status=403)

        # Process event asynchronously
        header = data.get("header", {})
        event = data.get("event", {})
        event_type = header.get("event_type", "")

        if event_type == "im.message.receive_v1":
            asyncio.create_task(self._on_message_event(event))

        return web.json_response({"code": 0})

    async def _on_message_event(self, event: dict):
        """Handle a received message event."""
        message = event.get("message", {})
        sender = event.get("sender", {})

        msg_id = message.get("message_id", "")
        msg_type = message.get("message_type", "")
        chat_type = message.get("chat_type", "")

        # Dedup
        if msg_id in self._seen_message_ids:
            return
        self._seen_message_ids.add(msg_id)
        if len(self._seen_message_ids) > self._seen_message_ids_max:
            # Trim oldest (set doesn't preserve order, but this is good enough)
            self._seen_message_ids = set(list(self._seen_message_ids)[-500:])

        # Only handle text messages in p2p chats for now
        if msg_type != "text":
            return
        if chat_type != "p2p":
            return

        # Extract text content
        try:
            content = json.loads(message.get("content", "{}"))
            text = content.get("text", "").strip()
        except (json.JSONDecodeError, AttributeError):
            return

        if not text:
            return

        open_id = sender.get("sender_id", {}).get("open_id", "")
        if not open_id:
            return

        prefixed_id = self.make_prefixed_id(open_id)
        now = datetime.now()

        logger.info(f"[{self.bot_name}] Feishu message from {open_id}: {text}")

        # Handle slash commands
        if text.startswith("/") and self._command_router:
            handled = await self._command_router.handle_command(prefixed_id, text)
            if handled:
                return

        if self._command_router and await self._command_router.handle_governance_nl(prefixed_id, text):
            return

        if self.brain and not self.brain.can_chat_with(prefixed_id):
            logger.info(f"[{self.bot_name}] Blocked Feishu message from {open_id}: not approved")
            return

        # Use base class unified debounce
        self._buffer_message(prefixed_id, text)
