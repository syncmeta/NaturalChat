import { describe, it, expect } from "vitest";
import { makeContactId, parseContactId } from "../../src/core/contact-id.js";

describe("makeContactId", () => {
  it("creates correct format", () => {
    expect(makeContactId("telegram", "12345")).toBe("telegram:12345");
  });

  it("works with Matrix-style IDs containing colons", () => {
    expect(makeContactId("matrix", "@bot:example.com")).toBe("matrix:@bot:example.com");
  });

  it("throws on empty channelType", () => {
    expect(() => makeContactId("", "12345")).toThrow("channelType");
  });

  it("throws on empty platformId", () => {
    expect(() => makeContactId("telegram", "")).toThrow("platformId");
  });

  it("throws if channelType contains colon", () => {
    expect(() => makeContactId("tele:gram", "12345")).toThrow("冒号");
  });
});

describe("parseContactId", () => {
  it("parses simple ID", () => {
    const result = parseContactId("telegram:12345");
    expect(result.channelType).toBe("telegram");
    expect(result.platformId).toBe("12345");
  });

  it("preserves colons in platformId", () => {
    const result = parseContactId("matrix:@bot:example.com");
    expect(result.channelType).toBe("matrix");
    expect(result.platformId).toBe("@bot:example.com");
  });

  it("throws on invalid format (no colon)", () => {
    expect(() => parseContactId("invalid")).toThrow("无效");
  });

  it("roundtrips correctly", () => {
    const original = makeContactId("web", "session-abc-123");
    const parsed = parseContactId(original);
    expect(parsed.channelType).toBe("web");
    expect(parsed.platformId).toBe("session-abc-123");
    expect(makeContactId(parsed.channelType, parsed.platformId)).toBe(original);
  });
});
