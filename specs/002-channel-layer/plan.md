# Implementation Plan: Channel 运行层

**Branch**: `002-channel-layer` | **Date**: 2026-04-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-channel-layer/spec.md`

## Summary

实现 Channel 层的运行时基础设施：消息防抖器（将用户连发的多条消息聚合为一批）、Contact ID 工具（统一标识联系人）、Channel 调度器（连接 Channel 与 Brain 的消息管线）。本阶段不包含任何具体 Channel 实现（Web、Telegram 等由后续 Spec 完成）。

## Technical Context

**Language/Version**: TypeScript 5.x (strict mode)
**Runtime**: Bun
**Primary Dependencies**: 无新增依赖（使用 001 已安装的 pino）
**Storage**: N/A（本层无持久化）
**Testing**: Vitest
**Target Platform**: Linux (Docker), macOS
**Project Type**: 常驻后台服务模块
**Performance Goals**: 防抖处理延迟 < 10ms（不含等待窗口本身），100 个并发联系人无性能退化
**Constraints**: 无全局可变状态，异步操作，组合优先
**Scale/Scope**: 单 Bot 同时 1~100 个联系人

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 宪法条目 | 状态 | 说明 |
|----------|------|------|
| 组合优先，不用类继承 | ✅ | ChannelDispatcher 是组合，不继承 Channel |
| 无全局可变状态 | ✅ | 防抖状态按 BotInstance 隔离 |
| 文件操作只用异步 API | N/A | 本层无文件操作 |
| Channel 只负责收发 | ✅ | 业务逻辑在 Brain，Channel 只做消息转发 |

无违规。通过。

## Project Structure

### Documentation (this feature)

```text
specs/002-channel-layer/
├── plan.md              # This file
├── research.md          # 技术决策
├── data-model.md        # 实体定义
└── tasks.md             # 任务分解
```

### Source Code (repository root)

```text
src/
├── core/
│   ├── channel-dispatcher.ts   # 调度器：连接 Channel 和 Brain
│   ├── message-debouncer.ts    # 消息防抖器
│   ├── contact-id.ts           # Contact ID 工具函数
│   └── bot-instance.ts         # 更新：集成调度器
tests/
├── core/
│   ├── channel-dispatcher.test.ts
│   ├── message-debouncer.test.ts
│   └── contact-id.test.ts
```

**Structure Decision**: 所有新代码放在 `src/core/` 下，与 001 的接口定义同层。这些是核心运行时组件，不属于某个特定 Channel。

## Implementation Approach

### 消息防抖器 (MessageDebouncer)

**工作原理**：
1. 收到消息时，以 contactId 为 key 查找或创建一个待处理批次
2. 将消息加入批次，重置该联系人的等待计时器
3. 等待窗口到期后，触发回调并传入整个消息批次
4. 如果等待期间又收到新消息，重置计时器（滑动窗口）

**配置**：
- `debounceMs`: 等待窗口毫秒数（默认 2000ms）
- `maxWaitMs`: 最大等待时间（默认 10000ms），防止用户持续输入导致永远不处理

**API**：
```typescript
interface MessageDebouncer {
  push(message: IncomingMessage): void;
  onBatch(callback: (messages: IncomingMessage[]) => Promise<void>): void;
  clear(contactId: string): void;
  dispose(): void;
}
```

### Contact ID

纯工具函数，无状态：

```typescript
function makeContactId(channelType: string, platformId: string): string;
function parseContactId(contactId: string): { channelType: string; platformId: string };
```

格式: `channelType:platformId`。冒号是分隔符，platformId 中可包含冒号（如 Matrix 的 `@user:server.com`），解析时只分割第一个冒号。

### Channel 调度器 (ChannelDispatcher)

**职责**：将 Channel 和 Brain 连接起来。

**消息流**：
1. Channel 收到消息 → 调度器的 `handleIncoming()` 被调用
2. 消息进入防抖器
3. 防抖器触发批次 → 合并消息文本 → 调用 Brain.handleMessage()
4. 同时发送 typing 状态到对应 Channel
5. Brain 返回回复 → 按顺序通过 Channel 发送
6. 多条回复之间间隔 500ms（模拟打字节奏）

**错误处理**：
- Channel 发送失败：记录错误，尝试发送下一条
- Brain 处理失败：记录错误，不回复用户（避免暴露内部错误）

### BotInstance 更新

更新 BotInstance 的 `start()` 方法：
- 创建 ChannelDispatcher（注入 Brain 和所有 Channel）
- Channel 的 onMessage 回调连接到调度器
- `stop()` 时清理调度器资源（dispose 防抖器）

## Complexity Tracking

无宪法违规，不需要记录。
