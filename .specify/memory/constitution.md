# NaturalChat 宪法

本文档定义不可违反的技术原则和约束。产品定义见 PRD。

## 技术原则

### I. TypeScript 严格模式
所有代码使用 TypeScript（`strict: true`）。全程 `async/await`，不用回调，不做同步阻塞。

### II. 统一模型提供商
整个项目使用一个模型提供商（一个 API base URL + 一个 API key），通过 `openai` npm 包访问 OpenAI 兼容端点。不同任务使用不同模型，全局配置默认值，Bot 可覆盖。

### III. YAML + Zod 配置
所有配置使用 YAML。每个配置文件有对应的 Zod schema，启动时校验，无效即报错——不对缺失的必填字段静默使用默认值。

### IV. Bot-as-Directory
每个 Bot 自包含在 `bots/<name>/` 下（config、secrets、prompts、skills、data）。全局共享资源放在 bot 目录之外。

### V. 组合优先
不搞类继承层级。Channel 接口是唯一的抽象。其余一律用组合和依赖注入。

### VI. Docker-Only 部署
仅支持 Docker Compose 部署。Honcho、RSSHub 等服务全部容器化。不支持裸机部署。

### VII. Prompt 外部化
所有 LLM prompt 是外部 Markdown 文件，不硬编码在源代码中。使用中文编写，不做多语言版本。

### VIII. 无全局可变状态
所有状态限定在 Bot 实例内，或通过依赖注入显式共享。文件操作只用异步 API。

## 开发流程

- 每个功能按 spec → plan → tasks → implement 推进
- 测试使用 Vitest
- 代码规范：ESLint + Prettier

## 治理

本宪法优先于所有其他开发指导。任何修订需明确记录理由。

**版本**: 1.0.0 | **批准日期**: 2026-04-01
