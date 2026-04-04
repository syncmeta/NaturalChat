# Spec: 010-memory-system

## 概述

实现 Memory 接口的本地文件存储版本，为每个 Bot 提供持久化的用户上下文记忆。

## 用户故事

### US1 - 本地文件记忆 (P1)

**作为** Bot 运维者
**我希望** Bot 能在 `data/memory/` 下以 JSON 文件形式持久化每个用户的上下文
**以便** Bot 重启后仍能记住用户的画像和历史摘要

**验收标准**:
- 实现 Memory 接口的 FileMemory 类
- 每个 contactId 一个 JSON 文件，存储在 `<botDir>/data/memory/`
- contactId 中的冒号等特殊字符做安全转义作为文件名
- getContext 找不到文件时返回默认空 UserContext
- updateContext 做 merge（不覆盖未提供的字段）
- 文件读写全部异步
- 处理并发写入的安全性（同一 contactId 串行写入）

### US2 - Brain 集成记忆 (P2)

**作为** Bot
**我希望** SimpleBrain 在处理消息时能读取和更新用户记忆
**以便** 我能记住用户的偏好和上下文

**验收标准**:
- SimpleBrain 可选接收 Memory 实例
- 处理消息前读取用户上下文
- 将上下文摘要注入到 system prompt
- 每次交互后更新 lastInteraction 时间戳
