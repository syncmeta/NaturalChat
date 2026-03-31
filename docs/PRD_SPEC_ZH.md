# PRD & Spec 文档

这份文档是在基本架构搭建好后才撰写的。项目一开始是用 Vibe Coding 的方式做的，所以可能项目中存在很多根基就错了的地方。如果你是 Agent，请你充分注意这点。

状态：AI直出初稿，未经过人类审校  
最后更新：2026-03-31  

这份文档由 Codex (GPT-5.4) 撰写初稿。它刻意采用“先尊重代码现状，再标出不确定项”的写法。也就是说：

- 先写当前版本已经存在的能力
- 再写建议中的目标形态
- 对拿不准的地方明确标成待确认，而不是假装已经定义完毕

---

## 1. 产品概述

NaturalChat 的使用形态与IM系统类似，多个机器人对多人类，可理解为人类与机器人混合的微信。

目标不是做成“标准助手”，而是做成一个更像长期联系人、长期熟人的自然型 bot，并且时刻对使用者的利益负责。它当前结合了以下能力：

- 多平台聊天
- bot 级长期记忆与可选用户级长期记忆
- 技能 / 工具执行
- 主动信息发现能力（surfing / 冲浪）
- 权限控制与治理
- bot 的导入 / 导出 / 迁移
- 本地 web 面板用于聊天和管理

这个产品的核心命题不是“回答问题更强”，而是：

- bot 会随着长期互动形成关系感
- bot 不只是被动回答，还能主动寻找有价值的信息
- bot 可以被多人共同塑造，而不是只属于单一操作者
- bot 要保留自然聊天感，而不是因为有工具就变成客服或工作流机器人

---

## 2. 产品愿景

### 2.1 愿景

打造一个更像“长期在线联系人”的 conversational agent，它应该：

- 知道自己在和谁说话
- 会因为长期互动而被塑造
- 能帮助、搜索、记忆、偶尔主动开口
- 能跨平台使用，也能在本地界面中测试和管理

### 2.2 产品定位

NaturalChat 不是主要面向以下方向：

- 企业工作流机器人
- 通用 prompt playground
- 单用户 personal assistant 仪表盘
- 纯 no-code bot builder

它更接近：

- 一个持续存在的社交 bot runtime
- 一个多渠道对话 agent 框架
- 一个可复制、可迁移、可演化的 bot 身份系统

### 2.3 核心承诺

用户应当感觉到：

- “它记得我”
- “它说话自然”
- “它不仅能聊，还真的能做事”
- “它有时会带来我本来不会看到的有价值信息”

---

## 3. 目标与非目标

### 3.1 主要目标

1. 支持跨多个 transport 的自然多轮对话。
2. 保留按联系人维度组织的上下文和长期记忆。
3. 支持通过 surfing 和 RSS 做主动信息发现。
4. 支持 creator/admin 治理，不依赖重型后端。
5. 支持 bot 作为包导出和导入。
6. 优先保障本地优先、可自托管、可开发者使用的工作流。
7. 即使没有外部平台，也支持通过 web 面板完成本地测试。

### 3.2 次要目标

1. 支持 prompt 和 skill 热重载，缩短调试闭环。
2. 支持带沙箱的工具执行。
3. 提供相对友好的安装向导。
4. 尽量保持配置是文本可读、文件可编辑的。

### 3.3 非目标

1. 当前阶段不追求全平台生产级稳定性。
2. 当前阶段不做完整 SaaS 多租户管理。
3. 当前阶段不做完整分析、计费、后台运营系统。
4. 当前阶段不强绑定某个托管基础设施。
5. 当前阶段不承诺 surfing / reflection 的高确定性质量。

---

## 4. 用户与角色

### 4.1 Creator / Operator

安装、配置、部署和治理 bot 的人。

需求：

- 易于安装
- 配置结构稳定、可理解
- 能控制 access mode 和管理员
- 能先在本地验证，再对外开放
- 能导出 / 导入 bot

### 4.2 End Contact

通过 Telegram、Matrix、Feishu、XMPP 或 web 面板与 bot 对话的人。

需求：

- 回复自然
- 能持续记住上下文
- 偶尔带来有价值的主动发现
- 使用门槛低

### 4.3 Collaborator / Co-shaper

朋友、管理员或反复与 bot 互动的人，他们会长期影响 bot 的风格和行为。

需求：

- bot 能记住互动风格、偏好和关系上下文
- 即使不是管理员，也能在长期互动中塑造 bot

### 4.4 Developer

扩展 prompt、skills、transport、打包流程或安装体验的人。

需求：

- 架构可理解
- 配置可读可改
- 本地能重现
- 隐藏状态尽量少

---

## 5. 关键使用场景

### 5.1 对话场景

- 用户通过任意平台和 bot 聊天
- bot 能判断用户是否还没打完字
- bot 能记住历史偏好和对话上下文
- bot 以自然低摩擦的方式回复

### 5.2 主动发现信息场景

- bot 根据已有关系和记忆判断什么内容可能值得看
- bot 搜索网页并可选打开页面深读
- bot 将 RSS 作为额外信息输入
- bot 判断是否值得主动分享给联系人

### 5.3 治理场景

- creator 认领 bot
- creator 切换访问模式
- creator 添加 / 移除管理员
- admin 审批联系人请求或 bot 包请求

### 5.4 可迁移场景

- creator 导出 bot 为分享包
- 另一台机器导入该包
- 保留 prompts、skills、部分人格数据和来源谱系
- secrets 被剥离，需本地重新填写

### 5.5 本地测试场景

- 操作人本地安装项目
- 不配置外部平台，只用 web 面板测试
- 在面板里聊天、改配置、重启 bot

---

## 6. 产品范围

### 6.1 范围内

- 多 bot 工作区
- 各 transport 接入层
- web 面板
- prompt bundle 体系
- skill 体系
- OpenAI-compatible LLM 接入
- 本地文件记忆 + 可选 Memobase
- surfing / RSS / Firecrawl
- 导入 / 导出 / 原地更新
- 交互式安装器

### 6.2 范围外

- 托管式身份系统
- 独立中心化用户数据库
- 完整内容审核后台
- 原生移动端 App
- 云端统一管理控制台

---

## 7. 功能需求

### 7.1 多 Bot 运行时

系统必须：

- 扫描 `bots/` 下的可运行 bot
- 遇到模板 bot 或无效 bot 时跳过，而不是让整个系统崩掉
- 每个有效 bot 创建一个 `BotInstance`
- 支持一个 bot 绑定多个 transport
- 支持按名称重启单个 bot

当前实现：

- [src/bot_manager.py](/Users/hey/Downloads/naturalchat/main/src/bot_manager.py)
- 单进程承载所有 bot

### 7.2 Bot 配置体系

每个 bot 应支持：

- `config.yaml`：非敏感配置
- `secrets.yaml`：敏感配置
- `prompts/`：prompt bundle
- `skills/`：私有技能
- `bot_data/`：运行时数据

系统必须：

- 合并 `config.yaml` + `secrets.yaml`
- 在启动前做最小配置校验

当前实现：

- [src/bot_config.py](/Users/hey/Downloads/naturalchat/main/src/bot_config.py)
- [src/config_validation.py](/Users/hey/Downloads/naturalchat/main/src/config_validation.py)

### 7.3 Transport 层

当前代码中支持的 transport：

- Telegram
- Matrix
- Feishu
- XMPP
- Web transport

共享职责：

- 接收消息
- 规范化 contact ID
- 路由 slash commands
- 路由治理相关自然语言
- 做消息防抖 / batching
- 把内容送给 `BotBrain`

平台特有职责：

- 平台连接与认证
- 发送文字、输入状态和文件（如果平台支持）

当前实现：

- [src/transport/base.py](/Users/hey/Downloads/naturalchat/main/src/transport/base.py)
- [src/transport/](/Users/hey/Downloads/naturalchat/main/src/transport)

### 7.4 Web 面板

Web 面板必须支持：

- 登录
- 列出 bot
- 基于 WebSocket 的聊天
- 查看 bot 配置
- 保存 bot 配置
- 重启 bot
- 查看某个 web session 的历史

当前实现：

- [src/web_panel/server.py](/Users/hey/Downloads/naturalchat/main/src/web_panel/server.py)
- [src/web_panel/static/index.html](/Users/hey/Downloads/naturalchat/main/src/web_panel/static/index.html)

当前限制：

- 没有配置修改审计
- 没有面板内的角色分层
- 虽然注释提到了日志能力，但目前没有真正的实时日志页

### 7.5 对话引擎

对话引擎必须：

- 按联系人维护 history
- 注入系统 prompt 和统一回复格式约束
- 可选调用 tools / skills
- 支持 streaming 和非 streaming
- 用 `|||` 分隔多条消息
- 支持 silence markers
- 在历史超预算时裁剪 / 总结

当前实现：

- [src/llm_agent.py](/Users/hey/Downloads/naturalchat/main/src/llm_agent.py)

### 7.6 自然语气与输出风格

产品要求：

- 使用用户当前语言回复
- 短、自然、像即时聊天
- 避免客服腔
- 体现关系感、舒适度和真实判断

当前实现：

- `LLMAgent` 里硬编码了一段统一回复规范
- 每个 bot 还可通过 prompt bundle 定制

### 7.7 记忆系统

记忆分两层：

1. 本地 bot_data 文件
2. 可选的 Memobase 用户记忆

本地存储包括：

- bot 自我反思
- 对朋友的印象
- 能力说明
- autonomous config
- token budgets
- governance metadata
- RSS 路由

Memobase 存储包括：

- 用户上下文
- 用户聊天写入
- flush / delete 生命周期能力

当前实现：

- [src/memory_manager.py](/Users/hey/Downloads/naturalchat/main/src/memory_manager.py)

### 7.8 权限控制与治理

支持的 access mode：

- `open`
- `approval`
- `private`

系统必须支持：

- creator claim
- creator-only 改 access mode
- admin 管理
- blacklist / approved_contacts
- pending request 审批和拒绝

当前实现：

- [src/bot_brain.py](/Users/hey/Downloads/naturalchat/main/src/bot_brain.py)
- [src/command_router.py](/Users/hey/Downloads/naturalchat/main/src/command_router.py)

### 7.9 命令系统

当前共享命令路由支持：

- `/surf`
- `/start`
- `/reset`
- `/pack`
- `/access`
- `/approve <id>`
- `/deny <id>`

要求：

- 所有可输入文本的平台都应有一致的命令行为

当前状态：

- Telegram / Matrix / XMPP / Feishu 已接通
- Web 最近已被补齐到同样逻辑

### 7.10 Surfing

Surfing 是一个手动 / 自动的信息发现循环，包含：

- 收集记忆上下文
- 可选拉取 RSS 上下文
- 用 LLM 规划搜索词
- 执行 web search
- 可选打开页面
- 逐步评估结果
- 决定是否 / 如何分享

要求：

- `/surf` 能触发一次手动 round
- 自动冲浪只有在启用时才运行
- 系统应避免过度打扰用户
- quiet hours 和 cooldown 生效

当前实现：

- [src/bot_brain.py](/Users/hey/Downloads/naturalchat/main/src/bot_brain.py)
- `common_skills/web_search`
- 可选 Firecrawl / RSSHub

当前关键事实：

- surfing 很依赖 memory context
- 上下文不足时，手动 `/surf` 也可能直接告诉你“不知道该搜什么”

### 7.11 Skills / Tools

系统必须支持：

- 共享内置技能
- bot 私有技能
- skill 热重载
- 暴露为 OpenAI tool schema 给主模型调用

当前实现：

- [src/skill_loader.py](/Users/hey/Downloads/naturalchat/main/src/skill_loader.py)
- [common_skills](/Users/hey/Downloads/naturalchat/main/common_skills)

### 7.12 Package 导出 / 导入

打包系统必须：

- 导出 prompts、skills、选定 bot_data、config、去敏后的 secrets
- 带 manifest 和 checksum
- 导入到新 bot 目录
- 支持本地覆盖 secrets
- 更新 provenance
- 支持原地更新

当前实现：

- [src/bot_packager.py](/Users/hey/Downloads/naturalchat/main/src/bot_packager.py)
- [manage.py](/Users/hey/Downloads/naturalchat/main/manage.py)
- 聊天中的 `/pack` 流程

### 7.13 安装器

当前项目有两个安装器：

- [install.sh](/Users/hey/Downloads/naturalchat/main/install.sh)
- [install.py](/Users/hey/Downloads/naturalchat/main/install.py)

当前主路径看起来应以 `install.sh` 为主。

安装器需要支持：

- 新机器初始化
- 依赖安装
- 可选的 Memobase / Firecrawl / RSSHub / Serper 配置
- 外部 transport 配置
- 生成 bot 配置
- 生成 web 面板凭据
- 结束页启动选项

近期重要变化：

- “开机 / 登录自启”和“立即运行”已拆开
- 支持安装器语言选择
- 支持本地默认值文件
- 支持 web-only bot 生成路径

当前问题：

- installer 和 runtime 曾经存在不完全一致的问题
- 仍应视为演进中，不算完全稳定

---

## 8. 非功能需求

### 8.1 本地优先可运维性

- 除了外部模型 API，不应强依赖 hosted backend
- 配置应保持人类可编辑

### 8.2 安全性

- 代码执行优先使用沙箱
- 缺少沙箱时必须清晰提示

### 8.3 性能

- 正常聊天响应应保持接近即时聊天体验
- typing / debounce 逻辑要避免明显抢答
- 单进程下 web 面板应保持可用

### 8.4 可移植性

- 首要支持 macOS 和 Linux
- Windows 目前更像部分支持，而不是成熟主路径

### 8.5 隐私与数据处理

- secrets 不应进入导出包
- 本地私有文件应尽量不进 git
- 面板需要有本地认证机制

当前弱点：

- web 面板认证仍是偏轻量的本地 bearer token 方案，不是强安全系统

---

## 9. 当前架构

### 9.1 运行时架构

```text
用户 / 管理者
  -> Transport（Telegram / Matrix / Feishu / XMPP / Web）
  -> BotInstance
  -> BotBrain
  -> LLMAgent
  -> MemoryManager
  -> Skills / 外部 API / 可选 Memobase
```

### 9.2 核心职责划分

- [main.py](/Users/hey/Downloads/naturalchat/main/main.py)
  启动 bot manager 和 web panel

- [src/bot_manager.py](/Users/hey/Downloads/naturalchat/main/src/bot_manager.py)
  发现 bot、加载配置、组装实例

- [src/bot_instance.py](/Users/hey/Downloads/naturalchat/main/src/bot_instance.py)
  把一个 brain 绑定到多个 transport

- [src/bot_brain.py](/Users/hey/Downloads/naturalchat/main/src/bot_brain.py)
  编排层：reflection、surfing、governance、memory update、critic review

- [src/llm_agent.py](/Users/hey/Downloads/naturalchat/main/src/llm_agent.py)
  模型交互、history、tools、streaming

- [src/memory_manager.py](/Users/hey/Downloads/naturalchat/main/src/memory_manager.py)
  本地 bot data + Memobase

- [src/command_router.py](/Users/hey/Downloads/naturalchat/main/src/command_router.py)
  slash commands 与治理自然语言

- [src/web_panel/server.py](/Users/hey/Downloads/naturalchat/main/src/web_panel/server.py)
  web UI 后端

### 9.3 配置层级

项目级：

- `config.yaml`
- `.env`
- `web_panel.yaml`

bot 级：

- `bots/<name>/config.yaml`
- `bots/<name>/secrets.yaml`
- `bots/<name>/prompts/`
- `bots/<name>/skills/`
- `bots/<name>/bot_data/`

### 9.4 外部依赖

- OpenAI-compatible 模型 API
- 可选 Docker
- 可选 Memobase
- 可选 RSSHub
- 可选 Firecrawl
- 可选各平台凭据

---

## 10. 数据模型与关键文件

### 10.1 Bot 运行时状态

`bot_data/` 中的重要文件包括：

- `bot_meta.json`
- `bot_self_reflection.json`
- `friends_impressions.md`
- `autonomous_config.json`
- `token_budgets.json`
- `memobase_uid_map.json`
- `rsshub_routes.json`

### 10.2 History

当前 conversation history 主要保存在 `LLMAgent._histories` 的进程内内存中。

这意味着：

- 进程重启后原始 history 不会完整保留
- 长期上下文更多依赖 summary 和可选 Memobase，而不是完整原始消息持久化

### 10.3 Contact ID

标准 contact ID 会带 platform 前缀，例如：

- `telegram:<chat_id>`
- `matrix:<room_id>`
- `web:<session_id>`

它是 transport 路由、治理和消息派发的统一键。

---

## 11. 用户流程

### 11.1 新操作者本地启动流程

1. clone repo
2. 运行 `install.sh`
3. 选择可选组件
4. 生成 bot 配置
5. 启动应用
6. 通过 web panel 或外部平台开始测试

### 11.2 首次联系人对话流程

1. 用户发消息
2. transport 标准化 contact ID
3. 先走命令路由
4. 再做 access check
5. 再走 debounce / typing wait
6. bot 回复
7. 可能触发 memory update
8. 之后可能触发 reflection / surfing

### 11.3 手动冲浪流程

1. 用户发送 `/surf`
2. command router 先确认
3. `BotBrain.do_surf_once()` 执行
4. 读入 memory context 和 RSS context
5. 规划搜索
6. 收集和评估结果
7. 以正常聊天口吻组织并发回

### 11.4 Package 分发流程

1. admin 导出 bot
2. 包中包含非敏感配置、prompts、skills、部分 personality 数据
3. 另一台机器导入时补本地 secrets
4. provenance 被更新

---

## 12. 当前产品风险

### 12.1 安装器与运行时不一致风险

历史上 installer 输出和 runtime 真实要求并不总是完全一致。

例子：

- 文案说 web panel 总是可用，但配置里未必真的写了 web transport
- Memobase 镜像和部署假设会变化

### 12.2 粗糙度 / 测试不足风险

README 自己就明确说当前版本仍然粗糙、未充分测试。

含义：

- 不应把当前行为视为完全定型的产品真相

### 12.3 Web 面板安全性风险

当前 panel auth 偏轻量。

待确认：

- 它是否只打算给 localhost / 可信环境使用？
- 还是未来要演化成更完整的权限体系？

### 12.4 记忆质量风险

当前 memory 分散在：

- 进程内 history
- 本地 summary / bot_data
- 可选 Memobase

风险：

- 用户理解中的“长期记忆”可能强于系统真实可保证的记忆质量

### 12.5 Surfing 质量风险

Surfing 是当前最有想象力、也最不稳定的能力之一。

风险包括：

- 上下文不足导致搜索低价值
- 缺少足够 guardrail 导致主动打扰
- 依赖外部搜索 / 抓取质量

### 12.6 多平台一致性风险

虽然架构意图是共享行为，但 transport 实现可能会漂移。

例子：

- web 命令路由曾经和其他 transport 脱节

---

## 13. 待确认问题 / 需要产品拍板的地方

这部分是文档里最重要的内容之一。凡是当前代码里看起来有意图、但还没有真正定义清楚的地方，都应该从这里改起。

### 13.1 Bot 身份模型

- 一个 bot 是否应该是“同时面向很多人的共享社交体”？
- 还是实际产品中更常见的是“很多彼此隔离的小 bot”？
- 跨联系人影响应该有多强，才不显得 creepy？

### 13.2 群聊策略

README_ZH 提到了群聊，但实现细节和治理策略还不清楚。

需要明确：

- 是只有 @mention 才说话，还是允许自由插话
- 群里说话阈值怎么控制
- 怎么避免刷屏 / 打断

### 13.3 Surfing 产品边界

需要明确：

- surfing 是主要手动功能，还是旗舰主动能力
- 主动分享应该多激进
- 配置和 UI 中应暴露哪些控制项

### 13.4 Web 面板定位

当前面板能做：

- 聊天
- 改配置
- 重启 bot
- 看历史

需要明确它未来是：

- 只是本地测试 / 管理工具
- 还是主要的管理 UI

### 13.5 Package 的产品哲学

需要明确 package 到底代表什么：

- 一份可迁移人格
- 一个可部署 bot 应用
- 一个可分享的文化对象
- 一个可追踪 lineage 的 fork 系统

### 13.6 记忆哲学

需要明确：

- 什么应该只保留在本地
- 什么必须进 Memobase
- 什么可以跟随 export/import
- “共同养育”到底允许保留哪些痕迹

### 13.7 安装体验的目标对象

需要明确 installer 主要面向谁：

- 本地开发者
- hobby VPS 用户
- 普通终端用户

这个问题会影响：

- 安装器文案
- 默认值
- service 安装方式
- web panel onboarding

### 13.8 部署体系定位

代码里仍有 deploy 相关遗留和文档痕迹，但产品意图并不完全清晰。

需要明确 deploy 相关内容到底是：

- 一等支持路径
- 维护者内部工具
- 准备废弃的旧路径

### 13.9 外部依赖策略

需要明确官方推荐默认值：

- LLM provider
- 搜索 provider
- 抓取 provider
- memory backend

### 13.10 Web-only Bot 支持

当前代码已经更接近支持 web-only 测试，但需要产品明确：

- web-only 是正式支持模式
- 还是只用于 dev/testing

---

## 14. 建议的产品决策（草案）

这部分不是事实，是为了方便你改而给出的建议版本。

### 14.1 将 Web 面板定位为一等本地测试入口

建议：

- 是，web-only bot 应该成为正式支持路径
- web panel 应成为首次验证最简单的入口

原因：

- 大幅降低 onboarding 成本
- 把产品验证从第三方 transport 凭据中解耦出来

### 14.2 保持外部平台可选

建议：

- 不选任何外部平台也应成功安装
- 生成配置时始终包含 `web.enabled: true`

### 14.3 保持 Memobase 可选，但文档要更清楚

建议：

- local-only memory 仍是有效基础模式
- Memobase 是提升长期用户上下文质量的增强选项

### 14.4 将 Surfing 定位为高级能力，默认保守

建议：

- 默认 `surfing.enabled: false`
- 手动 `/surf` 作为最安全测试入口
- 上下文不足时给出更直白解释

### 14.5 将 Import/Export 视为产品签名能力

建议：

- 保持 package portability 在产品里占核心位置
- 明确写清导出保留什么、剥离什么

---

## 15. 工程规格

### 15.1 Bot 生命周期

1. 发现 bot 目录
2. 读取合并配置
3. 校验配置
4. 加载 prompt bundle
5. 初始化 memory manager
6. 初始化 llm agent
7. 加载 skills
8. 构建 transports
9. 创建 `BotBrain`
10. 创建 `BotInstance`
11. 启动 bot task 和 transport task

### 15.2 配置校验规则

最小 bot 配置要求：

- `transports` 必须是非空 mapping
- 至少一个 enabled transport
- 有效的 `llm.base_url`
- 有效的 `llm.model`
- 有效的 `llm.max_history_tokens`

当前 transport-specific 规则：

- Telegram 需要 token
- Matrix 需要 homeserver + user_id + token/password
- Feishu 需要 app credentials
- XMPP 需要 jid/password
- Web 只需要 `enabled: true`

### 15.3 命令路由顺序

所有可文本输入 transport 的目标顺序应是：

1. slash command handling
2. governance natural-language handling
3. access check（普通聊天）
4. debounce 和 buffer
5. 交给 brain 处理

### 15.4 Web Panel API 面

当前接口：

- `POST /api/login`
- `GET /api/bots`
- `GET /api/bots/{name}/config`
- `PUT /api/bots/{name}/config`
- `POST /api/bots/{name}/restart`
- `GET /api/bots/{name}/history`
- `GET /ws/chat/{bot_name}`

### 15.5 打包规则

导出包含：

- prompts
- skills
- 去敏后的 secrets
- 选定的 personality / bot_data

导出不包含：

- 原始用户历史
- 真正的敏感凭据
- 任意运行时缓存

### 15.6 安装默认值机制

当前推荐机制：

- 可提交模板：`install.defaults.example`
- 本地私有值：`local/install.defaults`
- 安装器存在时自动加载

这样既支持：

- 本地快速复测
- 也支持把模板安全放进 git

---

## 16. “良好本地测试体验”的验收标准

未来要把本地测试体验做到至少满足下面这套流程：

一个新开发者 / 操作人应该能够：

1. clone repo
2. 可选复制 `install.defaults.example` 到 `local/install.defaults`
3. 运行 `bash install.sh`
4. 不选任何外部平台
5. 成功完成安装
6. 启动应用
7. 登录 web 面板
8. 和生成的 web-enabled bot 聊天
9. 执行 `/reset` 和 `/surf`
10. 如果有配置错误，能看懂错误提示

如果这条链路不通，就说明 onboarding 还不合格。

---

## 17. 建议的近端路线图

### 17.1 Phase 1：Onboarding 与本地可测性

- 彻底打通 web-only 路径
- 对齐 installer / runtime
- 改善 LLM 凭据错误提示
- 把 Memobase 配置文档补清楚

### 17.2 Phase 2：产品表面清理

- 明确 panel 定位
- 明确 package 模型
- 更明确地记录治理模型
- 消除 deploy / 安装 / 文档之间的历史歧义

### 17.3 Phase 3：主动能力质量提升

- 提升 surfing 质量和控制力
- 提升 reflection 的实际价值
- 提升 memory update 的稳定性

### 17.4 Phase 4：稳定性与分发

- 让 restart / reload 更可预测
- 增加 transport 一致性测试
- 让安装 / 部署路径更清晰

---

## 18. 维护者修改说明

建议修改优先级：

1. 产品概述、目标、使用场景
2. 待确认问题 / 建议产品决策
3. 验收标准
4. 工程规格细节

如果文档内容和代码不一致，优先明确区分：

- 当前实现
- 目标行为
- 待确认项

不要把这三者混在一起写。
