# Data Model: 项目基础架构

## 配置实体

### GlobalConfig

全局配置，从项目根目录的 `config.yaml` 加载。

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| api_base_url | string (URL) | 是 | 模型提供商 API 地址 |
| api_key | string | 是 | 模型提供商 API 密钥 |
| models | ModelConfig | 是 | 各任务默认模型 |

### ModelConfig

6 种任务的模型配置。

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| chat | string | 是 | 对话模型 |
| critic | string | 是 | 批评审查模型 |
| surf_planner | string | 是 | 冲浪规划模型 |
| surf_evaluator | string | 是 | 冲浪评估模型 |
| reflection | string | 是 | 反思模型 |
| summary | string | 是 | 摘要模型 |

### BotConfig

Bot 级配置，从 `bots/<name>/config.yaml` 加载。

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | string | 是 | Bot 显示名 |
| description | string | 否 | Bot 性格描述 |
| models | Partial\<ModelConfig\> | 否 | 模型覆盖，未指定的回退全局 |
| channels | ChannelEntry[] | 否 | 启用的 Channel 列表 |

### ChannelEntry

Channel 声明条目。

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| type | string | 是 | Channel 类型标识 (如 "telegram", "matrix", "web") |
| enabled | boolean | 否 | 是否启用，默认 true |

### BotSecrets

Bot 密钥，从 `bots/<name>/secrets.yaml` 加载。

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| [channel_type] | Record\<string, string\> | 否 | 按 Channel 类型分组的凭据键值对 |

示例：
```yaml
telegram:
  token: "123456:ABC..."
matrix:
  user_id: "@bot:example.com"
  password: "secret"
```

### ResolvedBotConfig

合并后的完整 Bot 配置（运行时使用）。GlobalConfig 的 models 与 BotConfig 的 models 合并后，所有字段已填充。

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | string | 是 | Bot 显示名 |
| description | string | 是 | Bot 性格描述（默认空字符串） |
| models | ModelConfig | 是 | 完整的模型配置（已合并） |
| channels | ChannelEntry[] | 是 | Channel 列表（默认空数组） |
| secrets | BotSecrets | 是 | 密钥（默认空对象） |
| botDir | string | 是 | Bot 目录的绝对路径 |

## 核心接口

### Channel

消息平台适配器。

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| start() | - | Promise\<void\> | 连接到平台 |
| stop() | - | Promise\<void\> | 断开连接 |
| sendMessage(contactId, text) | string, string | Promise\<void\> | 发送文本消息 |
| sendFile(contactId, file) | string, FilePayload | Promise\<void\> | 发送文件 |
| sendTyping(contactId) | string | Promise\<void\> | 发送输入状态 |
| onMessage | callback | - | 注册消息接收回调 |

### Brain

消息处理编排器。

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| handleMessage(msg) | IncomingMessage | Promise\<string[]\> | 处理消息，返回回复（数组=多条消息） |
| start() | - | Promise\<void\> | 启动后台任务（反思、冲浪等） |
| stop() | - | Promise\<void\> | 停止后台任务 |

### LLMAgent

LLM 调用层。

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| chat(messages, tools?) | Message[], Tool[]? | Promise\<ChatResult\> | 调用 LLM，可选工具 |

### Memory

记忆系统。

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| getContext(contactId) | string | Promise\<UserContext\> | 获取用户上下文 |
| updateContext(contactId, data) | string, any | Promise\<void\> | 更新用户上下文 |

### SkillLoader

技能系统。遵循 Anthropic Agent Skills 规范：每个技能是一个目录，包含 `SKILL.md`（YAML frontmatter 定义 name/description + Markdown body 定义指令）和可选的 `scripts/` 目录。技能采用渐进加载：先读 frontmatter 元数据，触发时才加载完整内容。

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| discover(dirs) | string[] | Promise\<SkillMeta[]\> | 扫描目录，读取 SKILL.md frontmatter（name, description） |
| loadSkill(name) | string | Promise\<Skill\> | 按需加载完整技能内容（body + scripts） |
| getToolDefinitions() | - | Tool[] | 将已发现的技能转为 LLM tool format |
| execute(name, params) | string, any | Promise\<string\> | 执行技能脚本 |

## 运行时实体

### BotManager

| 方法 | 说明 |
|------|------|
| discover() | 扫描 bots/ 目录，返回 Bot 目录列表 |
| loadAll(globalConfig) | 加载所有 Bot 配置，创建 BotInstance |
| startAll() | 启动所有 BotInstance |
| stopAll() | 停止所有 BotInstance |

### BotInstance

| 属性/方法 | 类型 | 说明 |
|-----------|------|------|
| config | ResolvedBotConfig | 合并后的完整配置 |
| channels | Channel[] | 已注册的 Channel（后续注入） |
| brain | Brain \| null | Brain 模块（后续注入） |
| memory | Memory \| null | Memory 模块（后续注入） |
| skillLoader | SkillLoader \| null | 技能加载器（后续注入） |
| start() | Promise\<void\> | 启动 Bot（启动各模块） |
| stop() | Promise\<void\> | 停止 Bot（停止各模块） |
