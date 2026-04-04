import type { Brain } from "../core/interfaces/brain.js";
import type { LLMAgent } from "../core/interfaces/llm-agent.js";
import type { Memory } from "../core/interfaces/memory.js";
import type { IncomingMessage, ChatMessage } from "../core/types.js";
import { ConversationHistory } from "../llm/conversation-history.js";
import { AccessControl, type AccessMode, type AccessResult } from "./access-control.js";
import { PromptBuilder } from "./prompt-builder.js";
import { splitReply } from "./reply-splitter.js";
import logger from "../utils/logger.js";

export interface SimpleBrainConfig {
  botDir: string;
  botName: string;
  botDescription: string;
  accessMode?: AccessMode;
  maxHistoryTokens?: number;
  ownerId?: string;
  memory?: Memory;
}

/**
 * SimpleBrain — Brain 接口的基础实现
 *
 * 消息处理管线：
 * 访问控制检查 → 获取/创建历史 → 构建 prompt → 调用 LLM → 拆分回复
 */
export class SimpleBrain implements Brain {
  private readonly llmAgent: LLMAgent;
  private readonly memory: Memory | null;
  private readonly accessControl: AccessControl;
  private readonly promptBuilder: PromptBuilder;
  private readonly maxHistoryTokens: number;
  private readonly log;

  /** 按联系人隔离的对话历史 */
  private readonly histories = new Map<string, ConversationHistory>();

  constructor(llmAgent: LLMAgent, config: SimpleBrainConfig) {
    this.llmAgent = llmAgent;
    this.memory = config.memory ?? null;
    this.maxHistoryTokens = config.maxHistoryTokens ?? 4000;
    this.log = logger.child({ module: "Brain", bot: config.botName });

    this.accessControl = new AccessControl(config.accessMode ?? "open");
    if (config.ownerId) {
      this.accessControl.setOwner(config.ownerId);
    }

    this.promptBuilder = new PromptBuilder({
      botDir: config.botDir,
      botName: config.botName,
      botDescription: config.botDescription,
    });
  }

  async handleMessage(message: IncomingMessage): Promise<string[]> {
    const { contactId, text } = message;

    // 1. 访问控制
    const access = this.accessControl.check(contactId);
    if (access !== "allowed") {
      return [this.getAccessDeniedMessage(access)];
    }

    // 2. 空消息检查
    if (!text.trim()) {
      return [];
    }

    // 3. 获取或创建对话历史
    const history = this.getOrCreateHistory(contactId);

    // 4. 构建 system prompt（含记忆上下文）
    let systemPrompt = await this.promptBuilder.getSystemPrompt();

    if (this.memory) {
      try {
        const userCtx = await this.memory.getContext(contactId);
        if (userCtx.summary) {
          systemPrompt += `\n\n## 关于这个用户的记忆\n${userCtx.summary}`;
        }
        if (userCtx.profile && Object.keys(userCtx.profile).length > 0) {
          const profileStr = Object.entries(userCtx.profile)
            .map(([k, v]) => `- ${k}: ${v}`)
            .join("\n");
          systemPrompt += `\n\n## 用户画像\n${profileStr}`;
        }
      } catch (e) {
        this.log.warn({ err: e, contactId }, "读取记忆失败，继续处理");
      }
    }

    history.setSystem(systemPrompt);

    // 5. 添加用户消息
    history.add({ role: "user", content: text });

    // 6. 调用 LLM
    let replyText: string;
    try {
      const messages = history.getMessages();
      const result = await this.llmAgent.chat(messages);
      replyText = result.content;

      this.log.debug(
        { contactId, usage: result.usage },
        "LLM 调用完成",
      );
    } catch (e) {
      this.log.error({ err: e, contactId }, "LLM 调用失败");
      // 回滚最后一条用户消息（因为没有成功处理）
      return ["抱歉 出了点问题 稍后再试试"];
    }

    // 7. 将 AI 回复写入历史
    if (replyText) {
      history.add({ role: "assistant", content: replyText });
    }

    // 8. 更新记忆
    if (this.memory) {
      try {
        await this.memory.updateContext(contactId, {
          lastInteraction: new Date(),
        });
      } catch (e) {
        this.log.warn({ err: e, contactId }, "更新记忆失败");
      }
    }

    // 9. 拆分回复
    const replies = splitReply(replyText);
    return replies.length > 0 ? replies : [""];
  }

  async start(): Promise<void> {
    this.log.info("Brain 启动");
  }

  async stop(): Promise<void> {
    this.histories.clear();
    this.log.info("Brain 停止");
  }

  private getOrCreateHistory(contactId: string): ConversationHistory {
    let history = this.histories.get(contactId);
    if (!history) {
      history = new ConversationHistory({ maxTokens: this.maxHistoryTokens });
      this.histories.set(contactId, history);
    }
    return history;
  }

  private getAccessDeniedMessage(result: AccessResult): string {
    switch (result) {
      case "denied":
        return "抱歉 我目前只和特定的人聊天";
      case "pending":
        return "你好 我需要确认一下才能和你聊天 请稍等";
      default:
        return "";
    }
  }

  /** 获取访问控制实例（用于外部管理） */
  getAccessControl(): AccessControl {
    return this.accessControl;
  }
}
