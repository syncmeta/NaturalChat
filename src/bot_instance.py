"""
bot_instance.py - A single bot running on multiple transports.

One BotInstance = one BotBrain (shared) + multiple TransportClients.
The brain's send/composing/active callbacks are dispatched to the
correct transport based on the platform prefix in contact_id.
"""

import asyncio
import logging
from typing import Dict

from src.contact_ids import split_contact_id
from src.transport.base import TransportClient

logger = logging.getLogger(__name__)


def parse_contact_id(contact_id: str) -> tuple[str, str]:
    """Split a canonical contact ID into (platform, native_id)."""
    return split_contact_id(contact_id)


class BotInstance:
    """A bot running across one or more transport platforms."""

    def __init__(self, name: str, brain, transports: Dict[str, TransportClient]):
        self.name = name
        self.brain = brain
        self.transports = transports  # platform -> TransportClient

        # Wire brain callbacks to dispatch through transports
        brain._send_message = self._dispatch_send_message
        brain._send_composing = self._dispatch_send_composing
        brain._send_active = self._dispatch_send_active
        brain._approve_subscription = self._dispatch_approve_contact
        brain._send_file = self._dispatch_send_file

        # Wire brain reference into each transport
        for transport in transports.values():
            if hasattr(transport, 'wire_brain'):
                transport.wire_brain(brain)
            else:
                transport.brain = brain

    def _dispatch_send_message(self, contact_id: str, text: str):
        platform, native_id = parse_contact_id(contact_id)
        transport = self.transports.get(platform)
        if transport:
            transport.send_message_to(native_id, text)
        else:
            logger.warning(f"[{self.name}] Invalid or unreachable contact ID '{contact_id}', cannot send message")

    def _dispatch_send_composing(self, contact_id: str):
        platform, native_id = parse_contact_id(contact_id)
        transport = self.transports.get(platform)
        if transport:
            transport.send_composing(native_id)

    def _dispatch_send_active(self, contact_id: str):
        platform, native_id = parse_contact_id(contact_id)
        transport = self.transports.get(platform)
        if transport:
            transport.send_active(native_id)

    def _dispatch_approve_contact(self, contact_id: str):
        platform, native_id = parse_contact_id(contact_id)
        transport = self.transports.get(platform)
        if transport:
            transport.approve_contact(native_id)

    def _dispatch_send_file(self, contact_id: str, file_path: str, caption: str = "") -> bool:
        platform, native_id = parse_contact_id(contact_id)
        transport = self.transports.get(platform)
        if transport:
            return transport.send_file_to(native_id, file_path, caption)
        logger.warning(f"[{self.name}] Invalid or unreachable contact ID '{contact_id}', cannot send file")
        return False

    async def start(self):
        """Start brain background tasks and all transports."""
        brain_tasks = await self.brain.start_tasks()

        transport_tasks = []
        for transport in self.transports.values():
            transport_tasks.append(asyncio.create_task(transport.start()))

        all_tasks = brain_tasks + transport_tasks
        logger.info(f"[{self.name}] Started with {len(self.transports)} transport(s): {list(self.transports.keys())}")

        done, pending = await asyncio.wait(all_tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in pending:
            task.cancel()

    def stop(self):
        """Stop brain and all transports."""
        self.brain.stop()
        for transport in self.transports.values():
            transport.stop()
