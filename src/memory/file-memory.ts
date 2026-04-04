import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import type { Memory } from "../core/interfaces/memory.js";
import type { UserContext } from "../core/types.js";
import logger from "../utils/logger.js";

/**
 * FileMemory — 基于本地文件的 Memory 实现
 *
 * 每个 contactId 对应一个 JSON 文件，存储在 <botDir>/data/memory/ 下。
 * 使用 per-contactId 写入锁确保并发安全。
 */
export class FileMemory implements Memory {
  private readonly memoryDir: string;
  private readonly log;

  /** per-contactId 写入锁：确保同一 contactId 的写入串行执行 */
  private readonly writeLocks = new Map<string, Promise<void>>();

  constructor(botDir: string) {
    this.memoryDir = join(botDir, "data", "memory");
    this.log = logger.child({ module: "FileMemory" });
  }

  /** 初始化存储目录 */
  async init(): Promise<void> {
    await mkdir(this.memoryDir, { recursive: true });
    this.log.info({ dir: this.memoryDir }, "记忆存储目录已就绪");
  }

  async getContext(contactId: string): Promise<UserContext> {
    const filePath = this.contactIdToPath(contactId);
    try {
      const raw = await readFile(filePath, "utf-8");
      const data = JSON.parse(raw) as UserContext;
      // 恢复 Date 类型
      if (data.lastInteraction) {
        data.lastInteraction = new Date(data.lastInteraction);
      }
      return data;
    } catch (e: unknown) {
      // 文件不存在 → 返回默认空上下文
      if (isNodeError(e) && e.code === "ENOENT") {
        return { contactId };
      }
      this.log.warn({ err: e, contactId }, "读取记忆文件失败");
      return { contactId };
    }
  }

  async updateContext(contactId: string, data: Partial<UserContext>): Promise<void> {
    // 使用写入锁确保串行写入
    const previous = this.writeLocks.get(contactId) ?? Promise.resolve();
    const current = previous.then(() => this.doUpdate(contactId, data)).catch((e) => {
      this.log.error({ err: e, contactId }, "更新记忆失败");
    });
    this.writeLocks.set(contactId, current);
    await current;
  }

  private async doUpdate(contactId: string, data: Partial<UserContext>): Promise<void> {
    // 读取现有数据
    const existing = await this.getContext(contactId);

    // Merge：浅合并顶层字段，profile 做深合并
    const merged: UserContext = {
      ...existing,
      ...data,
      contactId, // 确保 contactId 不变
    };

    // profile 深合并
    if (existing.profile && data.profile) {
      merged.profile = { ...existing.profile, ...data.profile };
    }

    const filePath = this.contactIdToPath(contactId);
    await mkdir(this.memoryDir, { recursive: true });
    await writeFile(filePath, JSON.stringify(merged, null, 2), "utf-8");

    this.log.debug({ contactId }, "记忆已更新");
  }

  /**
   * contactId → 文件路径
   * 将 contactId 中的特殊字符转为安全文件名
   */
  private contactIdToPath(contactId: string): string {
    const safeName = contactId
      .replace(/:/g, "_")
      .replace(/[^a-zA-Z0-9_\-\.]/g, (ch) => encodeURIComponent(ch));
    return join(this.memoryDir, `${safeName}.json`);
  }
}

/** Node.js error 类型守卫 */
function isNodeError(e: unknown): e is NodeJS.ErrnoException {
  return e instanceof Error && "code" in e;
}
