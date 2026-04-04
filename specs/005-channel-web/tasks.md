# Tasks: Web Panel Channel

**Input**: Design documents from `/specs/005-channel-web/`

## Phase 1: Setup

- [X] T001 Create src/channels/ and src/channels/web/ directories

---

## Phase 2: User Story 1 - WebSocket Channel (Priority: P1)

**Goal**: 实现 Channel 接口的 WebSocket 版本

- [X] T002 [US1] Implement WebChannel class with Bun.serve WebSocket in src/channels/web/web-channel.ts
- [X] T003 [US1] Write tests for WebChannel: start/stop, message routing, session isolation in tests/channels/web-channel.test.ts

**Checkpoint**: WebSocket Channel 测试通过

---

## Phase 3: User Story 2 - Web Panel 前端 (Priority: P2)

**Goal**: 提供简易 HTML 页面

- [X] T004 [US2] Create embedded HTML for chat UI in src/channels/web/panel.html.ts
- [X] T005 [US2] Integrate static HTML serving into WebChannel start()

**Checkpoint**: 浏览器访问可看到聊天页面

---

## Phase 4: Integration

- [X] T006 Update BotManager to create WebChannel for bots with web channel config in src/core/bot-manager.ts
- [X] T007 Verify build and all tests pass

---

## Dependencies

- Phase 2 depends on 001 Channel interface + 002 Contact ID
- Phase 3 depends on Phase 2
- Phase 4 depends on all
