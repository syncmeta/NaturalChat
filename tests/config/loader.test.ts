import { describe, it, expect } from "vitest";
import { resolve } from "path";
import {
  parseGlobalConfig,
  parseBotConfig,
  parseBotSecrets,
  mergeModelConfig,
  resolveBotConfig,
} from "../../src/config/loader.js";
import { ConfigError } from "../../src/utils/errors.js";
import type { ModelConfig, GlobalConfig } from "../../src/config/types.js";

const FIXTURES = resolve(import.meta.dirname, "../fixtures");

describe("parseGlobalConfig", () => {
  it("loads valid config", async () => {
    const config = await parseGlobalConfig(resolve(FIXTURES, "valid-config.yaml"));
    expect(config.api_key).toBe("sk-test-key-12345");
    expect(config.api_base_url).toBe("https://api.openai.com/v1");
    expect(config.models.chat).toBe("gpt-4o");
  });

  it("throws ConfigError for invalid config", async () => {
    await expect(
      parseGlobalConfig(resolve(FIXTURES, "invalid-config.yaml")),
    ).rejects.toThrow(ConfigError);
  });

  it("throws ConfigError for non-existent file", async () => {
    await expect(
      parseGlobalConfig(resolve(FIXTURES, "non-existent.yaml")),
    ).rejects.toThrow(ConfigError);
  });
});

describe("parseBotConfig", () => {
  it("loads valid bot config", async () => {
    const config = await parseBotConfig(resolve(FIXTURES, "bots/test-bot/config.yaml"));
    expect(config.name).toBe("测试机器人");
    expect(config.models?.chat).toBe("gpt-4o-mini");
    expect(config.channels).toHaveLength(2);
  });

  it("throws ConfigError for broken bot config", async () => {
    await expect(
      parseBotConfig(resolve(FIXTURES, "bots/broken-bot/config.yaml")),
    ).rejects.toThrow(ConfigError);
  });
});

describe("parseBotSecrets", () => {
  it("loads valid secrets", async () => {
    const secrets = await parseBotSecrets(resolve(FIXTURES, "bots/test-bot/secrets.yaml"));
    expect(secrets.telegram?.token).toBe("123456:ABC-DEF");
  });

  it("returns empty object for missing file", async () => {
    const secrets = await parseBotSecrets(resolve(FIXTURES, "bots/broken-bot/secrets.yaml"));
    expect(secrets).toEqual({});
  });
});

describe("mergeModelConfig", () => {
  const globalModels: ModelConfig = {
    chat: "gpt-4o",
    critic: "gpt-4o",
    surf_planner: "gpt-4o-mini",
    surf_evaluator: "gpt-4o-mini",
    reflection: "gpt-4o",
    summary: "gpt-4o-mini",
  };

  it("returns global defaults when no bot override", () => {
    const merged = mergeModelConfig(globalModels);
    expect(merged).toEqual(globalModels);
  });

  it("overrides only specified fields", () => {
    const merged = mergeModelConfig(globalModels, { chat: "gpt-4o-mini" });
    expect(merged.chat).toBe("gpt-4o-mini");
    expect(merged.critic).toBe("gpt-4o");
  });

  it("does not mutate original", () => {
    mergeModelConfig(globalModels, { chat: "gpt-4o-mini" });
    expect(globalModels.chat).toBe("gpt-4o");
  });
});

describe("resolveBotConfig", () => {
  const globalConfig: GlobalConfig = {
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
  };

  it("merges config correctly", () => {
    const resolved = resolveBotConfig(
      { name: "test", description: "desc", channels: [{ type: "web", enabled: true }] },
      { web: { admin: "pass" } },
      globalConfig,
      "/path/to/bot",
    );
    expect(resolved.name).toBe("test");
    expect(resolved.models.chat).toBe("gpt-4o");
    expect(resolved.secrets.web?.admin).toBe("pass");
    expect(resolved.botDir).toBe("/path/to/bot");
  });

  it("applies bot model overrides", () => {
    const resolved = resolveBotConfig(
      { name: "test", description: "", models: { chat: "claude-3" }, channels: [] },
      {},
      globalConfig,
      "/path",
    );
    expect(resolved.models.chat).toBe("claude-3");
    expect(resolved.models.critic).toBe("gpt-4o");
  });
});
