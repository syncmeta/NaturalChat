/**
 * Contact ID — 统一联系人标识
 *
 * 格式: `channelType:platformId`
 * 例如: "telegram:12345", "matrix:@user:server.com"
 */

/**
 * 生成 Contact ID
 */
export function makeContactId(channelType: string, platformId: string): string {
  if (!channelType) throw new Error("channelType 不能为空");
  if (!platformId) throw new Error("platformId 不能为空");
  if (channelType.includes(":")) throw new Error("channelType 不能包含冒号");
  return `${channelType}:${platformId}`;
}

/**
 * 解析 Contact ID，以第一个冒号为分隔
 */
export function parseContactId(contactId: string): {
  channelType: string;
  platformId: string;
} {
  const idx = contactId.indexOf(":");
  if (idx === -1) {
    throw new Error(`无效的 Contact ID 格式: ${contactId}`);
  }
  return {
    channelType: contactId.slice(0, idx),
    platformId: contactId.slice(idx + 1),
  };
}
