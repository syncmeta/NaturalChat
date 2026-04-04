import type { ChatMessage, ChatResult, Tool } from "../types.js";

/**
 * LLMAgent — LLM 调用层
 *
 * 封装对 OpenAI-compatible API 的调用。
 * 支持对话历史和可选的工具调用。
 */
export interface LLMAgent {
  /** 调用 LLM 进行对话 */
  chat(messages: ChatMessage[], tools?: Tool[]): Promise<ChatResult>;
}
