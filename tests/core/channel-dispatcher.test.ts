import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { ChannelDispatcher } from "../../src/core/channel-dispatcher.js";
import type { Channel, MessageHandler } from "../../src/core/interfaces/channel.js";
import type { Brain } from "../../src/core/interfaces/brain.js";
import type { IncomingMessage, FilePayload } from "../../src/core/types.js";

/** Flush microtask queue */
function flushPromises(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function makeMockChannel(type = "test"): Channel & { triggerMessage: (msg: IncomingMessage) => Promise<void> } {
  let handler: MessageHandler | null = null;

  return {
    type,
    start: vi.fn().mockResolvedValue(undefined),
    stop: vi.fn().mockResolvedValue(undefined),
    sendMessage: vi.fn().mockResolvedValue(undefined),
    sendFile: vi.fn().mockResolvedValue(undefined) as (contactId: string, file: FilePayload) => Promise<void>,
    sendTyping: vi.fn().mockResolvedValue(undefined),
    onMessage(h: MessageHandler) {
      handler = h;
    },
    async triggerMessage(msg: IncomingMessage) {
      if (handler) await handler(msg);
    },
  };
}

function makeMockBrain(replies: string[] = ["OK"]): Brain {
  return {
    handleMessage: vi.fn().mockResolvedValue(replies),
    start: vi.fn().mockResolvedValue(undefined),
    stop: vi.fn().mockResolvedValue(undefined),
  };
}

function makeMsg(contactId: string, text: string, channelType = "test"): IncomingMessage {
  return {
    id: Math.random().toString(36).slice(2),
    contactId,
    text,
    timestamp: new Date(),
    channelType,
  };
}

describe("ChannelDispatcher", () => {
  // Use real timers and short debounce for async tests
  it("routes message to brain and reply back to channel", async () => {
    const channel = makeMockChannel();
    const brain = makeMockBrain(["你好！"]);
    const dispatcher = new ChannelDispatcher([channel], brain, { debounceMs: 50 });
    dispatcher.start();

    await channel.triggerMessage(makeMsg("user:1", "hello"));

    // Wait for debounce + processing
    await new Promise((r) => setTimeout(r, 150));

    expect(brain.handleMessage).toHaveBeenCalledTimes(1);
    expect(channel.sendMessage).toHaveBeenCalledWith("user:1", "你好！");

    dispatcher.stop();
  });

  it("sends typing indicator before brain processes", async () => {
    const channel = makeMockChannel();
    const brain = makeMockBrain(["reply"]);
    const dispatcher = new ChannelDispatcher([channel], brain, { debounceMs: 50 });
    dispatcher.start();

    await channel.triggerMessage(makeMsg("user:1", "hello"));
    await new Promise((r) => setTimeout(r, 150));

    expect(channel.sendTyping).toHaveBeenCalledWith("user:1");
    const typingOrder = (channel.sendTyping as ReturnType<typeof vi.fn>).mock.invocationCallOrder[0];
    const sendOrder = (channel.sendMessage as ReturnType<typeof vi.fn>).mock.invocationCallOrder[0];
    expect(typingOrder).toBeLessThan(sendOrder);

    dispatcher.stop();
  });

  it("batches multiple messages from same contact", async () => {
    const channel = makeMockChannel();
    const brain = makeMockBrain(["reply"]);
    const dispatcher = new ChannelDispatcher([channel], brain, { debounceMs: 200 });
    dispatcher.start();

    await channel.triggerMessage(makeMsg("user:1", "line1"));
    await new Promise((r) => setTimeout(r, 30));
    await channel.triggerMessage(makeMsg("user:1", "line2"));
    await new Promise((r) => setTimeout(r, 30));
    await channel.triggerMessage(makeMsg("user:1", "line3"));

    // Wait for debounce (200ms from last message) + processing
    await new Promise((r) => setTimeout(r, 350));

    expect(brain.handleMessage).toHaveBeenCalledTimes(1);
    const call = (brain.handleMessage as ReturnType<typeof vi.fn>).mock.calls[0][0];
    expect(call.text).toBe("line1\nline2\nline3");

    dispatcher.stop();
  });

  it("routes reply to correct channel", async () => {
    const channelA = makeMockChannel("channelA");
    const channelB = makeMockChannel("channelB");
    const brain = makeMockBrain(["reply to B"]);
    const dispatcher = new ChannelDispatcher([channelA, channelB], brain, { debounceMs: 50 });
    dispatcher.start();

    await channelB.triggerMessage(makeMsg("user:B", "hi from B", "channelB"));
    await new Promise((r) => setTimeout(r, 150));

    expect(channelB.sendMessage).toHaveBeenCalledWith("user:B", "reply to B");
    expect(channelA.sendMessage).not.toHaveBeenCalled();

    dispatcher.stop();
  });

  it("sends multiple replies with delay between them", async () => {
    const channel = makeMockChannel();
    const brain = makeMockBrain(["reply1", "reply2", "reply3"]);
    const dispatcher = new ChannelDispatcher([channel], brain, { debounceMs: 50 });
    dispatcher.start();

    await channel.triggerMessage(makeMsg("user:1", "hello"));

    // Wait for debounce + processing + 2 intervals (500ms each)
    await new Promise((r) => setTimeout(r, 1300));

    expect(channel.sendMessage).toHaveBeenCalledTimes(3);
    expect(channel.sendMessage).toHaveBeenNthCalledWith(1, "user:1", "reply1");
    expect(channel.sendMessage).toHaveBeenNthCalledWith(2, "user:1", "reply2");
    expect(channel.sendMessage).toHaveBeenNthCalledWith(3, "user:1", "reply3");

    dispatcher.stop();
  });

  it("does not crash when channel send fails", async () => {
    const channel = makeMockChannel();
    (channel.sendMessage as ReturnType<typeof vi.fn>).mockRejectedValueOnce(new Error("network error"));
    const brain = makeMockBrain(["reply"]);
    const dispatcher = new ChannelDispatcher([channel], brain, { debounceMs: 50 });
    dispatcher.start();

    await channel.triggerMessage(makeMsg("user:1", "hello"));
    await new Promise((r) => setTimeout(r, 150));

    expect(brain.handleMessage).toHaveBeenCalled();

    dispatcher.stop();
  });

  it("stop cleans up resources", () => {
    const channel = makeMockChannel();
    const brain = makeMockBrain();
    const dispatcher = new ChannelDispatcher([channel], brain);
    dispatcher.start();
    dispatcher.stop();
  });
});
