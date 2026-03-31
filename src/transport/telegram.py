"""
telegram.py - Telegram Bot transport implementation.

Uses python-telegram-bot (async) for receiving and sending messages.
Telegram Bot API does not push user typing indicators, so this transport
relies on the LLM-based debounce judge in the base TransportClient.
"""

import asyncio
import logging
import os
from datetime import datetime

from telegram import Update, BotCommand, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    MessageHandler,
    CommandHandler,
    filters,
    ContextTypes,
)

from src.transport.base import TransportClient
from src.command_router import CommandRouter

logger = logging.getLogger(__name__)
_APPROVE_RE = __import__("re").compile(r"/approve\s+([A-Za-z0-9_]+)")
_DENY_RE = __import__("re").compile(r"/deny\s+([A-Za-z0-9_]+)")


class TelegramTransport(TransportClient):
    """Telegram Bot transport: connects via Bot API and relays messages to BotBrain."""

    def __init__(
        self,
        token: str,
        bot_name: str,
        msg_wait_initial: float = 2.5,
    ):
        super().__init__(bot_name)
        self.token = token
        self.msg_wait_initial = msg_wait_initial
        self._command_router = None
        self._app = None
        self._stopping = False

    @property
    def platform(self) -> str:
        return "telegram"

    def wire_brain(self, brain):
        """Wire brain and create command router."""
        self.brain = brain

        def _reply(contact_id, text):
            # contact_id is prefixed; extract native chat_id
            _, native_id = contact_id.split(":", 1) if ":" in contact_id else ("", contact_id)
            self.send_message_to(native_id, text)

        self._command_router = CommandRouter(
            brain=brain,
            bot_name=self.bot_name,
            reply_fn=_reply,
            bot_id=f"tg_bot:{self.bot_name}",
        )

    def send_message_to(self, contact_id: str, text: str) -> None:
        """Send a message to a Telegram chat. contact_id is a chat_id string."""
        if self._app and self._app.bot:
            asyncio.create_task(self._async_send(int(contact_id), text))

    async def _async_send(self, chat_id: int, text: str):
        """Actually send the message (async)."""
        try:
            reply_markup = self._build_governance_markup(text)
            # Telegram has a 4096 char limit per message
            if len(text) <= 4096:
                await self._app.bot.send_message(chat_id=chat_id, text=text, reply_markup=reply_markup)
            else:
                # Split into chunks
                for i in range(0, len(text), 4096):
                    await self._app.bot.send_message(
                        chat_id=chat_id,
                        text=text[i:i+4096],
                        reply_markup=reply_markup if i == 0 else None,
                    )
        except Exception as e:
            logger.error(f"[{self.bot_name}] Telegram send error to {chat_id}: {e}")

    def _build_governance_markup(self, text: str):
        approve_match = _APPROVE_RE.search(text or "")
        deny_match = _DENY_RE.search(text or "")
        if not approve_match and not deny_match:
            return None
        request_id = (approve_match or deny_match).group(1)
        keyboard = [[
            InlineKeyboardButton("Approve", callback_data=f"approve:{request_id}"),
            InlineKeyboardButton("Deny", callback_data=f"deny:{request_id}"),
        ]]
        return InlineKeyboardMarkup(keyboard)

    def send_composing(self, contact_id: str) -> None:
        """Send typing indicator."""
        if self._app and self._app.bot:
            asyncio.create_task(self._async_send_typing(int(contact_id)))

    async def _async_send_typing(self, chat_id: int):
        try:
            await self._app.bot.send_chat_action(chat_id=chat_id, action="typing")
        except Exception:
            pass

    def send_active(self, contact_id: str) -> None:
        """No-op: Telegram automatically stops typing indicator."""
        pass

    def send_file_to(self, contact_id: str, file_path: str, caption: str = "") -> bool:
        if not self._app or not self._app.bot or not os.path.isfile(file_path):
            return False
        asyncio.create_task(self._async_send_file(int(contact_id), file_path, caption))
        return True

    async def _async_send_file(self, chat_id: int, file_path: str, caption: str = ""):
        try:
            with open(file_path, "rb") as f:
                await self._app.bot.send_document(chat_id=chat_id, document=f, filename=os.path.basename(file_path), caption=caption or None)
        except Exception as e:
            logger.error(f"[{self.bot_name}] Telegram file send error to {chat_id}: {e}")

    async def start(self) -> None:
        """Build and run the Telegram bot application."""
        self._app = Application.builder().token(self.token).build()

        # Register handlers
        self._app.add_handler(CommandHandler("start", self._on_command))
        self._app.add_handler(CommandHandler("pack", self._on_command))
        self._app.add_handler(CommandHandler("surf", self._on_command))
        self._app.add_handler(CommandHandler("reset", self._on_command))
        self._app.add_handler(CommandHandler("access", self._on_command))
        self._app.add_handler(CommandHandler("approve", self._on_command))
        self._app.add_handler(CommandHandler("deny", self._on_command))
        self._app.add_handler(CallbackQueryHandler(self._on_callback_query))
        self._app.add_handler(MessageHandler(filters.Document.ALL, self._on_document_message))
        self._app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, self._on_text_message))

        # Set bot commands menu
        try:
            await self._app.bot.set_my_commands([
                BotCommand("start", "Initialize this bot"),
                BotCommand("pack", "Request or download this bot package"),
                BotCommand("surf", "Trigger surfing"),
                BotCommand("reset", "Reset conversation"),
                BotCommand("access", "Show or change access mode"),
            ])
        except Exception:
            pass

        logger.info(f"[{self.bot_name}] Telegram transport starting...")

        # Initialize and start polling
        await self._app.initialize()
        await self._app.start()
        await self._app.updater.start_polling(drop_pending_updates=True)

        logger.info(f"[{self.bot_name}] Telegram transport running")

        # Wait until stopped
        stop_event = asyncio.Event()
        self._stop_event = stop_event
        await stop_event.wait()

        # Cleanup
        await self._app.updater.stop()
        await self._app.stop()
        await self._app.shutdown()

    def stop(self) -> None:
        self._stopping = True
        if hasattr(self, '_stop_event'):
            self._stop_event.set()

    # ── Message handlers ─────────────────────────────────────────────

    async def _on_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle /command messages."""
        if not update.message or not update.message.text:
            return

        chat_id = str(update.message.chat_id)
        prefixed_id = self.make_prefixed_id(chat_id)
        body = update.message.text.strip()

        # Normalize Telegram /command@botname to /command
        if "@" in body.split()[0]:
            parts = body.split()
            parts[0] = parts[0].split("@")[0]
            body = " ".join(parts)

        if self._command_router:
            await self._command_router.handle_command(prefixed_id, body)

    async def _on_text_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle regular text messages with unified debounce."""
        if not update.message or not update.message.text:
            return

        chat_id = str(update.message.chat_id)
        prefixed_id = self.make_prefixed_id(chat_id)
        body = update.message.text.strip()

        logger.info(f"[{self.bot_name}] TG message from {chat_id}: {body}")

        # Governance NL handling
        if self._command_router and await self._command_router.handle_governance_nl(prefixed_id, body):
            return

        if self.brain and not self.brain.can_chat_with(prefixed_id):
            logger.info(f"[{self.bot_name}] Blocked TG message from {chat_id}: not approved")
            return

        # Use base class unified debounce
        self._buffer_message(prefixed_id, body)

    async def _on_document_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle uploaded package files for self-update."""
        if not update.message or not update.message.document:
            return

        chat_id = str(update.message.chat_id)
        prefixed_id = self.make_prefixed_id(chat_id)
        document = update.message.document
        filename = document.file_name or ""

        if not filename.endswith(".tar.gz"):
            self.send_message_to(chat_id, "Only .tar.gz bot packages are supported for updates.")
            return

        if not self.brain or not self.brain.bot_dir:
            self.send_message_to(chat_id, "Bot update storage is not available.")
            return

        inbox_dir = os.path.join(self.brain.bot_dir, "inbox")
        os.makedirs(inbox_dir, exist_ok=True)
        target_path = os.path.join(inbox_dir, f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{filename}")

        try:
            tg_file = await context.bot.get_file(document.file_id)
            await tg_file.download_to_drive(custom_path=target_path)
        except Exception as e:
            logger.error(f"[{self.bot_name}] Failed to download package from Telegram: {e}", exc_info=True)
            self.send_message_to(chat_id, "Failed to download the package.")
            return

        request_id = self.brain.request_update_from_package(target_path, detected_by=prefixed_id)
        recipients = self.brain.governance_recipients()
        if recipients:
            await self.brain.notify_governance(
                f"[Update Package] Detected package for bot {self.bot_name}"
                f"\nFile: {os.path.basename(target_path)}"
                f"\nUploaded by: {prefixed_id}"
                f"\nRequest ID: {request_id}"
                f"\nReply /approve {request_id} to update this bot"
                f"\nReply /deny {request_id} to ignore it"
            )
        self.send_message_to(chat_id, f"Package uploaded: {os.path.basename(target_path)}. Awaiting approval ({request_id}).")

    async def _on_callback_query(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Handle governance approve/deny buttons."""
        if not update.callback_query or not update.callback_query.data:
            return
        query = update.callback_query
        await query.answer()

        chat_id = str(query.message.chat_id) if query.message else ""
        prefixed_id = self.make_prefixed_id(chat_id) if chat_id else ""
        action, _, request_id = query.data.partition(":")
        if not prefixed_id or action not in {"approve", "deny"} or not request_id:
            return

        if action == "approve":
            result = await self.brain.approve_request(prefixed_id, request_id)
        else:
            result = await self.brain.deny_request(prefixed_id, request_id)

        try:
            await query.edit_message_reply_markup(reply_markup=None)
        except Exception:
            pass
        self.send_message_to(chat_id, result)
