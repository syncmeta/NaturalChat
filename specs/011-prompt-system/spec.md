# Spec: 011-prompt-system

## 概述

Prompt 系统：从 Bot 的 `prompts/` 目录加载外部 Markdown prompt 文件，支持变量替换和 prompt registry。

## 用户故事

### US1 - Prompt Registry (P1)

**作为** Bot 开发者
**我希望** 将不同用途的 prompt 存放在 `prompts/` 下的 Markdown 文件中
**以便** 修改 prompt 不需要改代码，只需编辑 Markdown

**验收标准**:
- PromptRegistry 扫描 `prompts/` 目录加载所有 `.md` 文件
- 每个文件名（去掉 .md）作为 prompt 名称：`system.md` → "system"
- 支持通过 `get(name)` 获取 prompt 内容
- 支持 `{{变量}}` 模板语法替换
- 内置变量：`{{botName}}`, `{{botDescription}}`, `{{date}}`
- 找不到文件时返回 null，调用方决定 fallback
- 支持 reload 清除缓存

### US2 - Brain 集成 (P2)

**作为** SimpleBrain
**我希望** 使用 PromptRegistry 替代现有 PromptBuilder
**以便** 统一 prompt 加载逻辑，支持更多 prompt 文件

**验收标准**:
- SimpleBrain 使用 PromptRegistry 加载 system prompt
- 向后兼容：无 prompts/system.md 时使用默认行为 prompt
- PromptBuilder 保留但标记为 deprecated，内部委托给 PromptRegistry
