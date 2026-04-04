# Tasks: Skill System

**Input**: Design documents from `/specs/012-skill-system/`

## Phase 1: Setup

- [X] T001 Create src/skill/ directory

---

## Phase 2: User Story 1 - SKILL.md Parsing (Priority: P1)

**Goal**: 实现 SKILL.md 解析

- [X] T002 [US1] Implement skill-parser.ts for SKILL.md frontmatter + body parsing in src/skill/skill-parser.ts
- [X] T003 [US1] Write tests for skill-parser in tests/skill/skill-parser.test.ts

**Checkpoint**: SKILL.md 解析测试通过

---

## Phase 3: User Story 2 - FileSkillLoader (Priority: P2)

**Goal**: 实现 SkillLoader 接口

- [X] T004 [US2] Implement FileSkillLoader class in src/skill/file-skill-loader.ts
- [X] T005 [US2] Write tests for FileSkillLoader in tests/skill/file-skill-loader.test.ts

**Checkpoint**: FileSkillLoader 测试通过

---

## Phase 4: Integration

- [X] T006 Update BotManager to create FileSkillLoader and inject into BotInstance in src/core/bot-manager.ts
- [X] T007 Verify build and all tests pass

---

## Dependencies

- Phase 2 standalone
- Phase 3 depends on Phase 2 + SkillLoader interface from 001
- Phase 4 depends on all
