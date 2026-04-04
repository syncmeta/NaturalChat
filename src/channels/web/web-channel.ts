import type { ServerWebSocket } from "bun";
import type { Channel, MessageHandler } from "../../core/interfaces/channel.js";
import type { IncomingMessage, FilePayload } from "../../core/types.js";
import { makeContactId } from "../../core/contact-id.js";
import { PANEL_HTML } from "./panel-html.js";
import logger from "../../utils/logger.js";

export interface WebChannelConfig {
  port?: number;
  hostname?: string;
}

interface WsData {
  contactId: string;
  sessionId: string;
}

/**
 * WebChannel — Web Panel 的 WebSocket Channel 实现
 *
 * 使用 Bun 内置 HTTP/WebSocket 服务器。
 * 每个 WebSocket 连接视为独立 session。
 */
export class WebChannel implements Channel {
  readonly type = "web";

  private readonly port: number;
  private readonly hostname: string;
  private server: ReturnType<typeof Bun.serve> | null = null;
  private messageHandler: MessageHandler | null = null;
  private readonly sessions = new Map<string, ServerWebSocket<WsData>>();
  private readonly log;
  private sessionCounter = 0;

  constructor(config: WebChannelConfig = {}) {
    this.port = config.port ?? 3000;
    this.hostname = config.hostname ?? "0.0.0.0";
    this.log = logger.child({ module: "WebChannel" });
  }

  async start(): Promise<void> {
    const self = this;

    this.server = Bun.serve<WsData>({
      port: this.port,
      hostname: this.hostname,

      fetch(req, server) {
        const url = new URL(req.url);

        // WebSocket upgrade
        if (url.pathname === "/ws") {
          const sessionId = `session-${++self.sessionCounter}-${Date.now()}`;
          const contactId = makeContactId("web", sessionId);

          const upgraded = server.upgrade(req, {
            data: { contactId, sessionId },
          });

          if (!upgraded) {
            return new Response("WebSocket upgrade failed", { status: 400 });
          }
          return undefined;
        }

        // Serve panel HTML
        if (url.pathname === "/" || url.pathname === "/index.html") {
          return new Response(PANEL_HTML, {
            headers: { "Content-Type": "text/html; charset=utf-8" },
          });
        }

        return new Response("Not Found", { status: 404 });
      },

      websocket: {
        open(ws) {
          self.sessions.set(ws.data.contactId, ws);
          self.log.info({ contactId: ws.data.contactId }, "WebSocket 已连接");
        },

        message(ws, message) {
          try {
            const data = JSON.parse(String(message));
            if (data.type === "message" && data.text) {
              const incoming: IncomingMessage = {
                id: `web-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
                contactId: ws.data.contactId,
                text: data.text,
                timestamp: new Date(),
                channelType: "web",
              };

              if (self.messageHandler) {
                void self.messageHandler(incoming);
              }
            }
          } catch (e) {
            self.log.warn({ err: e }, "无法解析 WebSocket 消息");
          }
        },

        close(ws) {
          self.sessions.delete(ws.data.contactId);
          self.log.info({ contactId: ws.data.contactId }, "WebSocket 已断开");
        },
      },
    });

    this.log.info({ port: this.port }, "Web Panel 已启动");
  }

  async stop(): Promise<void> {
    // Close all WebSocket connections
    for (const [, ws] of this.sessions) {
      ws.close(1001, "Server shutting down");
    }
    this.sessions.clear();

    if (this.server) {
      this.server.stop();
      this.server = null;
    }

    this.log.info("Web Panel 已停止");
  }

  async sendMessage(contactId: string, text: string): Promise<void> {
    const ws = this.sessions.get(contactId);
    if (!ws) {
      this.log.warn({ contactId }, "发送消息失败：session 不存在");
      return;
    }
    ws.send(JSON.stringify({ type: "message", text }));
  }

  async sendFile(_contactId: string, _file: FilePayload): Promise<void> {
    // Web Panel 暂不支持文件发送
    this.log.warn("Web Panel 暂不支持文件发送");
  }

  async sendTyping(contactId: string): Promise<void> {
    const ws = this.sessions.get(contactId);
    if (!ws) return;
    ws.send(JSON.stringify({ type: "typing" }));
  }

  onMessage(handler: MessageHandler): void {
    this.messageHandler = handler;
  }

  /** 获取当前活跃连接数 */
  get activeConnections(): number {
    return this.sessions.size;
  }
}
