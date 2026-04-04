import type { UserContext } from "../types.js";

/**
 * Memory — 记忆系统接口
 *
 * 管理用户上下文和画像。
 * 具体实现（Honcho / 本地文件）由后续 Spec 提供。
 */
export interface Memory {
  /** 获取用户上下文 */
  getContext(contactId: string): Promise<UserContext>;

  /** 更新用户上下文 */
  updateContext(contactId: string, data: Partial<UserContext>): Promise<void>;
}
