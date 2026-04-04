import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdir, writeFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { PromptRegistry } from "../../src/prompt/prompt-registry.js";

const TEST_DIR = join(import.meta.dirname, "../../tmp-test-prompts");
const PROMPTS_DIR = join(TEST_DIR, "prompts");

describe("PromptRegistry", () => {
  beforeEach(async () => {
    await mkdir(PROMPTS_DIR, { recursive: true });
  });

  afterEach(async () => {
    await rm(TEST_DIR, { recursive: true, force: true });
  });

  it("loads .md files from prompts directory", async () => {
    await writeFile(join(PROMPTS_DIR, "system.md"), "你是一个助手");
    await writeFile(join(PROMPTS_DIR, "greeting.md"), "你好呀");

    const registry = new PromptRegistry(TEST_DIR);
    await registry.load();

    expect(registry.names()).toContain("system");
    expect(registry.names()).toContain("greeting");
    expect(registry.get("system")).toBe("你是一个助手");
    expect(registry.get("greeting")).toBe("你好呀");
  });

  it("ignores non-.md files", async () => {
    await writeFile(join(PROMPTS_DIR, "system.md"), "prompt");
    await writeFile(join(PROMPTS_DIR, "notes.txt"), "ignored");

    const registry = new PromptRegistry(TEST_DIR);
    await registry.load();

    expect(registry.names()).toEqual(["system"]);
  });

  it("returns null for unknown prompt", async () => {
    const registry = new PromptRegistry(TEST_DIR);
    await registry.load();

    expect(registry.get("nonexistent")).toBeNull();
  });

  it("handles missing prompts directory gracefully", async () => {
    const registry = new PromptRegistry("/tmp/no-such-bot-dir");
    await registry.load();

    expect(registry.names()).toEqual([]);
    expect(registry.isLoaded).toBe(true);
  });

  it("substitutes {{variables}} in templates", async () => {
    await writeFile(
      join(PROMPTS_DIR, "system.md"),
      "你的名字是 {{botName}}。{{botDescription}}。今天是 {{date}}。",
    );

    const registry = new PromptRegistry(TEST_DIR);
    await registry.load();

    const result = registry.get("system", {
      botName: "小明",
      botDescription: "一个友善的机器人",
    });

    expect(result).toContain("小明");
    expect(result).toContain("一个友善的机器人");
    // date should be replaced with today's date (YYYY-MM-DD)
    expect(result).toMatch(/\d{4}-\d{2}-\d{2}/);
    expect(result).not.toContain("{{date}}");
  });

  it("preserves unknown variables as-is", async () => {
    await writeFile(join(PROMPTS_DIR, "test.md"), "Hello {{unknown}}");

    const registry = new PromptRegistry(TEST_DIR);
    await registry.load();

    const result = registry.get("test", {
      botName: "X",
      botDescription: "",
    });

    expect(result).toBe("Hello {{unknown}}");
  });

  it("returns raw content when no variables provided", async () => {
    await writeFile(join(PROMPTS_DIR, "raw.md"), "{{botName}} 是好人");

    const registry = new PromptRegistry(TEST_DIR);
    await registry.load();

    expect(registry.get("raw")).toBe("{{botName}} 是好人");
  });

  it("reload clears cache and reloads", async () => {
    await writeFile(join(PROMPTS_DIR, "v1.md"), "版本1");

    const registry = new PromptRegistry(TEST_DIR);
    await registry.load();

    expect(registry.get("v1")).toBe("版本1");

    // Update file
    await writeFile(join(PROMPTS_DIR, "v1.md"), "版本2");
    await registry.reload();

    expect(registry.get("v1")).toBe("版本2");
  });

  it("clearCache resets state", async () => {
    await writeFile(join(PROMPTS_DIR, "test.md"), "内容");

    const registry = new PromptRegistry(TEST_DIR);
    await registry.load();

    expect(registry.isLoaded).toBe(true);

    registry.clearCache();

    expect(registry.isLoaded).toBe(false);
    expect(registry.get("test")).toBeNull();
  });

  it("trims whitespace from loaded content", async () => {
    await writeFile(join(PROMPTS_DIR, "space.md"), "\n  内容  \n\n");

    const registry = new PromptRegistry(TEST_DIR);
    await registry.load();

    expect(registry.get("space")).toBe("内容");
  });
});
