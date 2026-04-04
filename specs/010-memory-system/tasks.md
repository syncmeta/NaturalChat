# Tasks: Memory System

**Input**: Design documents from `/specs/010-memory-system/`

## Phase 1: Setup

- [X] T001 Create src/memory/ directory

---

## Phase 2: User Story 1 - FileMemory (Priority: P1)

**Goal**: 实现 Memory 接口的本地文件存储版本

- [X] T002 [US1] Implement FileMemory class in src/memory/file-memory.ts
- [X] T003 [US1] Write tests for FileMemory in tests/memory/file-memory.test.ts

**Checkpoint**: FileMemory 测试通过

---

## Phase 3: User Story 2 - Brain 集成 (Priority: P2)

**Goal**: SimpleBrain 集成 Memory

- [X] T004 [US2] Update SimpleBrain to accept and use optional Memory in src/brain/simple-brain.ts
- [X] T005 [US2] Write/update tests for SimpleBrain memory integration in tests/brain/simple-brain.test.ts

**Checkpoint**: Brain 能读写记忆

---

## Phase 4: Integration

- [X] T006 Update BotManager to create FileMemory and inject into BotInstance in src/core/bot-manager.ts
- [X] T007 Verify build and all tests pass

---

## Dependencies

- Phase 2 depends on Memory interface from 001
- Phase 3 depends on Phase 2 + SimpleBrain from 004
- Phase 4 depends on all
