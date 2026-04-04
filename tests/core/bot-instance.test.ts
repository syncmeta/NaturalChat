import { describe, it, expect, vi } from "vitest";
import { BotInstance } from "../../src/core/bot-instance.js";
import type { ResolvedBotConfig } from "../../src/config/types.js";
import type { Channel, MessageHandler } from "../../src/core/interfaces/channel.js";
import type { Brain } from "../../src/core/interfaces/brain.js";
import type { FilePayload } from "../../src/core/types.js";

const mockConfig: ResolvedBotConfig = {
  name: "测试 Bot",
  description: "单元测试用",
  models: {
    chat: "gpt-4o",
    critic: "gpt-4o",
    surf_planner: "gpt-4o-mini",
    surf_evaluator: "gpt-4o-mini",
    reflection: "gpt-4o",
    summary: "gpt-4o-mini",
  },
  channels: [{ type: "web", enabled: true }],
  secrets: {},
  botDir: "/tmp/test-bot",
};

function makeMockChannel(): Channel {
  return {
    type: "test",
    start: vi.fn().mockResolvedValue(undefined),
    stop: vi.fn().mockResolvedValue(undefined),
    sendMessage: vi.fn().mockResolvedValue(undefined),
    sendFile: vi.fn().mockResolvedValue(undefined) as (contactId: string, file: FilePayload) => Promise<void>,
    sendTyping: vi.fn().mockResolvedValue(undefined),
    onMessage: vi.fn() as (handler: MessageHandler) => void,
  };
}

function makeMockBrain(): Brain {
  return {
    handleMessage: vi.fn().mockResolvedValue(["OK"]),
    start: vi.fn().mockResolvedValue(undefined),
    stop: vi.fn().mockResolvedValue(undefined),
  };
}

describe("BotInstance", () => {
  it("creates with resolved config", () => {
    const instance = new BotInstance(mockConfig);
    expect(instance.config.name).toBe("测试 Bot");
    expect(instance.channels).toEqual([]);
    expect(instance.brain).toBeNull();
    expect(instance.memory).toBeNull();
    expect(instance.skillLoader).toBeNull();
  });

  it("start and stop lifecycle works without modules", async () => {
    const instance = new BotInstance(mockConfig);
    await expect(instance.start()).resolves.toBeUndefined();
    await expect(instance.stop()).resolves.toBeUndefined();
  });

  it("starts channels and brain when injected", async () => {
    const instance = new BotInstance(mockConfig);
    const channel = makeMockChannel();
    const brain = makeMockBrain();

    instance.channels = [channel];
    instance.brain = brain;

    await instance.start();

    expect(channel.start).toHaveBeenCalled();
    expect(brain.start).toHaveBeenCalled();

    await instance.stop();

    expect(brain.stop).toHaveBeenCalled();
    expect(channel.stop).toHaveBeenCalled();
  });

  it("creates dispatcher when brain and channels are present", async () => {
    const instance = new BotInstance(mockConfig);
    const channel = makeMockChannel();
    const brain = makeMockBrain();

    instance.channels = [channel];
    instance.brain = brain;

    await instance.start();

    // onMessage should have been called by dispatcher.start()
    expect(channel.onMessage).toHaveBeenCalled();

    await instance.stop();
  });

  it("does not create dispatcher without brain", async () => {
    const instance = new BotInstance(mockConfig);
    const channel = makeMockChannel();
    instance.channels = [channel];

    await instance.start();

    // onMessage should NOT have been called (no dispatcher)
    expect(channel.onMessage).not.toHaveBeenCalled();

    await instance.stop();
  });
});
