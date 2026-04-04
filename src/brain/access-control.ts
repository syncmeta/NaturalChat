export type AccessMode = "open" | "approval" | "private";
export type AccessResult = "allowed" | "denied" | "pending";

/**
 * AccessControl — 访问控制
 *
 * 三种模式：
 * - open: 所有人可访问
 * - approval: 新用户需要审批
 * - private: 只有 owner 可访问
 */
export class AccessControl {
  private mode: AccessMode;
  private owner: string | null = null;
  private readonly approved = new Set<string>();

  constructor(mode: AccessMode = "open") {
    this.mode = mode;
  }

  /**
   * 检查联系人是否有权访问
   */
  check(contactId: string): AccessResult {
    switch (this.mode) {
      case "open":
        return "allowed";

      case "private":
        if (!this.owner) return "allowed"; // 未设置 owner 时允许
        return contactId === this.owner ? "allowed" : "denied";

      case "approval":
        if (this.owner && contactId === this.owner) return "allowed";
        return this.approved.has(contactId) ? "allowed" : "pending";
    }
  }

  /**
   * 批准联系人
   */
  approve(contactId: string): void {
    this.approved.add(contactId);
  }

  /**
   * 设置 owner
   */
  setOwner(contactId: string): void {
    this.owner = contactId;
    this.approved.add(contactId);
  }

  /**
   * 获取当前模式
   */
  getMode(): AccessMode {
    return this.mode;
  }

  /**
   * 设置模式
   */
  setMode(mode: AccessMode): void {
    this.mode = mode;
  }
}
