# Tasks: Bot Brain

**Input**: Design documents from `/specs/004-bot-brain/`

## Phase 1: Setup

- [X] T001 Create src/brain/ and tests/brain/ directories

---

## Phase 2: Foundational - Utilities

- [X] T002 [P] Implement reply splitter (split by double newline, max 500 chars) in src/brain/reply-splitter.ts
- [X] T003 [P] Write tests for reply splitter in tests/brain/reply-splitter.test.ts
- [X] T004 [P] Implement access control (open/approval/private modes) in src/brain/access-control.ts
- [X] T005 [P] Write tests for access control in tests/brain/access-control.test.ts
- [X] T006 Implement prompt builder (load system.md, inject bot info) in src/brain/prompt-builder.ts
- [X] T007 Write tests for prompt builder in tests/brain/prompt-builder.test.ts

**Checkpoint**: 工具模块测试通过

---

## Phase 3: User Story 1 + 3 - SimpleBrain (Priority: P1)

**Goal**: Brain 接口实现，完整消息处理管线

- [X] T008 [US1] Implement SimpleBrain class in src/brain/simple-brain.ts
- [X] T009 [US1] Write tests for SimpleBrain with mock LLMAgent in tests/brain/simple-brain.test.ts
- [X] T010 [US1] Create test fixture prompts/system.md in tests/fixtures/bots/test-bot/prompts/system.md

**Checkpoint**: 完整管线测试通过

---

## Phase 4: Polish

- [X] T011 [P] Verify build: `bun run build` zero errors
- [X] T012 [P] Run full test suite: `bun test` all passing

---

## Dependencies

- Phase 2: 并行实现各工具模块
- Phase 3: 依赖 Phase 2 的所有模块 + 003 的 LLMAgent
- Phase 4: 依赖所有
