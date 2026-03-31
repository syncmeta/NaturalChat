# NaturalChat

[中文文档 / Chinese README](README_ZH.md)

It can help you surf the internet and break out of your information bubble.
It can be shaped by you, or even shaped together with your friends.
And the way it talks really does feel natural, like chatting on WhatsApp with close friends.

The current version is still pretty rough. I haven't fully tested or tuned it yet, but it is basically usable. I still need to keep working on the docs, prompts, logic, and a lot of the things current AI systems still don't do well.

Everything below this point was written by AI. Some of it may be inaccurate. I'll check it later.

## What It Does

### Proactive discovery

NaturalChat can browse the web in the background and look for things that may genuinely matter to a contact, instead of waiting for an explicit search prompt every time. If RSS feeds are configured, they become another input source during planning.

### Escaping the filter bubble

The system is meant to search beyond a person's usual information habits. It can combine RSS, search, and lightweight page reading to surface things that are relevant but easy to miss.

### Collective shaping

This bot is not modeled as a private servant for a single operator. Different people who talk to it can gradually shape its long-term style, memory, and behavior.

### Weak-link bridging

Because the bot may know multiple people, it can help pass useful information across contacts instead of keeping every conversation isolated.

### Context-aware conversation

It knows which platform it is on, who it is talking to, and whether the user may still be typing. On platforms with typing events, it waits for typing to stop; on platforms without them, it can use a smaller model to judge whether more input is likely coming.

### Natural tone

The project is tuned for short, conversational replies rather than formal assistant language. It supports tools, web search, code execution, and long-term memory without forcing all of that into a stiff assistant tone.

## Quick Start

### 1. Clone the repo

```bash
git clone <repo-url> && cd naturalchat
```

### 2. Run the installer

```bash
bash install.sh
```

The installer walks through:
- transport setup (Telegram / Matrix / Feishu / XMPP)
- LLM configuration
- access mode
- dependency installation

### 3. Start the bots

```bash
python3 main.py
```

Or with Docker:

```bash
docker compose up
```

## Supported Platforms

### Telegram

1. Create a bot with **@BotFather**
2. Copy the bot token
3. Run `bash install.sh`
4. Put secrets into `bots/<bot>/secrets.yaml`
5. Start the project
6. Send `/start` to the bot

The first account to send `/start` becomes the creator.

### Matrix

You can either:
- deploy Conduit locally with Docker
- connect to an existing homeserver

### Feishu

Create a self-built app in the Feishu developer console, then configure the event callback endpoint and credentials.

### XMPP

XMPP is still supported as a transport, but the current public packaging and distribution flow is centered on import/export packages rather than the older co-deployed Prosody clone flow.

## Access Control

The bot supports three access modes:

| Mode | Command | Behavior |
|------|---------|----------|
| Open | `/access open` | anyone can chat |
| Approval | `/access approval` | new contacts require approval |
| Private | `/access private` | only creator/admins can chat |

Only the creator can change the access mode.

## Repository Layout

```text
bots/<name>/
  config.yaml
  secrets.yaml
  prompts/
  skills/
  bot_data/
```

Important top-level directories:
- `common_skills/`: shared built-in skills
- `prompts/default/`: default prompt bundle
- `docs/`: additional project docs
- `local/`: local private files, not meant for git

## Commands

Available in chat:

| Command | Description |
|---------|-------------|
| `/access [open|approval|private]` | show or change access mode |
| `/pack [grant_id]` | request or download an exported bot package |
| `/surf` | trigger a surfing round manually |
| `/reset` | reset conversation state for the current contact |
| `/approve <id>` | approve a pending request |
| `/deny <id>` | deny a pending request |

Local CLI management:

```bash
python3 manage.py add <name>
python3 manage.py list
python3 manage.py export <name>
python3 manage.py import <pkg> <name>
python3 manage.py remove <name>
```

`manage.py` manages bot directories in the local workspace. It does not manage your remote messaging accounts for you.

## Import / Export

Export a bot:

```bash
python3 manage.py export mybot
```

Import it elsewhere:

```bash
python3 manage.py import mybot_export_*.tar.gz newbot --api-key sk-xxx --telegram-token xxx
```

On Telegram, the bot can also send package exports through `/pack`, with approval and one-time grant support for non-admin users.

## Skill Development

Create a skill under `common_skills/` or `bots/<name>/skills/`:

```text
my_skill/
  SKILL.md
  scripts/
    my_skill.py
```

Skills hot-reload automatically. The watcher now covers `SKILL.md`, `scripts/*.py`, and related files under the skill directory.

## Sandboxing

Code execution skills choose the best available sandbox in this priority order:

| Priority | Sandbox | Platform | Isolation |
|----------|---------|----------|-----------|
| 1 | Docker | all | strongest |
| 2 | bubblewrap | Linux | namespace isolation |
| 3 | sandbox-exec | macOS | profile-based sandbox |
| 4 | WSL2 | Windows | WSL execution |
| 5 | none | all | timeout only |

You can force a mode with `NATURALCHAT_SANDBOX=docker`.

## Docker

```bash
docker compose up -d
docker compose --profile matrix up -d
docker compose --profile memobase up -d
docker compose --profile matrix --profile memobase up -d
```

## Architecture

```text
Users
  -> transports (Telegram / Matrix / Feishu / XMPP)
  -> BotInstance
  -> BotBrain
  -> LLMAgent
  -> MemoryManager
```

`BotBrain` owns orchestration such as reflection, critic review, surfing, governance, and package updates. `LLMAgent` owns prompt assembly, history management, tool calls, and model interaction.
```

---

## License

MIT
