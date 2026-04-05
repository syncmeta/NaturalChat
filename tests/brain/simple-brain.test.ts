import { describe, it, expect, vi } from "vitest";
import { SimpleBrain } from "../../src/brain/simple-brain.js";
import type { LLMAgent } from "../../src/core/interfaces/llm-agent.js";
import type { Memory } from "../../src/core/interfaces/memory.js";
import type { IncomingMessage, UserContext } from "../../src/core/types.js";

function makeMockAgent(reply = "你好"): LLMAgent {
  return {
    chat: vi.fn().mockResolvedValue({
      content: reply,
      usage: { promptTokens: 10, completionTokens: 5, totalTokens: 15 },
    }),
  };
}

function makeMsg(contactId: string, text: string): IncomingMessage {
  return {
    id: "msg-1",
    contactId,
    text,
    timestamp: new Date(),
    channelType: "test",
  };
}

describe("SimpleBrain", () => {
  it("processes message and returns reply", async () => {
    const agent = makeMockAgent("你好 朋友");
    const brain = new SimpleBrain(agent, {
      botDir: "/tmp/test",
      botName: "小助手",
      botDescription: "测试用",
    });

    const replies = await brain.handleMessage(makeMsg("user:1", "你好"));

    expect(replies.length).toBeGreaterThan(0);
    expect(replies[0]).toContain("你好");
    expect(agent.chat).toHaveBeenCalledTimes(1);
  });

  it("splits multi-paragraph reply", async () => {
    const agent = makeMockAgent("第一段\n\n第二段\n\n第三段");
    const brain = new SimpleBrain(agent, {
      botDir: "/tmp/test",
      botName: "小助手",
      botDescription: "",
    });

    const replies = await brain.handleMessage(makeMsg("user:1", "你好"));

    expect(replies).toEqual(["第一段", "第二段", "第三段"]);
  });

  it("returns error message when LLM fails", async () => {
    const agent: LLMAgent = {
      chat: vi.fn().mockRejectedValue(new Error("API error")),
    };
    const brain = new SimpleBrain(agent, {
      botDir: "/tmp/test",
      botName: "小助手",
      botDescription: "",
    });

    const replies = await brain.handleMessage(makeMsg("user:1", "你好"));

    expect(replies).toHaveLength(1);
    expect(replies[0]).toContain("抱歉");
  });

  it("returns empty for empty message", async () => {
    const agent = makeMockAgent();
    const brain = new SimpleBrain(agent, {
      botDir: "/tmp/test",
      botName: "小助手",
      botDescription: "",
    });

    const replies = await brain.handleMessage(makeMsg("user:1", ""));
    expect(replies).toEqual([]);
    expect(agent.chat).not.toHaveBeenCalled();
  });

  it("isolates history between contacts", async () => {
    const agent = makeMockAgent("OK");
    const brain = new SimpleBrain(agent, {
      botDir: "/tmp/test",
      botName: "小助手",
      botDescription: "",
    });

    await brain.handleMessage(makeMsg("user:A", "A的消息"));
    await brain.handleMessage(makeMsg("user:B", "B的消息"));

    expect(agent.chat).toHaveBeenCalledTimes(2);

    // Check that messages are different (different history context)
    const call1Messages = (agent.chat as ReturnType<typeof vi.fn>).mock.calls[0][0];
    const call2Messages = (agent.chat as ReturnType<typeof vi.fn>).mock.calls[1][0];

    // User messages should be different
    const userMsg1 = call1Messages.find((m: { role: string }) => m.role === "user");
    const userMsg2 = call2Messages.find((m: { role: string }) => m.role === "user");
    expect(userMsg1.content).toBe("A的消息");
    expect(userMsg2.content).toBe("B的消息");
  });

  describe("access control", () => {
    it("denies in private mode for non-owner", async () => {
      const agent = makeMockAgent();
      const brain = new SimpleBrain(agent, {
        botDir: "/tmp/test",
        botName: "小助手",
        botDescription: "",
        accessMode: "private",
        ownerId: "owner:1",
      });

      const replies = await brain.handleMessage(makeMsg("stranger:2", "你好"));

      expect(replies).toHaveLength(1);
      expect(replies[0]).toContain("抱歉");
      expect(agent.chat).not.toHaveBeenCalled();
    });

    it("allows owner in private mode", async () => {
      const agent = makeMockAgent("OK");
      const brain = new SimpleBrain(agent, {
        botDir: "/tmp/test",
        botName: "小助手",
        botDescription: "",
        accessMode: "private",
        ownerId: "owner:1",
      });

      const replies = await brain.handleMessage(makeMsg("owner:1", "你好"));

      expect(agent.chat).toHaveBeenCalled();
    });

    it("returns pending in approval mode for unknown user", async () => {
      const agent = makeMockAgent();
      const brain = new SimpleBrain(agent, {
        botDir: "/tmp/test",
        botName: "小助手",
        botDescription: "",
        accessMode: "approval",
        ownerId: "owner:1",
      });

      const replies = await brain.handleMessage(makeMsg("unknown:3", "你好"));

      expect(replies[0]).toContain("确认");
      expect(agent.chat).not.toHaveBeenCalled();
    });
  });

  it("start and stop lifecycle", async () => {
    const agent = makeMockAgent();
    const brain = new SimpleBrain(agent, {
      botDir: "/tmp/test",
      botName: "小助手",
      botDescription: "",
    });

    await expect(brain.start()).resolves.toBeUndefined();
    await expect(brain.stop()).resolves.toBeUndefined();
  });

  describe("memory integration", () => {
    function makeMockMemory(ctx?: Partial<UserContext>): Memory {
      return {
        getContext: vi.fn().mockResolvedValue({
          contactId: "user:1",
          ...ctx,
        }),
        updateContext: vi.fn().mockResolvedValue(undefined),
      };
    }

    it("injects memory summary into system prompt", async () => {
      const agent = makeMockAgent("好的");
      const memory = makeMockMemory({ summary: "用户喜欢编程" });

      const brain = new SimpleBrain(agent, {
        botDir: "/tmp/test",
        botName: "小助手",
        botDescription: "",
        memory,
      });

      await brain.handleMessage(makeMsg("user:1", "你好"));

      // Verify system message contains memory
      const messages = (agent.chat as ReturnType<typeof vi.fn>).mock.calls[0][0];
      const systemMsg = messages.find((m: { role: string }) => m.role === "system");
      expect(systemMsg.content).toContain("用户喜欢编程");
    });

    it("injects user profile into system prompt", async () => {
      const agent = makeMockAgent("好的");
      const memory = makeMockMemory({
        profile: { lang: "zh", city: "上海" },
      });

      const brain = new SimpleBrain(agent, {
        botDir: "/tmp/test",
        botName: "小助手",
        botDescription: "",
        memory,
      });

      await brain.handleMessage(makeMsg("user:1", "你好"));

      const messages = (agent.chat as ReturnType<typeof vi.fn>).mock.calls[0][0];
      const systemMsg = messages.find((m: { role: string }) => m.role === "system");
      expect(systemMsg.content).toContain("lang");
      expect(systemMsg.content).toContain("上海");
    });

    it("updates lastInteraction after reply", async () => {
      const agent = makeMockAgent("好的");
      const memory = makeMockMemory();

      const brain = new SimpleBrain(agent, {
        botDir: "/tmp/test",
        botName: "小助手",
        botDescription: "",
        memory,
      });

      await brain.handleMessage(makeMsg("user:1", "你好"));

      expect(memory.updateContext).toHaveBeenCalledWith("user:1", {
        lastInteraction: expect.any(Date),
      });
    });

    it("continues if memory getContext fails", async () => {
      const agent = makeMockAgent("好的");
      const memory: Memory = {
        getContext: vi.fn().mockRejectedValue(new Error("disk error")),
        updateContext: vi.fn().mockResolvedValue(undefined),
      };

      const brain = new SimpleBrain(agent, {
        botDir: "/tmp/test",
        botName: "小助手",
        botDescription: "",
        memory,
      });

      const replies = await brain.handleMessage(makeMsg("user:1", "你好"));
      expect(replies[0]).toBe("好的");
      expect(agent.chat).toHaveBeenCalled();
    });

    it("works without memory (backward compatible)", async () => {
      const agent = makeMockAgent("好的");
      const brain = new SimpleBrain(agent, {
        botDir: "/tmp/test",
        botName: "小助手",
        botDescription: "",
        // no memory
      });

      const replies = await brain.handleMessage(makeMsg("user:1", "你好"));
      expect(replies[0]).toBe("好的");
    });
  });
});
