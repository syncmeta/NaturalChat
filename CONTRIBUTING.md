# 贡献指南

## 添加新的传输平台

1. 在 `src/transport/` 下创建新文件，继承 `TransportClient`
2. 实现 `platform`、`start()`、`stop()`、`send_message_to()`、`send_composing()`、`send_active()` 和 `wire_brain()`
3. 在 `src/bot_manager.py` 的 `_build_transports()` 中注册
4. 在 `install.py` 中添加对应的安装选项

参考 `src/transport/telegram.py` 作为最简实现。

## 添加新的技能 (Skill)

1. 在 `common_skills/` 下创建目录，包含 `SKILL.md` 和 `scripts/` 目录
2. `SKILL.md` 使用 YAML frontmatter 定义技能名称、描述和参数
3. `scripts/` 下的 Python 文件实现 `async def execute(**kwargs) -> str`

参考 `common_skills/web_search/` 作为示例。

## 代码风格

- Python 3.10+
- 行宽 120 字符
- 使用 `async/await` 异步编程
- 日志使用 `logging` 模块
