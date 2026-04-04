# Feature Specification: LLM Agent

**Feature Branch**: `003-llm-agent`
**Created**: 2026-04-04
**Status**: Draft

## User Scenarios & Testing

### User Story 1 - 基本对话调用 (Priority: P1)

Bot 需要调用 LLM API 进行对话。给定一组消息历史，调用 OpenAI 兼容 API 获取回复。

**Why this priority**: 这是 Bot 能"说话"的基础。

**Independent Test**: 发送一组消息给 LLM Agent，获得回复文本和 token 用量。

**Acceptance Scenarios**:

1. **Given** 一组对话消息, **When** 调用 chat(), **Then** 返回 LLM 的回复文本和 token 用量
2. **Given** 配置了特定模型, **When** 调用 chat(), **Then** 使用配置的模型而非硬编码
3. **Given** API 返回错误, **When** 调用 chat(), **Then** 抛出可理解的错误信息

---

### User Story 2 - 对话历史管理 (Priority: P1)

对话历史会随着交流不断增长，需要管理机制防止超出模型 token 限制。系统需要感知 token 数量并在必要时裁剪历史。

**Why this priority**: 没有 token 管理，长对话会导致 API 报错。

**Independent Test**: 构造超长历史，调用时历史被自动裁剪，API 调用成功。

**Acceptance Scenarios**:

1. **Given** 历史 token 总量未超限, **When** 调用 chat(), **Then** 完整发送所有历史
2. **Given** 历史 token 总量超限, **When** 调用 chat(), **Then** 从最早的消息开始裁剪，保留 system prompt 和最近的消息
3. **Given** 裁剪后, **When** 观察裁剪结果, **Then** system 消息永远不被裁剪

---

### User Story 3 - 工具调用 (Priority: P2)

LLM 可以调用工具（function calling）来执行技能。Agent 需要支持将工具定义传给 API，解析工具调用请求。

**Why this priority**: 工具调用是技能系统的基础，但基本对话更优先。

**Independent Test**: 传入工具定义，LLM 返回工具调用请求，Agent 正确解析。

**Acceptance Scenarios**:

1. **Given** 提供了工具定义, **When** LLM 决定调用工具, **Then** 返回的 ChatResult 包含 toolCalls
2. **Given** LLM 不需要调用工具, **When** 只想文本回复, **Then** 返回纯文本，toolCalls 为空
3. **Given** 工具调用结果, **When** 将结果作为 tool role 消息回传, **Then** LLM 基于结果生成最终回复

---

### Edge Cases

- API 超时如何处理？
- API 返回空回复如何处理？
- token 计数不完全精确时的安全余量
- 网络断连后的重试策略

## Requirements

### Functional Requirements

- **FR-001**: 必须通过 OpenAI SDK 调用 OpenAI 兼容 API
- **FR-002**: API base URL 和 key 从全局配置读取
- **FR-003**: 调用时指定的模型名称来自配置（不同任务可能用不同模型）
- **FR-004**: 必须返回 token 用量信息（promptTokens, completionTokens, totalTokens）
- **FR-005**: 对话历史 token 裁剪时必须保留 system 消息
- **FR-006**: token 计数使用近似算法（字符数 / 4），预留安全余量
- **FR-007**: 支持传入 tools 参数进行 function calling
- **FR-008**: API 调用超时需可配置（默认 30 秒）
- **FR-009**: API 错误必须包装为可理解的错误信息，包含模型名和错误原因

### Key Entities

- **LLMAgent**: 封装 OpenAI SDK 调用的模块
- **ConversationHistory**: 对话历史管理器，负责 token 感知裁剪

## Success Criteria

- **SC-001**: 成功调用 OpenAI 兼容 API 并获得回���
- **SC-002**: 超长历史自动裁剪后仍能成功调用
- **SC-003**: 工具调用正确传递和解析
- **SC-004**: API 错误不导致进程崩溃

## Assumptions

- 使用项目已安装的 `openai` SDK
- 所有 LLM 提供商兼容 OpenAI API 格式
- token 近似计数足够准确（不需要精确 tokenizer）
- 本 Spec 不实现多轮工具调用循环（由 Brain 编排）
