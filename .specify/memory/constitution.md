# NaturalChat Constitution

## Core Principles

### I. Channel-Centric Architecture
The system is organized around Channels (messaging platform adapters). Each Channel implements a common interface. The Bot orchestration layer stays thin — it dispatches messages to/from Channels and delegates all heavy logic to dedicated modules (memory, skills, reflection, etc.). No god-objects.

### II. TypeScript + Node.js
All code is TypeScript (strict mode). Runtime is Node.js (LTS) or Bun. No Python, no mixed-language runtime. Use `async/await` throughout — no callback patterns, no sync blocking calls.

### III. OpenAI-Compatible LLM Interface
LLM calls go through the `openai` npm package against OpenAI-compatible endpoints (OpenRouter, local models, etc.). The system is model-agnostic — never assume a specific model's capabilities. Tool/function calling follows the OpenAI tool format.

### IV. Bot-as-Directory
Each bot instance lives in `bots/<name>/` with its own `config.yaml`, `secrets.yaml`, `prompts/`, `skills/`, and `data/`. A bot directory is self-contained and portable. Global shared resources (common skills, prompt templates) live outside bot directories.

### V. Configuration: YAML + Zod
All configuration is YAML. Every config file has a corresponding Zod schema that validates at startup. Fail fast on invalid config — never silently use defaults for missing required fields.

### VI. Honcho Local-First Memory
User memory uses Honcho, deployed locally via Docker by default. No cloud dependency for core functionality. Local file storage (JSON) for bot-level state (self-reflection, impressions, meta). Memory is a separate module, not interleaved with brain logic.

### VII. Externalized Prompts
All LLM prompts are external Markdown files in `prompts/` directories. Never hardcode prompt strings in source code. Support multiple languages (en, zh at minimum). Prompts are versioned alongside code.

### VIII. Skill Progressive Disclosure
Skills are defined by `SKILL.md` (YAML frontmatter for schema + Markdown description) and a `scripts/` directory for execution logic. Skills are dynamically loaded and hot-reloadable. Common skills live in `common_skills/`, bot-specific skills in `bots/<name>/skills/`.

### IX. Docker-First Deployment
The primary deployment method is Docker Compose. All services (bot, Honcho, RSSHub, etc.) are containerized. Bare-metal deployment is supported but secondary. The install script handles both paths.

## Technical Constraints

- **Package manager**: Use a single package manager consistently (npm or bun). Do not mix.
- **No class inheritance hierarchies**: Prefer composition and interfaces over deep class trees. Channel interface is the only abstract base.
- **Error handling**: Use typed errors. Never swallow errors silently. Log at appropriate levels.
- **No global mutable state**: All state is scoped to bot instances or explicitly shared via dependency injection.
- **File I/O**: Use `node:fs/promises` exclusively. No sync file operations.

## Development Workflow

- Each feature starts with a spec, then plan, then tasks, then implementation.
- Tests use Vitest. Write tests for core logic (LLM agent, memory, skill loader, brain orchestration). Channel adapters are tested via integration tests.
- Lint with ESLint + Prettier. Strict TypeScript — no `any` except at API boundaries with explicit type guards.

## Governance

This constitution supersedes all other development guidance. Any amendment requires explicit documentation and rationale.

**Version**: 1.0.0 | **Ratified**: 2026-04-01
