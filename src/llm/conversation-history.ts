import type { ChatMessage } from "../core/types.js";
import { estimateTokens } from "./token-counter.js";

const MESSAGE_OVERHEAD_TOKENS = 4;

export interface ConversationHistoryOptions {
  /** 最大 token 预算（包含 system prompt） */
  maxTokens: number;
  /** 为 LLM 回复预留的 token 数 */
  reservedTokens?: number;
}

/**
 * ConversationHistory — Token 感知的对话历史管理器
 *
 * 策略：
 * - system 消息永远保留
 * - 其他消息按时间排序，从最新往前填入
 * - 如果 token 预算不够，从最旧的消息开始丢弃
 */
export class ConversationHistory {
  private readonly maxTokens: number;
  private readonly reservedTokens: number;
  private systemContent: string | null = null;
  private messages: ChatMessage[] = [];

  constructor(options: ConversationHistoryOptions) {
    this.maxTokens = options.maxTokens;
    this.reservedTokens = options.reservedTokens ?? 1000;
  }

  /**
   * 设置 system prompt（永远不被裁剪）
   */
  setSystem(content: string): void {
    this.systemContent = content;
  }

  /**
   * 添加消息
   */
  add(message: ChatMessage): void {
    this.messages.push(message);
  }

  /**
   * 获取裁剪后的消息列表
   * system 永远在最前面，其余从最新往前填
   */
  getMessages(): ChatMessage[] {
    const budget = this.maxTokens - this.reservedTokens;
    let usedTokens = 0;

    // System 消息始终保留
    const result: ChatMessage[] = [];
    if (this.systemContent) {
      const systemMsg: ChatMessage = { role: "system", content: this.systemContent };
      const systemTokens = estimateTokens(this.systemContent) + MESSAGE_OVERHEAD_TOKENS;
      usedTokens += systemTokens;
      result.push(systemMsg);
    }

    // 从最新消息往前填
    const included: ChatMessage[] = [];
    for (let i = this.messages.length - 1; i >= 0; i--) {
      const msg = this.messages[i];
      const msgTokens = estimateTokens(msg.content) + MESSAGE_OVERHEAD_TOKENS;

      if (usedTokens + msgTokens > budget) {
        break; // 预算不够了
      }

      usedTokens += msgTokens;
      included.unshift(msg);
    }

    return [...result, ...included];
  }

  /**
   * 清空所有历史（保留 system）
   */
  clear(): void {
    this.messages = [];
  }

  /** 当前消息数量（不含 system） */
  get length(): number {
    return this.messages.length;
  }
}
