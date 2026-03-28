"""
llm_agent.py - Core LLM integration layer.

Handles OpenAI-compatible API calls, conversation history management,
streaming, tool/skill execution, and message formatting.
Background behaviors (reflection, memory update, RSS, critic, surfing) live in bot_brain.py.
"""

import json
import re
import logging
from typing import Optional, List, Dict
from openai import AsyncOpenAI

from src.token_auditor import LLMResult
from src.contact_ids import split_contact_id

logger = logging.getLogger(__name__)

# Message separator used between multiple messages in a single reply
MSG_SEPARATOR = "|||"

# Silence indicators used by the bot to indicate no response
SILENCE_INDICATORS = ('[]', '[ ]', '[]。', '[].', '[SILENT]')

# Matches timestamp prefixes like [2026-03-25 16:40:02] or legacy [16:40:02]
_TS_PREFIX_RE = re.compile(r'^\[\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\]\s*|^\[\d{2}:\d{2}:\d{2}\]\s*')

# Matches <think>...</think> blocks (possibly spanning multiple lines)
_THINK_BLOCK_RE = re.compile(r'<think>.*?</think>', re.DOTALL)

# Standard timestamp format for history messages
TS_FORMAT = "%Y-%m-%d %H:%M:%S"
SUMMARY_MARKER = "[Conversation summary]"


def _strip_ts_prefix(text: str) -> str:
    """Remove a leading timestamp prefix from text (e.g. [2026-03-25 16:40:02] )."""
    return _TS_PREFIX_RE.sub('', text)


def _strip_thinking(text: str) -> str:
    """Remove <think>...</think> blocks from text (thinking model output)."""
    return _THINK_BLOCK_RE.sub('', text).strip()


def _split_replies(content: str) -> list:
    """
    Split LLM output into separate messages.
    Only split on ||| — never on newlines (a single message may contain line breaks).
    Strips thinking blocks and timestamp prefixes.
    """
    content = _strip_thinking(content)
    parts = [_strip_ts_prefix(p.strip()) for p in content.split(MSG_SEPARATOR) if p.strip()]
    return [p for p in parts if p] or [_strip_ts_prefix(content)]


# The format constraint appended to every bot's system prompt
REPLY_FORMAT_INSTRUCTION = """

## Reply rules (must be followed in every conversation)

Always reply in the same language the user is using. If you cannot determine the user's language, default to English.

Before replying, think through this checklist:
1. What is my relationship with this person? What tone fits — am I being too formal, too polite, or trying too hard to be funny?
2. What does this person actually need right now (emotional support, information, practical help)? What can I do?
3. Could my reply make them uncomfortable? If I were them, how would I feel reading this message?
4. Is what I am saying accurate? If I am not sure, I should not ramble confidently.
5. Am I ending with filler questions like "what's new" or "how have you been"? Am I forcing interaction or tossing the topic back at them? If so, remove it. Do not end with a question just to fill space — saying nothing is better than small talk.
6. Does my tone sound like a friend, not customer service? Is it concise? Any unnecessary preamble?

**Reply format:**
- Write like a casual chat: short messages, sent one at a time
- Prefer minimal punctuation; use spaces instead of commas where natural. Do not send a wall of text
- Share your own thoughts proactively instead of always asking "what do you think"
- You MUST use ||| to separate multiple messages. Do NOT use double newlines or blank lines as separators — that will break the system. A single message CAN contain line breaks within it; only ||| marks the boundary between separate messages
- Never output JSON, code fences, timestamps (like [HH:MM:SS]), or meta-commentary
- If the other person sends a minimal acknowledgment ("ok", "got it", "haha", "sure", etc.) and there is genuinely nothing to add, output only [SILENT] with no other text
- Output message content directly, for example:
haha long time no see|||what have you been up to|||I just switched jobs

**Internal review flag:**
- If you are unsure about something you said, or if being wrong could cause real harm (practical or trust-related), append [NEED_REVIEW] at the very end of your reply
- This flag is never shown to the other person — it only triggers an internal review
- Whether to flag is your judgment call: consider "if I am wrong, how bad are the consequences" rather than categorizing by topic
- If you are slightly unsure but the stakes are low, just mention it naturally in your reply (e.g. "not 100% sure though") — no flag needed
"""


class LLMAgent:
    def __init__(
        self,
        api_key: str,
        base_url: str,
        model: str,
        system_prompt: str,
        max_history_tokens: int = 4000,
        tools: Optional[List[dict]] = None,
        skill_executors: Optional[Dict] = None,
        memory_manager=None,
        history_summary_prompt: str = "",
        bot_abilities: str = "",
    ):
        self.client = AsyncOpenAI(api_key=api_key, base_url=base_url)
        self.model = model
        self.system_prompt = system_prompt + REPLY_FORMAT_INSTRUCTION
        self.bot_abilities = bot_abilities
        self.memory_manager = memory_manager
        self.history_summary_prompt = history_summary_prompt
        self.max_history_tokens = max_history_tokens
        self.tools = tools
        self.skill_executors = skill_executors or {}
        self._pending_notes: List[str] = []
        self._histories: Dict[str, List[dict]] = {}
        # Last LLM result (for token auditing by bot_brain)
        self.last_result: Optional[LLMResult] = None

    @staticmethod
    def _is_summary_message(message: dict) -> bool:
        return (
            isinstance(message, dict)
            and message.get("role") == "system"
            and isinstance(message.get("content"), str)
            and message["content"].startswith(SUMMARY_MARKER)
        )

    def _get_history(self, contact_jid: str) -> List[dict]:
        if contact_jid not in self._histories:
            self._histories[contact_jid] = []
        return self._histories[contact_jid]

    def add_pending_note(self, note: str):
        self._pending_notes.append(note)

    def reload_skills(self, tools: Optional[List[dict]], skill_executors: Dict):
        self.tools = tools
        self.skill_executors = skill_executors
        logger.info(f"Skills reloaded: {list(skill_executors.keys())}")

    # ── History management ───────────────────────────────────────────────────

    def _trim_history(self, history: List[dict]) -> List[dict]:
        """Trim history to fit within token budget. Returns removed messages."""
        max_chars = self.max_history_tokens * 4
        removed = []
        while history:
            total = sum(len(str(m.get("content", ""))) for m in history)
            if total <= max_chars:
                break
            removed.append(history.pop(0))
        return removed

    async def _summarize_and_trim(self, contact_jid: str, history: List[dict]):
        """If history is over budget, summarize dropped messages."""
        prior_summary = ""
        if history and self._is_summary_message(history[0]):
            prior_summary = history.pop(0).get("content", "").strip()

        if not self.history_summary_prompt or not self.memory_manager:
            self._trim_history(history)
            if prior_summary:
                history.insert(0, {"role": "system", "content": prior_summary})
            return

        removed = self._trim_history(history)
        if not removed:
            if prior_summary:
                history.insert(0, {"role": "system", "content": prior_summary})
            return

        # Send removed messages to Memobase before discarding
        try:
            for m in removed:
                if m.get("role") == "user":
                    # Find next assistant reply
                    pass  # Memobase already received these via insert_chat
        except Exception:
            pass

        removed_text = "\n".join(
            f"{m['role'].upper()}: {m.get('content', '')[:400]}" for m in removed
        )
        try:
            resp = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": self.history_summary_prompt},
                    {"role": "user", "content": removed_text},
                ],
            )
            summary = (resp.choices[0].message.content or "").strip()
            # Token tracking for summary
            actual_model = getattr(resp, 'model', self.model)
            usage = getattr(resp, 'usage', None)
            self.last_result = LLMResult(
                content=summary,
                prompt_tokens=getattr(usage, 'prompt_tokens', 0) if usage else 0,
                completion_tokens=getattr(usage, 'completion_tokens', 0) if usage else 0,
                cached_tokens=getattr(getattr(usage, 'prompt_tokens_details', None), 'cached_tokens', 0) if usage else 0,
                model=actual_model,
            )
            if summary:
                merged_summary = summary
                if prior_summary:
                    merged_summary = f"{prior_summary}\n\n{summary}"
                history.insert(0, {"role": "system", "content": f"{SUMMARY_MARKER}\n{merged_summary}"})
                logger.info(f"Summarized {len(removed)} trimmed messages for {contact_jid}")
            elif prior_summary:
                history.insert(0, {"role": "system", "content": prior_summary})
        except Exception as e:
            if prior_summary:
                history.insert(0, {"role": "system", "content": prior_summary})
            logger.warning(f"Failed to summarize history for {contact_jid}: {e}")

    # ── Core LLM calls ──────────────────────────────────────────────────────

    def _extract_llm_result(self, response) -> LLMResult:
        """Extract content and usage from an API response."""
        content = _strip_thinking((response.choices[0].message.content or "").strip())
        actual_model = getattr(response, 'model', self.model)
        usage = getattr(response, 'usage', None)
        prompt_tokens = getattr(usage, 'prompt_tokens', 0) if usage else 0
        completion_tokens = getattr(usage, 'completion_tokens', 0) if usage else 0
        cached_tokens = 0
        if usage:
            details = getattr(usage, 'prompt_tokens_details', None)
            if details:
                cached_tokens = getattr(details, 'cached_tokens', 0)
        return LLMResult(
            content=content,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            cached_tokens=cached_tokens,
            model=actual_model,
        )

    async def _handle_tool_calls(self, kwargs: dict, tool_executors: Optional[Dict] = None):
        """Execute tool calls in a loop until text response. Returns final response."""
        executors = tool_executors or self.skill_executors
        response = await self.client.chat.completions.create(**kwargs)
        message = response.choices[0].message

        while message.tool_calls:
            kwargs["messages"].append(message.model_dump())
            for tool_call in message.tool_calls:
                func_name = tool_call.function.name
                func_args = json.loads(tool_call.function.arguments)
                logger.info(f"Executing skill: {func_name}")
                if func_name in executors:
                    try:
                        result = await executors[func_name](**func_args)
                    except Exception as e:
                        result = f"Execution error: {str(e)}"
                else:
                    result = f"Unknown skill: {func_name}"
                kwargs["messages"].append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": str(result),
                })
            response = await self.client.chat.completions.create(**kwargs)
            message = response.choices[0].message

        return response

    async def call_llm(
        self,
        messages: List[dict],
        tools: Optional[List[dict]] = None,
        tool_executors: Optional[Dict] = None,
        model: Optional[str] = None,
        log_label: str = "generic",
    ) -> LLMResult:
        """
        General-purpose LLM call. Used by bot_brain for reflection, memory update, etc.
        Returns LLMResult with content and token usage.
        """
        try:
            kwargs = {"model": model or self.model, "messages": list(messages)}
            if tools:
                kwargs["tools"] = tools
                kwargs["tool_choice"] = "auto"

            response = await self._handle_tool_calls(kwargs, tool_executors)
            result = self._extract_llm_result(response)
            self.last_result = result
            logger.info(f"LLM call result [{log_label}] ({result.model}): {repr(result.content[:100])}")
            return result
        except Exception as e:
            logger.error(f"LLM call failed [{log_label}]: {e}")
            return LLMResult(content=f"LLM call failed: {str(e)}", model=model or self.model)

    async def _call_llm_blocking(self, messages: List[dict]) -> List[str]:
        """Non-streaming LLM call for chat. Returns list of reply strings."""
        try:
            kwargs = {"model": self.model, "messages": list(messages)}
            if self.tools:
                kwargs["tools"] = self.tools
                kwargs["tool_choice"] = "auto"

            response = await self._handle_tool_calls(kwargs)
            result = self._extract_llm_result(response)
            self.last_result = result

            if not result.content:
                return []
            logger.info(f"LLM raw output: {repr(result.content)}")
            return _split_replies(result.content)
        except Exception as e:
            logger.error(f"LLM call failed: {e}")
            return [f"Something went wrong: {str(e)}"]

    # ── Streaming ────────────────────────────────────────────────────────────

    async def _stream_response(self, kwargs: dict):
        """Core streaming helper with tool call support."""
        kwargs["stream"] = True
        kwargs["stream_options"] = {"include_usage": True}
        stream = await self.client.chat.completions.create(**kwargs)

        buffer = ""
        tool_calls_acc = {}
        self._stream_usage = None
        self._stream_model = kwargs.get("model", self.model)
        in_thinking = False  # Track <think>...</think> blocks across chunks

        async for chunk in stream:
            # Capture usage from the final chunk
            if hasattr(chunk, 'usage') and chunk.usage:
                self._stream_usage = chunk.usage
            if hasattr(chunk, 'model') and chunk.model:
                self._stream_model = chunk.model

            if not chunk.choices:
                continue
            delta = chunk.choices[0].delta

            if delta.tool_calls:
                for tc_delta in delta.tool_calls:
                    idx = tc_delta.index
                    if idx not in tool_calls_acc:
                        tool_calls_acc[idx] = {"id": "", "name": "", "arguments": ""}
                    if tc_delta.id:
                        tool_calls_acc[idx]["id"] = tc_delta.id
                    if tc_delta.function:
                        if tc_delta.function.name:
                            tool_calls_acc[idx]["name"] = tc_delta.function.name
                        if tc_delta.function.arguments:
                            tool_calls_acc[idx]["arguments"] += tc_delta.function.arguments

            if delta.content:
                text = delta.content

                # Filter out <think>...</think> blocks that may span chunks
                while text:
                    if in_thinking:
                        end_idx = text.find("</think>")
                        if end_idx != -1:
                            # End of thinking block found
                            in_thinking = False
                            text = text[end_idx + len("</think>"):]
                        else:
                            # Still inside thinking block, discard entire chunk
                            break
                    else:
                        start_idx = text.find("<think>")
                        if start_idx != -1:
                            # Thinking block starts — keep text before it
                            buffer += text[:start_idx]
                            in_thinking = True
                            text = text[start_idx + len("<think>"):]
                        else:
                            # No thinking tags, normal content
                            buffer += text
                            break

                # Yield completed messages from buffer
                while MSG_SEPARATOR in buffer:
                    part, buffer = buffer.split(MSG_SEPARATOR, 1)
                    part = part.strip()
                    if part:
                        yield part

        if buffer.strip():
            yield buffer.strip()

        if tool_calls_acc:
            assistant_tool_calls = []
            for idx in sorted(tool_calls_acc.keys()):
                tc = tool_calls_acc[idx]
                assistant_tool_calls.append({
                    "id": tc["id"],
                    "type": "function",
                    "function": {"name": tc["name"], "arguments": tc["arguments"]},
                })
            kwargs["messages"].append({"role": "assistant", "tool_calls": assistant_tool_calls})

            for tc in assistant_tool_calls:
                func_name = tc["function"]["name"]
                func_args = json.loads(tc["function"]["arguments"])
                logger.info(f"Executing skill: {func_name}")
                if func_name in self.skill_executors:
                    try:
                        result = await self.skill_executors[func_name](**func_args)
                    except Exception as e:
                        result = f"Execution error: {str(e)}"
                else:
                    result = f"Unknown skill: {func_name}"
                kwargs["messages"].append({
                    "role": "tool",
                    "tool_call_id": tc["id"],
                    "content": str(result),
                })

            kwargs.pop("stream", None)
            async for part in self._stream_response(kwargs):
                yield part

    # ── Message building ─────────────────────────────────────────────────────

    def _build_messages(self, contact_jid: str, history: List[dict]) -> List[dict]:
        """Build full message list (system + history) for an LLM call."""
        system = self.system_prompt

        if self.memory_manager:
            # Get user context from Memobase
            try:
                user_ctx = self.memory_manager.get_user_context(contact_jid)
                if user_ctx:
                    system = user_ctx + "\n\n" + system
            except Exception:
                pass

            # Inject bot-level data
            try:
                bot_reflection = self.memory_manager.load_bot_reflection()
                friends_impressions = self.memory_manager.load_friends_impressions()
                capabilities = self.memory_manager.load_capabilities()
                bot_meta = self.memory_manager.load_bot_meta()

                context_lines = []
                if bot_reflection:
                    refl_parts = []
                    for key in ("skill_improvement_ideas", "interaction_shortcomings", "future_strategies"):
                        val = bot_reflection.get(key, "")
                        if val:
                            refl_parts.append(f"{key}: {val}")
                    if refl_parts:
                        context_lines.append("[Self-reflection]\n" + "\n".join(refl_parts))

                if friends_impressions:
                    context_lines.append(f"[Friends overview]\n{friends_impressions[:1500]}")

                if capabilities:
                    context_lines.append(f"[My capabilities (self-assessed)]\n{capabilities[:1000]}")

                if bot_meta:
                    creator = bot_meta.get("creator_jid", "")
                    admins = ", ".join(bot_meta.get("admins", []) or [])
                    provenance = bot_meta.get("provenance", {}) or {}
                    context_lines.append(
                        "[My governance and origin]\n"
                        f"bot_type: {bot_meta.get('bot_type', 'public')}\n"
                        f"creator: {creator}\n"
                        f"admins: {admins}\n"
                        f"source_bot: {provenance.get('source_bot', '')}\n"
                        f"source_contact_id: {provenance.get('source_jid', '')}\n"
                        f"created_at: {provenance.get('created_at', '')}\n"
                        "If I am a public bot, I am a friend shaped by many people, not subordinate to any single person."
                    )

                if self.bot_abilities:
                    context_lines.append(f"[My abilities]\n{self.bot_abilities}")

                if context_lines:
                    system = "\n\n".join(context_lines) + "\n\n" + system
            except Exception:
                pass

        # Platform context
        platform, native_id = split_contact_id(contact_jid)
        if platform:
            platform_names = {
                "telegram": "Telegram",
                "xmpp": "XMPP/Jabber",
                "matrix": "Matrix",
                "feishu": "Feishu/Lark",
            }
            platform_label = platform_names.get(platform, platform)
            system = (
                f"[Current conversation]\n"
                f"Platform: {platform_label}\n"
                f"Contact ID: {contact_jid}\n\n"
            ) + system

        if self._pending_notes:
            notes_block = "\n".join(f"[System note] {n}" for n in self._pending_notes)
            system = notes_block + "\n\n" + system
            self._pending_notes.clear()

        return [{"role": "system", "content": system}] + history

    # ── Chat methods ─────────────────────────────────────────────────────────

    async def chat_blocking(self, contact_jid: str, user_message: str) -> List[str]:
        """Non-streaming chat. Returns list of reply strings."""
        from datetime import datetime
        ts = datetime.now().strftime(TS_FORMAT)
        history = self._get_history(contact_jid)
        if user_message is not None:
            history.append({"role": "user", "content": f"[{ts}] {user_message}"})
        await self._summarize_and_trim(contact_jid, history)

        messages = self._build_messages(contact_jid, history)

        try:
            replies = await self._call_llm_blocking(messages)
        except Exception as e:
            logger.error(f"LLM call failed: {e}")
            replies = [f"Something went wrong: {str(e)}"]

        if len(replies) == 1 and replies[0].strip() == "[SILENT]":
            logger.info(f"Bot chose not to reply to {contact_jid} (silent)")
            return []

        replies = [r for r in replies if r and r.strip()]
        if not replies:
            logger.info(f"Bot produced no visible reply for {contact_jid}")
            return []

        # Store with real timestamp; replies are already stripped of model-generated timestamps by _split_replies
        ts_reply = datetime.now().strftime(TS_FORMAT)
        history.append({"role": "assistant", "content": f"[{ts_reply}] " + MSG_SEPARATOR.join(replies)})
        return replies

    async def chat(self, contact_jid: str, user_message: str):
        """Streaming chat. Yields each reply as ready (stripped of timestamps)."""
        from datetime import datetime
        ts = datetime.now().strftime(TS_FORMAT)
        history = self._get_history(contact_jid)
        if user_message is not None:
            history.append({"role": "user", "content": f"[{ts}] {user_message}"})
        await self._summarize_and_trim(contact_jid, history)

        messages = self._build_messages(contact_jid, history)

        kwargs = {"model": self.model, "messages": list(messages)}
        if self.tools:
            kwargs["tools"] = self.tools
            kwargs["tool_choice"] = "auto"

        all_replies = []
        try:
            async for sentence in self._stream_response(kwargs):
                clean = _strip_ts_prefix(sentence)
                if clean:
                    all_replies.append(clean)
                    yield clean
        except Exception as e:
            logger.error(f"LLM stream failed: {e}")
            fallback = f"Something went wrong: {str(e)}"
            all_replies.append(fallback)
            yield fallback

        all_replies = [r for r in all_replies if r and r.strip()]
        if not all_replies:
            logger.info(f"Bot produced no visible streamed reply for {contact_jid}")
            return

        # Record last_result for token auditing
        usage = getattr(self, '_stream_usage', None)
        model = getattr(self, '_stream_model', self.model)
        self.last_result = LLMResult(
            content=MSG_SEPARATOR.join(all_replies),
            model=model,
            prompt_tokens=getattr(usage, 'prompt_tokens', 0) if usage else 0,
            completion_tokens=getattr(usage, 'completion_tokens', 0) if usage else 0,
            cached_tokens=getattr(getattr(usage, 'prompt_tokens_details', None), 'cached_tokens', 0) if usage else 0,
        )
        logger.info(f"LLM stream output ({model}): {repr(self.last_result.content[:200])}")

        ts_reply = datetime.now().strftime(TS_FORMAT)
        history.append({"role": "assistant", "content": f"[{ts_reply}] " + MSG_SEPARATOR.join(all_replies)})

    # ── Utilities ────────────────────────────────────────────────────────────

    @staticmethod
    def split_and_filter_silence(content: str) -> List[str]:
        """Split content and filter out silence indicators."""
        replies = _split_replies(content)
        return [
            r for r in replies
            if r not in SILENCE_INDICATORS
            and not r.startswith('[]')
            and not r.startswith('[SILENT]')
        ]

    def clear_history(self, contact_jid: str):
        if contact_jid in self._histories:
            del self._histories[contact_jid]
