import type { ResolvedBotConfig } from "../config/types.js";
import type { Channel, Brain, Memory, SkillLoader } from "./interfaces/index.js";
import { ChannelDispatcher } from "./channel-dispatcher.js";
import logger from "../utils/logger.js";

/**
 * BotInstance — 运行时 Bot 容器
 *
 * 持有配置和可选的功能模块引用。
 * 当 Brain 和 Channel 都已注入时，自动创建 ChannelDispatcher 连接它们。
 */
export class BotInstance {
  readonly config: ResolvedBotConfig;
  channels: Channel[] = [];
  brain: Brain | null = null;
  memory: Memory | null = null;
  skillLoader: SkillLoader | null = null;

  private dispatcher: ChannelDispatcher | null = null;
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

    // 如果 Brain 和 Channel 都就绪，创建并启动调度器
    if (this.brain && this.channels.length > 0) {
      this.dispatcher = new ChannelDispatcher(this.channels, this.brain);
      this.dispatcher.start();
      this.log.info("调度器已启动");
    }

    this.log.info("Bot 启动完成");
  }

  async stop(): Promise<void> {
    this.log.info("Bot 停止中...");

    // 停止调度器（先于 Brain 和 Channel）
    if (this.dispatcher) {
      this.dispatcher.stop();
      this.dispatcher = null;
      this.log.info("调度器已停止");
    }

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
