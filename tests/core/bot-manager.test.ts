import { describe, it, expect, beforeEach } from "vitest";
import { resolve } from "path";
import { BotManager } from "../../src/core/bot-manager.js";
import type { GlobalConfig } from "../../src/config/types.js";

const FIXTURES = resolve(import.meta.dirname, "../fixtures");

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

describe("BotManager", () => {
  let manager: BotManager;

  beforeEach(() => {
    manager = new BotManager();
  });

  describe("discover", () => {
    it("discovers bot directories", async () => {
      const dirs = await manager.discover(resolve(FIXTURES, "bots"));
      // Should find test-bot and broken-bot, but not _template
      expect(dirs.length).toBeGreaterThanOrEqual(2);
      expect(dirs.some((d) => d.endsWith("test-bot"))).toBe(true);
      expect(dirs.some((d) => d.endsWith("broken-bot"))).toBe(true);
    });

    it("skips _template directory", async () => {
      const dirs = await manager.discover(resolve(FIXTURES, "bots"));
      expect(dirs.some((d) => d.endsWith("_template"))).toBe(false);
    });

    it("returns empty array for non-existent directory", async () => {
      const dirs = await manager.discover("/non/existent/path");
      expect(dirs).toEqual([]);
    });
  });

  describe("loadAll", () => {
    it("loads valid bots and skips invalid ones", async () => {
      const dirs = await manager.discover(resolve(FIXTURES, "bots"));
      await manager.loadAll(globalConfig, dirs);

      // test-bot should load, broken-bot should fail
      expect(manager.instanceCount).toBe(1);
      const instances = manager.getInstances();
      expect(instances[0].config.name).toBe("测试机器人");
    });

    it("merges model config correctly", async () => {
      const dirs = await manager.discover(resolve(FIXTURES, "bots"));
      await manager.loadAll(globalConfig, dirs);

      const instances = manager.getInstances();
      const config = instances[0].config;
      // Bot overrides chat model
      expect(config.models.chat).toBe("gpt-4o-mini");
      // Others fall back to global
      expect(config.models.critic).toBe("gpt-4o");
    });
  });

  describe("startAll / stopAll", () => {
    it("starts and stops without error", async () => {
      const dirs = await manager.discover(resolve(FIXTURES, "bots"));
      await manager.loadAll(globalConfig, dirs);
      await manager.startAll();
      expect(manager.instanceCount).toBe(1);

      await manager.stopAll();
      expect(manager.instanceCount).toBe(0);
    });
  });
});
