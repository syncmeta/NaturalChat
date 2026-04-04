# Implementation Plan: Bot Brain

**Branch**: `004-bot-brain` | **Date**: 2026-04-04 | **Spec**: [spec.md](./spec.md)

## Summary

实现 Bot 的"大脑"：消息处理管线（prompt 构建 → LLM 调用 → 回复拆分）、访问控制（三种模式）、per-contact 对话历史隔离。

## Technical Context

**Language/Version**: TypeScript 5.x (strict mode)
**Primary Dependencies**: 无新增（使用 003 的 LLMAgent + ConversationHistory）
**Testing**: Vitest

## Constitution Check

| 宪法条目 | 状态 | 说明 |
|----------|------|------|
| 组合优先 | ✅ | SimpleBrain 组合 LLMAgent + ConversationHistory |
| 像微信聊天风格 | ✅ | 回复拆分 + prompt 中注入行为准则 |
| Prompt 外部化 | ✅ | system prompt 从文件加载 |
| 访问控制三模式 | ✅ | open/approval/private |

## Project Structure

```text
src/
├── brain/
│   ├── simple-brain.ts       # Brain 接口实现
│   ├── access-control.ts     # 访问控制
│   ├── prompt-builder.ts     # Prompt 构建
│   └── reply-splitter.ts     # 回复拆分
tests/
├── brain/
│   ├── simple-brain.test.ts
│   ├── access-control.test.ts
│   ├── prompt-builder.test.ts
│   └── reply-splitter.test.ts
```

## Implementation Approach

### SimpleBrain

实现 Brain 接口，编排处理流程：

1. 访问控制检查
2. 获取/创建该联系人的 ConversationHistory
3. 从 prompts/system.md 加载 system prompt（缓存）
4. 调用 LLMAgent.chat()
5. 拆分回复为多条消息
6. 将用户消息和 AI 回复写入历史

### AccessControl

```typescript
type AccessMode = "open" | "approval" | "private";

interface AccessControl {
  check(contactId: string): AccessResult;  // "allowed" | "denied" | "pending"
  approve(contactId: string): void;
  setOwner(contactId: string): void;
}
```

### ReplySplitter

将 LLM 回复拆分为 IM 风格的短消息：
1. 先按双换行 `\n\n` 分段
2. 超过 500 字符的段在句号/问号/感叹号处断开
3. 过滤空段
4. 保持顺序

### PromptBuilder

从 Bot 目录加载 prompt 文件，组装完整的 system prompt：
- 加载 `prompts/system.md`（如果存在）
- 注入 Bot 的 name 和 description
- 添加宪法中的行为准则（简化版，嵌入 prompt）
