"""
xmpp.py - XMPP transport implementation.

Handles XMPP connection, composing state detection, and reply sending.
Message batching/debounce is handled by the base TransportClient.
"""

import asyncio
import logging
import ssl
from datetime import datetime

import slixmpp

from src.transport.base import TransportClient
from src.command_router import CommandRouter

logger = logging.getLogger(__name__)


class XMPPTransport(TransportClient, slixmpp.ClientXMPP):
    """XMPP transport: connects to an XMPP server and relays messages to BotBrain."""

    def __init__(
        self,
        jid: str,
        password: str,
        bot_name: str,
        msg_wait_initial: float = 2.5,
        msg_wait_after_typing_stop: float = 5.0,
        typing_hard_timeout: float = 10.0,
        xmpp_host: str = "localhost",
        xmpp_port: int = 5222,
    ):
        TransportClient.__init__(self, bot_name)
        slixmpp.ClientXMPP.__init__(self, jid, password)

        self.msg_wait_initial = msg_wait_initial
        self.msg_wait_after_typing_stop = msg_wait_after_typing_stop
        self.typing_hard_timeout = typing_hard_timeout
        self.supports_typing = True

        self.xmpp_host = xmpp_host
        self.xmpp_port = xmpp_port
        self._stopping = False
        self._stop_event = asyncio.Event()
        self._command_router = None

        # Register event handlers
        self.add_event_handler("session_start", self._on_session_start)
        self.add_event_handler("message", self._on_message)
        self.add_event_handler("presence_subscribe", self._on_subscribe)
        self.add_event_handler("chatstate_composing", self._on_composing)
        self.add_event_handler("chatstate_active", self._on_chat_active)
        self.add_event_handler("chatstate_paused", self._on_chat_paused)

        # Register plugins
        self.register_plugin("xep_0030")
        self.register_plugin("xep_0199")
        self.register_plugin("xep_0085")
        self.register_plugin("xep_0184")

        # Disable TLS/SSL
        self.use_tls = False
        self.use_ssl = False
        ssl_ctx = ssl.create_default_context()
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode = ssl.CERT_NONE
        self.ssl_context = ssl_ctx

    # ── TransportClient interface ──────────────────────────────────────────

    @property
    def platform(self) -> str:
        return "xmpp"

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
            bot_id=self.boundjid.bare,
        )

    def send_message_to(self, contact_id: str, text: str) -> None:
        """Send a chat message. contact_id is a bare JID (no platform prefix)."""
        self.send_message(mto=contact_id, mbody=text, mtype="chat")

    def send_composing(self, contact_id: str) -> None:
        msg = self.make_message(mto=contact_id, mtype="chat")
        msg["chat_state"] = "composing"
        msg.send()

    def send_active(self, contact_id: str) -> None:
        msg = self.make_message(mto=contact_id, mtype="chat")
        msg["chat_state"] = "active"
        msg.send()

    def approve_contact(self, contact_id: str) -> None:
        self.send_presence(pto=contact_id, ptype="subscribed")
        self.send_presence(pto=contact_id, ptype="subscribe")

    async def start(self) -> None:
        """Connect and run until stopped."""
        self.add_event_handler("disconnected", self._on_disconnected)
        self.connect(
            address=(self.xmpp_host, self.xmpp_port),
            disable_starttls=True,
            use_ssl=False,
        )
        await self._stop_event.wait()

    def stop(self) -> None:
        self._stopping = True
        self.disconnect()

    # ── XMPP event handlers ───────────────────────────────────────────────

    async def _on_session_start(self, event):
        await self.get_roster()
        self.send_presence()
        logger.info(f"[{self.bot_name}] Connected and online as {self.boundjid.bare}")

    async def _on_subscribe(self, presence):
        requester_jid = presence["from"].bare
        status_msg = (presence.get("status") or "").strip()
        logger.info(f"[{self.bot_name}] Subscribe request from {requester_jid}: {status_msg}")

        if not self.brain.requires_contact_approval():
            self.send_presence(pto=requester_jid, ptype="subscribed")
            self.send_presence(pto=requester_jid, ptype="subscribe")
            return

        prefixed_id = self.make_prefixed_id(requester_jid)
        request_id = self.brain.request_contact_approval(prefixed_id, status_msg)
        await self.brain.notify_governance(
            f"[Friend request] {requester_jid} wants to add {self.boundjid.bare}"
            f"\nMessage: {status_msg or 'none'}"
            f"\nRequest ID: {request_id}"
            f"\nAny admin or creator can reply /approve {request_id} to accept"
        )

    # ── Message reception ─────────────────────────────────────────────────

    async def _on_message(self, msg):
        """Buffer incoming messages via base class debounce."""
        if msg["type"] not in ("chat", "normal"):
            return
        if msg["from"].bare == self.boundjid.bare:
            return
        body = msg.get("body", "").strip()
        if not body:
            return

        sender_jid = msg["from"].bare
        prefixed_id = self.make_prefixed_id(sender_jid)
        ts_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        logger.info(f"[{self.bot_name}] Message from {sender_jid} at {ts_str}: {body}")

        # Handle slash commands
        if body.startswith("/") and self._command_router:
            handled = await self._command_router.handle_command(prefixed_id, body)
            if handled:
                return

        if self._command_router and await self._command_router.handle_governance_nl(prefixed_id, body):
            return

        if self.brain and not self.brain.can_chat_with(prefixed_id):
            logger.info(f"[{self.bot_name}] Blocked message from {sender_jid}: not approved")
            return

        # Use base class unified debounce
        self._buffer_message(prefixed_id, body)

    def _on_composing(self, msg):
        jid = msg["from"].bare
        prefixed_id = self.make_prefixed_id(jid)
        self._on_typing_started(prefixed_id)

    def _on_chat_active(self, msg):
        jid = msg["from"].bare
        prefixed_id = self.make_prefixed_id(jid)
        self._on_typing_stopped(prefixed_id)

    def _on_chat_paused(self, msg):
        jid = msg["from"].bare
        prefixed_id = self.make_prefixed_id(jid)
        self._on_typing_stopped(prefixed_id)

    # ── Connection lifecycle ─────────────────────────────────────────────

    async def _on_disconnected(self, event):
        if self._stopping:
            self._stop_event.set()
            return
        logger.warning(f"[{self.bot_name}] Disconnected, reconnecting in 5s...")
        await asyncio.sleep(5)
        self.connect(
            address=(self.xmpp_host, self.xmpp_port),
            disable_starttls=True,
            use_ssl=False,
        )
