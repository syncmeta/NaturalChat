/**
 * 共享类型定义
 */

/** 收到的消息 */
export interface IncomingMessage {
  /** 消息唯一 ID */
  id: string;
  /** 发送者的联系人 ID（格式: channel_type:platform_id） */
  contactId: string;
  /** 消息文本内容 */
  text: string;
  /** 附带的文件（可选） */
  files?: FilePayload[];
  /** 消息时间戳 */
  timestamp: Date;
  /** 来源 Channel 类型标识 */
  channelType: string;
  /** 原始平台数据（供 Channel 特定逻辑使用） */
  raw?: unknown;
}

/** 文件负载 */
export interface FilePayload {
  /** 文件名 */
  name: string;
  /** MIME 类型 */
  mimeType: string;
  /** 文件内容（Buffer 或 URL） */
  data: Buffer | string;
}

/** LLM 对话消息 */
export interface ChatMessage {
  role: "system" | "user" | "assistant" | "tool";
  content: string;
  /** tool call 相关 */
  tool_call_id?: string;
  tool_calls?: ToolCall[];
}

/** LLM 工具调用 */
export interface ToolCall {
  id: string;
  type: "function";
  function: {
    name: string;
    arguments: string;
  };
}

/** LLM 调用结果 */
export interface ChatResult {
  /** 回复文本 */
  content: string;
  /** 工具调用请求（如果有） */
  toolCalls?: ToolCall[];
  /** Token 用量 */
  usage?: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
}

/** 用户上下文（从记忆系统获取） */
export interface UserContext {
  /** 联系人 ID */
  contactId: string;
  /** 历史摘要 */
  summary?: string;
  /** 用户画像 */
  profile?: Record<string, unknown>;
  /** 最后交互时间 */
  lastInteraction?: Date;
}

/** 技能元数据（从 SKILL.md frontmatter 加载） */
export interface SkillMeta {
  /** 技能唯一名称 */
  name: string;
  /** 技能描述 */
  description: string;
  /** 技能目录路径 */
  dirPath: string;
}

/** 完整技能（按需加载） */
export interface Skill extends SkillMeta {
  /** SKILL.md body 内容（完整指令） */
  instructions: string;
  /** 可用的脚本列表 */
  scripts: string[];
}

/** LLM 工具定义（OpenAI function calling 格式） */
export interface Tool {
  type: "function";
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}
