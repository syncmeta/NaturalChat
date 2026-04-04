# Tasks: LLM Agent

**Input**: Design documents from `/specs/003-llm-agent/`
**Prerequisites**: plan.md, spec.md

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Create src/llm/ and tests/llm/ directories

---

## Phase 2: Foundational - Token Counter

**Purpose**: Token 计数是历史管理和 Agent 的基础依赖

- [X] T002 Implement estimateTokens and estimateMessagesTokens in src/llm/token-counter.ts
- [X] T003 Write tests for token counter: English text, Chinese text, mixed, message overhead in tests/llm/token-counter.test.ts

**Checkpoint**: Token 计数函数测试通过

---

## Phase 3: User Story 2 - 对话历史管理 (Priority: P1)

**Goal**: Token 感知的历史裁剪

**Independent Test**: 超长历史被裁剪后仍保留 system 和最近消息

- [X] T004 [US2] Implement ConversationHistory class with add, getMessages, setSystem, clear in src/llm/conversation-history.ts
- [X] T005 [US2] Write tests for ConversationHistory: add messages, system preserved, oldest trimmed first, within budget in tests/llm/conversation-history.test.ts

**Checkpoint**: 历史管理测试通过

---

## Phase 4: User Story 1 + 3 - OpenAI Agent (Priority: P1 + P2)

**Goal**: 实现 LLMAgent 接口，支持对话和工具调用

**Independent Test**: Mock OpenAI SDK，验证调用参数和返回值转��

- [X] T006 [US1] Implement OpenAIAgent class implementing LLMAgent interface in src/llm/openai-agent.ts
- [X] T007 [US1] Write tests for OpenAIAgent: mock SDK, verify chat call, verify result mapping, verify error handling, verify tool calls passed in tests/llm/openai-agent.test.ts

**Checkpoint**: Agent 调用测试通过

---

## Phase 5: Polish

- [X] T008 [P] Verify build: `bun run build` zero errors
- [X] T009 [P] Run full test suite: `bun test` all passing

---

## Dependencies

- Phase 2 (Token Counter): 无依赖
- Phase 3 (History): 依赖 Phase 2
- Phase 4 (Agent): 依赖 Phase 2（token 计数用于日志），独立于 Phase 3
- Phase 5: 依赖所有
