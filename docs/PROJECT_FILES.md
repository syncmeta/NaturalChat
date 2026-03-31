# 项目文件说明

这份文档只解释当前版本保留下来的主要文件和目录，不解释已经废弃的旧结构。

## 顶层

- `main.py`
  项目启动入口。启动所有 bot。

- `install.py`
  交互式安装向导。生成 bot 目录、`config.yaml`、`secrets.yaml`、prompt 目录。

- `manage.py`
  命令行管理工具。用于管理当前工作区里的 bot 目录：创建、列出、导入、导出、删除 bot。

- `config.yaml`
  项目级全局非敏感配置。不是某个 bot 的配置。

- `docker-compose.yml`
  本机或服务器的 Docker 编排入口。可拉起 bot、Matrix、Memobase。

- `README.md`
  对外使用文档。

## docs

- `docs/PROJECT_FILES.md`
  当前这份文件。解释项目里主要文件的用途。

## bots

- `bots/<bot>/config.yaml`
  单个 bot 的非敏感配置。

- `bots/<bot>/secrets.yaml`
  单个 bot 的敏感配置，比如 token、password、api_key。

- `bots/<bot>/prompts/`
  所有 prompt 文件。`registry.yaml` 标明每个 prompt 的用途和注入位置。

- `bots/<bot>/skills/`
  这个 bot 私有的技能。

- `bots/<bot>/inbox/`
  本地更新收件箱。你把 bot 导出包放进这里，bot 会检测并在 Telegram 里询问是否更新自己。

- `bots/<bot>/bot_data/`
  运行时数据。包括 bot meta、审计、记忆相关文件。一般不手改，除非你明确知道自己在改什么。

- `bots/example/`
  配置模板，不是实际运行 bot。

## src

- `src/bot_manager.py`
  扫描 `bots/`，加载配置，创建 bot，组装 transport、brain、llm。

- `src/bot_config.py`
  负责把 `config.yaml` 和 `secrets.yaml` 读进来，合成运行时配置。

- `src/config_validation.py`
  配置和 skill 的基础校验逻辑。

- `src/prompt_store.py`
  prompt 目录的加载和初始化逻辑。

- `src/bot_brain.py`
  核心编排层。反思、审查、冲浪、权限控制都在这里。

- `src/llm_agent.py`
  直接和模型 API 交互的层。

- `src/command_router.py`
  各平台共用的命令路由。

- `src/bot_instance.py`
  把一个 brain 和多个 transport 绑在一起。

- `src/skill_loader.py`
  读取并检查 skills。

- `src/memory_manager.py`
  本地记忆和 Memobase 的读写入口。

- `src/bot_packager.py`
  bot 导入导出和原地更新。

- `src/transport/`
  各个平台接入层。只负责平台通信，不负责业务决策。

## deploy

- `deploy/deploy.sh`
  用于把项目推到服务器并重启服务。

- `deploy/bootstrap-runtime.sh`
  服务器上准备 Python 运行时和虚拟环境。

- `deploy/setup-memobase.sh`
  根据 bot 配置生成并启动 Memobase 配置。

- `deploy/render_memobase_config.py`
  从 bot 配置生成 Memobase 用的配置文件。

- `deploy/memobase-compose.yml`
  Memobase 专用 Docker Compose。

- `deploy/naturalchat4.service`
  systemd 服务文件模板。

## local

- `local/`
  你自己机器上的私有测试和部署文件目录，不进 git。
  建议把本机测试记录、服务器参数、临时脚本都放这里。
