"""
token_auditor.py - Token consumption tracking and auditing.

Records per-contact, per-task, per-model token usage with sliding time windows.
Writes audit data to a JSON file for model read-only access.
"""

import json
import os
import time
import logging
import asyncio
from datetime import datetime, timedelta
from typing import Optional
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


@dataclass
class LLMResult:
    """Result from an LLM call, including token usage."""
    content: str
    prompt_tokens: int = 0
    completion_tokens: int = 0
    cached_tokens: int = 0
    model: str = ""  # Actual model used (from response.model)


class TokenAuditor:
    """
    Tracks token consumption per contact, task type, and model.
    Maintains a sliding 3-hour window and daily/total aggregates.
    """

    def __init__(self, audit_file_path: str):
        self.audit_file_path = audit_file_path
        self._lock = asyncio.Lock()
        # Detailed records for sliding window: [(timestamp, contact_jid, task_type, model, prompt, completion, cached)]
        self._records: list = []
        # Persistent totals: {contact_jid: {task_type: {prompt, completion, cached}, ...}, ...}
        self._totals: dict = {}
        # Per-model totals: {contact_jid: {model: {prompt, completion, cached}}}
        self._model_totals: dict = {}
        # Daily totals with date key
        self._daily: dict = {}  # {date_str: {contact_jid: {prompt, completion, cached}}}
        self._load()

    def _load(self):
        """Load persisted audit data."""
        if not os.path.isfile(self.audit_file_path):
            return
        try:
            with open(self.audit_file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            self._totals = data.get("_totals", {})
            self._model_totals = data.get("_model_totals", {})
            self._daily = data.get("_daily", {})
            # Records are not persisted (only for 3h window, rebuilt from runtime)
        except Exception as e:
            logger.warning(f"Failed to load token audit: {e}")

    async def record(
        self,
        contact_jid: str,
        task_type: str,
        model: str,
        prompt_tokens: int,
        completion_tokens: int,
        cached_tokens: int = 0,
    ):
        """Record a token consumption event."""
        async with self._lock:
            now = time.time()
            today = datetime.now().strftime("%Y-%m-%d")

            # Add to sliding window records
            self._records.append((now, contact_jid, task_type, model, prompt_tokens, completion_tokens, cached_tokens))

            # Update totals by task
            if contact_jid not in self._totals:
                self._totals[contact_jid] = {}
            by_task = self._totals[contact_jid]
            if task_type not in by_task:
                by_task[task_type] = {"prompt": 0, "completion": 0, "cached": 0}
            by_task[task_type]["prompt"] += prompt_tokens
            by_task[task_type]["completion"] += completion_tokens
            by_task[task_type]["cached"] += cached_tokens

            # Update totals by model
            if contact_jid not in self._model_totals:
                self._model_totals[contact_jid] = {}
            by_model = self._model_totals[contact_jid]
            if model not in by_model:
                by_model[model] = {"prompt": 0, "completion": 0, "cached": 0}
            by_model[model]["prompt"] += prompt_tokens
            by_model[model]["completion"] += completion_tokens
            by_model[model]["cached"] += cached_tokens

            # Update daily totals
            if today not in self._daily:
                self._daily[today] = {}
            if contact_jid not in self._daily[today]:
                self._daily[today][contact_jid] = {"prompt": 0, "completion": 0, "cached": 0}
            self._daily[today][contact_jid]["prompt"] += prompt_tokens
            self._daily[today][contact_jid]["completion"] += completion_tokens
            self._daily[today][contact_jid]["cached"] += cached_tokens

            # Cleanup old records and save
            self._cleanup()
            self._save()

    def _cleanup(self):
        """Remove records older than 3 hours. Clean up old daily entries (keep 7 days)."""
        cutoff = time.time() - 3 * 3600
        self._records = [r for r in self._records if r[0] >= cutoff]

        # Clean old daily entries
        week_ago = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
        self._daily = {k: v for k, v in self._daily.items() if k >= week_ago}

    def _compute_3h(self) -> dict:
        """Compute 3-hour sliding window aggregates."""
        cutoff = time.time() - 3 * 3600
        result = {}  # {contact_jid: {prompt, completion, cached}}
        for ts, jid, task, model, p, c, cached in self._records:
            if ts < cutoff:
                continue
            if jid not in result:
                result[jid] = {"prompt": 0, "completion": 0, "cached": 0}
            result[jid]["prompt"] += p
            result[jid]["completion"] += c
            result[jid]["cached"] += cached
        return result

    def _save(self):
        """Write audit data to JSON file."""
        today = datetime.now().strftime("%Y-%m-%d")
        three_h = self._compute_3h()

        # Build per-contact output
        contacts = {}
        all_jids = set(self._totals.keys()) | set(self._model_totals.keys())
        for jid in all_jids:
            contact_total = {"prompt": 0, "completion": 0, "cached": 0}
            by_task = self._totals.get(jid, {})
            for task_data in by_task.values():
                for k in ("prompt", "completion", "cached"):
                    contact_total[k] += task_data.get(k, 0)

            contacts[jid] = {
                "last_3h": three_h.get(jid, {"prompt": 0, "completion": 0, "cached": 0}),
                "today": self._daily.get(today, {}).get(jid, {"prompt": 0, "completion": 0, "cached": 0}),
                "total": contact_total,
                "by_task": by_task,
                "by_model": self._model_totals.get(jid, {}),
            }

        # Build global aggregates
        global_total = {"prompt": 0, "completion": 0, "cached": 0}
        global_3h = {"prompt": 0, "completion": 0, "cached": 0}
        global_today = {"prompt": 0, "completion": 0, "cached": 0}
        global_by_task = {}
        global_by_model = {}

        for jid, cdata in contacts.items():
            for k in ("prompt", "completion", "cached"):
                global_total[k] += cdata["total"].get(k, 0)
                global_3h[k] += cdata["last_3h"].get(k, 0)
                global_today[k] += cdata["today"].get(k, 0)
            for task, tdata in cdata.get("by_task", {}).items():
                if task not in global_by_task:
                    global_by_task[task] = {"prompt": 0, "completion": 0, "cached": 0}
                for k in ("prompt", "completion", "cached"):
                    global_by_task[task][k] += tdata.get(k, 0)
            for model, mdata in cdata.get("by_model", {}).items():
                if model not in global_by_model:
                    global_by_model[model] = {"prompt": 0, "completion": 0, "cached": 0}
                for k in ("prompt", "completion", "cached"):
                    global_by_model[model][k] += mdata.get(k, 0)

        output = {
            "contacts": contacts,
            "global": {
                "last_3h": global_3h,
                "today": global_today,
                "total": global_total,
                "by_task": global_by_task,
                "by_model": global_by_model,
            },
            "last_updated": datetime.now().isoformat(),
            # Internal state for persistence (not for model consumption)
            "_totals": self._totals,
            "_model_totals": self._model_totals,
            "_daily": self._daily,
        }

        try:
            os.makedirs(os.path.dirname(self.audit_file_path), exist_ok=True)
            with open(self.audit_file_path, "w", encoding="utf-8") as f:
                json.dump(output, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"Failed to save token audit: {e}")

    def get_audit(self) -> dict:
        """Read the current audit data (for injection into context)."""
        if not os.path.isfile(self.audit_file_path):
            return {}
        try:
            with open(self.audit_file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            # Strip internal fields
            data.pop("_totals", None)
            data.pop("_model_totals", None)
            data.pop("_daily", None)
            return data
        except Exception:
            return {}
