# Feature Specification: Bot Brain

**Feature Branch**: `004-bot-brain`
**Created**: 2026-04-04
**Status**: Draft

## User Scenarios & Testing

### User Story 1 - 消息处理管线 (Priority: P1)

Bot 收到消息后，经过编排管线处理：构建 prompt、调用 LLM、获取回复。Brain 是 Bot 的"大脑"，接收来自 Channel Dispatcher 的消息并返回回复。

**Why this priority**: 这是 Bot 能"思考和回复"的核心。

**Independent Test**: 发送一条消息给 Brain，Brain 调用 LLM 并返回回复文本。

**Acceptance Scenarios**:

1. **Given** 用户发送消息, **When** Brain 处理, **Then** 构建 system prompt + 用户消息 → 调用 LLM → 返回回复
2. **Given** LLM 返回多段回复（含换行）, **When** 回复拆分, **Then** 按换行拆分为多条消息返回
3. **Given** LLM 调用失败, **When** Brain 处理, **Then** 返回友好的错误提示而不是崩溃

---

### User Story 2 - 访问控制 (Priority: P2)

Bot 支持三种访问模式：开放、审批、私密。根据当前模式决定是否处理用户的消息。

**Why this priority**: 安全和隐私的基础保障。

**Independent Test**: 在私密模式下，非创建者的消息被拒绝。

**Acceptance Scenarios**:

1. **Given** 开放模式, **When** 任何人发消息, **Then** 正常处理
2. **Given** 私密模式, **When** 非创建者发消息, **Then** 返回拒绝提示
3. **Given** 审批模式, **When** 未批准用户发消息, **Then** 返回等待审批提示

---

### User Story 3 - 回复风格处理 (Priority: P1)

Bot 的回复需要符合宪法中定义的对话风格：像微信聊天、不像客服、简洁高效。Brain 需要在 system prompt 中注入这些行为准则，并将长回复拆分为适合 IM 的短消息。

**Why this priority**: Bot 的人格和风格是产品差异化的核心。

**Independent Test**: LLM 回复包含多段文字时，被拆分为多条短消息。

**Acceptance Scenarios**:

1. **Given** Brain 构建 prompt, **When** 观察 system prompt, **Then** 包含人格准则和对话风格要求
2. **Given** LLM 回复为一大段文字, **When** 拆分处理, **Then** 按双换行或合理断点拆分为多条
3. **Given** LLM 回复只有一行, **When** 不需要拆分, **Then** 直接作为单条消息返回

---

### Edge Cases

- LLM 返回空字符串如何处理？
- 用户发送空消息如何处理？
- 并发多个联系人同时发消息时的隔离性

## Requirements

### Functional Requirements

- **FR-001**: Brain 必须实现 001 定义的 Brain 接口（handleMessage, start, stop）
- **FR-002**: handleMessage 必须构建包含 system prompt 的完整消息列表
- **FR-003**: system prompt 必须从 Bot 目录的 prompts/ 中加载（如果存在）
- **FR-004**: 回复必须按双换行拆分为多条消息
- **FR-005**: 每条回复消息不应超过 500 字符（超长则在合理断点处拆分）
- **FR-006**: 访问控制支持三种模式：open, approval, private
- **FR-007**: 对话历史必须按联系人隔离（不同用户的历史互不影响）
- **FR-008**: LLM 调用失败时返回友好提示，不暴露内部错误

### Key Entities

- **SimpleBrain**: Brain 接口的基础实现
- **AccessControl**: 访问控制策略
- **PromptBuilder**: 构建完整 prompt 的工具

## Success Criteria

- **SC-001**: 消息发到 Brain 后能收到 LLM 生成的回复
- **SC-002**: 长回复被拆分为多条 IM 风格的消息
- **SC-003**: 私密模式下未授权用户被拒绝
- **SC-004**: 不同联系人的对话历史互相隔离

## Assumptions

- LLMAgent 已在 003 中实现
- ConversationHistory 已在 003 中实现
- 本 Spec 不实现工具调用循环（技能执行由后续 012 实现）
- 本 Spec 不实现反思、批评等高级功能（由 013、014 实现）
- Prompt 文件格式为 Markdown，system prompt 从 `prompts/system.md` 加载
