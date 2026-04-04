# Research: Channel 运行层

## R-001: 防抖策略选择

**Decision**: 滑动窗口 + 最大等待时间（ceiling）

**Rationale**:
- 纯固定窗口：用户发完第一条就开始计时，可能在用户还在打字时就触发处理
- 纯滑动窗口：如果用户持续输入，会无限推迟处理
- 滑动窗口 + ceiling：每条新消息重置等待，但总等待不超过上限，兼顾两者

**Alternatives considered**:
- 固定窗口（收到第一条后等 N 秒）：对连续快速输入效果差
- 基于输入状态检测：需要 Channel 支持 typing indicator 上报，不是所有平台都有

## R-002: Contact ID 格式

**Decision**: `channelType:platformId`，以第一个冒号为分隔

**Rationale**:
- 简单直观，可读性好
- 冒号在 Channel type 名称中不出现（如 telegram、matrix、web）
- Platform ID 可能包含冒号（如 Matrix 的 @user:server.com），因此解析时只分割第一个冒号
- 无需引入更复杂的编码方案

**Alternatives considered**:
- URL 格式 `channel://platformId`：过度设计
- JSON `{"type":"telegram","id":"123"}`：不便于用作 Map key
- 下划线分隔 `telegram_12345`：platform ID 可能包含下划线

## R-003: 多条回复间隔策略

**Decision**: 固定间隔 500ms

**Rationale**:
- 模拟人类打字节奏，不会一次性丢出所有回复
- 500ms 是微信/Telegram 中两条连续消息的最小自然间隔
- 后续可改为基于回复长度的动态间隔

**Alternatives considered**:
- 无间隔：回复一口气全发，不像人类
- 基于字数动态计算：增加复杂度，当前阶段不必要
- Channel 特定间隔：不同 Channel 体验不同，增加配置负担

## R-004: Brain 处理期间新消息处理

**Decision**: 新消息进入防抖器正常排队

**Rationale**:
- 防抖器按联系人隔离，所以同一用户在 Brain 处理上一批时发的新消息会开始新一轮防抖
- Brain.handleMessage 是异步的，上一次处理完成后，新批次的防抖可能已经积累好了
- 不需要显式的队列机制——防抖器本身就是按联系人的消息缓冲区
- 注意：需要确保同一联系人的处理是串行的（不并发调用 Brain），通过 per-contact lock 实现

**Alternatives considered**:
- 全局消息队列：过重，不同联系人的消息互不影响
- 丢弃：不可接受，用户消息不应丢失
