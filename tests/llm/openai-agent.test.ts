import { describe, it, expect, vi, beforeEach } from "vitest";
import { OpenAIAgent } from "../../src/llm/openai-agent.js";
import type { ChatMessage, Tool } from "../../src/core/types.js";
import type OpenAI from "openai";

function makeMockClient(mockCreate: ReturnType<typeof vi.fn>) {
  return {
    chat: {
      completions: {
        create: mockCreate,
      },
    },
  } as unknown as OpenAI;
}

describe("OpenAIAgent", () => {
  let agent: OpenAIAgent;
  let mockCreate: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    mockCreate = vi.fn();
    agent = new OpenAIAgent({
      baseURL: "https://api.test.com/v1",
      apiKey: "test-key",
      defaultModel: "gpt-4o",
      _client: makeMockClient(mockCreate),
    });
  });

  it("calls API with correct parameters", async () => {
    mockCreate.mockResolvedValue({
      choices: [{ message: { content: "Hello!", tool_calls: null } }],
      usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 },
    });

    const messages: ChatMessage[] = [
      { role: "system", content: "You are a bot" },
      { role: "user", content: "Hi" },
    ];

    const result = await agent.chat(messages);

    expect(mockCreate).toHaveBeenCalledTimes(1);
    const callArgs = mockCreate.mock.calls[0][0];
    expect(callArgs.model).toBe("gpt-4o");
    expect(callArgs.messages).toHaveLength(2);
    expect(result.content).toBe("Hello!");
  });

  it("returns token usage", async () => {
    mockCreate.mockResolvedValue({
      choices: [{ message: { content: "reply" } }],
      usage: { prompt_tokens: 20, completion_tokens: 10, total_tokens: 30 },
    });

    const result = await agent.chat([{ role: "user", content: "test" }]);

    expect(result.usage).toEqual({
      promptTokens: 20,
      completionTokens: 10,
      totalTokens: 30,
    });
  });

  it("passes tools when provided", async () => {
    mockCreate.mockResolvedValue({
      choices: [{ message: { content: "result" } }],
      usage: null,
    });

    const tools: Tool[] = [
      {
        type: "function",
        function: {
          name: "search",
          description: "Search the web",
          parameters: { type: "object", properties: { query: { type: "string" } } },
        },
      },
    ];

    await agent.chat([{ role: "user", content: "search for cats" }], tools);

    const callArgs = mockCreate.mock.calls[0][0];
    expect(callArgs.tools).toHaveLength(1);
    expect(callArgs.tools[0].function.name).toBe("search");
  });

  it("parses tool calls from response", async () => {
    mockCreate.mockResolvedValue({
      choices: [
        {
          message: {
            content: null,
            tool_calls: [
              {
                id: "call_123",
                type: "function",
                function: { name: "search", arguments: '{"query":"cats"}' },
              },
            ],
          },
        },
      ],
      usage: { prompt_tokens: 10, completion_tokens: 15, total_tokens: 25 },
    });

    const result = await agent.chat([{ role: "user", content: "search for cats" }]);

    expect(result.content).toBe("");
    expect(result.toolCalls).toHaveLength(1);
    expect(result.toolCalls![0].id).toBe("call_123");
    expect(result.toolCalls![0].function.name).toBe("search");
    expect(result.toolCalls![0].function.arguments).toBe('{"query":"cats"}');
  });

  it("handles API errors gracefully", async () => {
    mockCreate.mockRejectedValue(new Error("Rate limit exceeded"));

    await expect(
      agent.chat([{ role: "user", content: "hello" }]),
    ).rejects.toThrow("LLM 调用失败 (模型: gpt-4o): Rate limit exceeded");
  });

  it("handles empty choices", async () => {
    mockCreate.mockResolvedValue({
      choices: [],
      usage: { prompt_tokens: 5, completion_tokens: 0, total_tokens: 5 },
    });

    const result = await agent.chat([{ role: "user", content: "hello" }]);
    expect(result.content).toBe("");
  });

  it("uses override model when provided", async () => {
    mockCreate.mockResolvedValue({
      choices: [{ message: { content: "reply" } }],
      usage: null,
    });

    await agent.chat([{ role: "user", content: "test" }], undefined, "gpt-4o-mini");

    const callArgs = mockCreate.mock.calls[0][0];
    expect(callArgs.model).toBe("gpt-4o-mini");
  });
});
