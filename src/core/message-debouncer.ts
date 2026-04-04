import type { IncomingMessage } from "./types.js";

export interface DebouncerOptions {
  /** 滑动窗口等待时间（毫秒） */
  debounceMs?: number;
  /** 最大等待时间上限（毫秒） */
  maxWaitMs?: number;
}

type BatchCallback = (messages: IncomingMessage[]) => Promise<void>;

interface PendingBatch {
  messages: IncomingMessage[];
  timer: ReturnType<typeof setTimeout>;
  firstMessageTime: number;
}

/**
 * MessageDebouncer — 按联系人隔离的消息防抖器
 *
 * 工作原理：
 * 1. push() 将消息加入对应联系人的待处理批次
 * 2. 每次 push 重置滑动窗口计时器
 * 3. 如果总等待超过 maxWaitMs，立即触发
 * 4. 计时器到期后调用 onBatch 回调
 */
export class MessageDebouncer {
  private readonly debounceMs: number;
  private readonly maxWaitMs: number;
  private readonly pending = new Map<string, PendingBatch>();
  private batchCallback: BatchCallback | null = null;

  constructor(options: DebouncerOptions = {}) {
    this.debounceMs = options.debounceMs ?? 2000;
    this.maxWaitMs = options.maxWaitMs ?? 10000;
  }

  /**
   * 注册批次处理回调
   */
  onBatch(callback: BatchCallback): void {
    this.batchCallback = callback;
  }

  /**
   * 加入消息，重置该联系人的等待计时器
   */
  push(message: IncomingMessage): void {
    const { contactId } = message;
    const existing = this.pending.get(contactId);

    if (existing) {
      // 已有待处理批次：加入消息，重置计时器
      clearTimeout(existing.timer);
      existing.messages.push(message);

      // 检查是否已达最大等待时间
      const elapsed = Date.now() - existing.firstMessageTime;
      if (elapsed >= this.maxWaitMs) {
        this.flush(contactId);
        return;
      }

      // 计算剩余可等待时间，取较小值
      const remaining = this.maxWaitMs - elapsed;
      const wait = Math.min(this.debounceMs, remaining);

      existing.timer = setTimeout(() => this.flush(contactId), wait);
    } else {
      // 新批次
      const timer = setTimeout(() => this.flush(contactId), this.debounceMs);
      this.pending.set(contactId, {
        messages: [message],
        timer,
        firstMessageTime: Date.now(),
      });
    }
  }

  /**
   * 立即触发某联系人的批次
   */
  private flush(contactId: string): void {
    const batch = this.pending.get(contactId);
    if (!batch) return;

    clearTimeout(batch.timer);
    this.pending.delete(contactId);

    if (this.batchCallback && batch.messages.length > 0) {
      // Fire and forget — 错误由调用方的回调处理
      void this.batchCallback(batch.messages);
    }
  }

  /**
   * 清除某联系人的待处理消息
   */
  clear(contactId: string): void {
    const batch = this.pending.get(contactId);
    if (batch) {
      clearTimeout(batch.timer);
      this.pending.delete(contactId);
    }
  }

  /**
   * 清理所有计时器，释放资源
   */
  dispose(): void {
    for (const [, batch] of this.pending) {
      clearTimeout(batch.timer);
    }
    this.pending.clear();
    this.batchCallback = null;
  }

  /** 获取某联系人的待处理消息数 */
  getPendingCount(contactId: string): number {
    return this.pending.get(contactId)?.messages.length ?? 0;
  }

  /** 是否有任何待处理消息 */
  get hasPending(): boolean {
    return this.pending.size > 0;
  }
}
