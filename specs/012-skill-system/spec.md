# Spec: 012-skill-system

## 概述

实现技能系统：按 Anthropic Agent Skills 规范，从 SKILL.md 文件加载技能定义，支持脚本执行。

## 用户故事

### US1 - SKILL.md 解析 (P1)

**作为** Bot 开发者
**我希望** 在 `skills/<name>/SKILL.md` 中定义技能
**以便** Bot 能自动发现和使用技能

SKILL.md 格式:
```markdown
---
name: weather
description: 查询天气信息
parameters:
  city:
    type: string
    description: 城市名称
    required: true
---

# 天气查询

当用户询问天气时，使用此技能查询指定城市的天气。
```

**验收标准**:
- 解析 YAML frontmatter 获取 name, description, parameters
- 解析 body 获取完整指令
- 扫描 scripts/ 目录获取可执行脚本列表
- 支持从多个目录发现技能（common_skills/ + bots/<name>/skills/）

### US2 - 技能执行 (P2)

**作为** Bot Brain
**我希望** 能调用技能执行脚本
**以便** Bot 能实际使用技能完成任务

**验收标准**:
- FileSkillLoader 实现 SkillLoader 接口
- discover 返回 SkillMeta 列表
- getToolDefinitions 生成 OpenAI function calling 格式的 Tool
- execute 运行技能的脚本并返回结果
- 脚本执行有超时保护（默认 30 秒）
