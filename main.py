#!/usr/bin/env python3
"""
main.py - Entry point for the multi-bot, multi-platform chatbot system.
"""

import asyncio
import logging
import signal
import sys

from src.bot_manager import BotManager


def setup_logging():
    """Configure logging."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    # Reduce noisy loggers
    logging.getLogger("slixmpp").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("telegram").setLevel(logging.WARNING)


async def main():
    setup_logging()
    logger = logging.getLogger("main")
    logger.info("=== NaturalChat4 Multi-Bot System ===")

    manager = BotManager()
    manager.discover_bots()

    if not manager.bots:
        logger.error("No bots found in bots/ directory. Use 'python manage.py add <name>' to create one.")
        sys.exit(1)

    # Handle graceful shutdown
    loop = asyncio.get_event_loop()
    stop_event = asyncio.Event()

    def signal_handler():
        logger.info("Shutting down...")
        for bot in manager.bots:
            bot.stop()
        stop_event.set()

    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, signal_handler)

    # Start all bots
    try:
        await manager.start_all()
    except Exception as e:
        logger.error(f"Error: {e}")
    finally:
        logger.info("All bots stopped.")


if __name__ == "__main__":
    asyncio.run(main())
