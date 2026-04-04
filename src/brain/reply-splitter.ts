const MAX_CHUNK_LENGTH = 500;

/**
 * 将 LLM 回复拆分为 IM 风格的短消息
 *
 * 策略：
 * 1. 按双换行分段
 * 2. 超长段在句末断开
 * 3. 过滤空段
 */
export function splitReply(text: string): string[] {
  if (!text || !text.trim()) return [];

  // 按双换行分段
  const paragraphs = text.split(/\n{2,}/).map((p) => p.trim()).filter(Boolean);

  const result: string[] = [];

  for (const para of paragraphs) {
    if (para.length <= MAX_CHUNK_LENGTH) {
      result.push(para);
    } else {
      // 超长段：在句末标点处断开
      result.push(...splitLongParagraph(para));
    }
  }

  return result;
}

function splitLongParagraph(text: string): string[] {
  const chunks: string[] = [];
  let remaining = text;

  while (remaining.length > MAX_CHUNK_LENGTH) {
    // 在 MAX_CHUNK_LENGTH 范围内找最后一个句末标点
    const searchRange = remaining.slice(0, MAX_CHUNK_LENGTH);
    const breakIndex = findLastSentenceBreak(searchRange);

    if (breakIndex > 0) {
      chunks.push(remaining.slice(0, breakIndex + 1).trim());
      remaining = remaining.slice(breakIndex + 1).trim();
    } else {
      // 找不到句末标点，在空格处断开
      const spaceIndex = searchRange.lastIndexOf(" ");
      if (spaceIndex > 0) {
        chunks.push(remaining.slice(0, spaceIndex).trim());
        remaining = remaining.slice(spaceIndex + 1).trim();
      } else {
        // 实在找不到断点，硬切
        chunks.push(remaining.slice(0, MAX_CHUNK_LENGTH));
        remaining = remaining.slice(MAX_CHUNK_LENGTH).trim();
      }
    }
  }

  if (remaining.trim()) {
    chunks.push(remaining.trim());
  }

  return chunks;
}

function findLastSentenceBreak(text: string): number {
  // 中英文句末标点
  const breaks = ["。", "！", "？", ".", "!", "?", "；", ";"];
  let lastIndex = -1;

  for (const br of breaks) {
    const idx = text.lastIndexOf(br);
    if (idx > lastIndex) {
      lastIndex = idx;
    }
  }

  return lastIndex;
}
