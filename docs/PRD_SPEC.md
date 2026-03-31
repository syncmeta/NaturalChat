# NaturalChat PRD + Product Spec Draft

Status: Draft  
Last updated: 2026-03-29  
Audience: product, engineering, maintainer  
Purpose: provide a single editable source of truth for what NaturalChat is, what it should do, how the current system works, and which areas still need product decisions.

This document is intentionally opinionated but incomplete-by-design. It tries to reflect the current codebase truth first, then marks unclear or unstable areas as explicit open questions instead of pretending the system is more settled than it is.

---

## 1. Product Summary

NaturalChat is a multi-bot, multi-transport conversational system designed to feel less like a formal assistant and more like a natural long-lived contact. It combines:

- chat across multiple messaging platforms
- shared but bot-scoped long-term memory
- skill/tool execution
- proactive information discovery ("surfing")
- access control and governance
- import/export packaging for bot cloning and distribution
- a local web panel for chat and administration

The product thesis is not "answer prompts better." The thesis is:

- a bot should develop relationship-aware behavior over time
- a bot should proactively find potentially useful information, not only react
- a bot can be socially shaped by multiple people, not just one owner
- a bot should preserve natural conversational tone while still being tool-capable

---

## 2. Product Vision

### 2.1 Vision

Create a conversational agent that behaves like a real ongoing contact:

- aware of who it is talking to
- shaped by repeated interaction
- capable of helping, searching, remembering, and occasionally taking initiative
- usable across messaging platforms and local interfaces

### 2.2 Product Positioning

NaturalChat is not primarily:

- an enterprise workflow chatbot
- a generic prompt playground
- a single-user personal assistant dashboard
- a no-code builder platform

It is closer to:

- a persistent social bot runtime
- a multi-channel conversational agent framework
- a packageable "bot identity" that can be cloned, shared, and evolved

### 2.3 Core Promise

Users should feel:

- "this bot remembers me"
- "this bot talks naturally"
- "this bot can actually do things"
- "this bot sometimes surfaces useful things I would not have found"

---

## 3. Goals and Non-Goals

### 3.1 Primary Goals

1. Support natural-feeling multi-turn chat across multiple transports.
2. Preserve per-contact context and long-term memory.
3. Enable proactive web discovery through surfing and RSS inputs.
4. Support creator/admin governance without requiring a heavyweight backend.
5. Allow bots to be exported/imported as portable packages.
6. Provide a local-first developer/operator workflow.
7. Allow local web testing even when no external transport is configured.

### 3.2 Secondary Goals

1. Hot-reload prompts and skills to tighten the authoring loop.
2. Support tool execution with sandboxing.
3. Keep deployment approachable with interactive installers.
4. Keep configuration human-readable and file-based.

### 3.3 Non-Goals

1. Perfect production-grade reliability across all transports.
2. Full SaaS-style multi-tenant account management.
3. Rich analytics, billing, or user administration portals.
4. Strongly opinionated hosted infrastructure.
5. Guaranteed autonomous behavior quality in surfing/reflection.

---

## 4. Users and Personas

### 4.1 Creator / Operator

The person who installs, configures, deploys, and governs the bot.

Needs:

- easy setup
- predictable config files
- control over access mode and admins
- safe testing before exposing a bot publicly
- package export/import

### 4.2 End Contact

A person chatting with the bot on Telegram, Matrix, Feishu, XMPP, or web panel.

Needs:

- natural, concise replies
- continuity across time
- useful proactive suggestions
- low-friction access

### 4.3 Collaborator / Co-shaper

A friend, admin, or repeated contact who influences bot behavior over time.

Needs:

- a bot that meaningfully remembers tone, preferences, and context
- social shaping without becoming an admin/operator necessarily

### 4.4 Developer

A person extending prompts, skills, transport integrations, or packaging/deployment flows.

Needs:

- understandable architecture
- file-based customization
- local reproducibility
- minimal hidden state

---

## 5. Key Use Cases

### 5.1 Conversational Use Cases

- user chats with the bot through a messaging transport
- bot waits until typing appears finished before responding
- bot remembers prior preferences and history
- bot responds in a natural, low-friction tone

### 5.2 Proactive Discovery Use Cases

- bot periodically evaluates what may matter to known contacts
- bot searches the web and optionally reads pages
- bot uses RSS feeds as another source of information
- bot may proactively share findings if deemed worthwhile

### 5.3 Governance Use Cases

- creator claims bot ownership
- creator changes access mode
- creator adds/removes admins through NL or commands
- admin approves/denies package or contact requests

### 5.4 Portability Use Cases

- creator exports a bot as a package
- another machine imports the package
- package preserves prompts, personality-ish state, skills, and provenance
- secrets are stripped and replaced with placeholders

### 5.5 Local Testing Use Cases

- operator installs the project locally
- operator tests chat through the web panel without external transports
- operator edits config and restarts from the web panel

---

## 6. Product Scope

### 6.1 In Scope

- multi-bot workspace
- platform transports
- web panel
- prompt bundle system
- skill system
- LLM integration through OpenAI-compatible APIs
- memory via local files and optional Memobase
- surfing / RSS / Firecrawl integrations
- packaging and update-in-place flows
- interactive installer(s)

### 6.2 Out of Scope

- hosted auth provider integration
- server-side user database beyond local files / Memobase
- full moderation suite
- mobile-native apps
- unified cloud dashboard

---

## 7. Functional Requirements

### 7.1 Multi-Bot Runtime

The system must:

- scan `bots/` for runnable bots
- ignore template-only or invalid bots without crashing the whole app
- create one `BotInstance` per valid bot
- allow multiple transports per bot
- support bot restart by name

Current implementation:

- `src/bot_manager.py`
- one process hosts all bots

### 7.2 Bot Configuration

Each bot must support:

- `config.yaml` for non-sensitive config
- `secrets.yaml` for sensitive data
- prompt bundle under `prompts/`
- private skills under `skills/`
- runtime data under `bot_data/`

The system must:

- deep-merge `config.yaml` + `secrets.yaml`
- validate minimum config correctness before starting

Current implementation:

- `src/bot_config.py`
- `src/config_validation.py`

### 7.3 Transport Layer

Supported transports currently in code:

- Telegram
- Matrix
- Feishu
- XMPP
- Web panel transport

Shared transport responsibilities:

- receive inbound messages
- normalize contact IDs
- run slash commands
- run governance natural-language parsing
- batch/debounce incoming messages
- pass message content into `BotBrain`

Transport-specific responsibilities:

- platform auth and connection lifecycle
- sending text, typing indicators, and files when supported

Current implementation:

- `src/transport/base.py`
- `src/transport/*.py`

### 7.4 Web Panel

The web panel must support:

- login using local username/password
- list bots
- open a WebSocket chat session
- view current bot config
- save bot config
- restart a bot
- inspect chat history for a web session

Current implementation:

- `src/web_panel/server.py`
- `src/web_panel/static/index.html`

Known limits:

- no audit trail for config edits
- no role separation inside the panel
- no live log viewer in current implementation despite doc/comment aspiration

### 7.5 Conversation Engine

The conversation engine must:

- maintain per-contact histories
- inject system prompt plus formatting rules
- optionally call tools / skills
- support streaming and non-streaming replies
- split multiple messages by `|||` only
- support silence markers
- trim/summarize history when it exceeds budget

Current implementation:

- `src/llm_agent.py`

### 7.6 Naturalness / Tone

The product requires:

- replies in the user's language when inferable
- short, conversational output
- avoidance of customer-service tone
- awareness of relationship and comfort

Current implementation:

- hardcoded reply-format instruction appended inside `LLMAgent`
- per-bot prompt bundle via `main.md` and related prompt files

### 7.7 Memory

Memory has two layers:

1. Local bot data files
2. Optional Memobase-backed user memory

Local memory stores:

- bot self reflection
- friends impressions
- capabilities
- autonomous config
- token budgets
- governance metadata
- RSS routes

Memobase stores:

- per-user memory context
- user-linked inserted chats
- optional flush/delete lifecycle

Current implementation:

- `src/memory_manager.py`

### 7.8 Access Control and Governance

Supported access modes:

- `open`
- `approval`
- `private`

The system must support:

- creator claim
- creator-only access mode changes
- admin list management
- blacklist / approved contacts
- pending request approval / denial

Current implementation:

- `src/bot_brain.py`
- `src/command_router.py`

### 7.9 Commands

Shared command router currently supports:

- `/surf`
- `/start`
- `/reset`
- `/pack`
- `/access`
- `/approve <id>`
- `/deny <id>`

Requirement:

- all transports that accept free text should route commands consistently

Current state:

- Telegram / Matrix / XMPP / Feishu do
- Web was recently corrected to do so too

### 7.10 Surfing

Surfing is a proactive/manual discovery loop that:

- gathers memory context
- optionally fetches RSS context
- plans search queries with an LLM
- executes web search
- optionally opens pages
- iteratively evaluates intermediate findings
- decides whether/how to share results

Requirements:

- `/surf` must trigger one manual round
- autonomous surfing must run only when enabled
- system should avoid spamming contacts
- quiet hours and cooldowns must apply

Current implementation:

- `src/bot_brain.py`
- `common_skills/web_search/`
- optional Firecrawl and RSSHub support

Critical current behavior:

- surfing depends heavily on memory context
- manual surfing may return "not enough context" until the bot has enough conversation or saved notes

### 7.11 Skills / Tools

The system must support:

- built-in shared skills
- bot-specific skills
- hot reload of skill code/metadata
- OpenAI-tool-schema exposure to the main model

Current implementation:

- `src/skill_loader.py`
- `common_skills/`

### 7.12 Package Export / Import

The packaging system must:

- export bot prompts, skills, selected bot_data, config, stripped secrets
- include manifest and checksums
- import into a new bot directory
- apply local override secrets
- update provenance
- support in-place update flow

Current implementation:

- `src/bot_packager.py`
- `manage.py`
- `/pack` flow in chat

### 7.13 Installer

The project currently has two installers:

- `install.sh`
- `install.py`

Primary intended path appears to be `install.sh`.

Requirements:

- fresh-machine setup guidance
- dependency installation
- optional Memobase / Firecrawl / RSSHub / Serper config
- external transport setup
- bot config generation
- web panel credentials
- launch options

Recent important changes:

- launch-at-login/boot decoupled from run-now
- installer language selection added
- local defaults file support added
- web-only bot generation path improved by writing `transports.web.enabled: true`

Known issue area:

- installer behavior and runtime expectations still have rough edges and should be treated as evolving

---

## 8. Non-Functional Requirements

### 8.1 Local-First Operability

- project should be usable without hosted backend dependencies beyond external model APIs
- file-based config should remain human-editable

### 8.2 Safety

- code execution should prefer sandboxed runtime
- missing sandbox should be surfaced clearly

### 8.3 Performance

- normal chat turnaround should feel conversational
- typing/debounce logic should avoid obviously premature replies
- web panel should remain usable with one local process

### 8.4 Portability

- local setup should work on macOS and Linux first
- Windows support appears partial via WSL-aware sandbox logic, but is not a clearly polished primary path

### 8.5 Privacy / Data Handling

- secrets should remain out of exported bot packages
- local private files should stay outside git-tracked paths where possible
- panel auth should exist for local administration

Known weakness:

- current panel auth is a local bearer-token mechanism, not a hardened security system

---

## 9. Current Architecture

### 9.1 Runtime Architecture

```text
User / Admin
  -> Transport (Telegram / Matrix / Feishu / XMPP / Web)
  -> BotInstance
  -> BotBrain
  -> LLMAgent
  -> MemoryManager
  -> Skills / external APIs / optional Memobase
```

### 9.2 Main Responsibilities

- `main.py`
  starts bot manager and web panel

- `src/bot_manager.py`
  discovers bots, loads config, assembles instances

- `src/bot_instance.py`
  binds one brain to many transports

- `src/bot_brain.py`
  orchestration layer for reflection, surfing, governance, memory updates, critic review

- `src/llm_agent.py`
  raw model integration, history, tools, streaming

- `src/memory_manager.py`
  local bot data + Memobase integration

- `src/command_router.py`
  slash commands and governance natural-language handling

- `src/web_panel/server.py`
  admin/chat web UI backend

### 9.3 Configuration Layers

Project-wide:

- `config.yaml`
- `.env`
- `web_panel.yaml`

Per-bot:

- `bots/<name>/config.yaml`
- `bots/<name>/secrets.yaml`
- `bots/<name>/prompts/`
- `bots/<name>/skills/`
- `bots/<name>/bot_data/`

### 9.4 External Dependencies

- OpenAI-compatible model API
- optional Docker
- optional Memobase
- optional RSSHub
- optional Firecrawl
- optional Telegram / Matrix / Feishu / XMPP credentials

---

## 10. Data Model and Important Files

### 10.1 Bot Runtime State

Per-bot runtime files under `bot_data/` include:

- `bot_meta.json`
- `bot_self_reflection.json`
- `friends_impressions.md`
- `autonomous_config.json`
- `token_budgets.json`
- `memobase_uid_map.json`
- `rsshub_routes.json`

### 10.2 Histories

Conversation histories are currently kept in-process inside `LLMAgent._histories`.

Implication:

- in-memory history is not durable across process restarts
- long-term context depends on summaries and optional Memobase, not raw full history persistence

### 10.3 Contact IDs

Canonical IDs are prefixed by transport, e.g.:

- `telegram:<chat_id>`
- `matrix:<room_id>`
- `web:<session_id>`

This is the routing key across transports and governance logic.

---

## 11. User Flows

### 11.1 New Local Operator Flow

1. clone repo
2. run `install.sh`
3. choose optional integrations
4. generate bot config
5. launch app
6. log into web panel or chat through transport

### 11.2 First Contact Flow

1. user messages bot
2. transport normalizes sender/contact ID
3. command routing runs first
4. access checks happen
5. debounce/typing logic waits
6. bot replies
7. memory update may happen
8. reflection/surfing loops may later run

### 11.3 Manual Surf Flow

1. user sends `/surf`
2. command router acknowledges
3. `BotBrain.do_surf_once()` runs
4. memory context and RSS context are loaded
5. search plan is generated
6. results are gathered/evaluated
7. findings are summarized back into normal conversational voice

### 11.4 Package Distribution Flow

1. admin exports package
2. package contains non-secret config, prompts, skills, selected personality data
3. package is imported elsewhere with local credentials injected
4. provenance is updated

---

## 12. Current Product Risks

### 12.1 Installer / Runtime Mismatch Risk

Historically, some installer outputs and runtime validation expectations have not perfectly matched.

Examples:

- web panel described as always available but not always reflected in generated transport config
- evolving Memobase image / deployment assumptions

### 12.2 Roughness / Incomplete Testing

The README itself explicitly states the product is still rough and incompletely tested.

Implication:

- current behavior should not be treated as fully stabilized product truth

### 12.3 Web Panel Security Risk

The local panel auth model is lightweight.

Open question:

- is this intended only for localhost/trusted environments, or should it evolve toward stronger auth controls?

### 12.4 Memory Quality Risk

Memory is split between in-process history, local summary files, and optional Memobase.

Risk:

- user expectations of "memory" may exceed what is actually durable or semantically coherent

### 12.5 Surfing Quality Risk

Surfing is one of the most ambitious features and also one of the least deterministic.

Risks include:

- weak context => low-value searches
- insufficient guardrails => noisy proactive messaging
- reliance on third-party search/scraping quality

### 12.6 Multi-Transport Consistency Risk

The architecture intends shared behavior across transports, but transport implementations can drift.

Example:

- web command routing had diverged from the others

---

## 13. Open Questions / Areas Needing Product Decisions

This section is intentionally explicit. These are the places where the current codebase suggests intent, but the intended product direction is not yet fully nailed down.

### 13.1 Bot Identity Model

- Is a bot meant to be one shared social entity across many contacts?
- Or should operators often create many isolated bots with different personas?
- How much cross-contact influence is desirable versus creepy?

### 13.2 Group Chat Strategy

README_ZH mentions group behavior, but implementation detail and moderation expectations are not clearly documented.

Need clarity on:

- mention detection vs free participation
- speaking thresholds in groups
- spam/interrupt behavior

### 13.3 Surfing Product Boundary

Need product decisions on:

- should surfing remain mostly manual
- or become a flagship proactive behavior
- how aggressive should proactive sharing be
- what explicit user controls should exist in config/UI

### 13.4 Web Panel Scope

Current web panel can:

- chat
- edit config
- restart bots
- inspect history

Need clarity on whether the panel should become:

- only a local testing/admin tool
- or a full primary management UI

### 13.5 Package Philosophy

Need clarity on what a package fundamentally represents:

- a portable personality
- a deployable bot app
- a shareable cultural artifact
- a bot fork lineage system

### 13.6 Memory Philosophy

Need clarity on:

- what should remain local-only
- what must go to Memobase
- what should survive export/import
- what "collective shaping" is allowed to persist

### 13.7 Install Experience

Need clarity on preferred install target:

- local developer machine
- hobby VPS
- end-user consumer machine

That answer changes:

- installer tone
- defaults
- system service setup
- web panel onboarding

### 13.8 Deployment Surface

The codebase still contains some deploy-related assumptions and docs, but product intent is no longer fully clear.

Need clarity on whether deploy scripts are:

- first-class supported path
- internal maintainer tooling
- deprecated

### 13.9 External Dependency Policy

Need clarity on first-party supported defaults for:

- LLM provider
- search provider
- scraping provider
- memory backend

### 13.10 Web-Only Bot Support

Current code now supports web-only testing more cleanly, but product intent should be explicit:

- should web-only be a supported normal mode
- or just a local dev/testing mode

---

## 14. Proposed Product Decisions (Draft Recommendations)

These are recommendations, not facts. They are included to make revision easier.

### 14.1 Position the Web Panel as a First-Class Local Testing Surface

Recommendation:

- yes, web-only bots should be officially supported
- the web panel should be the easiest path for first-run validation

Reason:

- it reduces onboarding friction dramatically
- it decouples product validation from third-party transport setup

### 14.2 Keep External Transports Optional

Recommendation:

- installation should succeed with no external transport selected
- generated config should always include `web.enabled: true`

### 14.3 Keep Memobase Optional but Better Documented

Recommendation:

- local-only memory remains valid baseline mode
- Memobase is the upgrade path for better long-term user context

### 14.4 Treat Surfing as an Advanced Feature with Conservative Defaults

Recommendation:

- default to `surfing.enabled: false`
- make `/surf` the safest entry point for testing
- add explicit explanations when surfing has insufficient context

### 14.5 Treat Package Import/Export as a Signature Product Feature

Recommendation:

- keep package portability central
- document clearly what exports preserve vs strip

---

## 15. Engineering Spec

### 15.1 Bot Lifecycle

1. discover bot directories
2. load merged config
3. validate config
4. load prompt bundle
5. instantiate memory manager
6. instantiate llm agent
7. load skills
8. build transports
9. create `BotBrain`
10. create `BotInstance`
11. start bot tasks and transport tasks

### 15.2 Config Validation Rules

Minimum bot config requires:

- non-empty `transports` mapping
- at least one enabled transport
- valid `llm.base_url`
- valid `llm.model`
- valid `llm.max_history_tokens`

Transport-specific validation currently includes:

- Telegram needs token
- Matrix needs homeserver + user_id + token/password
- Feishu needs app credentials
- XMPP needs jid/password
- Web needs only `enabled: true`

### 15.3 Command Routing Order

Target order for all text-capable transports:

1. slash command handling
2. governance natural-language handling
3. access check for normal chat
4. debounce and buffer
5. brain processing

### 15.4 Web Panel API Surface

Current endpoints:

- `POST /api/login`
- `GET /api/bots`
- `GET /api/bots/{name}/config`
- `PUT /api/bots/{name}/config`
- `POST /api/bots/{name}/restart`
- `GET /api/bots/{name}/history`
- `GET /ws/chat/{bot_name}`

### 15.5 Packaging Rules

Exports include:

- prompts
- skills
- stripped secrets
- selected bot personality data

Exports exclude:

- live raw user histories
- sensitive credentials
- arbitrary runtime cache

### 15.6 Install Defaults Mechanism

Current intended mechanism:

- committed template: `install.defaults.example`
- private local values: `local/install.defaults`
- installer auto-loads local defaults when present

This supports:

- reproducible local testing
- safe template sharing in git

---

## 16. Acceptance Criteria for a "Good" Local Test Experience

This section defines a practical target for future implementation/testing.

A new developer/operator should be able to:

1. clone repo
2. optionally copy `install.defaults.example` to `local/install.defaults`
3. run `bash install.sh`
4. choose no external transports
5. finish installation successfully
6. run the app
7. log into web panel
8. chat with a generated web-enabled bot
9. issue `/reset` and `/surf`
10. understand from errors when something is misconfigured

If this flow fails, the onboarding experience is still not acceptable.

---

## 17. Suggested Near-Term Roadmap

### 17.1 Phase 1: Onboarding and Local Testability

- make web-only flow fully stable
- align installer/runtime expectations
- improve error messages for LLM credential failures
- document Memobase setup clearly

### 17.2 Phase 2: Product Surface Cleanup

- clarify panel scope
- clarify package model
- document governance model more explicitly
- remove stale deploy/deprecation ambiguity

### 17.3 Phase 3: Proactive Behavior Quality

- improve surfing quality and controls
- improve reflection usefulness
- refine memory update quality

### 17.4 Phase 4: Reliability and Distribution

- more deterministic restart/config reload behavior
- better transport consistency tests
- cleaner installation/deployment paths

---

## 18. Editing Notes for Maintainer

When revising this document, treat sections in this priority order:

1. Product Summary, Goals, Use Cases
2. Open Questions / Proposed Decisions
3. Acceptance Criteria
4. Engineering Spec details

If a section disagrees with code, prefer marking it as:

- "current implementation"
- "target behavior"
- "open question"

Do not silently blur those categories together.
