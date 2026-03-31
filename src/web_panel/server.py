"""
server.py - NaturalChat web panel server.

Provides a web UI for chatting with bots, viewing logs, and editing config.
Uses aiohttp (already a project dependency).
"""

import asyncio
import hashlib
import hmac
import json
import logging
import os
import secrets
import time
from pathlib import Path

import aiohttp
from aiohttp import web

import yaml

logger = logging.getLogger(__name__)

STATIC_DIR = Path(__file__).parent / "static"
TOKEN_EXPIRY = 86400 * 7  # 7 days


class WebPanel:
    """Web-based admin panel and chat interface for NaturalChat."""

    def __init__(self, bot_manager, host: str = "0.0.0.0", port: int = 8080,
                 username: str = "", password: str = ""):
        self.bot_manager = bot_manager
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self._secret = secrets.token_hex(32)
        self.app = web.Application()
        self._setup_routes()

    def _setup_routes(self):
        self.app.router.add_post("/api/login", self._handle_login)
        self.app.router.add_get("/api/bots", self._handle_list_bots)
        self.app.router.add_get("/api/bots/{name}/config", self._handle_get_config)
        self.app.router.add_put("/api/bots/{name}/config", self._handle_put_config)
        self.app.router.add_post("/api/bots/{name}/restart", self._handle_restart_bot)
        self.app.router.add_get("/api/bots/{name}/history", self._handle_get_history)
        self.app.router.add_get("/ws/chat/{bot_name}", self._handle_ws_chat)
        # Static files (SPA) - must be last
        if STATIC_DIR.is_dir():
            self.app.router.add_static("/static", STATIC_DIR)
        self.app.router.add_get("/{tail:.*}", self._handle_index)

    def _generate_token(self) -> str:
        payload = f"{self.username}:{int(time.time()) + TOKEN_EXPIRY}"
        sig = hmac.new(self._secret.encode(), payload.encode(), hashlib.sha256).hexdigest()
        return f"{payload}:{sig}"

    def _verify_token(self, token: str) -> bool:
        try:
            parts = token.rsplit(":", 1)
            if len(parts) != 2:
                return False
            payload, sig = parts
            expected = hmac.new(self._secret.encode(), payload.encode(), hashlib.sha256).hexdigest()
            if not hmac.compare_digest(sig, expected):
                return False
            _, expiry = payload.rsplit(":", 1)
            return int(expiry) > int(time.time())
        except Exception:
            return False

    def _check_auth(self, request: web.Request) -> bool:
        if not self.username:
            return True  # No auth configured
        # Check Authorization header
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            return self._verify_token(auth[7:])
        # Check query param (for WebSocket)
        token = request.query.get("token", "")
        return self._verify_token(token) if token else False

    def _get_web_transport(self, bot_name: str):
        """Find the WebTransport for a given bot."""
        for bot in self.bot_manager.bots:
            if bot.name == bot_name:
                return bot.transports.get("web")
        return None

    # ── Auth ──

    async def _handle_login(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
        except Exception:
            return web.json_response({"error": "Invalid JSON"}, status=400)

        if not self.username:
            # No auth required
            return web.json_response({"token": self._generate_token()})

        if data.get("username") == self.username and data.get("password") == self.password:
            token = self._generate_token()
            return web.json_response({"token": token})
        return web.json_response({"error": "Invalid credentials"}, status=401)

    # ── Bot management ──

    async def _handle_list_bots(self, request: web.Request) -> web.Response:
        if not self._check_auth(request):
            return web.json_response({"error": "Unauthorized"}, status=401)

        bots = []
        for bot in self.bot_manager.bots:
            bots.append({
                "name": bot.name,
                "platforms": list(bot.transports.keys()),
                "model": bot.brain.config.get("llm", {}).get("model", "unknown"),
            })
        return web.json_response({"bots": bots})

    async def _handle_get_config(self, request: web.Request) -> web.Response:
        if not self._check_auth(request):
            return web.json_response({"error": "Unauthorized"}, status=401)

        name = request.match_info["name"]
        bot_dir = os.path.join(self.bot_manager.global_config.get("_base_dir", ""), "bots", name)
        if not bot_dir:
            bot_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bots", name)

        config_path = os.path.join(bot_dir, "config.yaml")
        if not os.path.isfile(config_path):
            return web.json_response({"error": "Bot not found"}, status=404)

        with open(config_path, "r", encoding="utf-8") as f:
            content = f.read()
        return web.json_response({"name": name, "config": content})

    async def _handle_put_config(self, request: web.Request) -> web.Response:
        if not self._check_auth(request):
            return web.json_response({"error": "Unauthorized"}, status=401)

        name = request.match_info["name"]
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        bot_dir = os.path.join(base_dir, "bots", name)
        config_path = os.path.join(bot_dir, "config.yaml")

        if not os.path.isfile(config_path):
            return web.json_response({"error": "Bot not found"}, status=404)

        try:
            data = await request.json()
            config_text = data.get("config", "")
            # Validate YAML
            yaml.safe_load(config_text)
            with open(config_path, "w", encoding="utf-8") as f:
                f.write(config_text)
            return web.json_response({"ok": True, "message": "Config saved. Restart bot to apply."})
        except yaml.YAMLError as e:
            return web.json_response({"error": f"Invalid YAML: {e}"}, status=400)
        except Exception as e:
            return web.json_response({"error": str(e)}, status=500)

    async def _handle_restart_bot(self, request: web.Request) -> web.Response:
        if not self._check_auth(request):
            return web.json_response({"error": "Unauthorized"}, status=401)

        name = request.match_info["name"]
        ok = await self.bot_manager.restart_bot(name)
        if ok:
            return web.json_response({"ok": True, "message": f"Bot '{name}' restarted"})
        return web.json_response({"error": f"Failed to restart '{name}'"}, status=500)

    async def _handle_get_history(self, request: web.Request) -> web.Response:
        if not self._check_auth(request):
            return web.json_response({"error": "Unauthorized"}, status=401)

        name = request.match_info["name"]
        session_id = request.query.get("session", "default")
        contact_id = f"web:{session_id}"

        for bot in self.bot_manager.bots:
            if bot.name == name and hasattr(bot.brain, 'llm'):
                history = bot.brain.llm._histories.get(contact_id, [])
                messages = []
                for msg in history:
                    messages.append({
                        "role": msg.get("role", ""),
                        "content": msg.get("content", ""),
                    })
                return web.json_response({"messages": messages})
        return web.json_response({"messages": []})

    # ── WebSocket chat ──

    async def _handle_ws_chat(self, request: web.Request) -> web.WebSocketResponse:
        if not self._check_auth(request):
            ws = web.WebSocketResponse()
            await ws.prepare(request)
            await ws.send_json({"type": "error", "text": "Unauthorized"})
            await ws.close()
            return ws

        bot_name = request.match_info["bot_name"]
        transport = self._get_web_transport(bot_name)
        if not transport:
            ws = web.WebSocketResponse()
            await ws.prepare(request)
            await ws.send_json({"type": "error", "text": f"Bot '{bot_name}' not found or has no web transport"})
            await ws.close()
            return ws

        ws = web.WebSocketResponse(heartbeat=30)
        await ws.prepare(request)

        session_id = request.query.get("session", "default")
        transport.register_ws(session_id, ws)
        logger.info(f"[{bot_name}] Web panel connected: session={session_id}")

        try:
            async for msg in ws:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    try:
                        data = json.loads(msg.data)
                        text = data.get("text", "").strip()
                        if text:
                            await transport.handle_web_message(session_id, text)
                    except json.JSONDecodeError:
                        pass
                elif msg.type == aiohttp.WSMsgType.ERROR:
                    logger.warning(f"[{bot_name}] WS error: {ws.exception()}")
        finally:
            transport.unregister_ws(session_id, ws)
            logger.info(f"[{bot_name}] Web panel disconnected: session={session_id}")

        return ws

    # ── Static / SPA ──

    async def _handle_index(self, request: web.Request) -> web.Response:
        index_path = STATIC_DIR / "index.html"
        if index_path.is_file():
            return web.FileResponse(index_path)
        return web.Response(text="NaturalChat Web Panel - static files not found", status=404)

    # ── Start ──

    async def start(self):
        runner = web.AppRunner(self.app)
        await runner.setup()
        site = web.TCPSite(runner, self.host, self.port)
        await site.start()
        if self.username:
            logger.info(f"Web panel: http://{self.host}:{self.port} (auth required)")
        else:
            logger.info(f"Web panel: http://{self.host}:{self.port} (no auth)")
