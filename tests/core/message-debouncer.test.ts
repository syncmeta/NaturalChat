import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { MessageDebouncer } from "../../src/core/message-debouncer.js";
import type { IncomingMessage } from "../../src/core/types.js";

function makeMsg(contactId: string, text: string): IncomingMessage {
  return {
    id: Math.random().toString(36).slice(2),
    contactId,
    text,
    timestamp: new Date(),
    channelType: "test",
  };
}

describe("MessageDebouncer", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("fires single message after debounce timeout", async () => {
    const debouncer = new MessageDebouncer({ debounceMs: 100 });
    const callback = vi.fn().mockResolvedValue(undefined);
    debouncer.onBatch(callback);

    debouncer.push(makeMsg("user:1", "hello"));

    expect(callback).not.toHaveBeenCalled();

    vi.advanceTimersByTime(100);

    expect(callback).toHaveBeenCalledTimes(1);
    expect(callback.mock.calls[0][0]).toHaveLength(1);
    expect(callback.mock.calls[0][0][0].text).toBe("hello");

    debouncer.dispose();
  });

  it("batches multiple messages within debounce window", async () => {
    const debouncer = new MessageDebouncer({ debounceMs: 200 });
    const callback = vi.fn().mockResolvedValue(undefined);
    debouncer.onBatch(callback);

    debouncer.push(makeMsg("user:1", "msg1"));
    vi.advanceTimersByTime(50);
    debouncer.push(makeMsg("user:1", "msg2"));
    vi.advanceTimersByTime(50);
    debouncer.push(makeMsg("user:1", "msg3"));

    expect(callback).not.toHaveBeenCalled();

    vi.advanceTimersByTime(200);

    expect(callback).toHaveBeenCalledTimes(1);
    const batch = callback.mock.calls[0][0];
    expect(batch).toHaveLength(3);
    expect(batch.map((m: IncomingMessage) => m.text)).toEqual(["msg1", "msg2", "msg3"]);

    debouncer.dispose();
  });

  it("respects maxWait ceiling", async () => {
    const debouncer = new MessageDebouncer({ debounceMs: 100, maxWaitMs: 250 });
    const callback = vi.fn().mockResolvedValue(undefined);
    debouncer.onBatch(callback);

    debouncer.push(makeMsg("user:1", "msg1")); // t=0
    vi.advanceTimersByTime(80);
    debouncer.push(makeMsg("user:1", "msg2")); // t=80
    vi.advanceTimersByTime(80);
    debouncer.push(makeMsg("user:1", "msg3")); // t=160
    vi.advanceTimersByTime(80);
    debouncer.push(makeMsg("user:1", "msg4")); // t=240

    // At t=240, elapsed from first = 240ms. Next push resets timer.
    // But remaining = 250 - 240 = 10ms. So timer should fire at t=250.
    vi.advanceTimersByTime(10);

    expect(callback).toHaveBeenCalledTimes(1);
    expect(callback.mock.calls[0][0]).toHaveLength(4);

    debouncer.dispose();
  });

  it("isolates different contacts", async () => {
    const debouncer = new MessageDebouncer({ debounceMs: 100 });
    const callback = vi.fn().mockResolvedValue(undefined);
    debouncer.onBatch(callback);

    debouncer.push(makeMsg("user:A", "A's message"));
    debouncer.push(makeMsg("user:B", "B's message"));

    vi.advanceTimersByTime(100);

    expect(callback).toHaveBeenCalledTimes(2);

    // Each call should have exactly 1 message from the respective user
    const calls = callback.mock.calls.map((c: unknown[]) => c[0] as IncomingMessage[]);
    const aCall = calls.find((msgs: IncomingMessage[]) => msgs[0].contactId === "user:A");
    const bCall = calls.find((msgs: IncomingMessage[]) => msgs[0].contactId === "user:B");

    expect(aCall).toHaveLength(1);
    expect(bCall).toHaveLength(1);

    debouncer.dispose();
  });

  it("clear removes pending messages", () => {
    const debouncer = new MessageDebouncer({ debounceMs: 100 });
    const callback = vi.fn().mockResolvedValue(undefined);
    debouncer.onBatch(callback);

    debouncer.push(makeMsg("user:1", "hello"));
    expect(debouncer.getPendingCount("user:1")).toBe(1);

    debouncer.clear("user:1");
    expect(debouncer.getPendingCount("user:1")).toBe(0);

    vi.advanceTimersByTime(200);
    expect(callback).not.toHaveBeenCalled();

    debouncer.dispose();
  });

  it("dispose clears all timers", () => {
    const debouncer = new MessageDebouncer({ debounceMs: 100 });
    const callback = vi.fn().mockResolvedValue(undefined);
    debouncer.onBatch(callback);

    debouncer.push(makeMsg("user:1", "hello"));
    debouncer.push(makeMsg("user:2", "world"));

    debouncer.dispose();

    vi.advanceTimersByTime(200);
    expect(callback).not.toHaveBeenCalled();
    expect(debouncer.hasPending).toBe(false);
  });
});
