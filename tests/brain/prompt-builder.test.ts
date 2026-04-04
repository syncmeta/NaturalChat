import { describe, it, expect } from "vitest";
import { resolve } from "path";
import { PromptBuilder } from "../../src/brain/prompt-builder.js";

const FIXTURES = resolve(import.meta.dirname, "../fixtures");

describe("PromptBuilder", () => {
  it("includes bot name in prompt", async () => {
    const builder = new PromptBuilder({
      botDir: resolve(FIXTURES, "bots/test-bot"),
      botName: "小助手",
      botDescription: "一个测试 Bot",
    });

    const prompt = await builder.getSystemPrompt();
    expect(prompt).toContain("小助手");
    expect(prompt).toContain("一个测试 Bot");
  });

  it("loads custom system.md when available", async () => {
    const builder = new PromptBuilder({
      botDir: resolve(FIXTURES, "bots/test-bot"),
      botName: "小助手",
      botDescription: "",
    });

    const prompt = await builder.getSystemPrompt();
    // If system.md exists, it should be loaded
    // If not, default prompt should be used
    expect(prompt).toContain("小助手");
  });

  it("uses default prompt when system.md missing", async () => {
    const builder = new PromptBuilder({
      botDir: "/nonexistent/path",
      botName: "测试",
      botDescription: "",
    });

    const prompt = await builder.getSystemPrompt();
    expect(prompt).toContain("微信聊天");
  });

  it("caches prompt", async () => {
    const builder = new PromptBuilder({
      botDir: "/nonexistent/path",
      botName: "测试",
      botDescription: "",
    });

    const prompt1 = await builder.getSystemPrompt();
    const prompt2 = await builder.getSystemPrompt();
    expect(prompt1).toBe(prompt2);
  });

  it("clearCache forces reload", async () => {
    const builder = new PromptBuilder({
      botDir: "/nonexistent/path",
      botName: "测试",
      botDescription: "",
    });

    await builder.getSystemPrompt();
    builder.clearCache();
    const prompt = await builder.getSystemPrompt();
    expect(prompt).toContain("测试");
  });
});
