# Research: 项目基础架构

## R-001: YAML 解析库选择

**Decision**: 使用 `yaml` (npm: yaml) 库

**Rationale**:
- Bun 原生支持 JSON 但不支持 YAML 解析，需要第三方库
- `yaml` (前身 `yaml@2`) 是最流行的纯 JS YAML 解析库，完整支持 YAML 1.2
- 零原生依赖，Bun 兼容性无问题
- 支持自定义 schema 和类型转换

**Alternatives considered**:
- `js-yaml`: 更老牌，但 YAML 1.2 支持不完整，维护频率下降
- 手写简单解析器: 不现实，YAML 规范复杂

## R-002: 日志库选择

**Decision**: 使用 `pino`

**Rationale**:
- 高性能 JSON 结构化日志，适合 Docker 环境（日志收集友好）
- 内置 `redact` 选项，可以按字段路径过滤敏感信息（正好满足 FR-009）
- 轻量，无复杂依赖
- Bun 兼容

**Alternatives considered**:
- `winston`: 功能更多但更重，对本项目过度
- `console.log`: 无结构化、无级别、无 redact，不适合生产
- `bunyan`: 不再活跃维护

## R-003: 配置校验错误格式

**Decision**: 自定义 Zod error formatter，输出中文友好的错误信息

**Rationale**:
- Zod 的默认错误信息是英文且结构化为 JSON，不适合直接展示给用户
- 自定义 formatter 可以输出 `字段路径: 期望类型, 实际值` 的格式
- 使用 `z.safeParse()` 避免抛异常，改为返回结果对象

**Alternatives considered**:
- 直接用 Zod 默认错误: 英文，对开发者不够友好
- 使用 `zod-validation-error`: 第三方格式化，但增加依赖且不支持中文定制

## R-004: BotInstance 模块注入方式

**Decision**: 构造函数注入 + 可选字段

**Rationale**:
- BotInstance 在骨架阶段只持有配置，各功能模块（Channel、Brain、Memory 等）由后续 Spec 注入
- 使用可选字段（`channel?: Channel[]`）允许渐进式添加模块
- 不使用依赖注入容器（如 tsyringe、inversify），避免引入不必要的复杂度
- 后续如果需要更复杂的 DI，可以在不改接口的前提下升级

**Alternatives considered**:
- DI 容器 (inversify/tsyringe): 当前模块数量不多，过度工程化
- 服务定位器模式: 隐式依赖，不利于类型安全
- 全局注册表: 违反宪法"无全局可变状态"

## R-005: Anthropic Agent Skills 规范

**Decision**: 技能系统遵循 Anthropic Agent Skills 开放规范

**Rationale**:
- 宪法明确要求遵循 Anthropic Skills 规范
- 规范格式：每个技能是一个目录，包含 `SKILL.md`（YAML frontmatter: name + description；Markdown body: 指令和示例）和可选的 `scripts/`、`references/`、`assets/` 子目录
- 渐进加载三阶段：(1) 元数据阶段只读 frontmatter (~100 词)；(2) 触发时加载完整 body；(3) 需要时读取资源文件或执行脚本
- 这是开放标准 (agentskills.io)，不锁定于 Claude，也可用于 Cursor、Gemini CLI 等
- 与现有项目的 SKILL.md + scripts/ 结构已经基本一致

**Alternatives considered**:
- 自定义格式: 不必要，现有格式已接近标准
- OpenAI function calling 原生格式: 太底层，缺乏描述性，不适合作为技能定义层

## R-006: 测试框架

**Decision**: 使用 Vitest

**Rationale**:
- 宪法明确指定使用 Vitest
- Vitest 原生支持 TypeScript，与 Bun 兼容良好
- API 兼容 Jest，学习成本低
- 内置 coverage、mocking、snapshot 等功能

**Alternatives considered**:
- Bun 内置测试: 兼容 Jest API 但功能较少，且宪法已指定 Vitest
- Jest: 需要额外配置 TypeScript 支持，Vitest 更轻量

## R-007: 进程信号处理

**Decision**: 监听 SIGTERM 和 SIGINT，使用 AbortController 协调关闭

**Rationale**:
- Docker 发送 SIGTERM 关闭容器，Ctrl+C 发送 SIGINT
- AbortController 是标准 API，可以传递给各子模块用于取消异步操作
- 设置 10 秒超时，超时后 `process.exit(1)` 强制退出

**Alternatives considered**:
- 只监听 SIGTERM: 会导致开发时 Ctrl+C 不能优雅关闭
- 不设超时: 可能导致进程挂死
