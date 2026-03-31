# NaturalChat

两大目标：

- 和人自然地交流、主动对话 和微信聊天一样 让它心里有你
- 自己上网冲浪 从使用者的利益出发 寻找他真正需要的东西 破除信息茧房

它有主动性。不是你问一句它答一句。

它/它们可以由一人养育，也可以和好友一起养育。



主要不是想做助手或工具。助手类应用大把人做，我没必要重复造轮子。

也不是想做标准的 AI 陪伴，解决的需求不在于缺爱了想找个 AI 陪或者无聊了想找个人聊天。



我期望它能帮人生活得更好，方式可以是给出靠谱的建议、指出自己意识不到的问题、提供有价值的信息、提供更好的生活方式与计划……这非常难实现，人都很难做到，但要想有一个这样的朋友也许比做一个这样的 AI 更难。不论如何，我先试试，弄来耍一耍。

目前这个版本还比较粗糙，我还没有完整地测试和调整过，但基本可用。文档、prompt、逻辑等等我还得改，很多AI做不好的地方我还没做。

以下都是AI写的了。很多地方不对。我晚点再手动校对。

## 它能做什么

### 推送你需要的，而不是抢夺你注意力的东西

它会基于它对你的了解，去找你可能感兴趣但还没注意到的内容。如果你配了 RSS 订阅源，它也会把 RSS 作为信息来源之一纳入考量。它不会什么都往你面前推，只在真正觉得值得的时候才开口。

### 破除信息茧房

你关注的信息源决定了你能看到什么。它会有意识地在你的兴趣边界之外寻找高质量内容，不是为了挑战你，而是为了让你看到更大的世界。RSS 订阅、网页搜索、深度阅读——它有多种手段，但目的只有一个：帮你跳出你自己的回音室。

### 共同养育

它不属于任何一个人。每一个跟它聊过天的人都在塑造它——它记住每个人的兴趣、偏好、说话方式，在互动中逐渐长成一个独特的存在。它有自己的反思周期，会回顾自己的表现，思考哪里可以做得更好。Creator 和 admin 共同管理它的行为边界，但它的性格是所有人一起养出来的。

### 建立弱连接

它同时认识你的很多朋友。当 A 问了一个 B 可能知道的问题，它可以主动去问 B，然后把答案带回来。它不是在代替人和人的交流，而是在人和人之间搭一座桥——那种你不会专门去联系、但如果有人牵线就会很有价值的弱连接。

### 状态感知

它知道自己在哪个平台上（Telegram、Matrix、XMPP、飞书），知道在和谁说话，知道当前的对话上下文。它能判断你是不是还在打字没说完——在支持输入状态的平台上它等你打完再回，不支持的平台上它用一个小模型来猜你说完了没有。它不会在你输入到一半的时候就急着回复。

### 自然

不是客服，不是助手，不说"好的，我来帮您处理"。它像一个真正的朋友那样说话——简短、直接、有自己的想法。它会在有把握的时候直接给你答案，不确定的时候老实说不确定。需要搜索的时候自己去搜，需要算的时候自己写代码算，不会假装自己什么都知道。

### 群聊

把它拉进群里，它就是群里的一员。Telegram 和 Matrix 原生支持群聊，它在群里和在私聊里一样自然。它会根据对话内容判断要不要说话——不是每句都要回，不是每个话题都要插嘴。

---

## 快速开始

### 1. 克隆项目

```bash
git clone <repo-url> && cd naturalchat
```

### 2. 运行安装向导

```bash
bash install.sh
```

安装向导会引导你：
- 选择接入平台（Telegram / Matrix / 飞书 / XMPP）
- 配置 LLM API
- 设置访问模式
- 自动安装依赖

### 3. 启动

```bash
python main.py
```

或使用 Docker：

```bash
docker compose up
```

---

## 平台接入指南

### Telegram Bot（推荐）

1. 在 Telegram 中搜索 **@BotFather**
2. 发送 `/newbot`，按提示设置名称和用户名
3. 复制返回的 **Bot Token**
4. 运行 `bash install.sh`，选择 Telegram，粘贴 Token
5. 检查 `bots/<bot>/secrets.yaml`，确认 `transports.telegram.token` 和 `llm.api_key` 已填好
6. 运行 `python main.py`
7. 在 Telegram 里先给 bot 发 `/start`
8. 第一个发送 `/start` 的账号会自动成为 creator，随后就可以切换访问模式

### Matrix

**方式 A — 使用 Conduit（推荐新手）：**

安装向导会自动用 Docker 部署 Conduit 服务器：

```bash
docker compose --profile matrix up -d
```

**方式 B — 连接已有 Matrix 服务器：**

在安装向导中选择"连接已有服务器"，输入 homeserver URL 和 access_token。

### 飞书

1. 在[飞书开放平台](https://open.feishu.cn)创建企业自建应用
2. 获取 App ID 和 App Secret
3. 在"事件订阅"中配置回调地址：`http://your-server:9000/feishu/event`
4. 在安装向导中填入凭据

### XMPP

需要一个 XMPP 服务器账号（如 Prosody、ejabberd 或公共服务器）。在安装向导中选择 XMPP 并填入 JID 和密码。

---

## 访问控制

通过 `/access` 命令或安装向导设置：

| 模式 | 命令 | 行为 |
|------|------|------|
| 开放 | `/access open` | 任何人都能聊天 |
| 审批 | `/access approval` | 新联系人需 admin 审批 |
| 私有 | `/access private` | 仅 creator 和 admin 可聊天 |

只有 creator 可以切换访问模式。管理员管理也仅接受 creator 的自然语言指令，例如"把 user@example.com 设为管理员"。

---

## 目录结构

每个 bot 是 `bots/` 下的一个目录：

```text
bots/mybot/
  config.yaml    # 非敏感配置
  secrets.yaml   # token、password、api_key 等敏感配置
  prompts/       # 所有 prompt，registry.yaml 标注用途
  skills/        # 自定义技能
  bot_data/      # 运行时数据（自动生成）
```

其他重要目录：
- `common_skills/` — 所有 bot 共享的内置技能
- `prompts/default/` — 默认 prompt 模板
- `local/` — 本机私有文件，不进 git
- [docs/PROJECT_FILES.md](docs/PROJECT_FILES.md) — 完整的文件说明

---

## 命令

聊天中可用的命令：

| 命令 | 说明 |
|------|------|
| `/access [open\|approval\|private]` | 查看或切换访问模式（仅 creator） |
| `/pack [grant_id]` | 获取或申请 bot 导出包 |
| `/surf` | 手动触发上网冲浪 |
| `/reset` | 重置对话历史 |
| `/approve <id>` | 审批请求 |
| `/deny <id>` | 拒绝请求 |

CLI 管理本地工作区里的 bot 目录：

```bash
python manage.py add <name>              # 创建机器人
python manage.py list                    # 列出所有机器人
python manage.py export <name>           # 导出为分享包
python manage.py import <pkg> <name>     # 从包导入
python manage.py remove <name>           # 删除机器人
```

---

## Bot 导入导出与分发

**跨机器导入导出：**

```bash
# 导出
python manage.py export mybot

# 在另一台机器导入
python manage.py import mybot_export_*.tar.gz newbot --api-key sk-xxx --telegram-token xxx
```

**Telegram 包分发：**

- creator/admin 直接发送 `/pack`，bot 会把导出包发回来
- 普通用户发送 `/pack` 会生成审批请求
- 批准后请求者获得 24 小时一次性领取口令
- 也可以直接把 `.tar.gz` 包发给 bot，它会自动走审批流程

---

## 技能开发

在 `common_skills/` 或 `bots/<name>/skills/` 下创建：

```text
my_skill/
  SKILL.md         # 技能描述（YAML frontmatter + 渐进式提示词）
  scripts/
    my_skill.py    # 实现 async def execute(**kwargs) -> str
```

技能文件变更会自动热加载，无需重启。支持 `SKILL.md`、`scripts/*.py` 和相关目录文件更新。参考 `common_skills/web_search/` 了解完整示例。

---

## 沙箱安全

代码执行技能自动选择最佳沙箱：

| 优先级 | 沙箱 | 平台 | 隔离级别 |
|--------|------|------|---------|
| 1 | Docker | 全平台 | 完全隔离（无网络、限内存） |
| 2 | bubblewrap | Linux | 命名空间隔离 |
| 3 | sandbox-exec | macOS | 沙箱配置文件隔离 |
| 4 | WSL2 | Windows | WSL 内执行 |
| 5 | 无沙箱 | 全平台 | 仅超时保护（会警告） |

通过环境变量 `NATURALCHAT_SANDBOX=docker` 可强制指定。

---

## Docker 部署

```bash
# 纯 bot（Telegram/飞书）
docker compose up -d

# bot + Matrix (Conduit)
docker compose --profile matrix up -d

# bot + Memobase 记忆系统
docker compose --profile memobase up -d

# 全部
docker compose --profile matrix --profile memobase up -d
```

---

## 架构

```text
用户 ──→ [Telegram / Matrix / 飞书 / XMPP]
              │
         TransportClient（统一防抖 + 输入状态感知 + 命令路由）
              │
         BotInstance（多平台调度）
              │
         BotBrain（编排层：反思、批评、冲浪、RSS、治理）
              │
         LLMAgent（LLM 调用 + 技能执行 + 平台感知）
              │
         MemoryManager（Memobase 长期记忆 + 本地文件）
```
