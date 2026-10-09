import { DailyLimiter, parseMedroRequest, tokenMatches } from "./medroAsistent";

jest.mock("firebase-functions/v2/https", () => ({ onRequest: () => jest.fn() }));

jest.mock("firebase-functions/params", () => ({
  defineSecret: () => ({ value: () => "test-secret" }),
}));

const valid = {
  model: "claude-sonnet-5-5",
  system: "instructiuni",
  messages: [{ role: "user", content: "Buna" }],
};

describe("parseMedroRequest", () => {
  it("accepts a well-formed request and keeps only the known fields", () => {
    expect(parseMedroRequest({ ...valid, max_tokens: 999999 })).toEqual(valid);
    expect(parseMedroRequest({ ...valid, model: "claude-opus-5-5" })).toMatchObject({ model: "claude-opus-5-5" });
  });

  it("refuses models outside the allow-list", () => {
    expect(parseMedroRequest({ ...valid, model: "claude-fable-5-1" })).toBe("model is not allowed");
    expect(parseMedroRequest({ ...valid, model: undefined })).toBe("model is not allowed");
  });

  it("refuses malformed bodies", () => {
    expect(parseMedroRequest(null)).toBe("body must be a JSON object");
    expect(parseMedroRequest("text")).toBe("body must be a JSON object");
    expect(parseMedroRequest({ ...valid, system: "" })).toBe("system must be a non-empty string");
    expect(parseMedroRequest({ ...valid, messages: [] })).toBe("messages must be a non-empty array");
    expect(parseMedroRequest({ ...valid, messages: "x" })).toBe("messages must be a non-empty array");
  });

  it("refuses oversized requests", () => {
    const huge = { ...valid, messages: [{ role: "user", content: "x".repeat(2_000_001) }] };
    expect(parseMedroRequest(huge)).toBe("request is too large");
  });
});

describe("tokenMatches", () => {
  it("matches only the exact token", () => {
    expect(tokenMatches("abc123", "abc123")).toBe(true);
    expect(tokenMatches("abc124", "abc123")).toBe(false);
    expect(tokenMatches("abc", "abc123")).toBe(false);
    expect(tokenMatches("", "abc123")).toBe(false);
    expect(tokenMatches(undefined, "abc123")).toBe(false);
    expect(tokenMatches(["abc123"], "abc123")).toBe(false);
  });
});

describe("DailyLimiter", () => {
  it("refuses requests past the day's limit and starts over the next UTC day", () => {
    const limiter = new DailyLimiter(2);
    const day1 = new Date("2026-10-09T10:00:00Z");
    expect(limiter.allow(day1)).toBe(true);
    expect(limiter.allow(day1)).toBe(true);
    expect(limiter.allow(day1)).toBe(false);
    expect(limiter.allow(new Date("2026-10-09T23:59:59Z"))).toBe(false);
    expect(limiter.allow(new Date("2026-10-10T00:00:01Z"))).toBe(true);
  });
});
