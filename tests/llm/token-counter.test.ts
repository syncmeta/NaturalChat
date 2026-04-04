import { describe, it, expect } from "vitest";
import { estimateTokens, estimateMessagesTokens } from "../../src/llm/token-counter.js";
import type { ChatMessage } from "../../src/core/types.js";

describe("estimateTokens", () => {
  it("returns 0 for empty string", () => {
    expect(estimateTokens("")).toBe(0);
  });

  it("estimates English text (roughly 4 chars per token)", () => {
    const result = estimateTokens("Hello, world!"); // 13 chars
    expect(result).toBeGreaterThan(0);
    expect(result).toBeLessThan(10); // Should be around 3-4
  });

  it("estimates Chinese text (roughly 1.5 chars per token)", () => {
    const result = estimateTokens("你好世界"); // 4 Chinese chars
    expect(result).toBeGreaterThan(1);
    expect(result).toBeLessThan(6); // Should be around 2-3
  });

  it("handles mixed Chinese and English", () => {
    const result = estimateTokens("Hello 你好 world 世界");
    expect(result).toBeGreaterThan(3);
  });

  it("longer text produces more tokens", () => {
    const short = estimateTokens("Hi");
    const long = estimateTokens("Hello, this is a much longer piece of text that should produce more tokens");
    expect(long).toBeGreaterThan(short);
  });
});

describe("estimateMessagesTokens", () => {
  it("returns 0 for empty array", () => {
    expect(estimateMessagesTokens([])).toBe(0);
  });

  it("adds per-message overhead", () => {
    const messages: ChatMessage[] = [
      { role: "user", content: "hi" },
    ];
    const tokensWithOverhead = estimateMessagesTokens(messages);
    const tokensWithout = estimateTokens("hi");
    expect(tokensWithOverhead).toBeGreaterThan(tokensWithout);
  });

  it("sums tokens across messages", () => {
    const messages: ChatMessage[] = [
      { role: "system", content: "You are a bot" },
      { role: "user", content: "Hello" },
      { role: "assistant", content: "Hi there" },
    ];
    const total = estimateMessagesTokens(messages);
    expect(total).toBeGreaterThan(10); // 3 messages * 4 overhead + content
  });
});
