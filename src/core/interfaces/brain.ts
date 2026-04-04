import type { IncomingMessage } from "../types.js";

/**
 * Brain — 消息处理编排器
 *
 * 负责接收消息后的处理管线：访问控制、命令路由、LLM 调用、工具执行等。
 * 返回回复消息数组（支持多条消息回复）。
 */
export interface Brain {
  /** 处理收到的消息，返回回复（数组 = 多条消息） */
  handleMessage(message: IncomingMessage): Promise<string[]>;

  /** 启动后台任务（反思、主动冲浪等） */
  start(): Promise<void>;

  /** 停止后台任务 */
  stop(): Promise<void>;
}
