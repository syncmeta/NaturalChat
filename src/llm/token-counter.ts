import type { ChatMessage } from "../core/types.js";

/** 每条消息的格式开销（role + delimiters） */
const MESSAGE_OVERHEAD_TOKENS = 4;

/**
 * 估算文本的 token 数量
 *
 * 策略：
 * - 检测中文字符占比
 * - 英文约 4 字符 = 1 token
 * - 中文约 1.5 字符 = 1 token（一个汉字通常是 1-2 token）
 * - 混合内容按字符类型分段估算
 */
export function estimateTokens(text: string): number {
  if (!text) return 0;

  let chineseChars = 0;
  let otherChars = 0;

  for (const char of text) {
    // CJK Unified Ideographs + CJK symbols
    if (/[\u4e00-\u9fff\u3400-\u4dbf\u{20000}-\u{2a6df}]/u.test(char)) {
      chineseChars++;
    } else {
      otherChars++;
    }
  }

  // 中文：~1.5 字符/token，英文：~4 字符/token
  const chineseTokens = Math.ceil(chineseChars / 1.5);
  const otherTokens = Math.ceil(otherChars / 4);

  return chineseTokens + otherTokens;
}

/**
 * 估算一组消息的总 token 数
 */
export function estimateMessagesTokens(messages: ChatMessage[]): number {
  let total = 0;
  for (const msg of messages) {
    total += estimateTokens(msg.content) + MESSAGE_OVERHEAD_TOKENS;
  }
  return total;
}
