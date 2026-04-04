import type { IncomingMessage, FilePayload } from "../types.js";

/** 消息接收回调 */
export type MessageHandler = (message: IncomingMessage) => Promise<void>;

/**
 * Channel — 消息平台适配器
 *
 * 每个 Channel 负责与一个消息平台（Telegram、Matrix、Web 等）通信。
 * 通过 onMessage 注册回调接收消息，通过 send* 方法发送消息。
 */
export interface Channel {
  /** Channel 类型标识（如 "telegram", "matrix", "web"） */
  readonly type: string;

  /** 连接到平台 */
  start(): Promise<void>;

  /** 断开连接 */
  stop(): Promise<void>;

  /** 发送文本消息 */
  sendMessage(contactId: string, text: string): Promise<void>;

  /** 发送文件 */
  sendFile(contactId: string, file: FilePayload): Promise<void>;

  /** 发送"正在输入"状态 */
  sendTyping(contactId: string): Promise<void>;

  /** 注册消息接收回调 */
  onMessage(handler: MessageHandler): void;
}
