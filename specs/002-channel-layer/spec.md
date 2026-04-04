# Feature Specification: Channel 运行层

**Feature Branch**: `002-channel-layer`
**Created**: 2026-04-04
**Status**: Draft
**Input**: Constitution Channel 定义 + 001 接口骨架

## User Scenarios & Testing

### User Story 1 - 消息防抖与批处理 (Priority: P1)

用户在 IM 中习惯连发多条短消息（像微信聊天一样），系统需要等待用户发完一组消息后再统一处理，而不是对每条消息单独回复。

**Why this priority**: 这是 Bot "像微信聊天"风格的基础。没有防抖，Bot 会对每条消息单独回复，行为非常像客服而不是朋友。

**Independent Test**: 快速连续发送 3 条消息，系统只产生一次处理调用，且包含全部 3 条消息的内容。

**Acceptance Scenarios**:

1. **Given** 用户在 2 秒内发送 3 条消息, **When** 防抖等待期结束, **Then** 系统将 3 条消息合并为一次处理请求
2. **Given** 用户发送 1 条消息, **When** 等待期内没有新消息, **Then** 系统正常处理这 1 条消息
3. **Given** 用户发送消息后等了很久又发, **When** 两条消息间隔超过等待窗口, **Then** 系统分别处理两次

---

### User Story 2 - Contact ID 统一标识 (Priority: P1)

每个用户在不同渠道有不同的平台 ID。系统需要一套统一的联系人标识方案，使得 Bot 能唯一识别一个联系人，无论消息从哪个渠道来。

**Why this priority**: Contact ID 是消息路由、记忆系统、访问控制的基础。没有它，Bot 无法将不同渠道的用户关联起来。

**Independent Test**: 从两个不同渠道发消息，系统生成不同的 Contact ID，格式符合约定。

**Acceptance Scenarios**:

1. **Given** Telegram 用户 ID 12345, **When** 生成 Contact ID, **Then** 得到 "telegram:12345"
2. **Given** Matrix 用户 @bot:example.com, **When** 生成 Contact ID, **Then** 得到 "matrix:@bot:example.com"
3. **Given** Contact ID "telegram:12345", **When** 解析, **Then** 得到 Channel 类型 "telegram" 和平台 ID "12345"

---

### User Story 3 - Channel 消息调度 (Priority: P1)

BotInstance 需要将来自各 Channel 的消息路由到 Brain 处理，并将 Brain 的回复通过正确的 Channel 发回。这是 Bot 多渠道运行的核心调度逻辑。

**Why this priority**: 没有调度层，Channel 和 Brain 无法连接，Bot 无法工作。

**Independent Test**: 使用一个模拟 Channel 和模拟 Brain，发送消息后验证 Brain 收到消息、Channel 收到回复。

**Acceptance Scenarios**:

1. **Given** Channel A 收到消息, **When** 消息经过防抖后送达 Brain, **Then** Brain 的回复通过 Channel A 发回给用户
2. **Given** Bot 有两个 Channel, **When** Channel B 收到消息, **Then** 回复只发到 Channel B，不影响 Channel A
3. **Given** Brain 返回多条回复, **When** 回复发送, **Then** 按顺序逐条发送，每条之间有适当间隔
4. **Given** Brain 处理中, **When** 用户等待回复, **Then** Channel 向用户发送"正在输入"状态

---

### Edge Cases

- 用户在 Brain 处理上一批消息时又发新消息会怎样？
- Channel 发送消息失败（网络错误）如何处理？
- Brain 返回空回复如何处理？
- 用户发送的消息包含文件附件时如何处理？

## Requirements

### Functional Requirements

- **FR-001**: 系统必须支持消息防抖——同一联系人在配置的等待窗口内的多条消息合并为一批处理
- **FR-002**: 防抖等待窗口必须可配置（默认值合理即可）
- **FR-003**: Contact ID 格式必须为 `channel_type:platform_id`，可拆解回原始部分
- **FR-004**: 调度器必须将消息路由到 Brain，并将回复路由回正确的 Channel
- **FR-005**: 调度器在 Brain 处理期间必须发送"正在输入"状态
- **FR-006**: 多条回复必须按顺序发送，之间有短间隔（模拟人类打字节奏）
- **FR-007**: Channel 发送失败必须记录错误日志，不得导致整个 Bot 崩溃
- **FR-008**: Brain 处理上一批消息期间收到的新消息应排队等待，不应丢弃
- **FR-009**: 消息防抖必须按联系人隔离——A 用户的消息不影响 B 用户的防抖计时

### Key Entities

- **MessageBatch**: 一组被防抖聚合的消息，包含联系人 ID、消息列表、来源 Channel
- **ContactId**: 统一联系人标识，格式 `type:platformId`
- **ChannelDispatcher**: 消息调度器，连接 Channel 和 Brain

## Success Criteria

### Measurable Outcomes

- **SC-001**: 2 秒内连发 3 条消息只触发 1 次 Brain 调用
- **SC-002**: 所有 Contact ID 格式一致且可逆解析
- **SC-003**: 回复消息在 Brain 完成后 1 秒内开始发送
- **SC-004**: Channel 发送失败不导致 Bot 或其他 Channel 崩溃

## Assumptions

- Brain 接口已在 001 中定义，本 Spec 使用但不实现 Brain
- Channel 接口已在 001 中定义，本 Spec 构建其运行时基础设施
- 单个 Bot 同时在线用户不超过 100 人
- 消息防抖的等待窗口对所有渠道统一（不区分 Channel 类型）
