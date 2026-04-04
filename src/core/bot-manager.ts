import { readdir, stat } from "node:fs/promises";
import { resolve, join } from "node:path";
import { BotInstance } from "./bot-instance.js";
import { parseBotConfig, parseBotSecrets, resolveBotConfig } from "../config/loader.js";
import type { GlobalConfig } from "../config/types.js";
import { BotLoadError } from "../utils/errors.js";
import logger from "../utils/logger.js";

const log = logger.child({ module: "BotManager" });

/**
 * BotManager — Bot 生命周期管理
 *
 * 负责发现、加载、启动和停止所有 Bot。
 */
export class BotManager {
  private instances: BotInstance[] = [];

  /**
   * 扫描 bots/ 目录，返回有效的 Bot 子目录路径
   * 跳过文件、_template、和以 . 开头的隐藏目录
   */
  async discover(botsDir: string): Promise<string[]> {
    const resolvedDir = resolve(botsDir);
    let entries: string[];

    try {
      entries = await readdir(resolvedDir);
    } catch {
      log.warn({ botsDir: resolvedDir }, "bots 目录不存在或不可读");
      return [];
    }

    const dirs: string[] = [];

    for (const entry of entries) {
      if (entry === "_template" || entry.startsWith(".")) continue;

      const fullPath = join(resolvedDir, entry);
      const s = await stat(fullPath);
      if (s.isDirectory()) {
        dirs.push(fullPath);
      }
    }

    log.info({ count: dirs.length }, "发现 Bot 目录");
    return dirs;
  }

  /**
   * 加载所有发现的 Bot，创建 BotInstance
   * 单个 Bot 加载失败不影响其他 Bot
   */
  async loadAll(globalConfig: GlobalConfig, botDirs: string[]): Promise<void> {
    for (const botDir of botDirs) {
      try {
        const configPath = join(botDir, "config.yaml");
        const secretsPath = join(botDir, "secrets.yaml");

        const botConfig = await parseBotConfig(configPath);
        const botSecrets = await parseBotSecrets(secretsPath);
        const resolved = resolveBotConfig(botConfig, botSecrets, globalConfig, botDir);

        const instance = new BotInstance(resolved);
        this.instances.push(instance);

        log.info({ bot: resolved.name, dir: botDir }, "Bot 加载成功");
      } catch (e) {
        const botName = botDir.split("/").pop() ?? botDir;
        const error =
          e instanceof Error
            ? new BotLoadError(`Bot 加载失败: ${botName}`, botName, e)
            : new BotLoadError(`Bot 加载失败: ${botName}`, botName);
        log.error({ err: error, botDir }, error.message);
      }
    }

    log.info({ loaded: this.instances.length, total: botDirs.length }, "Bot 加载完成");
  }

  /**
   * 启动所有已加载的 BotInstance
   */
  async startAll(): Promise<void> {
    for (const instance of this.instances) {
      try {
        await instance.start();
      } catch (e) {
        log.error(
          { err: e, bot: instance.config.name },
          `Bot 启动失败: ${instance.config.name}`,
        );
      }
    }
    log.info({ count: this.instances.length }, "所有 Bot 启动完成");
  }

  /**
   * 停止所有 BotInstance
   */
  async stopAll(): Promise<void> {
    log.info("正在停止所有 Bot...");

    const stopPromises = this.instances.map(async (instance) => {
      try {
        await instance.stop();
      } catch (e) {
        log.error(
          { err: e, bot: instance.config.name },
          `Bot 停止失败: ${instance.config.name}`,
        );
      }
    });

    await Promise.all(stopPromises);
    this.instances = [];
    log.info("所有 Bot 已停止");
  }

  /** 获取当前已加载的实例数量 */
  get instanceCount(): number {
    return this.instances.length;
  }

  /** 获取所有实例（只读） */
  getInstances(): readonly BotInstance[] {
    return this.instances;
  }
}
