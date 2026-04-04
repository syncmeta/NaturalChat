import { describe, it, expect } from "vitest";
import { splitReply } from "../../src/brain/reply-splitter.js";

describe("splitReply", () => {
  it("returns empty array for empty string", () => {
    expect(splitReply("")).toEqual([]);
    expect(splitReply("  ")).toEqual([]);
  });

  it("returns single message for short reply", () => {
    const result = splitReply("你好");
    expect(result).toEqual(["你好"]);
  });

  it("splits by double newline", () => {
    const result = splitReply("第一段\n\n第二段\n\n第三段");
    expect(result).toEqual(["第一段", "第二段", "第三段"]);
  });

  it("does not split by single newline", () => {
    const result = splitReply("第一行\n第二行");
    expect(result).toEqual(["第一行\n第二行"]);
  });

  it("filters empty paragraphs", () => {
    const result = splitReply("内容\n\n\n\n\n更多内容");
    expect(result).toEqual(["内容", "更多内容"]);
  });

  it("splits long paragraph at sentence boundary", () => {
    const longPara = "这是第一句话。".repeat(100);
    const result = splitReply(longPara);
    expect(result.length).toBeGreaterThan(1);
    for (const chunk of result) {
      expect(chunk.length).toBeLessThanOrEqual(510); // small margin
    }
  });

  it("handles text with no sentence boundaries", () => {
    const longWord = "a".repeat(600);
    const result = splitReply(longWord);
    expect(result.length).toBeGreaterThan(1);
  });
});
