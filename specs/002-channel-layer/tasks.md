# Tasks: Channel 运行层

**Input**: Design documents from `/specs/002-channel-layer/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

## Phase 1: Setup

**Purpose**: 无额外 Setup，复用 001 项目结构

（无任务）

---

## Phase 2: User Story 2 - Contact ID 统一标识 (Priority: P1)

**Goal**: 提供 Contact ID 的生成与解析工具，格式 `channelType:platformId`

**Independent Test**: `makeContactId("telegram", "12345")` 返回 `"telegram:12345"`，`parseContactId` 可逆

- [X] T001 [US2] Implement makeContactId and parseContactId functions in src/core/contact-id.ts
- [X] T002 [US2] Write tests for Contact ID: create, parse, roundtrip, edge cases (colon in platformId) in tests/core/contact-id.test.ts

**Checkpoint**: Contact ID 工具函数测试全部通过

---

## Phase 3: User Story 1 - 消息防抖与批处理 (Priority: P1) 🎯 MVP

**Goal**: 同一联系人连发的多条消息聚合为一批处理

**Independent Test**: 快速 push 3 条消息，只触发 1 次 batch 回调

- [X] T003 [US1] Implement MessageDebouncer class with push, onBatch, clear, dispose in src/core/message-debouncer.ts
- [X] T004 [US1] Write tests for MessageDebouncer: single message fires after timeout, multiple messages batched, maxWait ceiling, per-contact isolation, dispose cleans timers in tests/core/message-debouncer.test.ts

**Checkpoint**: 防抖器单元测试全部通过

---

## Phase 4: User Story 3 - Channel 消息调度 (Priority: P1)

**Goal**: 将 Channel 和 Brain 连接起来，消息通过防抖后送到 Brain，回复发回 Channel

**Independent Test**: 使用 mock Channel 和 mock Brain，验证完整消息流

- [X] T005 [US3] Implement ChannelDispatcher: handleIncoming, processBatch (merge texts, send typing, call brain, send replies with 500ms interval), start, stop in src/core/channel-dispatcher.ts
- [X] T006 [US3] Update BotInstance to integrate ChannelDispatcher: create dispatcher in start(), wire channel.onMessage to dispatcher, dispose in stop() in src/core/bot-instance.ts
- [X] T007 [US3] Write tests for ChannelDispatcher: message routes to brain, reply sent back to correct channel, typing indicator sent, multiple replies sent with delay, channel send error logged not crashed in tests/core/channel-dispatcher.test.ts
- [X] T008 [US3] Write tests for updated BotInstance: start wires channels to dispatcher, stop disposes dispatcher in tests/core/bot-instance.test.ts

**Checkpoint**: 完整消息流测试通过——mock Channel → 防抖 → mock Brain → 回复

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T009 [P] Verify build passes: `bun run build` with zero errors
- [X] T010 [P] Run full test suite: `bun test` all passing

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 2 (Contact ID)**: 无依赖，纯工具函数
- **Phase 3 (防抖器)**: 依赖 001 的 IncomingMessage 类型
- **Phase 4 (调度器)**: 依赖 Phase 2 (Contact ID) + Phase 3 (防抖器) + 001 的 Channel/Brain 接口
- **Phase 5 (Polish)**: 依赖所有上述

### Within Each Phase

- Tasks marked [P] can run in parallel
- Unmarked tasks run sequentially in listed order

---

## Implementation Strategy

### MVP (US2 + US1 + US3)

1. Phase 2: Contact ID 工具 → 测试通过
2. Phase 3: 防抖器 → 测试通过
3. Phase 4: 调度器 + BotInstance 集成 → 完整消息流测试通过
4. Phase 5: 全量验证

---

## Notes

- Contact ID 放在最前面因为它是纯函数，最简单，且被调度器依赖
- 本阶段没有真实的 Channel 实现，测试全部使用 mock
- BotInstance 的更新是关键集成点，需要仔细处理向后兼容
