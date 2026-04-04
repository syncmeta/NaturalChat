# Data Model: Channel 运行层

## Contact ID

纯值对象（无状态），工具函数操作。

| 操作 | 输入 | 输出 | 说明 |
|------|------|------|------|
| makeContactId | channelType: string, platformId: string | string | 生成 "type:platformId" |
| parseContactId | contactId: string | { channelType, platformId } | 解析，以第一个冒号分割 |

## MessageDebouncer

按联系人隔离的消息防抖器。

### 配置

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| debounceMs | number | 2000 | 滑动窗口等待时间 |
| maxWaitMs | number | 10000 | 最大等待时间上限 |

### 内部状态（per contact）

| 字段 | 类型 | 说明 |
|------|------|------|
| messages | IncomingMessage[] | 累积的消息列表 |
| timer | Timer | 滑动窗口计时器 |
| firstMessageTime | number | 第一条消息的时间戳，用于 ceiling 判断 |

### 方法

| 方法 | 说明 |
|------|------|
| push(message) | 加入消息，重置/设置计时器 |
| onBatch(callback) | 注册批次处理回调 |
| clear(contactId) | 清除某联系人的待处理消息 |
| dispose() | 清理所有计时器 |

## ChannelDispatcher

连接 Channel 和 Brain 的调度器。

### 构造参数

| 参数 | 类型 | 说明 |
|------|------|------|
| channels | Channel[] | 已注册的 Channel 列表 |
| brain | Brain | Brain 实例 |
| debounceMs | number? | 防抖等待时间（可选） |
| maxWaitMs | number? | 最大等待时间（可选） |

### 方法

| 方法 | 说明 |
|------|------|
| start() | 将各 Channel 的 onMessage 连接到调度器 |
| stop() | 清理防抖器、释放资源 |

### 消息流

```
Channel.onMessage
  → ChannelDispatcher.handleIncoming(message)
    → MessageDebouncer.push(message)
      → [等待窗口到期]
        → 合并消息文本
        → Channel.sendTyping(contactId)
        → Brain.handleMessage(mergedMessage)
          → Channel.sendMessage(contactId, reply) × N（间隔 500ms）
```
