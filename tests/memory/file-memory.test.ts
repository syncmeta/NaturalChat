import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { rm, readFile } from "node:fs/promises";
import { join } from "node:path";
import { FileMemory } from "../../src/memory/file-memory.js";

const TEST_DIR = join(import.meta.dirname, "../../tmp-test-memory");

describe("FileMemory", () => {
  let memory: FileMemory;

  beforeEach(async () => {
    memory = new FileMemory(TEST_DIR);
    await memory.init();
  });

  afterEach(async () => {
    await rm(TEST_DIR, { recursive: true, force: true });
  });

  it("init creates the memory directory", async () => {
    const { stat } = await import("node:fs/promises");
    const s = await stat(join(TEST_DIR, "data", "memory"));
    expect(s.isDirectory()).toBe(true);
  });

  it("getContext returns default for unknown contactId", async () => {
    const ctx = await memory.getContext("web:unknown-user");
    expect(ctx.contactId).toBe("web:unknown-user");
    expect(ctx.summary).toBeUndefined();
    expect(ctx.profile).toBeUndefined();
  });

  it("updateContext creates and persists data", async () => {
    await memory.updateContext("web:user1", {
      summary: "喜欢编程",
      lastInteraction: new Date("2026-04-01"),
    });

    const ctx = await memory.getContext("web:user1");
    expect(ctx.contactId).toBe("web:user1");
    expect(ctx.summary).toBe("喜欢编程");
    expect(ctx.lastInteraction).toEqual(new Date("2026-04-01"));
  });

  it("updateContext merges without overwriting unset fields", async () => {
    await memory.updateContext("web:user2", {
      summary: "初次见面",
      profile: { lang: "zh" },
    });

    // 只更新 summary，不应丢失 profile
    await memory.updateContext("web:user2", {
      summary: "老朋友了",
    });

    const ctx = await memory.getContext("web:user2");
    expect(ctx.summary).toBe("老朋友了");
    expect(ctx.profile).toEqual({ lang: "zh" });
  });

  it("updateContext deep-merges profile", async () => {
    await memory.updateContext("web:user3", {
      profile: { lang: "zh", hobby: "读书" },
    });

    await memory.updateContext("web:user3", {
      profile: { hobby: "编程", city: "上海" },
    });

    const ctx = await memory.getContext("web:user3");
    expect(ctx.profile).toEqual({
      lang: "zh",
      hobby: "编程",
      city: "上海",
    });
  });

  it("sanitizes contactId with special characters for filename", async () => {
    const contactId = "telegram:12345";
    await memory.updateContext(contactId, { summary: "test" });

    // Verify file exists with sanitized name
    const filePath = join(TEST_DIR, "data", "memory", "telegram_12345.json");
    const content = await readFile(filePath, "utf-8");
    const data = JSON.parse(content);
    expect(data.contactId).toBe(contactId);
    expect(data.summary).toBe("test");
  });

  it("handles concurrent writes to same contactId safely", async () => {
    // Fire multiple updates concurrently
    const promises = Array.from({ length: 10 }, (_, i) =>
      memory.updateContext("web:concurrent", {
        summary: `update-${i}`,
      }),
    );

    await Promise.all(promises);

    const ctx = await memory.getContext("web:concurrent");
    expect(ctx.contactId).toBe("web:concurrent");
    // summary should be one of the updates (last one wins due to serial lock)
    expect(ctx.summary).toMatch(/^update-\d$/);
  });

  it("survives re-init (simulates restart)", async () => {
    await memory.updateContext("web:persist", {
      summary: "应该还在",
    });

    // Create new instance (simulating restart)
    const memory2 = new FileMemory(TEST_DIR);
    await memory2.init();

    const ctx = await memory2.getContext("web:persist");
    expect(ctx.summary).toBe("应该还在");
  });
});
