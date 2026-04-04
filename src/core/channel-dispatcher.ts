import type { Channel } from "./interfaces/channel.js";
import type { Brain } from "./interfaces/brain.js";
import type { IncomingMessage } from "./types.js";
import { MessageDebouncer } from "./message-debouncer.js";
import logger from "../utils/logger.js";

const REPLY_INTERVAL_MS = 500;

export interface DispatcherOptions {
  debounceMs?: number;
  maxWaitMs?: number;
}

/**
 * ChannelDispatcher — 连接 Channel 和 Brain 的调度器
 *
 * 消息流：
 * Channel.onMessage → 防抖 → 合并 → Brain.handleMessage → 按序回复
 */
export class ChannelDispatcher {
  private readonly channels: Channel[];
  private readonly brain: Brain;
  private readonly debouncer: MessageDebouncer;
  private readonly log;

  /** 记录每条消息来自哪个 Channel，用于回复路由 */
  private readonly channelMap = new Map<string, Channel>();

  /** Per-contact 处理锁，确保同一联系人的消息串行处理 */
  private readonly processing = new Map<string, Promise<void>>();

  constructor(channels: Channel[], brain: Brain, options: DispatcherOptions = {}) {
    this.channels = channels;
    this.brain = brain;
    this.log = logger.child({ module: "ChannelDispatcher" });

    this.debouncer = new MessageDebouncer({
      debounceMs: options.debounceMs,
      maxWaitMs: options.maxWaitMs,
    });

    this.debouncer.onBatch((messages) => this.processBatch(messages));
  }

  /**
   * 启动调度器：将各 Channel 的 onMessage 连接到本调度器
   */
  start(): void {
    for (const channel of this.channels) {
      channel.onMessage(async (message) => this.handleIncoming(message, channel));
    }
    this.log.info({ channelCount: this.channels.length }, "调度器已启动");
  }

  /**
   * 停止调度器：清理防抖器和状态
   */
  stop(): void {
    this.debouncer.dispose();
    this.channelMap.clear();
    this.processing.clear();
    this.log.info("调度器已停止");
  }

  /**
   * 处理来自 Channel 的消息
   */
  private handleIncoming(message: IncomingMessage, channel: Channel): void {
    // 记录消息来源 Channel（用于回复路由）
    this.channelMap.set(message.contactId, channel);
    this.debouncer.push(message);
  }

  /**
   * 处理一批防抖聚合后的消息
   */
  private async processBatch(messages: IncomingMessage[]): Promise<void> {
    if (messages.length === 0) return;

    const contactId = messages[0].contactId;
    const channel = this.channelMap.get(contactId);

    if (!channel) {
      this.log.error({ contactId }, "找不到消息来源 Channel");
      return;
    }

    // Per-contact 串行处理：等待上一次处理完成
    const previousProcessing = this.processing.get(contactId) ?? Promise.resolve();

    const currentProcessing = previousProcessing.then(async () => {
      try {
        await this.handleBatch(messages, channel, contactId);
      } catch (e) {
        this.log.error({ err: e, contactId }, "批次处理失败");
      }
    });

    this.processing.set(contactId, currentProcessing);
  }

  private async handleBatch(
    messages: IncomingMessage[],
    channel: Channel,
    contactId: string,
  ): Promise<void> {
    // 合并消息文本
    const mergedText = messages.map((m) => m.text).join("\n");
    const mergedMessage: IncomingMessage = {
      ...messages[0],
      text: mergedText,
      files: messages.flatMap((m) => m.files ?? []),
    };

    this.log.debug(
      { contactId, messageCount: messages.length },
      "处理消息批次",
    );

    // 发送 typing 状态
    try {
      await channel.sendTyping(contactId);
    } catch (e) {
      this.log.warn({ err: e, contactId }, "发送 typing 状态失败");
    }

    // 调用 Brain
    let replies: string[];
    try {
      replies = await this.brain.handleMessage(mergedMessage);
    } catch (e) {
      this.log.error({ err: e, contactId }, "Brain 处理消息失败");
      return;
    }

    // 按顺序发送回复
    for (let i = 0; i < replies.length; i++) {
      const reply = replies[i];
      if (!reply) continue;

      try {
        await channel.sendMessage(contactId, reply);
      } catch (e) {
        this.log.error({ err: e, contactId, replyIndex: i }, "发送回复失败");
      }

      // 多条回复之间间隔
      if (i < replies.length - 1) {
        await sleep(REPLY_INTERVAL_MS);
      }
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
