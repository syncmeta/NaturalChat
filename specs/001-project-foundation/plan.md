# Implementation Plan: 项目基础架构

**Branch**: `001-project-foundation` | **Date**: 2026-04-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-project-foundation/spec.md`

## Summary

搭建 NaturalChat 的 TypeScript 项目骨架：定义所有核心模块的接口（Channel、Brain、LLMAgent、Memory、SkillLoader）、实现配置系统（YAML + Zod 分层校验）、实现 BotManager 生命周期（发现 Bot、加载配置、启动、优雅关闭）。本阶段各模块只有接口，不含具体实现。

## Technical Context

**Language/Version**: TypeScript 5.x (strict mode)
**Runtime**: Bun (latest stable)
**Primary Dependencies**: zod (配置校验), yaml (YAML 解析), pino (日志)
**Storage**: 本地文件系统 (YAML 配置文件, JSON 运行时数据)
**Testing**: Vitest
**Target Platform**: Linux (Docker), macOS, Windows (通过 Docker)
**Project Type**: 常驻后台服务 (daemon)
**Performance Goals**: 10 个 Bot 启动 < 5 秒, 优雅关闭 < 5 秒
**Constraints**: 无全局可变状态, 异步文件操作, 组合优先无类继承
**Scale/Scope**: 单实例承载 1~50 个 Bot

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 宪法条目 | 状态 | 说明 |
|----------|------|------|
| TypeScript 严格模式 | ✅ | `tsconfig.json` 设置 `strict: true` |
| 运行时 Bun | ✅ | 使用 Bun 作为运行时和包管理器 |
| YAML + Zod 配置校验 | ✅ | 全局和 Bot 配置均用 Zod schema 校验 |
| 组合优先，不用类继承 | ✅ | Channel 等模块用 TypeScript interface，不用 abstract class |
| 无全局可变状态 | ✅ | 状态限定在 BotInstance 内 |
| 文件操作只用异步 API | ✅ | 使用 `Bun.file()` 和 `node:fs/promises` |
| Bot-as-Directory | ✅ | 每个 Bot 在 `bots/<name>/` 下自包含 |
| Prompt 外部化 | ✅ | 本阶段只定义接口，Prompt 加载由后续 Spec 实现 |
| Docker-only 部署 | N/A | 部署是后续 Spec (018) |

无违规。通过。

## Project Structure

### Documentation (this feature)

```text
specs/001-project-foundation/
├── plan.md              # This file
├── research.md          # Phase 0: 技术决策记录
├── data-model.md        # Phase 1: 实体与接口定义
└── tasks.md             # Phase 2: 任务分解 (/speckit.tasks)
```

### Source Code (repository root)

```text
src/
├── index.ts                 # 入口：启动 BotManager
├── config/
│   ├── schema.ts            # Zod schemas: GlobalConfigSchema, BotConfigSchema, BotSecretsSchema
│   ├── loader.ts            # 配置加载：读 YAML → 解析 → Zod 校验 → 合并
│   └── types.ts             # 导出类型: GlobalConfig, BotConfig, BotSecrets, ResolvedBotConfig
├── core/
│   ├── bot-manager.ts       # BotManager: 扫描 bots/, 创建实例, 启动/停止
│   ├── bot-instance.ts      # BotInstance: 持有配置和模块引用的运行时容器
│   └── interfaces/
│       ├── channel.ts       # Channel 接口
│       ├── brain.ts         # Brain 接口
│       ├── llm-agent.ts     # LLMAgent 接口
│       ├── memory.ts        # Memory 接口
│       └── skill-loader.ts  # SkillLoader 接口
├── utils/
│   ├── logger.ts            # pino logger, 敏感信息过滤
│   └── errors.ts            # 自定义错误类型
tests/
├── config/
│   ├── schema.test.ts       # Zod schema 校验测试
│   └── loader.test.ts       # 配置加载测试
├── core/
│   ├── bot-manager.test.ts  # 生命周期测试
│   └── bot-instance.test.ts # 实例创建测试
└── fixtures/
    ├── valid-config.yaml    # 合法配置样例
    ├── invalid-config.yaml  # 非法配置样例
    └── bots/
        ├── test-bot/
        │   ├── config.yaml
        │   └── secrets.yaml
        └── broken-bot/
            └── config.yaml  # 故意写错的配置

bots/
└── _template/               # 示例 Bot 模板
    ├── config.yaml
    ├── secrets.yaml
    ├── prompts/
    │   └── .gitkeep
    ├── skills/
    │   └── .gitkeep
    └── data/
        └── .gitkeep

config.yaml                  # 全局配置文件（gitignored，提供 config.example.yaml）
config.example.yaml          # 全局配置模板
docker-compose.dev.yaml      # 开发用：只启动依赖服务（Honcho 等）
package.json                 # Bun 项目配置
tsconfig.json                # TypeScript 严格模式配置
```

**Structure Decision**: 单项目结构（Single project），`src/` 下按职责分 `config/`、`core/`、`utils/`。核心模块接口集中在 `src/core/interfaces/`，后续 Spec 的实现代码放在对应的新目录中（如 `src/channels/`、`src/memory/` 等）。

## Implementation Approach

### 配置系统设计

**分层配置**：
1. **全局配置** (`config.yaml`): 模型提供商 (api_base_url, api_key)、6 种任务默认模型 (chat, critic, surf_planner, surf_evaluator, reflection, summary)
2. **Bot 配置** (`bots/<name>/config.yaml`): 名字、性格描述、模型覆盖 (可选)、启用的 Channel 列表
3. **Bot 密钥** (`bots/<name>/secrets.yaml`): Channel 凭据 (token, password 等)

**配置合并策略**: Bot 的 `models` 字段为可选的 partial 对象。加载时与全局 `models` 合并，Bot 指定的覆盖全局默认，未指定的回退。生成 `ResolvedBotConfig` 类型（所有字段都已填充）。

**校验错误格式**: 使用 Zod 的 `safeParse` + 自定义 error formatter，输出格式：
```
配置校验失败: bots/my-bot/config.yaml
  - models.chat: 期望 string, 实际 number
  - name: 必填字段缺失
```

### 日志设计

使用 pino（高性能 JSON 日志库）。配置 redact 选项过滤敏感字段路径（`*.api_key`, `*.token`, `*.password`），确保密钥不出现在日志中。

### BotManager 生命周期

1. **发现**: 读取 `bots/` 目录，过滤出子目录（忽略文件和 `_template`）
2. **加载**: 为每个目录加载并校验配置，失败则记录错误并跳过
3. **启动**: 为每个成功加载的 Bot 创建 BotInstance，调用 `start()`（本阶段空实现）
4. **关闭**: 收到 SIGTERM/SIGINT → 调用每个 BotInstance 的 `stop()`，设 10 秒超时强制退出

停止方式：
- **生产环境**: `docker compose down` 或 `docker compose stop`，Docker 向容器发 SIGTERM
- **开发环境**: 终端 Ctrl+C 发 SIGINT
- 代码层面统一监听 SIGTERM + SIGINT，处理逻辑一致

### 开发体验设计

**两种运行模式**：

1. **开发模式**（日常开发用）:
   - `docker compose -f docker-compose.dev.yaml up -d` 启动依赖服务（Honcho 等）
   - `bun --watch src/index.ts` 启动主进程，文件变更自动重启
   - 改代码即时生效，改 Prompt 文件也即时生效（`--watch` 监控整个项目目录）

2. **生产模式**（部署用）:
   - `docker compose up -d` 启动所有服务（含主进程）
   - 通过 Dockerfile 构建镜像

**package.json scripts**：
- `dev` — 启动依赖服务 + `bun --watch` 主进程
- `start` — 直接运行主进程（Docker 容器内使用）
- `test` — 运行 Vitest
- `build` — TypeScript 类型检查

### 接口设计原则

所有接口使用 TypeScript `interface`（不用 abstract class），符合宪法"组合优先"原则。每个接口只定义最小必要方法。后续 Spec 实现时，通过依赖注入将具体实现注入 BotInstance。

## Complexity Tracking

无宪法违规，不需要记录。
