import type { ResolvedBotConfig } from "../config/types.js";
import type { Channel, Brain, Memory, SkillLoader } from "./interfaces/index.js";
import logger from "../utils/logger.js";

/**
 * BotInstance — 运行时 Bot 容器
 *
 * 持有配置和可选的功能模块引用。
 * 本阶段 start/stop 为空实现，后续 Spec 注入具体模块。
 */
export class BotInstance {
  readonly config: ResolvedBotConfig;
  channels: Channel[] = [];
  brain: Brain | null = null;
  memory: Memory | null = null;
  skillLoader: SkillLoader | null = null;

  private readonly log;

  constructor(config: ResolvedBotConfig) {
    this.config = config;
    this.log = logger.child({ bot: config.name });
  }

  async start(): Promise<void> {
    this.log.info("Bot 启动中...");

    // 启动所有 Channel
    for (const channel of this.channels) {
      await channel.start();
      this.log.info({ channelType: channel.type }, "Channel 已启动");
    }

    // 启动 Brain（如果已注入）
    if (this.brain) {
      await this.brain.start();
      this.log.info("Brain 已启动");
    }

    this.log.info("Bot 启动完成");
  }

  async stop(): Promise<void> {
    this.log.info("Bot 停止中...");

    // 停止 Brain
    if (this.brain) {
      await this.brain.stop();
      this.log.info("Brain 已停止");
    }

    // 停止所有 Channel
    for (const channel of this.channels) {
      await channel.stop();
      this.log.info({ channelType: channel.type }, "Channel 已停止");
    }

    this.log.info("Bot 已停止");
  }
}
