"""
bot_brain.py - Central orchestration layer for all bot behaviors.

Owns all background tasks (reflection, memory update, RSS, critic review, surfing)
and manages token budget gating. The XMPP client delegates to this layer.
"""

import asyncio
import html
import json
import logging
import os
import random
import re
import shutil
import time
from dataclasses import dataclass
from datetime import datetime
from typing import List, Dict, Optional, Callable, Awaitable

import aiohttp
import feedparser

from src.contact_ids import is_contact_id, strip_contact_prefix
from src.token_auditor import TokenAuditor, LLMResult
from src.skill_loader import load_skills, skills_to_openai_tools, get_skill_executor

logger = logging.getLogger(__name__)

_HTML_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\s+")


@dataclass
class ChatResult:
    """Result from handling a user message."""
    replies: List[str]
    needs_critic_review: bool = False


class BotBrain:
    def __init__(
        self,
        llm_agent,
        memory_manager,
        token_auditor: TokenAuditor,
        send_message_fn: Callable,
        send_composing_fn: Callable,
        send_active_fn: Callable,
        config: dict,
        approve_subscription_fn: Optional[Callable] = None,
    ):
        self.llm = llm_agent
        self.memory = memory_manager
        self.auditor = token_auditor
        self._send_message = send_message_fn
        self._send_composing = send_composing_fn
        self._send_active = send_active_fn
        self._send_file = lambda *a, **k: False
        self._approve_subscription = approve_subscription_fn
        self.config = config
        self.bot_name = config.get("_name", "bot")
        self.bot_dir = config.get("_dir", "")
        self.bot_meta = config.get("_bot_meta", {}) or {}
        self.update_inbox_dir = os.path.join(self.bot_dir, "inbox") if self.bot_dir else ""
        self.update_archive_dir = os.path.join(self.bot_dir, "bot_data", "package_updates") if self.bot_dir else ""

        # Config values
        self.reflection_delay = config.get("reflection_delay", 30.0)
        self.reflection_prompt = config.get("_reflection_prompt", "")
        self.profile_update_prompt = config.get("_profile_update_prompt", "")
        self.critic_config = config.get("critic", {})
        self.critic_prompt = config.get("_critic_prompt", "")
        self.correction_prompt = config.get("_correction_prompt", "")
        self.surfing_config = config.get("surfing", {})
        self.surfing_prompt = config.get("_surfing_prompt", "")
        self.rsshub_server = config.get("rsshub_server", "")


        # Token budget
        self.default_token_budget = config.get("token_budget", {}).get("default_score", 50)
        self._token_budgets: Dict[str, int] = {}
        self._load_token_budgets()

        # Per-contact locks
        self._processing_locks: Dict[str, asyncio.Lock] = {}

        # Background tasks
        self._reflection_tasks: Dict[str, asyncio.Task] = {}
        self._critic_tasks: Dict[str, asyncio.Task] = {}
        self._stopping = False

        # Skill management
        self.skill_dirs = config.get("_skill_dirs", [])

        # RSS state
        self._seen_rss_guids: set = set()

        # Surfing activity tracking
        self._last_chat_time: Optional[datetime] = None  # last time any user chatted
        self._surfing_idle_threshold = self.surfing_config.get("idle_threshold", 7200)  # 2h no chat → stop surfing
        self._surfing_quiet_hours = self.surfing_config.get("quiet_hours", [0, 8])  # [start, end) 24h format

        # Critic model clients
        self._critic_clients: list = []  # [(name, AsyncOpenAI, model_name)]
        self._init_model_clients()

        # Surfing model clients
        self._surfing_planner_client = None  # (AsyncOpenAI, model_name)
        self._surfing_eval_client = None  # (AsyncOpenAI, model_name)

        # Debounce model client (small/fast model for judging if user is done typing)
        self._debounce_client = None  # (AsyncOpenAI, model_name)

    def _save_bot_meta(self):
        if self.memory:
            self.memory.save_bot_meta(self.bot_meta)

    @staticmethod
    def _strip_prefix(contact_id: str) -> str:
        """Strip platform prefix from a canonical contact ID."""
        return strip_contact_prefix(contact_id)

    def _reachable_contact_ids(self) -> List[str]:
        """Return currently valid prefixed contact IDs for outbound messages."""
        targets: List[str] = []
        for jid in self.llm._histories.keys():
            if is_contact_id(jid) and jid not in targets:
                targets.append(jid)

        for jid in [self.bot_meta.get("creator_jid")] + self.bot_meta.get("admins", []) + self.bot_meta.get("approved_contacts", []):
            if is_contact_id(jid) and jid not in targets:
                targets.append(jid)
        return targets

    def _normalize_contact_id(self, contact_id: str, allowed_targets: Optional[List[str]] = None) -> Optional[str]:
        """Map legacy or loosely formatted contact IDs to a currently reachable prefixed ID."""
        if not isinstance(contact_id, str):
            return None

        target = contact_id.strip()
        if not target:
            return None

        allowed = allowed_targets or self._reachable_contact_ids()
        if target in allowed:
            return target

        native = self._strip_prefix(target)
        matches = [jid for jid in allowed if self._strip_prefix(jid) == native]
        if len(matches) == 1:
            return matches[0]
        return None

    def _filter_reachable_targets(self, targets: List[str]) -> List[str]:
        """Keep only targets that map to a reachable prefixed contact ID."""
        allowed = self._reachable_contact_ids()
        normalized: List[str] = []
        for target in targets:
            mapped = self._normalize_contact_id(target, allowed)
            if mapped and mapped not in normalized:
                normalized.append(mapped)
        return normalized

    def _id_matches(self, contact_id: str, stored_id: str) -> bool:
        """Check if a (possibly prefixed) contact_id matches a stored ID.
        Handles both prefixed and bare IDs for backward compat."""
        if not contact_id or not stored_id:
            return False
        return contact_id == stored_id

    def _id_in_list(self, contact_id: str, id_list: list) -> bool:
        """Check if contact_id matches any ID in a list (handles prefixed/bare)."""
        return any(self._id_matches(contact_id, stored) for stored in (id_list or []))

    def is_creator(self, jid: str) -> bool:
        return bool(jid) and self._id_matches(jid, self.bot_meta.get("creator_jid", ""))

    def claim_creator(self, jid: str) -> bool:
        """Claim creator ownership if not set yet."""
        jid = (jid or "").strip()
        if not jid or self.bot_meta.get("creator_jid"):
            return False
        self.bot_meta["creator_jid"] = jid
        self._save_bot_meta()
        return True

    def is_admin(self, jid: str) -> bool:
        return bool(jid) and (self.is_creator(jid) or self._id_in_list(jid, self.bot_meta.get("admins", [])))

    def governance_recipients(self) -> List[str]:
        recipients = []
        creator = self.bot_meta.get("creator_jid", "")
        if creator:
            recipients.append(creator)
        for jid in self.bot_meta.get("admins", []) or []:
            if jid and jid not in recipients:
                recipients.append(jid)
        return recipients

    def is_blacklisted(self, jid: str) -> bool:
        return self._id_in_list(jid, self.bot_meta.get("blacklist", []))

    def is_contact_approved(self, jid: str) -> bool:
        return self._id_in_list(jid, self.bot_meta.get("approved_contacts", [])) or self.is_admin(jid)

    def requires_contact_approval(self) -> bool:
        return self.get_access_mode() == "approval"

    def get_access_mode(self) -> str:
        """Get current access mode: 'open', 'approval', or 'private'."""
        return self.bot_meta.get("access_mode", "open")

    def set_access_mode(self, mode: str, actor_jid: str = "") -> bool:
        """Set access mode. Returns True if valid and changed."""
        if mode not in ("open", "approval", "private"):
            return False
        if actor_jid and not self.is_creator(actor_jid):
            return False
        self.bot_meta["access_mode"] = mode
        self._save_bot_meta()
        return True

    def can_chat_with(self, jid: str) -> bool:
        if self.is_blacklisted(jid):
            return False
        mode = self.get_access_mode()
        if mode == "private":
            return self.is_admin(jid)
        if mode == "approval":
            return self.is_contact_approved(jid)
        return True  # "open"

    def add_admins(self, admin_jids: List[str]) -> List[str]:
        existing = list(self.bot_meta.get("admins", []) or [])
        added = []
        creator = self.bot_meta.get("creator_jid", "")
        for jid in admin_jids:
            jid = (jid or "").strip()
            if not jid or jid == creator or jid in existing:
                continue
            existing.append(jid)
            added.append(jid)
        self.bot_meta["admins"] = existing
        self._save_bot_meta()
        return added

    def remove_admins(self, admin_jids: List[str]) -> List[str]:
        existing = list(self.bot_meta.get("admins", []) or [])
        removed = []
        for jid in admin_jids:
            jid = (jid or "").strip()
            if jid in existing:
                existing.remove(jid)
                removed.append(jid)
        self.bot_meta["admins"] = existing
        self._save_bot_meta()
        return removed

    def _new_request_id(self, prefix: str) -> str:
        return f"{prefix}_{int(time.time())}_{random.randint(1000, 9999)}"

    def request_contact_approval(self, requester_jid: str, message: str = "") -> str:
        request_id = self._new_request_id("contact")
        item = {
            "id": request_id,
            "requester_jid": requester_jid,
            "message": message.strip(),
            "created_at": datetime.now().isoformat(),
            "status": "pending",
        }
        pending = list(self.bot_meta.get("pending_contact_requests", []) or [])
        pending.append(item)
        self.bot_meta["pending_contact_requests"] = pending
        self._save_bot_meta()
        return request_id

    def request_update_from_package(self, package_path: str, detected_by: str = "watcher") -> str:
        request_id = self._new_request_id("update")
        item = {
            "id": request_id,
            "package_path": package_path,
            "filename": os.path.basename(package_path),
            "detected_by": detected_by,
            "created_at": datetime.now().isoformat(),
            "status": "pending",
        }
        pending = list(self.bot_meta.get("pending_update_requests", []) or [])
        pending.append(item)
        self.bot_meta["pending_update_requests"] = pending
        self._save_bot_meta()
        return request_id

    def request_package_access(self, requester_jid: str) -> str:
        request_id = self._new_request_id("pack")
        item = {
            "id": request_id,
            "requester_jid": requester_jid,
            "created_at": datetime.now().isoformat(),
            "status": "pending",
        }
        pending = list(self.bot_meta.get("pending_package_requests", []) or [])
        pending.append(item)
        self.bot_meta["pending_package_requests"] = pending
        self._save_bot_meta()
        return request_id

    async def notify_governance(self, text: str):
        for jid in self.governance_recipients():
            try:
                self._send_message(jid, text)
            except Exception:
                logger.warning(f"[{self.bot_name}] Failed to notify governance recipient {jid}")

    async def approve_request(self, approver_jid: str, request_id: str) -> str:
        if not self.is_admin(approver_jid):
            return "You don't have approval permissions."

        for key in ("pending_contact_requests", "pending_update_requests", "pending_package_requests"):
            pending = list(self.bot_meta.get(key, []) or [])
            for idx, item in enumerate(pending):
                if item.get("id") != request_id or item.get("status") != "pending":
                    continue
                item["status"] = "approved"
                item["approved_by"] = approver_jid
                item["approved_at"] = datetime.now().isoformat()
                pending[idx] = item
                self.bot_meta[key] = pending
                self._save_bot_meta()

                if key == "pending_contact_requests":
                    approved = list(self.bot_meta.get("approved_contacts", []) or [])
                    requester = item.get("requester_jid", "")
                    if requester and requester not in approved:
                        approved.append(requester)
                        self.bot_meta["approved_contacts"] = approved
                        self._save_bot_meta()
                    if requester and self._approve_subscription:
                        try:
                            self._approve_subscription(requester)
                        except Exception:
                            logger.warning(f"[{self.bot_name}] Failed to approve XMPP subscription for {requester}")
                    return f"Contact request {request_id} approved."

                if key == "pending_update_requests":
                    return await self._approve_update_request(item)

                if key == "pending_package_requests":
                    return await self._approve_package_request(item)

        return f"Pending request {request_id} not found."

    async def _approve_update_request(self, item: dict) -> str:
        from src.bot_packager import update_bot_in_place
        from src.bot_manager import global_bot_manager

        package_path = item.get("package_path", "")
        if not package_path or not os.path.isfile(package_path):
            return f"Update package not found: {package_path}"

        update_bot_in_place(package_path, self.bot_dir)
        archived = self._archive_update_package(package_path, "applied")
        for recipient in self.governance_recipients():
            self._send_message(
                recipient,
                f"Bot {self.bot_name} updated from package {os.path.basename(package_path)} and will restart now."
            )
        if global_bot_manager:
            asyncio.create_task(global_bot_manager.restart_bot(self.bot_name))
        return f"Update applied from {os.path.basename(archived)}. Restarting bot."

    async def _approve_package_request(self, item: dict) -> str:
        requester = item.get("requester_jid", "")
        grant_id = self._new_request_id("packgrant")
        grant = {
            "id": grant_id,
            "requester_jid": requester,
            "created_at": datetime.now().isoformat(),
            "expires_at": (datetime.now().timestamp() + 24 * 3600),
            "used": False,
        }
        grants = list(self.bot_meta.get("package_download_grants", []) or [])
        grants.append(grant)
        self.bot_meta["package_download_grants"] = grants
        self._save_bot_meta()
        if requester:
            self._send_message(
                requester,
                f"Your package request was approved.\nReply /pack {grant_id} within 24 hours to download a one-time copy."
            )
        return f"Package request approved. Grant ID: {grant_id}"

    def _build_package_output_path(self) -> str:
        exports_dir = os.path.join(self.bot_dir, "bot_data", "package_exports")
        os.makedirs(exports_dir, exist_ok=True)
        filename = f"{self.bot_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.tar.gz"
        return os.path.join(exports_dir, filename)

    def _export_package(self) -> str:
        from src.bot_packager import export_bot
        from src.bot_manager import COMMON_SKILLS_DIR

        return export_bot(
            self.bot_dir,
            output_path=self._build_package_output_path(),
            common_skills_dir=COMMON_SKILLS_DIR,
        )

    async def send_package_to(self, requester_jid: str) -> str:
        package_path = self._export_package()
        sent = self._send_file(
            requester_jid,
            package_path,
            caption=f"{self.bot_name} package export",
        )
        if not sent:
            return "This platform does not support package delivery yet."
        return f"Package sent: {os.path.basename(package_path)}"

    async def redeem_package_grant(self, requester_jid: str, grant_id: str) -> str:
        grants = list(self.bot_meta.get("package_download_grants", []) or [])
        now_ts = datetime.now().timestamp()
        for idx, grant in enumerate(grants):
            if grant.get("id") != grant_id:
                continue
            if grant.get("used"):
                return "This package grant has already been used."
            if grant.get("requester_jid") != requester_jid:
                return "This package grant is not for you."
            if float(grant.get("expires_at", 0)) < now_ts:
                return "This package grant has expired."
            result = await self.send_package_to(requester_jid)
            if result.startswith("Package sent:"):
                grant["used"] = True
                grant["used_at"] = datetime.now().isoformat()
                grants[idx] = grant
                self.bot_meta["package_download_grants"] = grants
                self._save_bot_meta()
            return result
        return f"Package grant {grant_id} not found."

    async def deny_request(self, approver_jid: str, request_id: str) -> str:
        if not self.is_admin(approver_jid):
            return "You don't have approval permissions."
        for key in ("pending_contact_requests", "pending_update_requests", "pending_package_requests"):
            pending = list(self.bot_meta.get(key, []) or [])
            for idx, item in enumerate(pending):
                if item.get("id") != request_id or item.get("status") != "pending":
                    continue
                item["status"] = "denied"
                item["denied_by"] = approver_jid
                item["denied_at"] = datetime.now().isoformat()
                pending[idx] = item
                self.bot_meta[key] = pending
                self._save_bot_meta()
                if key == "pending_update_requests":
                    self._archive_update_package(item.get("package_path", ""), "denied")
                return f"Request {request_id} denied."
        return f"Pending request {request_id} not found."

    def _archive_update_package(self, package_path: str, status: str) -> str:
        if not package_path or not os.path.isfile(package_path):
            return package_path
        archive_dir = os.path.join(self.update_archive_dir, status)
        os.makedirs(archive_dir, exist_ok=True)
        target_path = os.path.join(archive_dir, os.path.basename(package_path))
        if os.path.abspath(package_path) == os.path.abspath(target_path):
            return target_path
        shutil.move(package_path, target_path)
        return target_path

    def _scan_update_packages(self) -> list[str]:
        candidates = []
        for directory in [self.update_inbox_dir]:
            if not directory or not os.path.isdir(directory):
                continue
            for fname in sorted(os.listdir(directory)):
                if fname.endswith(".tar.gz"):
                    candidates.append(os.path.join(directory, fname))
        return candidates

    async def _watch_update_packages(self):
        if self.update_inbox_dir:
            os.makedirs(self.update_inbox_dir, exist_ok=True)

        while not self._stopping:
            await asyncio.sleep(2)
            try:
                known = {
                    item.get("package_path")
                    for item in (self.bot_meta.get("pending_update_requests", []) or [])
                    if item.get("status") == "pending"
                }
                for package_path in self._scan_update_packages():
                    if package_path in known:
                        continue
                    request_id = self.request_update_from_package(package_path)
                    recipients = self.governance_recipients()
                    if not recipients:
                        logger.info(f"[{self.bot_name}] Update package detected but no creator/admin yet: {package_path}")
                        continue
                    detected_by = next(
                        (
                            item.get("detected_by", "watcher")
                            for item in (self.bot_meta.get("pending_update_requests", []) or [])
                            if item.get("id") == request_id
                        ),
                        "watcher",
                    )
                    text = (
                        f"[Update Package] Detected package for bot {self.bot_name}"
                        f"\nFile: {os.path.basename(package_path)}"
                        f"\nRequest ID: {request_id}"
                        f"\nReply /approve {request_id} to update this bot"
                        f"\nReply /deny {request_id} to ignore it"
                    )
                    if detected_by and detected_by != "watcher":
                        text = (
                            f"[Update Package] Detected package for bot {self.bot_name}"
                            f"\nFile: {os.path.basename(package_path)}"
                            f"\nDetected by: {detected_by}"
                            f"\nRequest ID: {request_id}"
                            f"\nReply /approve {request_id} to update this bot"
                            f"\nReply /deny {request_id} to ignore it"
                        )
                    await self.notify_governance(text)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"[{self.bot_name}] Update package watcher error: {e}")

    def _init_model_clients(self):
        """Initialize AsyncOpenAI clients for critic and surfing models."""
        from openai import AsyncOpenAI

        llm_config = self.config.get("llm", {})
        default_api_key = llm_config.get("api_key", "")
        default_base_url = llm_config.get("base_url", "https://api.openai.com/v1")

        models = self.config.get("models") or []
        for m in models:
            api_key = m.get("api_key") or default_api_key
            base_url = m.get("base_url") or default_base_url
            model_name = m.get("model", "")
            name = m.get("name", model_name)
            role = m.get("role", "")

            if not api_key or not model_name:
                continue

            client = AsyncOpenAI(api_key=api_key, base_url=base_url)

            if role == "critic":
                self._critic_clients.append((name, client, model_name))
            elif role == "surfing":
                self._surfing_planner_client = (client, model_name)
            elif role == "surfing_eval":
                self._surfing_eval_client = (client, model_name)
            elif role == "debounce":
                self._debounce_client = (client, model_name)

    def _load_token_budgets(self):
        """Load per-contact token budgets from memory manager."""
        if self.memory:
            self._token_budgets = self.memory.load_token_budgets()

    def _save_token_budgets(self):
        """Save per-contact token budgets."""
        if self.memory:
            self.memory.save_token_budgets(self._token_budgets)

    def get_token_budget(self, contact_jid: str) -> int:
        return self._token_budgets.get(contact_jid, self.default_token_budget)

    def set_token_budget(self, contact_jid: str, score: int):
        self._token_budgets[contact_jid] = max(0, min(100, score))
        self._save_token_budgets()

    def get_lock(self, jid: str) -> asyncio.Lock:
        if jid not in self._processing_locks:
            self._processing_locks[jid] = asyncio.Lock()
        return self._processing_locks[jid]

    # ── Debounce LLM judge ───────────────────────────────────────────────────

    async def should_wait_for_more(self, contact_jid: str, buffered_messages: list) -> bool:
        """Ask a small model whether the user is likely still composing more messages.

        Used by transports that cannot detect typing indicators (Telegram, Feishu).
        Returns True if the model thinks we should wait for more input.
        """
        if not self._debounce_client:
            return False

        client, model_name = self._debounce_client

        # Build minimal context: just the buffered messages
        user_text = "\n".join(buffered_messages[-5:])  # At most last 5 messages
        messages = [
            {
                "role": "system",
                "content": (
                    "You judge whether a chat user has finished their current thought or is likely to send more messages. "
                    "Consider: incomplete sentences, trailing punctuation like '...', lists being enumerated, "
                    "very short fragments that seem like part of a larger thought. "
                    "Reply with exactly one word: WAIT or GO."
                ),
            },
            {
                "role": "user",
                "content": f"The user just sent these messages in quick succession:\n{user_text}\n\nAre they done?",
            },
        ]

        try:
            response = await asyncio.wait_for(
                client.chat.completions.create(model=model_name, messages=messages, max_tokens=5),
                timeout=3.0,
            )
            answer = (response.choices[0].message.content or "").strip().upper()
            should_wait = "WAIT" in answer
            logger.debug(f"[{self.bot_name}] Debounce judge for {contact_jid}: {answer} -> wait={should_wait}")
            return should_wait
        except asyncio.TimeoutError:
            logger.debug(f"[{self.bot_name}] Debounce judge timeout for {contact_jid}")
            return False
        except Exception as e:
            logger.debug(f"[{self.bot_name}] Debounce judge error for {contact_jid}: {e}")
            return False

    # ── Token budget gating ──────────────────────────────────────────────────

    def _get_reflection_delay(self, contact_jid: str) -> float:
        """Adjust reflection delay based on token budget."""
        score = self.get_token_budget(contact_jid)
        if score >= 71:
            return max(15.0, self.reflection_delay * 0.5)
        elif score <= 30:
            return self.reflection_delay * 2.0
        return self.reflection_delay

    def _is_quiet_hours(self) -> bool:
        """Check if current time is within quiet hours (no proactive messages)."""
        start, end = self._surfing_quiet_hours
        hour = datetime.now().hour
        if start < end:
            return start <= hour < end
        else:  # e.g. [23, 7] wraps around midnight
            return hour >= start or hour < end

    def _should_surf(self) -> bool:
        """Determine if surfing should happen now based on activity and time."""
        if self._is_quiet_hours():
            return False
        if self._last_chat_time is None:
            return False  # No chat yet, nothing to surf about
        idle_seconds = (datetime.now() - self._last_chat_time).total_seconds()
        if idle_seconds > self._surfing_idle_threshold:
            return False  # Too long since last chat, user is away
        return True

    def _get_surfing_interval(self) -> float:
        """Calculate surfing interval based on token budget and recency of chat."""
        if not self._token_budgets:
            score = self.default_token_budget
        else:
            score = sum(self._token_budgets.values()) / len(self._token_budgets)
        min_interval = self.surfing_config.get("min_interval", 1800)
        max_interval = self.surfing_config.get("max_interval", 7200)
        base = max_interval - (max_interval - min_interval) * score / 100

        # Increase interval as idle time grows (linear ramp: 1x at 0min idle → 3x at threshold)
        if self._last_chat_time:
            idle_seconds = (datetime.now() - self._last_chat_time).total_seconds()
            ramp = 1.0 + 2.0 * min(idle_seconds / self._surfing_idle_threshold, 1.0)
            base *= ramp

        return base

    def _map_budget_score(self, score: int, min_value: int, max_value: int) -> int:
        """Map a 1-100 score to an integer range, inclusive."""
        score = max(1, min(100, int(score)))
        if min_value >= max_value:
            return min_value
        span = max_value - min_value
        return min_value + ((score - 1) * span) // 99

    def _get_surfing_budget_score(self, triggered_by: Optional[str] = None) -> int:
        if triggered_by:
            return self.get_token_budget(triggered_by)
        if not self._token_budgets:
            return self.default_token_budget
        return round(sum(self._token_budgets.values()) / len(self._token_budgets))

    def _build_surfing_budget_profile(self, triggered_by: Optional[str] = None) -> dict:
        score = self._get_surfing_budget_score(triggered_by)
        max_searches = self._map_budget_score(score, 1, 20)
        return {
            "score": score,
            "max_searches": max_searches,
            "max_initial_queries": min(max_searches, max(1, self.surfing_config.get("max_queries_per_round", 3))),
            "search_results_per_query": self._map_budget_score(score, 3, 8),
            "max_pages_to_open_per_query": self._map_budget_score(score, 0, 4),
            "page_char_budget": self._map_budget_score(score, 1200, 5000),
            "max_follow_up_queries_per_step": self._map_budget_score(score, 0, 3),
            "max_notes_chars": self._map_budget_score(score, 800, 4000),
        }

    # ── Message handling ─────────────────────────────────────────────────────

    async def handle_message(self, sender_jid: str, body: str) -> ChatResult:
        """
        Process a user message through LLM, send replies as they stream in.
        Called by the transport layer under the per-contact lock.
        """
        import random

        # Cancel pending background tasks for this contact
        self._cancel_reflection(sender_jid)
        self._cancel_critic(sender_jid)

        # Stream replies: send each one as soon as it arrives
        trigger_marker = self.critic_config.get("trigger_marker", "[NEED_REVIEW]")
        all_replies = []
        needs_review = False
        msg_count = 0
        self._send_composing(sender_jid)

        async for reply in self.llm.chat(sender_jid, body):
            if not reply or reply.strip() == "[SILENT]":
                continue

            # Strip [NEED_REVIEW] marker before sending
            if trigger_marker in reply:
                reply = reply.replace(trigger_marker, "").strip()
                needs_review = True
            if not reply:
                continue

            # Typing delay between messages (not before the first one)
            if msg_count > 0:
                char_delay = len(reply) * 0.05
                random_noise = random.uniform(0.5, 2.0)
                delay = min(char_delay + random_noise, 8.0)
                self._send_composing(sender_jid)
                await asyncio.sleep(delay)

            self._send_message(sender_jid, reply)
            all_replies.append(reply)
            msg_count += 1

        self._send_active(sender_jid)

        # Handle [SILENT] case
        if not all_replies:
            return ChatResult(replies=[], needs_critic_review=False)

        # Finalize needs_review based on budget
        if needs_review:
            budget = self.get_token_budget(sender_jid)
            needs_review = (
                self.critic_config.get("enabled", False)
                and budget >= 30
                and bool(self._critic_clients)
            )

        # Record token usage
        llm_result = self.llm.last_result
        if llm_result:
            await self.auditor.record(
                sender_jid, "chat", llm_result.model,
                llm_result.prompt_tokens, llm_result.completion_tokens, llm_result.cached_tokens,
                cost=llm_result.cost,
            )

        # Insert chat to Memobase
        if self.memory and all_replies:
            try:
                self.memory.insert_chat(sender_jid, body, " ||| ".join(all_replies))
            except Exception as e:
                logger.warning(f"Failed to insert chat to Memobase: {e}")

        return ChatResult(replies=all_replies, needs_critic_review=needs_review)

    # ── Post-reply actions ───────────────────────────────────────────────────

    async def post_reply_actions(self, sender_jid: str, chat_result: ChatResult):
        """Schedule background tasks after reply is sent. Called outside the lock."""
        # Schedule reflection
        self._schedule_reflection(sender_jid)

        # Schedule memory update
        asyncio.create_task(self._do_memory_update(sender_jid))

        # Schedule critic review if needed
        if chat_result.needs_critic_review:
            self._schedule_critic_review(sender_jid, chat_result.replies)

    # ── Reflection ───────────────────────────────────────────────────────────

    def _cancel_reflection(self, jid: str):
        task = self._reflection_tasks.pop(jid, None)
        if task and not task.done():
            task.cancel()

    def _schedule_reflection(self, jid: str):
        self._cancel_reflection(jid)
        if self.reflection_delay > 0 and self.reflection_prompt:
            task = asyncio.create_task(self._do_reflect(jid))
            self._reflection_tasks[jid] = task

    async def _do_reflect(self, jid: str):
        """Wait for silence, then run reflection."""
        try:
            delay = self._get_reflection_delay(jid)
            await asyncio.sleep(delay)
            logger.info(f"[{self.bot_name}] Triggering reflection for {jid}")

            history = self.llm._get_history(jid)
            if not history:
                return

            reflection_system = self.llm.system_prompt + "\n\n" + self.reflection_prompt

            # Optionally provide search tool for reflection (if budget >= 30)
            tools = None
            budget = self.get_token_budget(jid)
            if budget >= 30:
                tools = [{
                    "type": "function",
                    "function": {
                        "name": "web_search",
                        "description": "Search the web to verify or supplement what you just said",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": {"type": "string", "description": "Search keywords"}
                            },
                            "required": ["query"]
                        }
                    }
                }]

            messages = [{"role": "system", "content": reflection_system}] + list(history)
            messages.append({"role": "user", "content": "[Internal: review the recent conversation and decide if anything should be added]"})

            llm_result = await self.llm.call_llm(
                messages=messages,
                tools=tools,
                tool_executors={"web_search": self._search_ddg_for_tool} if tools else None,
                log_label="reflection",
            )

            await self.auditor.record(
                jid, "reflection", llm_result.model,
                llm_result.prompt_tokens, llm_result.completion_tokens, llm_result.cached_tokens,
                cost=llm_result.cost,
            )

            replies = self.llm.split_and_filter_silence(llm_result.content)
            if not replies:
                logger.info(f"[{self.bot_name}] Reflection: nothing to add.")
                return

            # Send follow-up messages
            lock = self.get_lock(jid)
            async with lock:
                for i, reply_text in enumerate(replies):
                    if not reply_text:
                        continue
                    if i > 0:
                        self._send_composing(jid)
                        delay = len(reply_text) * 0.05 + random.uniform(0.5, 1.5)
                        await asyncio.sleep(min(delay, 6.0))
                    self._send_message(jid, reply_text)
                    logger.info(f"[{self.bot_name}] Reflection reply to {jid}: {reply_text}")

                # Add to history
                ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                history = self.llm._get_history(jid)
                history.append({"role": "assistant", "content": f"[{ts}] " + " ||| ".join(replies)})

        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"[{self.bot_name}] Reflection error: {e}", exc_info=True)

    # ── Memory update ────────────────────────────────────────────────────────

    async def _do_memory_update(self, contact_jid: str):
        """Background: update bot reflection, friends impressions, capabilities."""
        try:
            if not self.memory or not self.profile_update_prompt:
                return
            history = self.llm._get_history(contact_jid)
            if not history:
                return

            recent = history[-20:]
            recent_text = "\n".join(
                f"{m['role'].upper()}: {m.get('content', '')[:300]}" for m in recent
            )

            # Load current bot data
            bot_reflection = self.memory.load_bot_reflection()
            friends_impressions = self.memory.load_friends_impressions()
            capabilities = self.memory.load_capabilities()

            # Get user context from Memobase if available
            user_context = ""
            try:
                user_context = self.memory.get_user_context(contact_jid)
            except Exception:
                pass

            user_content = (
                f"Current contact ID: {contact_jid}\n"
                f"AI self-reflection (bot_self_reflection):\n{json.dumps(bot_reflection, ensure_ascii=False)}\n\n"
                f"User memory context:\n{user_context}\n\n"
                f"Friends impressions overview:\n{friends_impressions}\n\n"
                f"Current capabilities:\n{capabilities}\n\n"
                f"Recent conversation:\n{recent_text}"
            )

            messages = [
                {"role": "system", "content": self.profile_update_prompt},
                {"role": "user", "content": user_content},
            ]

            llm_result = await self.llm.call_llm(messages=messages, log_label="memory_update")

            await self.auditor.record(
                contact_jid, "memory_update", llm_result.model,
                llm_result.prompt_tokens, llm_result.completion_tokens, llm_result.cached_tokens,
                cost=llm_result.cost,
            )

            content = llm_result.content
            # Strip markdown fences
            if content.startswith("```"):
                lines = content.split("\n")
                content = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
                content = content.strip()

            try:
                data = json.loads(content)
            except json.JSONDecodeError as e:
                logger.warning(f"Memory update JSON error for {contact_jid}: {e}\nContent: {content[:100]}")
                return

            # Update bot reflection
            new_refl = data.get("bot_self_reflection")
            if new_refl and isinstance(new_refl, dict):
                self.memory.save_bot_reflection(new_refl)

            # Update friends impressions
            new_impressions = data.get("friends_impressions")
            if new_impressions and isinstance(new_impressions, str):
                self.memory.save_friends_impressions(new_impressions)

            # Update capabilities
            new_caps = data.get("capabilities_update")
            if new_caps and isinstance(new_caps, str) and new_caps.strip():
                self.memory.save_capabilities(new_caps)

            # Flush Memobase user data
            try:
                self.memory.flush_user(contact_jid)
            except Exception:
                pass

            logger.info(f"Memory updated after chat with {contact_jid}")

        except Exception as e:
            logger.warning(f"Memory update failed for {contact_jid}: {e}")

    # ── Critic review ────────────────────────────────────────────────────────

    def _cancel_critic(self, jid: str):
        task = self._critic_tasks.pop(jid, None)
        if task and not task.done():
            task.cancel()

    def _schedule_critic_review(self, jid: str, original_replies: List[str]):
        self._cancel_critic(jid)
        self._critic_tasks[jid] = asyncio.create_task(
            self._do_critic_review(jid, original_replies)
        )

    async def _do_critic_review(self, jid: str, original_replies: List[str]):
        """Run critic models in parallel, then generate correction if needed."""
        try:
            if not self._critic_clients:
                return

            # Step 1: Run critics in parallel (outside lock)
            history = self.llm._get_history(jid)
            history_text = "\n".join(
                f"{m['role'].upper()}: {m.get('content', '')[:300]}" for m in (history or [])[-15:]
            )
            original_text = " ||| ".join(original_replies)

            critic_prompt = self.critic_prompt or "Review the following AI assistant reply for factual accuracy. List any issues found. If none, output [NO_ISSUES]."

            async def call_critic(name, client, model_name):
                try:
                    response = await asyncio.wait_for(
                        client.chat.completions.create(
                            model=model_name,
                            messages=[
                                {"role": "system", "content": critic_prompt},
                                {"role": "user", "content": f"Conversation history:\n{history_text}\n\nAssistant's latest reply:\n{original_text}"},
                            ],
                        ),
                        timeout=self.critic_config.get("timeout", 30),
                    )
                    content = (response.choices[0].message.content or "").strip()
                    actual_model = getattr(response, 'model', model_name)
                    usage = getattr(response, 'usage', None)
                    if usage:
                        _cd = getattr(usage, 'cost_details', None)
                        _cost = (getattr(_cd, 'upstream_inference_cost', 0.0) or 0.0) if _cd else (getattr(usage, 'total_cost', 0.0) or getattr(usage, 'cost', 0.0) or 0.0)
                        await self.auditor.record(
                            jid, "critic_review", actual_model,
                            getattr(usage, 'prompt_tokens', 0),
                            getattr(usage, 'completion_tokens', 0),
                            getattr(getattr(usage, 'prompt_tokens_details', None), 'cached_tokens', 0),
                            cost=float(_cost),
                        )
                    return {"name": name, "feedback": content, "no_issues": "[NO_ISSUES]" in content}
                except Exception as e:
                    logger.warning(f"Critic {name} failed: {e}")
                    return {"name": name, "feedback": "", "no_issues": True}

            feedbacks = await asyncio.gather(
                *[call_critic(n, c, m) for n, c, m in self._critic_clients]
            )

            # Check if all critics say no issues
            if all(f.get("no_issues") for f in feedbacks):
                logger.info(f"[{self.bot_name}] Critics found no issues for {jid}")
                return

            # Step 2: Generate correction (inside lock)
            lock = self.get_lock(jid)
            async with lock:
                correction_delay = self.critic_config.get("correction_delay", 5.0)
                await asyncio.sleep(correction_delay)

                feedback_text = "\n\n".join(
                    f"[{f['name']}]: {f['feedback']}" for f in feedbacks if not f.get("no_issues")
                )

                correction_system = self.correction_prompt or (
                    "Your reply was internally reviewed. Please correct based on feedback. "
                    "If the review found no issues, output [SILENT]."
                )

                # Build full context with history
                current_history = self.llm._get_history(jid)
                messages = self.llm._build_messages(jid, list(current_history or []))
                messages.append({
                    "role": "user",
                    "content": (
                        f"[Internal: critic review complete]\n\n"
                        f"Your previous reply:\n{original_text}\n\n"
                        f"Review feedback:\n{feedback_text}\n\n"
                        f"{correction_system}"
                    ),
                })

                llm_result = await self.llm.call_llm(messages=messages, log_label="critic_review")

                await self.auditor.record(
                    jid, "critic_review", llm_result.model,
                    llm_result.prompt_tokens, llm_result.completion_tokens, llm_result.cached_tokens,
                    cost=llm_result.cost,
                )

                correction_replies = self.llm.split_and_filter_silence(llm_result.content)
                if not correction_replies:
                    return

                # Send correction messages
                self._send_composing(jid)
                for i, reply_text in enumerate(correction_replies):
                    if not reply_text:
                        continue
                    if i > 0:
                        self._send_composing(jid)
                        delay = len(reply_text) * 0.05 + random.uniform(0.5, 2.0)
                        await asyncio.sleep(min(delay, 8.0))
                    self._send_message(jid, reply_text)
                    logger.info(f"[{self.bot_name}] Critic correction to {jid}: {reply_text}")
                self._send_active(jid)

                # Add to history with [correction] marker
                ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                history = self.llm._get_history(jid)
                history.append({"role": "assistant", "content": f"[{ts}] [correction] " + " ||| ".join(correction_replies)})

        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"[{self.bot_name}] Critic review error for {jid}: {e}", exc_info=True)

    # ── RSS ───────────────────────────────────────────────────────────────────

    async def _fetch_rss(self, rsshub_routes: list) -> list:
        """Fetch and parse RSS feeds."""
        items = []
        if not rsshub_routes:
            return items
        try:
            async with aiohttp.ClientSession() as session:
                for route in rsshub_routes:
                    url = f"{self.rsshub_server.rstrip('/')}/{route.lstrip('/')}"
                    try:
                        async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as response:
                            content = await response.text()
                            parsed = feedparser.parse(content)
                            for entry in parsed.entries[:10]:
                                guid = getattr(entry, 'id', getattr(entry, 'link', ''))
                                if guid and guid not in self._seen_rss_guids:
                                    self._seen_rss_guids.add(guid)
                                    items.append({
                                        "title": getattr(entry, 'title', ''),
                                        "link": getattr(entry, 'link', ''),
                                        "summary": getattr(entry, 'summary', getattr(entry, 'description', ''))
                                    })
                    except Exception as e:
                        logger.warning(f"[{self.bot_name}] RSS fetch error {url}: {e}")
        except Exception as e:
            logger.error(f"[{self.bot_name}] RSS session error: {e}")

        if len(self._seen_rss_guids) > 1000:
            self._seen_rss_guids = set(list(self._seen_rss_guids)[-500:])
        return items

    # ── Autonomous surfing ───────────────────────────────────────────────────

    async def _search_ddg_items(self, query: str, max_results: int = 5) -> List[dict]:
        """Search using DuckDuckGo and return structured results."""
        try:
            try:
                from ddgs import DDGS
            except ImportError:
                from duckduckgo_search import DDGS

            def _sync_search():
                with DDGS() as ddgs:
                    return list(ddgs.text(query, max_results=max_results, region="wt-wt"))

            results_raw = await asyncio.get_event_loop().run_in_executor(None, _sync_search)
            if not results_raw:
                return []

            results = []
            for r in results_raw:
                results.append({
                    "title": r.get("title", ""),
                    "snippet": r.get("body", ""),
                    "url": r.get("href", ""),
                })
            return results
        except Exception as e:
            return [{"title": "Search failed", "snippet": str(e), "url": ""}]

    async def _search_ddg(self, query: str, max_results: int = 5) -> str:
        """Search using DuckDuckGo."""
        results_raw = await self._search_ddg_items(query, max_results=max_results)
        if not results_raw:
            return "No results found."
        results = []
        for r in results_raw:
            results.append(f"【{r.get('title', '')}】\n{r.get('snippet', '')}\n{r.get('url', '')}")
        return "\n\n".join(results)

    def _sanitize_page_text(self, text: str, char_limit: int) -> str:
        text = re.sub(r"(?is)<script.*?>.*?</script>", " ", text)
        text = re.sub(r"(?is)<style.*?>.*?</style>", " ", text)
        text = _HTML_TAG_RE.sub(" ", text)
        text = html.unescape(text)
        text = _WS_RE.sub(" ", text).strip()
        return text[:char_limit]

    async def _open_web_page(self, url: str, char_limit: int = 2500) -> dict:
        """Fetch and simplify a web page. Uses Firecrawl/Crawl4AI if configured, else raw HTTP."""
        if not url or not url.startswith(("http://", "https://")):
            return {"url": url, "content": "", "error": "Invalid URL"}

        # Try Firecrawl / Crawl4AI first (better JS rendering and content extraction)
        firecrawl_url = self.config.get("firecrawl", {}).get("url", "") or os.environ.get("FIRECRAWL_URL", "")
        firecrawl_key = self.config.get("firecrawl", {}).get("api_key", "") or os.environ.get("FIRECRAWL_API_KEY", "")
        if firecrawl_url:
            # Auto-detect: Crawl4AI uses /crawl, Firecrawl uses /v1/scrape
            result = await self._open_web_page_crawl4ai(url, char_limit, firecrawl_url)
            if not result.get("error"):
                return result
            # Fallback to Firecrawl API
            result = await self._open_web_page_firecrawl(url, char_limit, firecrawl_url, firecrawl_key)
            if not result.get("error"):
                return result
            logger.debug(f"[{self.bot_name}] Crawl service failed for {url}: {result.get('error')}, falling back to raw HTTP")

        return await self._open_web_page_raw(url, char_limit)

    async def _open_web_page_crawl4ai(self, url: str, char_limit: int,
                                      crawl_url: str) -> dict:
        """Fetch a page via Crawl4AI API."""
        try:
            endpoint = crawl_url.rstrip("/") + "/crawl"
            payload = {"urls": url, "priority": 10}

            timeout = aiohttp.ClientTimeout(total=30)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(endpoint, json=payload, headers={"Content-Type": "application/json"}) as resp:
                    if resp.status >= 400:
                        return {"url": url, "content": "", "error": f"Crawl4AI HTTP {resp.status}"}
                    data = await resp.json()

            results = data.get("results", [])
            if not results:
                return {"url": url, "content": "", "error": "Crawl4AI returned no results"}

            first = results[0] if isinstance(results, list) else results
            markdown = first.get("markdown", "") or first.get("cleaned_html", "") or ""
            title = first.get("metadata", {}).get("title", "") if isinstance(first.get("metadata"), dict) else ""
            content = markdown[:char_limit] if markdown else ""

            return {
                "url": url,
                "title": title[:200],
                "content_type": "text/markdown",
                "content": content,
            }
        except Exception as e:
            return {"url": url, "content": "", "error": f"Crawl4AI: {e}"}

    async def _open_web_page_firecrawl(self, url: str, char_limit: int,
                                        firecrawl_url: str, api_key: str) -> dict:
        """Fetch a page via Firecrawl API (handles JS-rendered content)."""
        try:
            scrape_url = firecrawl_url.rstrip("/") + "/v1/scrape"
            headers = {"Content-Type": "application/json"}
            if api_key:
                headers["Authorization"] = f"Bearer {api_key}"

            payload = {
                "url": url,
                "formats": ["markdown"],
            }

            timeout = aiohttp.ClientTimeout(total=30)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(scrape_url, json=payload, headers=headers) as resp:
                    if resp.status >= 400:
                        body = await resp.text(errors="ignore")
                        return {"url": url, "content": "", "error": f"Firecrawl HTTP {resp.status}: {body[:200]}"}
                    data = await resp.json()

            result_data = data.get("data", {})
            markdown = result_data.get("markdown", "")
            metadata = result_data.get("metadata", {})
            title = metadata.get("title", "")[:200]
            content = markdown[:char_limit] if markdown else ""

            return {
                "url": metadata.get("sourceURL", url),
                "title": title,
                "content_type": "text/markdown",
                "content": content,
            }
        except Exception as e:
            return {"url": url, "content": "", "error": f"Firecrawl: {e}"}

    async def _open_web_page_raw(self, url: str, char_limit: int) -> dict:
        """Fetch a page via raw HTTP + HTML stripping (fallback)."""
        try:
            timeout = aiohttp.ClientTimeout(total=12)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(
                    url,
                    headers={"User-Agent": f"{self.bot_name}/1.0"},
                    allow_redirects=True,
                ) as resp:
                    content_type = resp.headers.get("Content-Type", "")
                    if resp.status >= 400:
                        return {"url": url, "content": "", "error": f"HTTP {resp.status}"}
                    raw = await resp.text(errors="ignore")
                    cleaned = self._sanitize_page_text(raw, char_limit)
                    title_match = re.search(r"(?is)<title[^>]*>(.*?)</title>", raw)
                    title = self._sanitize_page_text(title_match.group(1), 200) if title_match else ""
                    return {
                        "url": str(resp.url),
                        "title": title,
                        "content_type": content_type,
                        "content": cleaned,
                    }
        except Exception as e:
            return {"url": url, "content": "", "error": str(e)}

    async def _search_ddg_for_tool(self, query: str) -> str:
        """Search wrapper for tool calling."""
        return await self._search_ddg(query, max_results=3)

    async def _call_surfing_model(self, messages, role="surfing"):
        """Call a surfing model (planner or eval). Falls back to main model."""
        client_pair = self._surfing_planner_client if role == "surfing" else self._surfing_eval_client
        if not client_pair:
            return await self.llm.call_llm(messages=messages, log_label=f"{role}_fallback")

        client, model_name = client_pair
        response = await client.chat.completions.create(
            model=model_name, messages=messages,
        )
        content = (response.choices[0].message.content or "").strip()
        actual_model = getattr(response, 'model', model_name)
        usage = getattr(response, 'usage', None)
        if usage:
            _cost = getattr(usage, 'total_cost', 0.0) or getattr(usage, 'cost', 0.0) or 0.0
            await self.auditor.record(
                "_surfing", "surfing", actual_model,
                getattr(usage, 'prompt_tokens', 0),
                getattr(usage, 'completion_tokens', 0),
                getattr(getattr(usage, 'prompt_tokens_details', None), 'cached_tokens', 0),
                cost=float(_cost),
            )
        return LLMResult(content=content, model=actual_model)

    def _parse_json_response(self, text: str):
        """Strip markdown fences and parse JSON."""
        if text.startswith("```"):
            lines = text.split("\n")
            text = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
        return json.loads(text.strip())

    def _append_surf_note(self, notes: List[str], text: str, max_chars: int):
        text = (text or "").strip()
        if not text:
            return
        notes.append(text)
        total = 0
        kept = []
        for item in reversed(notes):
            total += len(item)
            if total > max_chars:
                break
            kept.append(item)
        notes[:] = list(reversed(kept))

    def _pick_candidate_targets(self, triggered_by: Optional[str], planned_queries: List[dict]) -> List[str]:
        if triggered_by:
            return self._filter_reachable_targets([triggered_by])

        targets = []
        for item in planned_queries:
            for jid in item.get("target_contacts", []) or []:
                if jid and jid not in targets:
                    targets.append(jid)
        if targets:
            return self._filter_reachable_targets(targets)

        return self._reachable_contact_ids()

    async def do_surf_once(self, triggered_by: str = None):
        """
        Execute one surfing round.
        triggered_by: if set, this is a manual /surf from this jid — share findings with them directly.
        """
        if not self.memory:
            logger.info(f"[{self.bot_name}] Surf skipped: no memory manager")
            if triggered_by:
                await self._surf_reply(triggered_by, "Memory system not ready, cannot surf.")
            return

        # Load context
        autonomous_config = self.memory.load_autonomous_config()
        friends_impressions = self.memory.load_friends_impressions()

        user_contexts = ""
        try:
            user_contexts = self.memory.get_all_user_contexts()
        except Exception:
            pass

        # Check if we have enough context to surf
        has_context = bool(friends_impressions.strip()) or bool(user_contexts.strip()) or bool(autonomous_config.get("surfing_focus_notes", "").strip())
        if not has_context and triggered_by:
            await self._surf_reply(
                triggered_by,
                "Not enough context about this contact to decide what to search for."
            )
            return

        budget_profile = self._build_surfing_budget_profile(triggered_by)
        trigger_mode = "manual" if triggered_by else "autonomous"
        candidate_targets = []

        # Optionally fetch RSS items as additional data source
        rss_context = ""
        if self.rsshub_server and self.memory:
            try:
                rsshub_routes = self.memory.load_rsshub_routes()
                if rsshub_routes:
                    rss_items = await self._fetch_rss(rsshub_routes)
                    if rss_items:
                        rss_lines = []
                        for i, item in enumerate(rss_items[:15]):
                            rss_lines.append(
                                f"{i+1}. {item.get('title', '')}\n"
                                f"   Link: {item.get('link', '')}\n"
                                f"   Summary: {item.get('summary', '')[:200]}"
                            )
                        rss_context = "[Recent RSS feed items]\n" + "\n".join(rss_lines)
                        logger.info(f"[{self.bot_name}] Surfing: fetched {len(rss_items)} RSS items as context")
            except Exception as e:
                logger.warning(f"[{self.bot_name}] Failed to fetch RSS for surfing: {e}")

        # Step 1: Plan queries
        network_global = self.config.get("network_global", True)
        network_note = ""
        if not network_global:
            network_note = (
                "IMPORTANT: This server is behind China's GFW. Google, YouTube, Twitter/X, Reddit, "
                "Wikipedia etc. are NOT accessible. Use Bing, Baidu, or domestic sites for searches. "
                "Some RSS routes for foreign sites may also fail.\n"
            )

        plan_input = (
            f"{network_note}"
            f"Trigger mode: {trigger_mode}\n"
            f"Triggered by: {triggered_by or 'none, autonomous surfing'}\n"
            f"Current time: {datetime.now().isoformat()}\n"
            f"Round budget: {json.dumps(budget_profile, ensure_ascii=False)}\n"
            f"Friends profile:\n{friends_impressions}\n"
            f"User context:\n{user_contexts[:2000]}\n"
            f"Previous focus direction:\n{autonomous_config.get('surfing_focus_notes', '')}\n"
        )
        if rss_context:
            plan_input += (
                f"\n{rss_context}\n\n"
                "You have both web search and RSS feeds available. "
                "RSS items above are already fetched — reference them directly if relevant. "
                "Only plan web searches for topics NOT covered by RSS.\n\n"
            )
        else:
            plan_input += "\n"
        plan_input += (
            f"Plan up to {budget_profile['max_initial_queries']} search queries."
            ' Output JSON: [{"query": "...", "reason": "...", "target_contacts": ["jid1"]}]'
        )
        plan_messages = [
            {"role": "system", "content": self.surfing_prompt or "You are an intelligent search planner."},
            {"role": "user", "content": plan_input},
        ]

        plan_result = await self._call_surfing_model(plan_messages, role="surfing")
        logger.info(f"[{self.bot_name}] Surfing plan: {plan_result.content[:200]}")

        queries = self._parse_json_response(plan_result.content)
        if not queries:
            logger.info(f"[{self.bot_name}] Surfing: no queries planned")
            if triggered_by:
                await self._surf_reply(triggered_by, "Nothing worth searching for right now.")
            return

        candidate_targets = self._pick_candidate_targets(triggered_by, queries)

        # Step 2: Execute searches with optional deep reading and follow-up search
        pending_queries = [
            {
                "query": q.get("query", ""),
                "reason": q.get("reason", ""),
                "target_contacts": q.get("target_contacts", []) or [],
                "depth": 0,
            }
            for q in queries[:budget_profile["max_initial_queries"]]
            if q.get("query", "").strip()
        ]
        temporary_notes: List[str] = []
        search_results = []
        search_count = 0
        seen_queries = set()

        while pending_queries and search_count < budget_profile["max_searches"]:
            item = pending_queries.pop(0)
            query_text = item.get("query", "").strip()
            if not query_text or query_text in seen_queries:
                continue

            seen_queries.add(query_text)
            search_count += 1
            logger.info(f"[{self.bot_name}] Surfing search {search_count}/{budget_profile['max_searches']}: {query_text}")

            raw_results = await self._search_ddg_items(
                query_text,
                max_results=budget_profile["search_results_per_query"],
            )

            opened_pages = []
            pages_to_open = budget_profile["max_pages_to_open_per_query"]
            for result in raw_results[:pages_to_open]:
                if not result.get("url"):
                    continue
                page = await self._open_web_page(
                    result["url"],
                    char_limit=budget_profile["page_char_budget"],
                )
                if page.get("content"):
                    opened_pages.append(page)

            search_entry = {
                "query": query_text,
                "reason": item.get("reason", ""),
                "target_contacts": item.get("target_contacts", []),
                "results": raw_results,
                "opened_pages": opened_pages,
                "depth": item.get("depth", 0),
            }
            search_results.append(search_entry)

            step_eval_system = (
                "You are a research assistant during a surfing session. Based on this round's search results, "
                "opened page content, and existing temporary notes, extract findings worth keeping and decide "
                "whether it's worth continuing to search in a particular direction.\n"
                "Output JSON:\n"
                "{\n"
                '  "notes": "temporary notes for yourself recording truly new information from this round; empty string if none",\n'
                '  "follow_up_queries": [{"query": "follow-up search terms", "reason": "why continue searching"}],\n'
                '  "focus_notes": "directions to focus on next surfing session; empty string if none"\n'
                "}"
            )
            step_eval_user = (
                f"Trigger mode: {trigger_mode}\n"
                f"Candidate share targets: {candidate_targets}\n"
                f"Budget: {json.dumps(budget_profile, ensure_ascii=False)}\n"
                f"Existing temporary notes:\n{chr(10).join(temporary_notes)[:budget_profile['max_notes_chars']]}\n\n"
                f"This round's search:\n{json.dumps(search_entry, ensure_ascii=False)[:7000]}"
            )
            step_eval = await self._call_surfing_model(
                [
                    {"role": "system", "content": step_eval_system},
                    {"role": "user", "content": step_eval_user},
                ],
                role="surfing",
            )

            logger.info(f"[{self.bot_name}] Surfing step eval: {step_eval.content[:300]}")
            try:
                step_data = self._parse_json_response(step_eval.content)
            except Exception:
                step_data = {}

            self._append_surf_note(
                temporary_notes,
                step_data.get("notes", ""),
                budget_profile["max_notes_chars"],
            )
            self._append_surf_note(
                temporary_notes,
                step_data.get("focus_notes", ""),
                budget_profile["max_notes_chars"],
            )

            remaining = budget_profile["max_searches"] - search_count
            follow_ups = step_data.get("follow_up_queries", []) or []
            for follow in follow_ups[:min(remaining, budget_profile["max_follow_up_queries_per_step"])]:
                follow_query = (follow.get("query", "") or "").strip()
                if not follow_query or follow_query in seen_queries:
                    continue
                pending_queries.append({
                    "query": follow_query,
                    "reason": follow.get("reason", ""),
                    "target_contacts": item.get("target_contacts", []),
                    "depth": item.get("depth", 0) + 1,
                })

        # Step 3: Final expensive evaluation for sharing
        eval_system = (
            "You are a surfing summary and sharing decision maker. First determine whether these findings "
            "are truly worth telling the user, considering whether the user needs them, whether the user "
            "likely already knows, and whether this was a self-initiated search.\n"
            "Output JSON:\n"
            "{\n"
            '  "findings": "final surfing notes for yourself; empty string if no new value",\n'
            '  "share_worthy": true/false,\n'
            '  "share_targets": ["jid1"],\n'
            '  "focus_notes": "what direction to focus on next surfing session",\n'
            '  "share_brief": "if worth mentioning, the key point to tell the user; otherwise empty string",\n'
            '  "why_share": "why it is or isn\'t worth sharing, for system judgment"\n'
            "}"
        )
        eval_messages = [
            {"role": "system", "content": eval_system},
            {"role": "user", "content": (
                f"Trigger mode: {trigger_mode}\n"
                f"Triggered by: {triggered_by or 'none'}\n"
                f"Candidate share targets: {candidate_targets}\n"
                f"Budget: {json.dumps(budget_profile, ensure_ascii=False)}\n"
                f"Friends profile:\n{friends_impressions}\n\n"
                f"User context:\n{user_contexts[:2500]}\n\n"
                f"Temporary notes:\n{chr(10).join(temporary_notes)[:budget_profile['max_notes_chars']]}\n\n"
                f"Search results:\n{json.dumps(search_results, ensure_ascii=False)[:8000]}"
                + (f"\n\nRSS feed context:\n{rss_context[:3000]}" if rss_context else "")
            )},
        ]

        eval_result = await self._call_surfing_model(eval_messages, role="surfing_eval")
        logger.info(f"[{self.bot_name}] Surfing eval: {eval_result.content[:300]}")

        evaluation = self._parse_json_response(eval_result.content)

        findings = evaluation.get("findings", "")
        share_worthy = evaluation.get("share_worthy", False)
        focus_notes = evaluation.get("focus_notes", "")
        share_brief = evaluation.get("share_brief", "")
        share_targets = evaluation.get("share_targets", []) or candidate_targets

        # Update autonomous config
        if focus_notes:
            autonomous_config["surfing_focus_notes"] = focus_notes
        self.memory.save_autonomous_config(autonomous_config)

        # Step 4: Share findings
        search_summary = json.dumps(search_results, ensure_ascii=False)[:3000]
        if triggered_by:
            context = (
                f"Final surfing notes:\n{findings}\n\n"
                f"Key points worth mentioning:\n{share_brief}\n\n"
                f"Raw search results:\n{search_summary}"
            ) if findings else f"Search results:\n{search_summary}\n\nNothing particularly noteworthy this time."
            await self._surf_reply(triggered_by, context, trigger_mode="manual")
        elif share_worthy and findings and not self._is_quiet_hours():
            await self._auto_share_findings(
                autonomous_config,
                findings,
                share_brief or findings,
                search_summary,
                share_targets,
            )

        logger.info(f"[{self.bot_name}] Surfing round complete")

    async def _surf_reply(self, target_jid: str, context_note: str, trigger_mode: str = "autonomous"):
        """Inject surfing context into the conversation and let the main model respond naturally.

        Uses the normal chat flow so the bot responds in its own voice with full conversation context.
        """
        target_jid = self._normalize_contact_id(target_jid)
        if not target_jid:
            logger.info(f"[{self.bot_name}] Skip surf reply to unreachable target")
            return

        if trigger_mode == "manual":
            note = (
                "You just browsed the web as requested by the user. You MUST reply with what you found. "
                "Do NOT output [SILENT]. Share the results naturally — don't use a formal report tone. "
                "Even if nothing interesting was found, briefly mention what you searched and that nothing stood out. "
                f"Internal surfing context:\n{context_note}"
            )
        else:
            note = (
                "You just browsed the web on your own. This is not a user-requested task and not a report. "
                "Only mention findings if they genuinely add new value for the current contact and "
                "they likely don't already know; otherwise stay silent and output [SILENT]. "
                f"Internal surfing context:\n{context_note}"
            )

        self.llm.add_pending_note(note)
        replies = await self.llm.chat_blocking(target_jid, None)

        # Manual trigger: guarantee a reply even if model returned empty/silent
        if trigger_mode == "manual" and not replies:
            replies = ["刚浏览了一圈，没找到什么特别的。"]

        for reply in replies:
            if reply:
                self._send_message(target_jid, reply)
                logger.info(f"[{self.bot_name}] Surf reply to {target_jid}: {reply}")

    async def _auto_share_findings(
        self,
        autonomous_config: dict,
        findings: str,
        share_brief: str,
        search_summary: str = "",
        target_jids: Optional[List[str]] = None,
    ):
        """Auto-share findings with users, respecting cooldowns."""
        if not self._last_chat_time:
            return

        targets = self._filter_reachable_targets(target_jids or self._reachable_contact_ids())
        for target_jid in targets:
            if target_jid not in self.llm._histories:
                continue
            last_times = autonomous_config.get("last_proactive_msg_time", {})
            cooldown = autonomous_config.get("surfing_cooldown_per_contact", {}).get(target_jid, 3600)
            last_time = last_times.get(target_jid, "")
            if last_time:
                try:
                    lt = datetime.fromisoformat(last_time)
                    if (datetime.now() - lt).total_seconds() < cooldown:
                        logger.info(f"Skipping proactive surf to {target_jid}: cooldown")
                        continue
                except Exception:
                    pass

            context = f"Final surfing notes:\n{findings}\n\nIf mentioning to the contact, only mention this key point:\n{share_brief}"
            if search_summary:
                context += f"\n\nRaw search results:\n{search_summary}"
            await self._surf_reply(target_jid, context, trigger_mode="autonomous")

            if "last_proactive_msg_time" not in autonomous_config:
                autonomous_config["last_proactive_msg_time"] = {}
            autonomous_config["last_proactive_msg_time"][target_jid] = datetime.now().isoformat()
            if self.memory:
                self.memory.save_autonomous_config(autonomous_config)
            break

    async def _surfing_loop(self):
        """Autonomous web surfing loop with activity-aware scheduling."""
        if not self.surfing_config.get("enabled", False):
            # Wait indefinitely so the task doesn't exit early
            while not self._stopping:
                await asyncio.sleep(3600)
            return

        await asyncio.sleep(30)  # Initial delay

        while not self._stopping:
            try:
                interval = self._get_surfing_interval()
                await asyncio.sleep(interval)

                if not self._should_surf():
                    logger.debug(f"[{self.bot_name}] Surfing skipped: quiet hours or idle too long")
                    continue

                await self.do_surf_once()

            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"[{self.bot_name}] Surfing error: {e}", exc_info=True)

    # ── Skill watching ───────────────────────────────────────────────────────

    def _get_skills_mtime(self) -> float:
        latest = 0.0
        for d in self.skill_dirs:
            if not os.path.isdir(d):
                continue
            for root, dirs, files in os.walk(d):
                dirs[:] = [name for name in dirs if not name.startswith(".") and name != "__pycache__"]
                for fname in files:
                    if fname.startswith(".") or fname.endswith((".pyc", ".pyo")):
                        continue
                    try:
                        t = os.path.getmtime(os.path.join(root, fname))
                        latest = max(latest, t)
                    except OSError:
                        pass
        return latest

    async def _watch_skills(self):
        """Poll skill dirs every 2 seconds and hot-reload on file changes."""
        last_mtime = self._get_skills_mtime()
        while not self._stopping:
            await asyncio.sleep(2)
            current_mtime = self._get_skills_mtime()
            if current_mtime != last_mtime:
                last_mtime = current_mtime
                try:
                    new_skills = load_skills(*self.skill_dirs)
                    new_tools = skills_to_openai_tools(new_skills) if new_skills else None
                    new_executors = get_skill_executor(new_skills) if new_skills else {}
                    self.llm.reload_skills(new_tools, new_executors)
                    names = list(new_executors.keys())
                    note = f"Skills updated! Current skills: {', '.join(names)}"
                    self.llm.add_pending_note(note)
                    logger.info(f"[{self.bot_name}] Skills hot-reloaded: {names}")
                except asyncio.CancelledError:
                    break
                except Exception as e:
                    logger.error(f"[{self.bot_name}] Skill reload error: {e}")

    # ── Lifecycle ────────────────────────────────────────────────────────────

    async def start_tasks(self) -> list:
        """Start all background tasks. Returns task list for the caller to manage."""
        tasks = [
            asyncio.create_task(self._watch_skills()),
            asyncio.create_task(self._watch_update_packages()),
            asyncio.create_task(self._surfing_loop()),
        ]
        return tasks

    def stop(self):
        self._stopping = True
        # Cancel all pending tasks
        for task in list(self._reflection_tasks.values()) + list(self._critic_tasks.values()):
            if task and not task.done():
                task.cancel()

    def on_new_message(self, sender_jid: str):
        """Called when a new message arrives — cancel pending background tasks for this contact."""
        self._last_chat_time = datetime.now()
        self._cancel_reflection(sender_jid)
        self._cancel_critic(sender_jid)

    async def reset(self, sender_jid: str) -> int:
        """Reset state for a specific contact only. Does NOT delete shared bot-level data."""
        count = 0

        # 1. Clear in-memory chat history for this contact
        if sender_jid in self.llm._histories:
            count += len(self.llm._histories[sender_jid])
            del self.llm._histories[sender_jid]

        # 2. Cancel pending tasks for this contact
        self._cancel_reflection(sender_jid)
        self._cancel_critic(sender_jid)

        # 3. Delete Memobase user data for this contact
        if self.memory:
            try:
                self.memory.delete_user(sender_jid)
                count += 1
            except Exception as e:
                logger.warning(f"Failed to delete Memobase user {sender_jid}: {e}")

        # 4. Reset token budget for this contact
        if sender_jid in self._token_budgets:
            del self._token_budgets[sender_jid]
            count += 1

        # Note: shared bot-level files (friends_impressions.md, bot_self_reflection.json,
        # autonomous_config.json, etc.) are NOT deleted — they belong to all contacts.

        logger.info(f"[{self.bot_name}] Reset for {sender_jid}: cleared {count} items")
        return count
