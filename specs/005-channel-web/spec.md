# Feature Specification: Web Panel Channel

**Feature Branch**: `005-channel-web`
**Created**: 2026-04-04
**Status**: Draft

## User Scenarios & Testing

### User Story 1 - WebSocket 通信 (Priority: P1)

用户通过浏览器打开 Web Panel，与 Bot 进行实时对话。消息通过 WebSocket 双向传输。

**Why this priority**: Web Panel 是第一个具体 Channel 实现，用于端到端验证整个系统。

**Independent Test**: 启动服务，WebSocket 客户端连接，发送消息，收到 Bot 回复。

**Acceptance Scenarios**:

1. **Given** Web Panel 服务启动, **When** 客户端通过 WebSocket 连接, **Then** 连接建立成功
2. **Given** 已连接, **When** 客户端发送消息, **Then** Channel 将消息传递给消息处理管线
3. **Given** Brain 返回回复, **When** 通过 Channel 发送, **Then** 客户端通过 WebSocket 收到回复
4. **Given** 客户端断开, **When** 重新连接, **Then** 分配新的 session

---

### User Story 2 - 简易前端页面 (Priority: P2)

提供一个极简的 HTML 页面用于测试对话，不需要前端框架。

**Why this priority**: 有了前端才能真正端到端测试。

**Independent Test**: 打开浏览器访问 URL，看到聊天界面，发送消息收到回复。

**Acceptance Scenarios**:

1. **Given** 访问 Web Panel URL, **When** 页面加载, **Then** 显示简单的聊天输入框
2. **Given** 在输入框输入消息, **When** 按发送, **Then** 消息出现在对话区，稍后收到回复

---

### Edge Cases

- WebSocket 连接断开后消息如何处理？
- 多个客户端同时连接如何隔离？
- 服务关闭时如何优雅断开所有 WebSocket？

## Requirements

### Functional Requirements

- **FR-001**: 实现 Channel 接口（start, stop, sendMessage, sendTyping, onMessage）
- **FR-002**: 使用 Bun 内置 WebSocket 服务器
- **FR-003**: 每个 WebSocket 连接视为独立 session，Contact ID 为 `web:session-xxx`
- **FR-004**: 提供静态 HTML 页面用于测试
- **FR-005**: stop() 必须关闭所有 WebSocket 连接和 HTTP 服务器
- **FR-006**: 消息格式使用 JSON: `{ type: "message", text: "..." }`
- **FR-007**: typing 状态通过 JSON 发送: `{ type: "typing" }`

### Key Entities

- **WebChannel**: Channel 接口的 WebSocket 实现
- **WebSession**: 表示一个 WebSocket 连接

## Success Criteria

- **SC-001**: `bun run dev` 启动后，通过浏览器打开 Web Panel 可完成一次完整对话
- **SC-002**: 多个浏览器标签同时连接互不干扰

## Assumptions

- 使用 Bun 内置的 HTTP/WebSocket 服务器，无需额外依赖
- Web Panel 端口可配置（默认 3000）
- 前端页面是内嵌 HTML（不需要打包工具）
- 本 Spec 不做用户认证（后续可加）
