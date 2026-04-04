import { describe, it, expect } from "vitest";
import { ConversationHistory } from "../../src/llm/conversation-history.js";

describe("ConversationHistory", () => {
  it("returns messages in order", () => {
    const history = new ConversationHistory({ maxTokens: 10000 });
    history.add({ role: "user", content: "hello" });
    history.add({ role: "assistant", content: "hi" });

    const msgs = history.getMessages();
    expect(msgs).toHaveLength(2);
    expect(msgs[0].role).toBe("user");
    expect(msgs[1].role).toBe("assistant");
  });

  it("includes system message first", () => {
    const history = new ConversationHistory({ maxTokens: 10000 });
    history.setSystem("You are a helpful bot");
    history.add({ role: "user", content: "hello" });

    const msgs = history.getMessages();
    expect(msgs[0].role).toBe("system");
    expect(msgs[0].content).toBe("You are a helpful bot");
    expect(msgs[1].role).toBe("user");
  });

  it("trims oldest messages when over budget", () => {
    // Very tight budget: only room for system + ~1 message
    const history = new ConversationHistory({ maxTokens: 100, reservedTokens: 20 });
    history.setSystem("sys"); // ~5 tokens

    // Add many messages to exceed budget
    for (let i = 0; i < 20; i++) {
      history.add({ role: "user", content: `Message number ${i} with some extra text to use tokens` });
    }

    const msgs = history.getMessages();
    // Should have system + some recent messages, NOT all 20
    expect(msgs.length).toBeLessThan(22); // system + 20
    expect(msgs.length).toBeGreaterThanOrEqual(2); // at least system + 1
    expect(msgs[0].role).toBe("system");

    // Last message should be the most recent one
    expect(msgs[msgs.length - 1].content).toContain("19");
  });

  it("never trims system message", () => {
    const history = new ConversationHistory({ maxTokens: 50, reservedTokens: 10 });
    history.setSystem("A long system prompt that takes many tokens by itself");
    history.add({ role: "user", content: "hello" });

    const msgs = history.getMessages();
    expect(msgs[0].role).toBe("system");
    expect(msgs[0].content).toContain("system prompt");
  });

  it("clear removes messages but preserves system", () => {
    const history = new ConversationHistory({ maxTokens: 10000 });
    history.setSystem("system");
    history.add({ role: "user", content: "hello" });
    history.add({ role: "assistant", content: "hi" });

    history.clear();
    expect(history.length).toBe(0);

    const msgs = history.getMessages();
    expect(msgs).toHaveLength(1);
    expect(msgs[0].role).toBe("system");
  });

  it("works without system message", () => {
    const history = new ConversationHistory({ maxTokens: 10000 });
    history.add({ role: "user", content: "hello" });

    const msgs = history.getMessages();
    expect(msgs).toHaveLength(1);
    expect(msgs[0].role).toBe("user");
  });
});
