# Implementation Plan: LLM Agent

**Branch**: `003-llm-agent` | **Date**: 2026-04-04 | **Spec**: [spec.md](./spec.md)

## Summary

实现 LLM 调用层：通过 OpenAI SDK 调用 OpenAI 兼容 API，管理对话历史（token 感知裁剪），支持工具调用。

## Technical Context

**Language/Version**: TypeScript 5.x (strict mode)
**Runtime**: Bun
**Primary Dependencies**: openai SDK (已安装)
**Testing**: Vitest
**Constraints**: 组合优先，无全局可变状态

## Constitution Check

| 宪法条目 | 状态 | 说明 |
|----------|------|------|
| OpenAI 兼容 API | ✅ | ��过 openai SDK，支持自定义 baseURL |
| 统一模型提供商 | ✅ | 全局 api_base_url + api_key |
| 不同任务用不同模型 | ✅ | chat() 接受 model 参数 |

无违规。

## Project Structure

```text
src/
├── llm/
│   ├── openai-agent.ts       # LLMAgent 接口的 OpenAI 实现
│   ├── conversation-history.ts # 对话历史管理器（token ��剪）
│   └── token-counter.ts      # token 近似计数
tests/
├── llm/
│   ├── openai-agent.test.ts
│   ├���─ conversation-history.test.ts
│   └── token-counter.test.ts
```

## Implementation Approach

### OpenAIAgent

实现 `LLMAgent` 接口，内部使用 `openai` SDK：

```typescript
class OpenAIAgent implements LLMAgent {
  constructor(config: { baseURL: string; apiKey: string; defaultModel: string; timeoutMs?: number })
  chat(messages, tools?): Promise<ChatResult>
}
```

- 构造时创建 `OpenAI` client（指定 baseURL + apiKey）
- `chat()` 调用 `client.chat.completions.create()`
- 将 SDK 返回值转为 `ChatResult` 类型
- 错误包装：捕获 SDK 异常，转为包含模型名和原因的错误

### ConversationHistory

Token 感知的历史管理器：

```typescript
class ConversationHistory {
  constructor(config: { maxTokens: number; reservedTokens?: number })
  add(message: ChatMessage): void
  getMessages(): ChatMessage[]
  setSystem(content: string): void
}
```

- `maxTokens`: 最大 token 预算
- `reservedTokens`: 为回复预留的 token 数（默认 1000）
- `setSystem()`: 设置 system prompt（永远不被裁剪）
- `add()`: 添加消息
- `getMessages()`: 返回裁剪后的消息。裁剪策略：保留 system + 从最新消息往前填，直到快到预算

### TokenCounter

简单的 token 近似计数：

```typescript
function estimateTokens(text: string): number
function estimateMessagesTokens(messages: ChatMessage[]): number
```

- 英文：约 4 字符 = 1 token
- 中文：约 2 字符 = 1 token
- 混合内容：保守估计，使用较高的系数
- 每条消息额外加 4 token（role + formatting overhead）

## Complexity Tracking

无宪法违规。
