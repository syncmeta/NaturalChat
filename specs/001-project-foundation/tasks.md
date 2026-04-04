# Tasks: 项目基础架构

**Input**: Design documents from `/specs/001-project-foundation/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)

## Phase 1: Setup

**Purpose**: 项目初始化，搭建可编译的空项目

- [ ] T001 Initialize Bun project: create package.json with name "naturalchat", add dependencies (zod, yaml, pino) and devDependencies (typescript, vitest, eslint, prettier) in package.json
- [ ] T002 Create tsconfig.json with strict: true, ES2022 target, moduleResolution bundler, paths alias "@/" → "src/"
- [ ] T003 [P] Create .eslintrc.cjs and .prettierrc with project code style rules
- [ ] T004 [P] Create .gitignore: add node_modules/, config.yaml, bots/*/, !bots/_template/, *.log, .env
- [ ] T005 Create src/ directory structure per plan.md: src/config/, src/core/, src/core/interfaces/, src/utils/
- [ ] T006 Create tests/ directory structure: tests/config/, tests/core/, tests/fixtures/

**Checkpoint**: `bun install` succeeds, empty project compiles with `bun run build`

---

## Phase 2: Foundational

**Purpose**: 核心基础设施——日志、错误类型、通用工具。所有 User Story 都依赖这些。

- [ ] T007 Implement logger with pino and sensitive field redaction (api_key, token, password) in src/utils/logger.ts
- [ ] T008 [P] Define custom error types (ConfigError, BotLoadError) in src/utils/errors.ts
- [ ] T009 [P] Create config.example.yaml with full annotated example (api_base_url, api_key, models with all 6 task defaults)

**Checkpoint**: 日志和错误处理就绪，后续任务可以使用

---

## Phase 3: User Story 1 - 项目骨架与模块接口 (Priority: P1) 🎯 MVP

**Goal**: 定义所有核心模块的接口，后续功能知道代码放哪、实现什么接口

**Independent Test**: 项目编译通过，所有接口定义存在且互相引用无错误

### Implementation for User Story 1

- [ ] T010 [P] [US1] Define Channel interface (start, stop, sendMessage, sendFile, sendTyping, onMessage) in src/core/interfaces/channel.ts
- [ ] T011 [P] [US1] Define Brain interface (handleMessage, start, stop) in src/core/interfaces/brain.ts
- [ ] T012 [P] [US1] Define LLMAgent interface (chat with messages and optional tools) in src/core/interfaces/llm-agent.ts
- [ ] T013 [P] [US1] Define Memory interface (getContext, updateContext) in src/core/interfaces/memory.ts
- [ ] T014 [P] [US1] Define SkillLoader interface (discover, loadSkill, getToolDefinitions, execute) per Anthropic Skills spec in src/core/interfaces/skill-loader.ts
- [ ] T015 [US1] Create barrel export for all interfaces in src/core/interfaces/index.ts
- [ ] T016 [US1] Define shared types (IncomingMessage, FilePayload, ChatResult, UserContext, Skill, SkillMeta, Tool) in src/core/types.ts

**Checkpoint**: `bun run build` 通过，所有接口可被引用

---

## Phase 4: User Story 2 - 配置系统 (Priority: P1)

**Goal**: 全局配置 + Bot 配置 + Zod 校验，配置错误给出清晰提示

**Independent Test**: 故意写错配置字段，启动时报错信息指出具体字段和问题

### Implementation for User Story 2

- [ ] T017 [US2] Define Zod schemas (GlobalConfigSchema, ModelConfigSchema, BotConfigSchema, BotSecretsSchema, ChannelEntrySchema) in src/config/schema.ts
- [ ] T018 [US2] Export TypeScript types derived from schemas (GlobalConfig, ModelConfig, BotConfig, BotSecrets, ChannelEntry, ResolvedBotConfig) in src/config/types.ts
- [ ] T019 [US2] Implement config loader: readYaml, parseGlobalConfig, parseBotConfig, parseBotSecrets, mergeModelConfig (Bot overrides global defaults) in src/config/loader.ts
- [ ] T020 [US2] Implement Zod error formatter: convert ZodError to human-readable Chinese messages with field path, expected type, actual value in src/config/error-formatter.ts
- [ ] T021 [US2] Write tests for Zod schemas: valid config passes, missing required field fails with clear message, wrong type fails, partial model override merges correctly in tests/config/schema.test.ts
- [ ] T022 [US2] Write tests for config loader: load valid YAML, load invalid YAML, merge bot models with global defaults, missing secrets file returns empty in tests/config/loader.test.ts
- [ ] T023 [US2] Create test fixtures: tests/fixtures/valid-config.yaml, tests/fixtures/invalid-config.yaml, tests/fixtures/bots/test-bot/config.yaml, tests/fixtures/bots/test-bot/secrets.yaml, tests/fixtures/bots/broken-bot/config.yaml

**Checkpoint**: `bun test tests/config/` 全部通过

---

## Phase 5: User Story 3 - BotManager 生命周期 (Priority: P1)

**Goal**: BotManager 扫描 bots/，加载配置创建实例，优雅关闭

**Independent Test**: 两个 Bot（一正确一错误），正确的启动、错误的报错不影响前者，SIGTERM 优雅关闭

### Implementation for User Story 3

- [ ] T024 [US3] Implement BotInstance class: constructor takes ResolvedBotConfig, holds optional module slots (channels, brain, memory, skillLoader), start() and stop() methods (empty impl for now) in src/core/bot-instance.ts
- [ ] T025 [US3] Implement BotManager: discover(botsDir) scans for subdirectories, loadAll(globalConfig) loads and validates each bot config, startAll() creates and starts BotInstances, stopAll() stops all in src/core/bot-manager.ts
- [ ] T026 [US3] Implement main entry point: load global config, create BotManager, discover and start all bots, register SIGTERM/SIGINT handlers with 10s timeout in src/index.ts
- [ ] T027 [US3] Write tests for BotManager: discovers bots in directory, skips non-directories and _template, loads valid bot, skips invalid bot without affecting others, stopAll calls stop on each instance in tests/core/bot-manager.test.ts
- [ ] T028 [US3] Write tests for BotInstance: creates with resolved config, start/stop lifecycle in tests/core/bot-instance.test.ts

**Checkpoint**: `bun start` 启动系统，发现并加载 Bot，SIGTERM 优雅关闭

---

## Phase 6: User Story 4 - 开发体验 (Priority: P1)

**Goal**: 改代码/Prompt 后自动重启，依赖服务 Docker 启动

**Independent Test**: 开发模式下修改源文件，进程 3 秒内自动重启

### Implementation for User Story 4

- [ ] T029 [US4] Add package.json scripts: "dev" (bun --watch src/index.ts), "start" (bun src/index.ts), "build" (tsc --noEmit), "test" (vitest)
- [ ] T030 [US4] Create docker-compose.dev.yaml: Honcho service only (for dev, bot process runs locally)
- [ ] T031 [US4] Create bots/_template/ directory with example config.yaml, secrets.yaml, prompts/.gitkeep, skills/.gitkeep, data/.gitkeep

**Checkpoint**: `bun run dev` 启动并监控文件变更，修改文件后自动重启

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 整理和验证

- [ ] T032 [P] Verify all interfaces compile correctly: run `bun run build` with zero errors
- [ ] T033 [P] Run full test suite: `bun test` with all tests passing
- [ ] T034 Verify end-to-end: create a test bot in bots/, run `bun start`, check logs show bot discovered and loaded, send SIGTERM, verify clean exit

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies
- **Phase 2 (Foundational)**: Depends on Phase 1
- **Phase 3 (US1 骨架)**: Depends on Phase 2
- **Phase 4 (US2 配置)**: Depends on Phase 2 + Phase 3 (needs types from interfaces)
- **Phase 5 (US3 生命周期)**: Depends on Phase 4 (needs config loader)
- **Phase 6 (US4 开发体验)**: Depends on Phase 5 (needs working start command)
- **Phase 7 (Polish)**: Depends on all above

### Within Each Phase

- Tasks marked [P] can run in parallel
- Unmarked tasks run sequentially in listed order

### Parallel Opportunities

Phase 1:
```
T003 (.eslintrc.cjs) || T004 (.gitignore)  — different files
```

Phase 2:
```
T008 (errors.ts) || T009 (config.example.yaml)  — different files
```

Phase 3 (US1):
```
T010 (channel.ts) || T011 (brain.ts) || T012 (llm-agent.ts) || T013 (memory.ts) || T014 (skill-loader.ts)  — all independent interfaces
```

---

## Implementation Strategy

### MVP First (US1 + US2 + US3)

1. Phase 1 + 2: Setup + Foundational
2. Phase 3: 接口定义 → 编译通过
3. Phase 4: 配置系统 → 测试通过
4. Phase 5: BotManager → `bun start` 能跑
5. **STOP and VALIDATE**: 系统能发现 Bot、加载配置、优雅关闭

### Then Add Dev Experience

6. Phase 6: 开发体验 → `bun run dev` 文件监控
7. Phase 7: 整体验证

---

## Notes

- 本阶段各模块接口只是定义，具体实现由后续 Spec 完成
- BotInstance 的 start()/stop() 是空实现，后续 Spec 注入真正的 Channel/Brain/Memory
- 测试在配置和 BotManager 阶段写，接口定义阶段不需要测试（纯类型定义）
