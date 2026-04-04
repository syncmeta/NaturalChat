import { readdir, readFile } from "node:fs/promises";
import { join, basename } from "node:path";
import logger from "../utils/logger.js";

const log = logger.child({ module: "PromptRegistry" });

export interface PromptVariables {
  botName: string;
  botDescription: string;
  [key: string]: string;
}

/**
 * PromptRegistry — Prompt 文件加载与管理
 *
 * 扫描 Bot 的 prompts/ 目录，将 .md 文件加载为可按名称获取的 prompt。
 * 支持 {{变量}} 模板语法。
 */
export class PromptRegistry {
  private readonly promptsDir: string;
  private readonly cache = new Map<string, string>();
  private loaded = false;

  constructor(botDir: string) {
    this.promptsDir = join(botDir, "prompts");
  }

  /**
   * 扫描并加载所有 prompt 文件
   */
  async load(): Promise<void> {
    this.cache.clear();

    try {
      const entries = await readdir(this.promptsDir);

      for (const entry of entries) {
        if (!entry.endsWith(".md")) continue;

        const name = basename(entry, ".md");
        const filePath = join(this.promptsDir, entry);

        try {
          const content = await readFile(filePath, "utf-8");
          this.cache.set(name, content.trim());
          log.debug({ name, path: filePath }, "已加载 prompt");
        } catch (e) {
          log.warn({ err: e, name, path: filePath }, "加载 prompt 文件失败");
        }
      }

      log.info({ count: this.cache.size, dir: this.promptsDir }, "Prompt 加载完成");
    } catch {
      log.debug({ dir: this.promptsDir }, "prompts 目录不存在，使用默认 prompt");
    }

    this.loaded = true;
  }

  /**
   * 获取 prompt（带变量替换）
   * @returns prompt 内容，找不到返回 null
   */
  get(name: string, variables?: PromptVariables): string | null {
    const raw = this.cache.get(name);
    if (!raw) return null;

    if (!variables) return raw;
    return this.substitute(raw, variables);
  }

  /**
   * 获取所有已加载的 prompt 名称
   */
  names(): string[] {
    return Array.from(this.cache.keys());
  }

  /**
   * 是否已加载
   */
  get isLoaded(): boolean {
    return this.loaded;
  }

  /**
   * 清除缓存（支持热更新）
   */
  clearCache(): void {
    this.cache.clear();
    this.loaded = false;
  }

  /**
   * 重新加载
   */
  async reload(): Promise<void> {
    await this.load();
  }

  /**
   * 模板变量替换：{{变量名}} → 值
   * 内置变量：{{date}} → 当前日期
   */
  private substitute(template: string, variables: PromptVariables): string {
    return template.replace(/\{\{(\w+)\}\}/g, (match, key: string) => {
      if (key === "date") {
        return new Date().toISOString().split("T")[0];
      }
      return key in variables ? variables[key] : match;
    });
  }
}

/**
 * 默认行为 prompt（当无自定义 prompt 时使用）
 */
export const DEFAULT_BEHAVIOR_PROMPT = `## 对话风格

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
