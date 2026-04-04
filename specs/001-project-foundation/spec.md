# Feature Specification: 项目基础架构

**Feature Branch**: `001-project-foundation`
**Created**: 2026-04-01
**Status**: Draft
**Input**: "项目整体架构骨架：目录布局、核心模块定义与接口、配置系统、BotManager 生命周期"

## User Scenarios & Testing

### User Story 1 - 后续功能有清晰的骨架可以插入 (Priority: P1)

后续开发每个功能模块（Channel、对话引擎、记忆、技能等）时，开发者需要知道：代码放哪、实现什么接口、怎么注册到系统中。项目骨架应定义好所有核心模块的边界和接口，但不实现具体逻辑——具体实现由各功能自己的 Spec 负责。

新增一个功能模块时，只需要实现对应接口并在配置中声明，不需要改动核心代码。

**Why this priority**: 没有骨架，后续功能不知道代码往哪放、模块之间怎么引用。这是所有功能的前提。

**Independent Test**: 项目能编译通过，所有模块接口定义存在且互相引用无错误，具体实现可以是空的。

**Acceptance Scenarios**:

1. **Given** 骨架已搭建, **When** 编译项目, **Then** 编译成功，无错误
2. **Given** 开发者要实现某个 Channel, **When** 查看项目结构, **Then** 能清楚知道该在哪创建文件、实现什么接口、怎么注册
3. **Given** 骨架定义了 Channel 接口, **When** 新建一个 Channel 实现, **Then** 只需实现接口并在配置中声明即可接入，不改核心代码

---

### User Story 2 - 开发者通过配置文件定义系统行为 (Priority: P1)

开发者通过编写配置文件来定义：使用哪个模型提供商、各种任务分别用哪个模型、每个 Bot 的名字和性格、每个 Bot 接入哪些 Channel。系统启动时校验所有配置，配置有误时给出清晰的错误信息（哪个字段、什么问题），而不是在运行时莫名其妙地崩溃。

配置分两层：全局配置（模型提供商、各任务默认模型）和 Bot 级配置（名字、性格、模型覆盖、Channel 凭据）。Bot 可以覆盖全局的模型选择，不覆盖则用全局默认。

**Why this priority**: 配置是所有模块的输入源，定义了系统的能力边界。

**Independent Test**: 故意写错配置中的某个字段，启动系统，验证错误信息是否清楚指出了问题所在。

**Acceptance Scenarios**:

1. **Given** 全局配置定义了模型提供商和各任务默认模型, **When** 系统启动, **Then** 配置被正确解析，可供各模块使用
2. **Given** 某个 Bot 覆盖了对话模型, **When** 系统加载该 Bot, **Then** 对话用覆盖的模型，其他任务用全局默认
3. **Given** 配置缺少必填字段, **When** 系统启动, **Then** 错误信息明确指出哪个字段缺失
4. **Given** 配置包含敏感信息（API key、token）, **When** 系统运行, **Then** 敏感信息绝不出现在日志中

---

### User Story 3 - 系统发现并管理多个 Bot 的生命周期 (Priority: P1)

启动系统后，BotManager 自动扫描 Bot 目录，为每个 Bot 加载配置并创建实例。某个 Bot 配置有误不影响其他 Bot。

停止方式取决于运行环境：生产环境通过 Docker 命令停止容器（Docker 向进程发送终止信号），开发环境在终端按 Ctrl+C。无论哪种方式，系统收到终止信号后都应有序关闭所有 Bot，然后正常退出。

**Why this priority**: 生命周期管理是运行时骨架——Channel 连接、定时任务、记忆更新都需要挂在 Bot 生命周期上。

**Independent Test**: 创建两个 Bot（一个正确、一个故意写错配置），启动系统，验证正确的能启动、错误的报错但不影响前者。然后停止系统，验证优雅关闭。

**Acceptance Scenarios**:

1. **Given** Bot 目录下有两个 Bot, **When** 启动系统, **Then** 两个都被发现并加载，日志显示各自状态
2. **Given** Bot 目录为空, **When** 启动系统, **Then** 系统正常启动，提示没有发现 Bot
3. **Given** 某个 Bot 配置有误, **When** 系统启动, **Then** 该 Bot 失败并报错，其他 Bot 正常
4. **Given** 系统运行中, **When** 通过 Docker 命令或 Ctrl+C 停止, **Then** 各 Bot 有序关闭，进程正常退出
5. **Given** 关闭超过 10 秒未完成, **When** 超时, **Then** 强制终止并记录警告

---

### User Story 4 - 开发者改完代码/Prompt 能立刻看到效果 (Priority: P1)

开发者在日常开发中频繁修改代码和 Prompt 文件，改完后需要立刻看到效果，而不是每次都重新构建 Docker 镜像。开发时 Bot 主进程直接在宿主机运行，文件变更后自动重启。依赖服务（Honcho 等）在 Docker 中运行，不需要频繁改动。

**Why this priority**: 开发体验直接影响迭代效率。如果每次改一行代码要等 Docker 重新构建，开发者会崩溃。

**Independent Test**: 启动开发模式，修改一个 Prompt 文件或源代码文件，观察系统是否自动重启并加载最新内容。

**Acceptance Scenarios**:

1. **Given** 系统以开发模式运行, **When** 修改源代码文件, **Then** 进程自动重启，加载最新代码
2. **Given** 系统以开发模式运行, **When** 修改 Bot 的 Prompt 文件, **Then** 变更被加载，不需要手动重启
3. **Given** 依赖服务（Honcho 等）已通过 Docker 启动, **When** 开发者启动主进程, **Then** 主进程能连接到 Docker 中的依赖服务
4. **Given** 开发者首次搭建开发环境, **When** 按文档操作, **Then** 5 分钟内能启动开发模式并运行起来

---

### Edge Cases

- Bot 目录不存在——自动创建，提示用户
- 配置文件为空——校验报错，列出所有必填字段
- Bot 的密钥文件不存在——该 Bot 没有 Channel 凭据，正常加载但不接入 Channel
- Bot 启动时抛未预期异常——捕获记录，跳过该 Bot，继续其他
- Bot 目录下有非目录文件（如 .DS_Store）——忽略

## Requirements

### Functional Requirements

#### 项目骨架
- **FR-001**: 项目 MUST 有明确的源码目录结构，各功能模块有独立的目录
- **FR-002**: 项目 MUST 定义以下核心模块的接口（具体实现由后续 Spec 完成）：
  - **Channel**：消息平台适配器——连接、断开、发送消息、发送文件、发送输入状态
  - **Brain**：消息处理编排器——接收消息、协调各模块、返回回复
  - **LLMAgent**：LLM 调用层——对话、工具调用
  - **Memory**：记忆系统——存取用户上下文和画像
  - **SkillLoader**：技能系统——加载、发现、执行技能
- **FR-003**: 各模块之间 MUST 通过接口交互，不直接依赖具体实现

#### 配置系统
- **FR-004**: 系统 MUST 读取全局配置文件
- **FR-005**: 系统 MUST 为每个 Bot 读取独立的配置文件和密钥文件（如存在）
- **FR-006**: 系统 MUST 在启动时校验所有配置，失败时输出人类可读的错误信息（字段名、期望类型、实际值）
- **FR-007**: 全局配置 MUST 包含统一的模型提供商设置和各任务（对话、批评、冲浪规划、冲浪评估、反思、摘要）的默认模型
- **FR-008**: Bot 配置 MUST 支持覆盖任意任务的模型选择，未覆盖则回退全局默认
- **FR-009**: 系统 MUST 在日志中隐藏敏感信息

#### BotManager 生命周期
- **FR-010**: BotManager MUST 自动扫描 Bot 目录，将每个子目录识别为一个 Bot
- **FR-011**: 单个 Bot 的错误 MUST NOT 影响其他 Bot
- **FR-012**: 系统 MUST 支持优雅关闭——收到终止信号后有序停止所有 Bot
- **FR-013**: 系统 MUST 提供示例 Bot 目录模板，方便创建新 Bot

#### 开发体验
- **FR-014**: 系统 MUST 支持开发模式——主进程在宿主机直接运行，文件变更后自动重启
- **FR-015**: 依赖服务（Honcho 等）MUST 能通过独立的 Docker Compose 配置启动，与本地主进程协同工作
- **FR-016**: Prompt 文件变更 SHOULD 能被系统感知并加载，无需手动重启

### Key Entities

- **GlobalConfig**: 全局配置——模型提供商、6 种任务的默认模型、系统级设置
- **BotConfig**: Bot 级配置——名字、性格描述、模型覆盖（可选）、启用的 Channel 列表
- **BotSecrets**: Bot 密钥——各 Channel 的凭据
- **BotManager**: 管理所有 Bot 生命周期——发现、加载、创建实例、启动、停止
- **BotInstance**: 单个 Bot 的运行时容器——持有配置，提供各功能模块的挂载点（Channel、Brain、Memory、Skills 由后续 Spec 注入）

## Success Criteria

### Measurable Outcomes

- **SC-001**: 后续开发者能在 5 分钟内找到应该在哪里创建文件、实现什么接口
- **SC-002**: 骨架阶段项目能编译通过，无类型错误
- **SC-003**: 配置校验错误信息能让开发者不查文档就能修正问题
- **SC-004**: 收到终止信号后 5 秒内完成关闭（无活跃处理时）
- **SC-005**: 10 个 Bot 同时加载，启动不超过 5 秒
- **SC-006**: 开发者修改代码后 3 秒内进程自动重启完成
- **SC-007**: 首次搭建开发环境到系统跑起来不超过 5 分钟

## Assumptions

- 本阶段各模块只有接口定义，具体实现由后续 Spec 完成
- BotInstance 在本阶段是"空壳"——能加载配置、能启动/停止，但没有实际对话能力
- 安装程序是独立的 Spec，不在本 Spec 范围内
- 配置文件由开发者手动维护，Web 面板配置编辑是后续功能
