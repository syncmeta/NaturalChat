# NaturalChat

[中文](README.md)

It's for:

- Naturally, proactively chat — like chatting on WhatsApp. It keeps you in mind.
- Break the filter bubble. Surf the internet on its own, from the user's perspective, finding what they actually need. 

It has agency. It doesn't just wait for you to ask.

It can be raised by one person, or together with friends.

I have no interest in building another assistant or tool — plenty of those exist. Not trying to build standard AI companionship either — it's not about loneliness or boredom.

I want it to help people live better: solid advice, pointing out blind spots, surfacing valuable information, better plans for life. That's extremely hard — even humans struggle with it. But finding a friend like that might be even harder than building an AI like that. So I'm giving it a shot.

The current version is rough. I haven't fully tested or tuned it, but it's basically usable. Docs, prompts, logic — lots still to fix.

Below is written by Claude.

## What It Does

**Proactive discovery** — Based on what it knows about you, it searches the web in the background for things you might care about but haven't noticed. If RSS feeds are configured, those are included too. It only speaks up when it thinks something is worth it.

**Breaking the filter bubble** — Deliberately looks for quality content outside your usual interests. RSS, web search, deep reading — whatever it takes to get you out of your echo chamber.

**Collective shaping** — It doesn't belong to any one person. Everyone who talks to it shapes it. It remembers each person's interests and style, gradually becoming something unique.

**Weak-link bridging** — It knows many of your friends at once. If A asks something B might know, it can go ask B and bring the answer back. Not replacing human connection — building bridges between people.

**Natural tone** — Not a customer service bot. No "Sure, let me help you with that." Talks like a friend — brief, direct, has its own opinions. Searches when it needs to, writes code when it needs to calculate, doesn't pretend to know everything.

**Input awareness** — On platforms with typing indicators (Matrix, XMPP), it waits for you to finish before replying. On platforms without them, it uses a small model to judge whether you're done.

**Group chat** — Add it to a group and it becomes a member. It decides when to speak based on the conversation — doesn't reply to everything.

## Quick Start

Requires Docker.

```bash
git clone https://github.com/syncmeta/NaturalChat.git && cd NaturalChat
bash install.sh
```

The installer walks you through platform selection, LLM API configuration, access mode, and deploys all services automatically.

After installation, manage with `nctl.sh`:

```bash
./nctl.sh start     # Start
./nctl.sh stop      # Stop
./nctl.sh restart   # Restart
./nctl.sh status    # Status
```

Uninstall:

```bash
bash uninstall.sh
```

## Platforms

| Platform | Notes |
|----------|-------|
| **Matrix** | The installer auto-deploys a Conduit server via Docker. Works out of the box. Can also connect to an existing server. |
| **Telegram** | Create a bot via @BotFather, paste the token in the installer. First person to send `/start` becomes the creator. |
| **Feishu** | Create a self-built app in the Feishu developer console, configure event subscription callback. |
| **XMPP** | Needs an XMPP account (Prosody, ejabberd, or a public server). |
| **Web Panel** | Auto-generated. URL and credentials shown after installation. |

## Access Control

| Mode | Command | Behavior |
|------|---------|----------|
| Open | `/access open` | Anyone can chat |
| Approval | `/access approval` | New contacts need admin approval |
| Private | `/access private` | Creator and admins only |

Only the creator can switch modes. Admin management is done via natural language, e.g. "make xxx an admin".

## Commands

In chat:

| Command | Description |
|---------|-------------|
| `/access [mode]` | View or change access mode |
| `/pack [grant_id]` | Export bot package |
| `/surf` | Trigger a surfing round |
| `/reset` | Reset conversation history |
| `/approve <id>` | Approve a request |
| `/deny <id>` | Deny a request |

Local management:

```bash
python manage.py add <name>
python manage.py list
python manage.py export <name>
python manage.py import <pkg> <name>
python manage.py remove <name>
```

## Skills

Create under `common_skills/` or `bots/<name>/skills/`:

```
my_skill/
  SKILL.md           # Skill description
  scripts/
    my_skill.py      # async def execute(**kwargs) -> str
```

File changes hot-reload automatically. See `common_skills/web_search/` for a complete example.

## Repository Layout

```
bots/<name>/
  config.yaml      # Configuration
  secrets.yaml     # Secrets
  prompts/         # Prompts
  skills/          # Custom skills
  bot_data/        # Runtime data

common_skills/     # Shared built-in skills
prompts/default/   # Default prompt templates
docker/            # Dockerfile, docker-compose, Conduit config
scripts/           # install.sh, nctl.sh, uninstall.sh
```

## Architecture

```
User → Transport (Matrix / Telegram / Feishu / XMPP / Web)
         ↓
       BotInstance (multi-platform dispatch)
         ↓
       BotBrain (orchestration: reflection, critic, surfing, RSS, governance)
         ↓
       LLMAgent (LLM calls + skill execution)
         ↓
       MemoryManager (Memobase long-term memory + local files)
```

The transport layer handles debounce, typing awareness, and command routing. Code execution skills auto-select the best available sandbox (Docker → bubblewrap → sandbox-exec → WSL2 → none).

## License

MIT
