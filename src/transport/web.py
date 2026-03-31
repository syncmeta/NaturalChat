"""
web.py - Web panel transport for NaturalChat.

Messages flow through WebSocket connections managed by the web panel server.
This transport handles the BotBrain integration side.
"""

import asyncio
import logging
from typing import Dict, Callable, Optional

from src.transport.base import TransportClient
from src.command_router import CommandRouter

logger = logging.getLogger(__name__)


class WebTransport(TransportClient):
    """Web panel transport: bridges WebSocket connections to BotBrain."""

    def __init__(self, bot_name: str):
        super().__init__(bot_name)
        self.supports_typing = False
        self._ws_connections: Dict[str, list] = {}  # session_id -> [ws, ...]
        self._command_router = None
        self._stop_event = None

    @property
    def platform(self) -> str:
        return "web"

    def wire_brain(self, brain):
        self.brain = brain

        def _reply(contact_id, text):
            _, native_id = contact_id.split(":", 1) if ":" in contact_id else ("", contact_id)
            self.send_message_to(native_id, text)

        self._command_router = CommandRouter(
            brain=brain,
            bot_name=self.bot_name,
            reply_fn=_reply,
            bot_id=f"web:{self.bot_name}",
        )

    async def start(self) -> None:
        """Wait until stopped. The web server is managed externally."""
        logger.info(f"[{self.bot_name}] Web transport ready")
        self._stop_event = asyncio.Event()
        await self._stop_event.wait()

    def stop(self) -> None:
        if self._stop_event:
            self._stop_event.set()

    def register_ws(self, session_id: str, ws) -> None:
        """Register a WebSocket connection for a session."""
        if session_id not in self._ws_connections:
            self._ws_connections[session_id] = []
        self._ws_connections[session_id].append(ws)
        logger.debug(f"[{self.bot_name}] WS registered for session {session_id}")

    def unregister_ws(self, session_id: str, ws) -> None:
        """Remove a WebSocket connection."""
        if session_id in self._ws_connections:
            self._ws_connections[session_id] = [
                w for w in self._ws_connections[session_id] if w is not ws
            ]
            if not self._ws_connections[session_id]:
                del self._ws_connections[session_id]

    async def handle_web_message(self, session_id: str, text: str) -> None:
        """Called by the web panel server when a message arrives via WebSocket."""
        prefixed_id = self.make_prefixed_id(session_id)

        # Check access
        if self.brain and not self.brain.can_chat_with(prefixed_id):
            await self._ws_send(session_id, {
                "type": "error",
                "text": "Access denied. Contact the bot admin.",
            })
            return

        # Check for slash commands
        if self._command_router and text.startswith("/"):
            handled = await self._command_router.handle_governance_nl(prefixed_id, text)
            if handled:
                return

        # Buffer message (triggers debounce -> brain processing -> send_message_to callback)
        self._buffer_message(prefixed_id, text)

    def send_message_to(self, contact_id: str, text: str) -> None:
        """Send reply to a session. contact_id is session_id (no platform prefix)."""
        asyncio.create_task(self._ws_send(contact_id, {
            "type": "message",
            "text": text,
            "bot": self.bot_name,
        }))

    def send_composing(self, contact_id: str) -> None:
        """Send typing indicator."""
        asyncio.create_task(self._ws_send(contact_id, {
            "type": "typing",
            "bot": self.bot_name,
        }))

    def send_active(self, contact_id: str) -> None:
        """Stop typing indicator."""
        asyncio.create_task(self._ws_send(contact_id, {
            "type": "typing_stop",
            "bot": self.bot_name,
        }))

    def send_file_to(self, contact_id: str, file_path: str, caption: str = "") -> bool:
        """Send file info to web client."""
        asyncio.create_task(self._ws_send(contact_id, {
            "type": "file",
            "path": file_path,
            "caption": caption,
            "bot": self.bot_name,
        }))
        return True

    async def _ws_send(self, session_id: str, data: dict) -> None:
        """Send JSON data to all WebSocket connections for a session."""
        import json
        ws_list = self._ws_connections.get(session_id, [])
        msg = json.dumps(data, ensure_ascii=False)
        dead = []
        for ws in ws_list:
            try:
                await ws.send_str(msg)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.unregister_ws(session_id, ws)
