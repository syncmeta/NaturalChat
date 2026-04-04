# Tasks: Prompt System

**Input**: Design documents from `/specs/011-prompt-system/`

## Phase 1: Setup

- [X] T001 Create src/prompt/ directory

---

## Phase 2: User Story 1 - PromptRegistry (Priority: P1)

**Goal**: 实现 Prompt 加载和注册

- [X] T002 [US1] Implement PromptRegistry class in src/prompt/prompt-registry.ts
- [X] T003 [US1] Write tests for PromptRegistry in tests/prompt/prompt-registry.test.ts

**Checkpoint**: PromptRegistry 测试通过

---

## Phase 3: User Story 2 - Brain 集成 (Priority: P2)

**Goal**: SimpleBrain 使用 PromptRegistry

- [X] T004 [US2] Update SimpleBrain to use PromptRegistry in src/brain/simple-brain.ts
- [X] T005 [US2] Update tests for SimpleBrain prompt integration in tests/brain/simple-brain.test.ts

**Checkpoint**: Brain 使用 PromptRegistry 加载 prompt

---

## Phase 4: Integration

- [X] T006 Verify build and all tests pass

---

## Dependencies

- Phase 2 standalone
- Phase 3 depends on Phase 2 + SimpleBrain from 004
- Phase 4 depends on all
