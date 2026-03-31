# 自然对话 NaturalChat 

[English](README_EN.md)

两大目标：

- 和人自然地交流、主动对话 和微信聊天一样 让它心里有你
- 破除信息茧房。自己上网冲浪 从使用者的利益出发 寻找他真正需要的东西 

它有主动性。不是你问一句它答一句。

它/它们可以由一人养育，也可以和好友一起养育。



主要不是想做助手或工具。助手类应用大把人做，我没必要重复造轮子。

也不是想做标准的 AI 陪伴，解决的需求不在于缺爱了想找个 AI 陪或者无聊了想找个人聊天。



我期望它能帮人生活得更好，方式可以是给出靠谱的建议、指出自己意识不到的问题、提供有价值的信息、提供更好的生活方式与计划……虽然这非常难实现，人都很难做到，但要想有一个这样的朋友也许比做一个这样的 AI 更难。不论如何，我先试试，弄来耍一耍。

目前这个版本还比较粗糙，我还没有完整地测试和调整过，但基本可用。文档、prompt、逻辑等等我还得改，很多AI做不好的地方我还没做。

以下由 Claude 撰写

## 它能做什么

**主动发现** — 它会基于对你的了解，在后台上网找你可能感兴趣但还没注意到的东西。配了 RSS 订阅源的话也会纳入考量。不会什么都推，只在觉得值得的时候才开口。

**破除信息茧房** — 有意识地在你的兴趣边界之外找高质量内容。RSS、网页搜索、深度阅读，手段不限，目的是帮你跳出自己的回音室。

**共同养育** — 不属于任何一个人。每个跟它聊过的人都在塑造它。它记住每个人的兴趣和说话方式，在互动中逐渐长成独特的存在。

**弱连接** — 它同时认识你的很多朋友。A 问了一个 B 可能知道的问题，它可以主动去问 B 把答案带回来。不是代替人的交流，是在人和人之间搭桥。

**自然** — 不是客服，不说"好的，我来帮您处理"。像朋友一样说话，简短直接，有自己的想法。需要搜就自己搜，需要算就自己写代码算，不假装什么都知道。

**输入感知** — 支持输入状态的平台（Matrix、XMPP）上它等你打完再回，不会在你打字到一半就急着回复。不支持的平台用小模型判断你说完了没有。

**群聊** — 拉进群里就是群里的一员。根据对话内容判断要不要说话，不是每句都要回。

## 快速开始

需要 Docker。

一键安装：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/syncmeta/NaturalChat/main/scripts/install.sh)
```

或者手动克隆：

```bash
git clone https://github.com/syncmeta/NaturalChat.git && cd NaturalChat
bash install.sh
```

安装向导会引导你选择平台、配置 LLM API、设置访问模式，自动部署所有服务。

装好后用 `nctl.sh` 管理：

```bash
./nctl.sh start     # 启动
./nctl.sh stop      # 停止
./nctl.sh restart   # 重启
./nctl.sh status    # 查看状态
./nctl.sh info      # 查看连接信息（面板地址、账号密码等）
```

卸载：

```bash
bash uninstall.sh
```

## 平台

| 平台 | 说明 |
|------|------|
| **Matrix** | 安装向导自动用 Docker 部署 Conduit 服务器，开箱即用。也可以连接已有服务器。 |
| **Telegram** | 通过 @BotFather 创建 bot，把 token 填进安装向导。第一个发 `/start` 的人自动成为 creator。 |
| **飞书** | 在飞书开放平台创建企业自建应用，配置事件订阅回调地址。 |
| **XMPP** | 需要一个 XMPP 账号（Prosody、ejabberd 或公共服务器）。 |
| **网页面板** | 自动生成，安装完成后会显示地址和登录凭据。 |

## 访问控制

| 模式 | 命令 | 行为 |
|------|------|------|
| 开放 | `/access open` | 任何人都能聊 |
| 审批 | `/access approval` | 新联系人需 admin 审批 |
| 私有 | `/access private` | 仅 creator 和 admin |

只有 creator 可以切换模式。管理员管理通过自然语言，例如"把 xxx 设为管理员"。

## 命令

聊天中：

| 命令 | 说明 |
|------|------|
| `/access [mode]` | 查看或切换访问模式 |
| `/pack [grant_id]` | 导出 bot 包 |
| `/surf` | 手动触发冲浪 |
| `/reset` | 重置对话历史 |
| `/approve <id>` | 审批请求 |
| `/deny <id>` | 拒绝请求 |

本地管理：

```bash
python manage.py add <name>
python manage.py list
python manage.py export <name>
python manage.py import <pkg> <name>
python manage.py remove <name>
```

## 技能

在 `common_skills/` 或 `bots/<name>/skills/` 下创建：

```
my_skill/
  SKILL.md           # 技能描述
  scripts/
    my_skill.py      # async def execute(**kwargs) -> str
```

文件变更自动热加载，不用重启。参考 `common_skills/web_search/` 了解完整示例。

## 目录结构

```
config/                # 全局配置
  config.yaml          # 非敏感配置（语言、RSSHub 等）
  secrets.yaml         # 敏感配置（API 密钥等）
  config.template.yaml # 配置模板
  secrets.template.yaml# 密钥模板

bots/<name>/
  config.yaml      # 配置
  secrets.yaml     # 密钥
  prompts/         # prompt
  skills/          # 自定义技能
  bot_data/        # 运行时数据

common_skills/     # 共享内置技能
prompts/
  default/         # 默认 prompt 模板
  zh/              # 中文 prompt
  en/              # 英文 prompt
docker/            # Dockerfile、docker-compose、Conduit 配置
scripts/           # install.sh、nctl.sh、uninstall.sh
```

## 架构

```
用户 → Transport (Matrix / Telegram / 飞书 / XMPP / Web)
         ↓
       BotInstance (多平台调度)
         ↓
       BotBrain (编排：反思、批评、冲浪、RSS、治理)
         ↓
       LLMAgent (LLM 调用 + 技能执行)
         ↓
       MemoryManager (Memobase 长期记忆 + 本地文件)
```

Transport 层统一处理防抖、输入状态感知和命令路由。代码执行技能按优先级自动选择沙箱（Docker → bubblewrap → sandbox-exec → WSL2 → 无沙箱）。

## License

MIT
