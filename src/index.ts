import { resolve } from "node:path";
import { BotManager } from "./core/bot-manager.js";
import { parseGlobalConfig } from "./config/loader.js";
import logger from "./utils/logger.js";

const log = logger.child({ module: "main" });
const SHUTDOWN_TIMEOUT_MS = 10_000;

async function main() {
  log.info("NaturalChat 启动中...");

  // 加载全局配置
  const configPath = resolve(process.cwd(), "config.yaml");
  const globalConfig = await parseGlobalConfig(configPath);
  log.info("全局配置加载成功");

  // 创建 BotManager 并发现 Bot
  const manager = new BotManager();
  const botsDir = resolve(process.cwd(), "bots");
  const botDirs = await manager.discover(botsDir);

  // 加载并启动所有 Bot
  await manager.loadAll(globalConfig, botDirs);
  await manager.startAll();

  log.info("NaturalChat 已启动");

  // 优雅关闭
  let stopping = false;

  const shutdown = async (signal: string) => {
    if (stopping) return;
    stopping = true;

    log.info({ signal }, "收到关闭信号，正在优雅关闭...");

    // 设置超时强制退出
    const timer = setTimeout(() => {
      log.error("关闭超时，强制退出");
      process.exit(1);
    }, SHUTDOWN_TIMEOUT_MS);

    try {
      await manager.stopAll();
      clearTimeout(timer);
      log.info("NaturalChat 已关闭");
      process.exit(0);
    } catch (e) {
      log.error({ err: e }, "关闭过程中出错");
      clearTimeout(timer);
      process.exit(1);
    }
  };

  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}

main().catch((e) => {
  log.fatal({ err: e }, "NaturalChat 启动失败");
  process.exit(1);
});
