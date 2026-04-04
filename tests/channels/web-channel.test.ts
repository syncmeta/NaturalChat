import { describe, it, expect, afterEach } from "vitest";
import { WebChannel } from "../../src/channels/web/web-channel.js";

describe("WebChannel", () => {
  let channel: WebChannel | null = null;

  afterEach(async () => {
    if (channel) {
      await channel.stop();
      channel = null;
    }
  });

  it("starts and stops without error", async () => {
    channel = new WebChannel({ port: 18080 });
    await channel.start();
    expect(channel.activeConnections).toBe(0);
    await channel.stop();
    channel = null;
  });

  it("serves HTML on GET /", async () => {
    channel = new WebChannel({ port: 18081 });
    await channel.start();

    const response = await fetch("http://localhost:18081/");
    expect(response.status).toBe(200);
    const html = await response.text();
    expect(html).toContain("NaturalChat");
  });

  it("returns 404 for unknown paths", async () => {
    channel = new WebChannel({ port: 18082 });
    await channel.start();

    const response = await fetch("http://localhost:18082/unknown");
    expect(response.status).toBe(404);
  });

  it("accepts WebSocket connection and routes messages", async () => {
    channel = new WebChannel({ port: 18083 });
    let receivedMessage: string | null = null;

    channel.onMessage(async (msg) => {
      receivedMessage = msg.text;
    });

    await channel.start();

    // Connect WebSocket
    const ws = new WebSocket("ws://localhost:18083/ws");
    await new Promise<void>((resolve, reject) => {
      ws.onopen = () => resolve();
      ws.onerror = (e) => reject(e);
    });

    expect(channel.activeConnections).toBe(1);

    // Send message
    ws.send(JSON.stringify({ type: "message", text: "你好" }));

    // Wait for message to be processed
    await new Promise((r) => setTimeout(r, 100));

    expect(receivedMessage).toBe("你好");

    ws.close();
    await new Promise((r) => setTimeout(r, 50));
    expect(channel.activeConnections).toBe(0);
  });

  it("sends message back to correct session", async () => {
    channel = new WebChannel({ port: 18084 });
    let lastContactId: string | null = null;

    channel.onMessage(async (msg) => {
      lastContactId = msg.contactId;
    });

    await channel.start();

    const ws = new WebSocket("ws://localhost:18084/ws");
    const received: string[] = [];

    await new Promise<void>((resolve) => {
      ws.onopen = () => resolve();
    });

    ws.onmessage = (e) => {
      const data = JSON.parse(e.data);
      if (data.type === "message") received.push(data.text);
    };

    // Send to trigger onMessage which gives us contactId
    ws.send(JSON.stringify({ type: "message", text: "hello" }));
    await new Promise((r) => setTimeout(r, 100));

    // Now send reply through channel
    expect(lastContactId).not.toBeNull();
    await channel.sendMessage(lastContactId!, "reply");

    await new Promise((r) => setTimeout(r, 100));
    expect(received).toContain("reply");

    ws.close();
  });

  it("sends typing indicator", async () => {
    channel = new WebChannel({ port: 18085 });
    let lastContactId: string | null = null;

    channel.onMessage(async (msg) => {
      lastContactId = msg.contactId;
    });

    await channel.start();

    const ws = new WebSocket("ws://localhost:18085/ws");
    const receivedTypes: string[] = [];

    await new Promise<void>((resolve) => {
      ws.onopen = () => resolve();
    });

    ws.onmessage = (e) => {
      const data = JSON.parse(e.data);
      receivedTypes.push(data.type);
    };

    ws.send(JSON.stringify({ type: "message", text: "hello" }));
    await new Promise((r) => setTimeout(r, 100));

    await channel.sendTyping(lastContactId!);
    await new Promise((r) => setTimeout(r, 100));

    expect(receivedTypes).toContain("typing");

    ws.close();
  });
});
