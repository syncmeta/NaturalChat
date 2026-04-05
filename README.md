# NaturalChat (Archived)

**This project has been discontinued.** The successor is [BeyondBubble](https://github.com/syncmeta/BeyondBubble).

---

## What was this

NaturalChat was an AI chatbot framework with two goals:

- Talk to people naturally, like a friend on WeChat — not a customer service bot
- Break information bubbles: proactively browse the web and surface things the user needs but doesn't know to look for

It supported Matrix, Telegram, Feishu, XMPP, and a web panel. The original version was written in Python.

## Why it stopped

The Python codebase accumulated too much technical debt — it started as XMPP-centric, then the core logic went through multiple rewrites while staying in the same files. `bot_brain.py` grew to 1800+ lines. A TypeScript rewrite was attempted (the `src/` directory in this repo), but it ran into its own problems:

- **Memory system**: The spec called for Honcho (a proper memory service with sessions, vector search, auto-summarization). What got built was `FileMemory` — a JSON file per user. Just `JSON.stringify` to disk. Not a substitute.
- **Skill system**: Partially follows the Anthropic Agent Skills format (SKILL.md with YAML frontmatter), but the execute loop was never wired into the conversation flow. Skills can be discovered and parsed, but the Brain never actually calls them.
- **Token trimming**: Uses character-count heuristics instead of tiktoken. No summarization of dropped messages — old context is simply lost.
- **Brain architecture**: `SimpleBrain` was becoming the same monolith as the old `bot_brain.py` — access control, memory injection, prompt building, history management all crammed into one class.

The rewrite got 8 specs done (154 tests passing) but the architecture wasn't heading in the right direction. Better to start fresh with lessons learned.

## What the TypeScript rewrite achieved

| Spec | What it does |
|------|-------------|
| 001 project-foundation | TS/Bun skeleton, YAML+Zod config, BotManager lifecycle |
| 002 channel-layer | Channel interface, message debouncing, Contact ID, dispatcher |
| 003 llm-agent | OpenAI SDK integration, conversation history, token counting |
| 004 bot-brain | Message pipeline, access control, reply splitting |
| 005 channel-web | WebSocket channel with embedded chat UI |
| 010 memory-system | File-based memory (not Honcho) |
| 011 prompt-system | PromptRegistry with template variables |
| 012 skill-system | SKILL.md parsing, FileSkillLoader (not wired to Brain) |

## Successor

Development continues at [BeyondBubble](https://github.com/syncmeta/BeyondBubble).

## License

MIT
