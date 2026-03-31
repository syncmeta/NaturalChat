#!/usr/bin/env python3
"""
main.py - Entry point for the multi-bot, multi-platform chatbot system.
"""

import asyncio
import logging
import os
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
    logging.getLogger("aiohttp.access").setLevel(logging.WARNING)


async def main():
    setup_logging()
    logger = logging.getLogger("main")
    logger.info("=== NaturalChat Multi-Bot System ===")

    manager = BotManager()
    manager.discover_bots()

    if not manager.bots:
        logger.error("No bots found in bots/ directory. Use 'python manage.py add <name>' to create one.")
        sys.exit(1)

    # Start web panel
    import secrets as _secrets

    web_panel = None
    panel_port = int(os.environ.get("WEB_PANEL_PORT", "8080"))
    panel_user = os.environ.get("WEB_PANEL_USER", "")
    panel_pass = os.environ.get("WEB_PANEL_PASS", "")

    # Check web_panel.yaml for credentials
    base_dir = os.path.dirname(os.path.abspath(__file__))
    panel_config_path = os.path.join(base_dir, "web_panel.yaml")
    if os.path.isfile(panel_config_path):
        import yaml
        with open(panel_config_path, "r", encoding="utf-8") as f:
            panel_config = yaml.safe_load(f) or {}
        panel_user = panel_user or panel_config.get("username", "")
        panel_pass = panel_pass or panel_config.get("password", "")
        panel_port = panel_config.get("port", panel_port)

    # Auto-generate credentials if none configured
    generated = False
    if not panel_user:
        panel_user = "admin"
        panel_pass = _secrets.token_urlsafe(9)
        generated = True
        # Save for next run
        try:
            import yaml
            with open(panel_config_path, "w", encoding="utf-8") as f:
                yaml.dump({"username": panel_user, "password": panel_pass, "port": panel_port},
                          f, default_flow_style=False)
            os.chmod(panel_config_path, 0o600)
        except Exception:
            pass  # Non-fatal

    try:
        from src.web_panel.server import WebPanel
        web_panel = WebPanel(
            bot_manager=manager,
            host="0.0.0.0",
            port=panel_port,
            username=panel_user,
            password=panel_pass,
        )
        await web_panel.start()
        if generated:
            logger.info(f"Web panel credentials auto-generated:")
            logger.info(f"  URL:      http://localhost:{panel_port}")
            logger.info(f"  Username: {panel_user}")
            logger.info(f"  Password: {panel_pass}")
            logger.info(f"  Saved to: {panel_config_path}")
    except Exception as e:
        logger.warning(f"Web panel failed to start: {e}")

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
