import { describe, it, expect } from "vitest";
import { BotInstance } from "../../src/core/bot-instance.js";
import type { ResolvedBotConfig } from "../../src/config/types.js";

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

describe("BotInstance", () => {
  it("creates with resolved config", () => {
    const instance = new BotInstance(mockConfig);
    expect(instance.config.name).toBe("测试 Bot");
    expect(instance.channels).toEqual([]);
    expect(instance.brain).toBeNull();
    expect(instance.memory).toBeNull();
    expect(instance.skillLoader).toBeNull();
  });

  it("start and stop lifecycle works", async () => {
    const instance = new BotInstance(mockConfig);
    await expect(instance.start()).resolves.toBeUndefined();
    await expect(instance.stop()).resolves.toBeUndefined();
  });
});
