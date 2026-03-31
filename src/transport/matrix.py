"""
matrix.py - Matrix transport implementation.

Uses matrix-nio (async) for connecting to Matrix homeservers.
Supports both access_token and password authentication.
Supports receiving typing indicators via m.typing events.
"""

import asyncio
import logging
from datetime import datetime
from typing import Optional

from nio import AsyncClient, MatrixRoom, RoomMessageText, LoginResponse, InviteMemberEvent

from src.transport.base import TransportClient
from src.command_router import CommandRouter

logger = logging.getLogger(__name__)

# Try to import TypingNoticeEvent (available in matrix-nio)
try:
    from nio import TypingNoticeEvent
    _HAS_TYPING_EVENT = True
except ImportError:
    _HAS_TYPING_EVENT = False


class MatrixTransport(TransportClient):
    """Matrix transport: connects to a homeserver and relays messages to BotBrain."""

    def __init__(
        self,
        homeserver_url: str,
        user_id: str,
        access_token: str = "",
        password: str = "",
        bot_name: str = "bot",
        device_name: str = "NaturalChat",
        msg_wait_initial: float = 2.5,
        msg_wait_after_typing_stop: float = 5.0,
        typing_hard_timeout: float = 10.0,
    ):
        super().__init__(bot_name)
        self.homeserver_url = homeserver_url
        self.user_id = user_id
        self.access_token = access_token
        self.password = password
        self.device_name = device_name
        self.msg_wait_initial = msg_wait_initial
        self.msg_wait_after_typing_stop = msg_wait_after_typing_stop
        self.typing_hard_timeout = typing_hard_timeout
        self.supports_typing = _HAS_TYPING_EVENT
        self._command_router = None
        self._stopping = False
        self._client: Optional[AsyncClient] = None

        # Track which sync token we've seen to avoid replaying old messages
        self._initial_sync_done = False

    @property
    def platform(self) -> str:
        return "matrix"

    def wire_brain(self, brain):
        self.brain = brain

        def _reply(contact_id, text):
            _, native_id = contact_id.split(":", 1) if ":" in contact_id else ("", contact_id)
            self.send_message_to(native_id, text)

        self._command_router = CommandRouter(
            brain=brain,
            bot_name=self.bot_name,
            reply_fn=_reply,
            bot_id=self.user_id,
        )

    def send_message_to(self, room_id: str, text: str) -> None:
        if self._client:
            asyncio.create_task(self._async_send(room_id, text))

    async def _async_send(self, room_id: str, text: str):
        try:
            await self._client.room_send(
                room_id=room_id,
                message_type="m.room.message",
                content={"msgtype": "m.text", "body": text},
            )
        except Exception as e:
            logger.error(f"[{self.bot_name}] Matrix send error to {room_id}: {e}")

    def send_composing(self, room_id: str) -> None:
        if self._client:
            asyncio.create_task(self._async_typing(room_id, True))

    def send_active(self, room_id: str) -> None:
        if self._client:
            asyncio.create_task(self._async_typing(room_id, False))

    async def _async_typing(self, room_id: str, typing: bool):
        try:
            await self._client.room_typing(room_id, typing, timeout=10000)
        except Exception:
            pass

    async def start(self) -> None:
        self._client = AsyncClient(self.homeserver_url, self.user_id)

        # Authenticate
        if self.access_token:
            self._client.access_token = self.access_token
            self._client.user_id = self.user_id
            self._client.device_id = self.device_name
            logger.info(f"[{self.bot_name}] Matrix: using access_token auth")
        elif self.password:
            resp = await self._client.login(self.password, device_name=self.device_name)
            if isinstance(resp, LoginResponse):
                logger.info(f"[{self.bot_name}] Matrix: logged in as {self.user_id}")
            else:
                logger.error(f"[{self.bot_name}] Matrix login failed: {resp}")
                return
        else:
            logger.error(f"[{self.bot_name}] Matrix: no access_token or password provided")
            return

        # Register callbacks
        self._client.add_event_callback(self._on_room_message, RoomMessageText)
        self._client.add_event_callback(self._on_invite, InviteMemberEvent)
        if _HAS_TYPING_EVENT:
            self._client.add_event_callback(self._on_typing_event, TypingNoticeEvent)

        logger.info(f"[{self.bot_name}] Matrix transport starting sync...")

        # Do initial sync to get current state (skip old messages)
        await self._client.sync(timeout=10000, full_state=True)
        self._initial_sync_done = True
        logger.info(f"[{self.bot_name}] Matrix: initial sync done, listening for messages")

        # Sync forever
        try:
            await self._client.sync_forever(timeout=30000)
        except Exception as e:
            if not self._stopping:
                logger.error(f"[{self.bot_name}] Matrix sync error: {e}")

        await self._client.close()

    def stop(self) -> None:
        self._stopping = True
        if self._client:
            asyncio.create_task(self._client.close())

    # ── Event handlers ────────────────────────────────────────────────────

    async def _on_invite(self, room: MatrixRoom, event: InviteMemberEvent):
        """Auto-join rooms when invited."""
        if event.state_key == self.user_id:
            logger.info(f"[{self.bot_name}] Matrix: invited to {room.room_id}, joining...")
            await self._client.join(room.room_id)

    async def _on_room_message(self, room: MatrixRoom, event: RoomMessageText):
        """Handle incoming text messages."""
        if not self._initial_sync_done:
            return
        if event.sender == self.user_id:
            return

        body = event.body.strip()
        if not body:
            return

        prefixed_id = self.make_prefixed_id(room.room_id)

        logger.info(f"[{self.bot_name}] Matrix message in {room.room_id} from {event.sender}: {body}")

        # Slash commands
        if body.startswith("/") and self._command_router:
            handled = await self._command_router.handle_command(prefixed_id, body)
            if handled:
                return

        if self._command_router and await self._command_router.handle_governance_nl(prefixed_id, body):
            return

        if self.brain and not self.brain.can_chat_with(prefixed_id):
            logger.info(f"[{self.bot_name}] Blocked Matrix message in {room.room_id}: not approved")
            return

        # Use base class unified debounce
        self._buffer_message(prefixed_id, body)

    async def _on_typing_event(self, room: MatrixRoom, event):
        """Handle typing notifications from Matrix."""
        prefixed_id = self.make_prefixed_id(room.room_id)

        # Check if any user other than ourselves is typing
        typing_users = [u for u in (event.users or []) if u != self.user_id]

        if typing_users:
            self._on_typing_started(prefixed_id)
        else:
            self._on_typing_stopped(prefixed_id)
