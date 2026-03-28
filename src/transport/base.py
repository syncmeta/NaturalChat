"""
base.py - Abstract base class for all transport clients.

Each transport (XMPP, Telegram, Matrix, Feishu) implements this interface.
BotBrain communicates with transports only through these methods.

Also provides unified message batching and debounce logic:
  - Platforms with typing indicators (XMPP, Matrix): wait for typing to stop + cooldown
  - Platforms without (Telegram, Feishu): use a small LLM to judge whether user is done
"""

import asyncio
import logging
import time
from abc import ABC, abstractmethod
from datetime import datetime
from typing import Optional

from src.contact_ids import make_contact_id

logger = logging.getLogger(__name__)


class TransportClient(ABC):
    """Abstract transport layer for a single bot on a single platform."""

    def __init__(self, bot_name: str):
        self.bot_name = bot_name
        self.brain = None  # Set by BotInstance after creation

        # Message batching state (per prefixed contact ID)
        self._msg_buffers: dict[str, list] = {}
        self._batch_tasks: dict[str, asyncio.Task] = {}

        # Typing state (for platforms that support it)
        self._composing_state: dict[str, bool] = {}
        self._composing_hard_deadline: dict[str, float] = {}

        # Debounce config (can be overridden by subclass __init__)
        self.msg_wait_initial: float = 2.5
        self.msg_wait_after_typing_stop: float = 5.0
        self.typing_hard_timeout: float = 10.0

        # Subclass should set to True if the platform pushes typing events
        self.supports_typing: bool = False

    @property
    @abstractmethod
    def platform(self) -> str:
        """Platform identifier: 'xmpp', 'telegram', 'matrix', 'feishu'."""
        ...

    @abstractmethod
    async def start(self) -> None:
        """Connect and start receiving messages."""
        ...

    @abstractmethod
    def stop(self) -> None:
        """Disconnect and clean up."""
        ...

    @abstractmethod
    def send_message_to(self, contact_id: str, text: str) -> None:
        """Send a text message to a contact (native ID, no platform prefix)."""
        ...

    @abstractmethod
    def send_composing(self, contact_id: str) -> None:
        """Indicate that the bot is typing. No-op if unsupported."""
        ...

    @abstractmethod
    def send_active(self, contact_id: str) -> None:
        """Indicate that the bot stopped typing. No-op if unsupported."""
        ...

    def approve_contact(self, contact_id: str) -> None:
        """Approve a contact/subscription request. Override if needed."""
        pass

    def send_file_to(self, contact_id: str, file_path: str, caption: str = "") -> bool:
        """Send a file to a contact. Override if supported."""
        return False

    def make_prefixed_id(self, native_id: str) -> str:
        """Create a canonical contact ID for this transport."""
        return make_contact_id(self.platform, native_id)

    # ── Unified message batching / debounce ──────────────────────────────

    def _buffer_message(self, prefixed_id: str, text: str):
        """Buffer an incoming message and start/restart the batch timer.

        Each transport's message handler should call this after access checks.
        """
        now = datetime.now()

        if self.brain:
            self.brain.on_new_message(prefixed_id)

        if prefixed_id not in self._msg_buffers:
            self._msg_buffers[prefixed_id] = []
        self._msg_buffers[prefixed_id].append((text, now))

        self._restart_batch_timer(prefixed_id)

    def _on_typing_started(self, prefixed_id: str):
        """Called when the remote user starts typing (platforms that support it)."""
        was_composing = self._composing_state.get(prefixed_id, False)
        self._composing_state[prefixed_id] = True

        # Set hard deadline on first typing event for this batch
        if not was_composing and prefixed_id not in self._composing_hard_deadline:
            self._composing_hard_deadline[prefixed_id] = time.time() + self.typing_hard_timeout

        logger.debug(f"[{self.bot_name}] {prefixed_id} typing started")

    def _on_typing_stopped(self, prefixed_id: str):
        """Called when the remote user stops typing (active/paused)."""
        if not self._composing_state.get(prefixed_id):
            return
        self._composing_state[prefixed_id] = False
        logger.debug(f"[{self.bot_name}] {prefixed_id} typing stopped")
        self._restart_batch_timer(prefixed_id)

    def _restart_batch_timer(self, prefixed_id: str):
        """Cancel any pending batch timer and start a new one."""
        task = self._batch_tasks.pop(prefixed_id, None)
        if task and not task.done():
            task.cancel()
        self._batch_tasks[prefixed_id] = asyncio.create_task(
            self._batch_wait(prefixed_id)
        )

    async def _batch_wait(self, prefixed_id: str):
        """Core debounce logic. Waits for user to finish, then processes."""
        try:
            # Phase 1: initial silence wait
            await asyncio.sleep(self.msg_wait_initial)

            if self.supports_typing:
                await self._batch_wait_typing(prefixed_id)
            else:
                await self._batch_wait_llm_judge(prefixed_id)

            # Assemble and process
            full_content = self._assemble_batch(prefixed_id)
            if not full_content:
                return

            if self.brain:
                lock = self.brain.get_lock(prefixed_id)
                async with lock:
                    # Absorb any messages that arrived while waiting for the lock
                    extra = self._assemble_batch(prefixed_id)
                    if extra:
                        full_content = full_content + "\n" + extra
                    await self._process_and_reply(prefixed_id, full_content)
        except asyncio.CancelledError:
            pass

    async def _batch_wait_typing(self, prefixed_id: str):
        """Typing-aware wait (XMPP, Matrix).

        After the initial 2.5s:
        - If user is typing: wait until they stop, then wait 5s more
        - Hard timeout 10s from first typing event
        - Each new typing event resets the 5s post-stop timer
        """
        if not self._composing_state.get(prefixed_id):
            # No typing detected during initial wait → process immediately
            return

        hard_deadline = self._composing_hard_deadline.get(prefixed_id, time.time() + self.typing_hard_timeout)

        # Wait for typing to stop (or hard timeout)
        while self._composing_state.get(prefixed_id):
            if time.time() >= hard_deadline:
                logger.debug(f"[{self.bot_name}] {prefixed_id} typing hard timeout reached")
                break
            await asyncio.sleep(0.5)

        # Typing stopped — wait 5s cooldown
        if time.time() < hard_deadline:
            cooldown_end = time.time() + self.msg_wait_after_typing_stop
            while time.time() < cooldown_end and time.time() < hard_deadline:
                if self._composing_state.get(prefixed_id):
                    # User started typing again — wait for them to stop, then reset 5s
                    while self._composing_state.get(prefixed_id):
                        if time.time() >= hard_deadline:
                            break
                        await asyncio.sleep(0.5)
                    # Reset cooldown (still bounded by hard deadline)
                    cooldown_end = time.time() + self.msg_wait_after_typing_stop
                await asyncio.sleep(0.5)

        # Clean up typing state for this batch
        self._composing_state.pop(prefixed_id, None)
        self._composing_hard_deadline.pop(prefixed_id, None)

    async def _batch_wait_llm_judge(self, prefixed_id: str):
        """LLM-based wait for platforms without typing indicators.

        After the initial 2.5s, asks a small model whether the user is done.
        If the model says wait, waits up to 10s for more messages.
        If a new message arrives during that 10s, restarts the whole flow.
        """
        if not self.brain:
            return

        buffer = self._msg_buffers.get(prefixed_id, [])
        if not buffer:
            return

        texts = [text for text, _ in buffer]

        try:
            should_wait = await self.brain.should_wait_for_more(prefixed_id, texts)
        except Exception as e:
            logger.debug(f"[{self.bot_name}] Debounce LLM judge failed: {e}")
            should_wait = False

        if not should_wait:
            return

        # Wait up to 10s; if new message arrives, restart the whole flow
        old_count = len(self._msg_buffers.get(prefixed_id, []))
        waited = 0.0
        while waited < self.typing_hard_timeout:
            await asyncio.sleep(0.5)
            waited += 0.5
            new_count = len(self._msg_buffers.get(prefixed_id, []))
            if new_count > old_count:
                # New message arrived — restart entire debounce flow
                self._restart_batch_timer(prefixed_id)
                return  # This task ends; new timer takes over

        # 10s passed with no new message — proceed to process

    def _assemble_batch(self, prefixed_id: str) -> str:
        """Pop all buffered messages and assemble into a single string."""
        buffer = self._msg_buffers.pop(prefixed_id, [])
        if not buffer:
            return ""

        parts = []
        log_parts = []
        for text, ts in buffer:
            ts_str = ts.strftime("%Y-%m-%d %H:%M:%S")
            parts.append(f"[{ts_str}] {text}")
            log_parts.append(f"{ts_str}: received")
        log_parts.append(f"{datetime.now().strftime('%H:%M:%S')}: processing")

        assembled_body = "\n".join(parts)
        if len(buffer) > 1:
            batch_log = "(message timeline: " + " → ".join(log_parts) + ")"
            return batch_log + "\n" + assembled_body
        return assembled_body

    async def _process_and_reply(self, prefixed_id: str, body: str):
        """Process message through brain and handle errors."""
        try:
            chat_result = await self.brain.handle_message(prefixed_id, body)
            asyncio.create_task(self.brain.post_reply_actions(prefixed_id, chat_result))
        except Exception as e:
            logger.error(f"[{self.bot_name}] Error processing message for {prefixed_id}: {e}", exc_info=True)
            _, native_id = prefixed_id.split(":", 1)
            self.send_message_to(native_id, "Sorry, something went wrong. Please try again later.")
