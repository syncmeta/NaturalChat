import OpenAI from "openai";
import type { LLMAgent } from "../core/interfaces/llm-agent.js";
import type { ChatMessage, ChatResult, Tool, ToolCall } from "../core/types.js";
import logger from "../utils/logger.js";

export interface OpenAIAgentConfig {
  /** OpenAI 兼容 API 的 base URL */
  baseURL: string;
  /** API 密钥 */
  apiKey: string;
  /** 默认模型名称 */
  defaultModel: string;
  /** 请求超时（毫秒） */
  timeoutMs?: number;
  /** 注入的 OpenAI client（仅用于测试） */
  _client?: OpenAI;
}

/**
 * OpenAIAgent — LLMAgent 接口的 OpenAI SDK 实现
 *
 * 通过 openai SDK 调用 OpenAI 兼容 API。
 * 支持普通对话和 function calling。
 */
export class OpenAIAgent implements LLMAgent {
  private readonly client: OpenAI;
  private readonly defaultModel: string;
  private readonly log;

  constructor(config: OpenAIAgentConfig) {
    this.client = config._client ?? new OpenAI({
      baseURL: config.baseURL,
      apiKey: config.apiKey,
      timeout: config.timeoutMs ?? 30_000,
    });
    this.defaultModel = config.defaultModel;
    this.log = logger.child({ module: "LLMAgent", model: config.defaultModel });
  }

  /**
   * 调用 LLM 进行对话
   *
   * @param messages - 对话消息列表
   * @param tools - 可选的工具定义（function calling）
   * @param model - 可选的模型覆盖（不指定则用默认）
   */
  async chat(messages: ChatMessage[], tools?: Tool[], model?: string): Promise<ChatResult> {
    const modelName = model ?? this.defaultModel;

    try {
      const params: OpenAI.Chat.ChatCompletionCreateParams = {
        model: modelName,
        messages: messages.map((m) => this.toOpenAIMessage(m)),
      };

      if (tools && tools.length > 0) {
        params.tools = tools.map((t) => ({
          type: "function" as const,
          function: t.function,
        }));
      }

      const response = await this.client.chat.completions.create(params);
      const choice = response.choices[0];

      if (!choice) {
        return { content: "", usage: this.extractUsage(response) };
      }

      const result: ChatResult = {
        content: choice.message.content ?? "",
        usage: this.extractUsage(response),
      };

      // 解析工具调用
      if (choice.message.tool_calls && choice.message.tool_calls.length > 0) {
        result.toolCalls = choice.message.tool_calls.map(
          (tc): ToolCall => ({
            id: tc.id,
            type: "function",
            function: {
              name: tc.function.name,
              arguments: tc.function.arguments,
            },
          }),
        );
      }

      this.log.debug(
        { model: modelName, usage: result.usage },
        "LLM 调用完成",
      );

      return result;
    } catch (e) {
      const errorMsg = e instanceof Error ? e.message : String(e);
      this.log.error({ err: e, model: modelName }, "LLM 调用失败");
      throw new Error(`LLM 调用失败 (模型: ${modelName}): ${errorMsg}`);
    }
  }

  private toOpenAIMessage(
    msg: ChatMessage,
  ): OpenAI.Chat.ChatCompletionMessageParam {
    if (msg.role === "tool") {
      return {
        role: "tool",
        content: msg.content,
        tool_call_id: msg.tool_call_id ?? "",
      };
    }

    if (msg.role === "assistant" && msg.tool_calls) {
      return {
        role: "assistant",
        content: msg.content || null,
        tool_calls: msg.tool_calls.map((tc) => ({
          id: tc.id,
          type: "function" as const,
          function: {
            name: tc.function.name,
            arguments: tc.function.arguments,
          },
        })),
      };
    }

    return {
      role: msg.role as "system" | "user" | "assistant",
      content: msg.content,
    };
  }

  private extractUsage(response: OpenAI.Chat.ChatCompletion): ChatResult["usage"] {
    if (!response.usage) return undefined;
    return {
      promptTokens: response.usage.prompt_tokens,
      completionTokens: response.usage.completion_tokens,
      totalTokens: response.usage.total_tokens,
    };
  }
}
