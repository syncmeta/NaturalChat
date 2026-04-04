import { describe, it, expect } from "vitest";
import {
  GlobalConfigSchema,
  BotConfigSchema,
  BotSecretsSchema,
  ChannelEntrySchema,
} from "../../src/config/schema.js";

describe("GlobalConfigSchema", () => {
  it("accepts valid config", () => {
    const result = GlobalConfigSchema.safeParse({
      api_base_url: "https://api.openai.com/v1",
      api_key: "sk-test",
      models: {
        chat: "gpt-4o",
        critic: "gpt-4o",
        surf_planner: "gpt-4o-mini",
        surf_evaluator: "gpt-4o-mini",
        reflection: "gpt-4o",
        summary: "gpt-4o-mini",
      },
    });
    expect(result.success).toBe(true);
  });

  it("rejects missing api_key", () => {
    const result = GlobalConfigSchema.safeParse({
      api_base_url: "https://api.openai.com/v1",
      models: {
        chat: "gpt-4o",
        critic: "gpt-4o",
        surf_planner: "gpt-4o-mini",
        surf_evaluator: "gpt-4o-mini",
        reflection: "gpt-4o",
        summary: "gpt-4o-mini",
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects invalid api_base_url", () => {
    const result = GlobalConfigSchema.safeParse({
      api_base_url: "not-a-url",
      api_key: "sk-test",
      models: {
        chat: "gpt-4o",
        critic: "gpt-4o",
        surf_planner: "gpt-4o-mini",
        surf_evaluator: "gpt-4o-mini",
        reflection: "gpt-4o",
        summary: "gpt-4o-mini",
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects wrong type in models", () => {
    const result = GlobalConfigSchema.safeParse({
      api_base_url: "https://api.openai.com/v1",
      api_key: "sk-test",
      models: {
        chat: 12345,
        critic: "gpt-4o",
        surf_planner: "gpt-4o-mini",
        surf_evaluator: "gpt-4o-mini",
        reflection: "gpt-4o",
        summary: "gpt-4o-mini",
      },
    });
    expect(result.success).toBe(false);
  });

  it("rejects missing model field", () => {
    const result = GlobalConfigSchema.safeParse({
      api_base_url: "https://api.openai.com/v1",
      api_key: "sk-test",
      models: {
        chat: "gpt-4o",
        // critic missing
        surf_planner: "gpt-4o-mini",
        surf_evaluator: "gpt-4o-mini",
        reflection: "gpt-4o",
        summary: "gpt-4o-mini",
      },
    });
    expect(result.success).toBe(false);
  });
});

describe("BotConfigSchema", () => {
  it("accepts valid bot config", () => {
    const result = BotConfigSchema.safeParse({
      name: "测试 Bot",
      description: "一个测试机器人",
      models: { chat: "gpt-4o-mini" },
      channels: [{ type: "web", enabled: true }],
    });
    expect(result.success).toBe(true);
  });

  it("accepts minimal bot config (name only)", () => {
    const result = BotConfigSchema.safeParse({ name: "最小 Bot" });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.description).toBe("");
      expect(result.data.channels).toEqual([]);
    }
  });

  it("rejects missing name", () => {
    const result = BotConfigSchema.safeParse({ description: "没有名字" });
    expect(result.success).toBe(false);
  });
});

describe("BotSecretsSchema", () => {
  it("accepts valid secrets", () => {
    const result = BotSecretsSchema.safeParse({
      telegram: { token: "123:ABC" },
      matrix: { user_id: "@bot:example.com", password: "secret" },
    });
    expect(result.success).toBe(true);
  });

  it("accepts empty object", () => {
    const result = BotSecretsSchema.safeParse({});
    expect(result.success).toBe(true);
  });
});

describe("ChannelEntrySchema", () => {
  it("defaults enabled to true", () => {
    const result = ChannelEntrySchema.safeParse({ type: "web" });
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.enabled).toBe(true);
    }
  });
});
