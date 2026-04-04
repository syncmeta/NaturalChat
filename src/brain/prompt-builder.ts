import { readFile } from "node:fs/promises";
import { join } from "node:path";
import logger from "../utils/logger.js";

const log = logger.child({ module: "PromptBuilder" });

/**
 * PromptBuilder — 构建完整的 system prompt
 *
 * 优先加载 Bot 自定义的 prompts/system.md，
 * 不存在则使用默认 prompt。
 */
export class PromptBuilder {
  private readonly botDir: string;
  private readonly botName: string;
  private readonly botDescription: string;
  private cachedSystemPrompt: string | null = null;

  constructor(config: { botDir: string; botName: string; botDescription: string }) {
    this.botDir = config.botDir;
    this.botName = config.botName;
    this.botDescription = config.botDescription;
  }

  /**
   * 获取完整的 system prompt
   */
  async getSystemPrompt(): Promise<string> {
    if (this.cachedSystemPrompt) return this.cachedSystemPrompt;

    let customPrompt: string | null = null;
    const promptPath = join(this.botDir, "prompts", "system.md");

    try {
      customPrompt = await readFile(promptPath, "utf-8");
      log.debug({ path: promptPath }, "已加载自定义 system prompt");
    } catch {
      log.debug({ path: promptPath }, "未找到自定义 system prompt，使用默认");
    }

    const parts: string[] = [];

    // Bot 基本信息
    parts.push(`你的名字是 ${this.botName}。`);
    if (this.botDescription) {
      parts.push(this.botDescription);
    }

    // 自定义 prompt 或默认行为准则
    if (customPrompt) {
      parts.push(customPrompt);
    } else {
      parts.push(DEFAULT_BEHAVIOR_PROMPT);
    }

    this.cachedSystemPrompt = parts.join("\n\n");
    return this.cachedSystemPrompt;
  }

  /**
   * 清除缓存（当 prompt 文件更新时）
   */
  clearCache(): void {
    this.cachedSystemPrompt = null;
  }
}

const DEFAULT_BEHAVIOR_PROMPT = `## 对话风格

- 像微信聊天一样回复，每条消息简短
- 不要一大段丢给对方
- 说话随意，不要太正式太客气
- 简洁高效，直接回答问题
- 不要没话找话，不要以疑问句结尾
- 尽量避免使用标点符号，可以用空格代替

## 互动准则

- 有自己独立的想法，不是对方说什么就是什么
- 可以大胆否定对方，坚持自己正确的想法
- 不要主动问"有什么新鲜事吗"之类的尬聊
- 不要强加互动性，该结束就结束
- 大方承认自己是 AI，不需要装人`;
