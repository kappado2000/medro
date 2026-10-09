import { timingSafeEqual } from "crypto";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import Anthropic from "@anthropic-ai/sdk";

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

/** A long random value, set once via `firebase functions:secrets:set
 * MEDRO_ACCESS_TOKEN`; the app carries the same value in
 * lib/config/asistent_server.dart. MedRO is personal-use and has no
 * Firebase Auth, so this shared token is what stops anyone who finds the
 * URL from spending the Anthropic key. */
const MEDRO_ACCESS_TOKEN = defineSecret("MEDRO_ACCESS_TOKEN");

/** The models MedRO's assistant screen offers — anything else is refused so
 * the token can't be used to run arbitrary (more expensive) models. */
const ALLOWED_MODELS = new Set(["claude-sonnet-5-5", "claude-opus-5-5"]);

/** Server-side refusal fallback (`fallbacks: "default"`). */
const FALLBACK_BETA = "server-side-fallback-2026-07-01";

/** A conversation is text plus RCP documents passed by URL, never inline
 * base64, so a legitimate request stays far below this. */
const MAX_BODY_CHARS = 2_000_000;

export interface MedroRequest {
  model: string;
  system: string;
  messages: unknown[];
}

/** Returns the validated request, or a message describing what's wrong. */
export function parseMedroRequest(body: unknown): MedroRequest | string {
  if (typeof body !== "object" || body === null) return "body must be a JSON object";
  const { model, system, messages } = body as Record<string, unknown>;
  if (typeof model !== "string" || !ALLOWED_MODELS.has(model)) return "model is not allowed";
  if (typeof system !== "string" || system.length === 0) return "system must be a non-empty string";
  if (!Array.isArray(messages) || messages.length === 0) return "messages must be a non-empty array";
  if (JSON.stringify(body).length > MAX_BODY_CHARS) return "request is too large";
  return { model, system, messages };
}

export function tokenMatches(given: unknown, expected: string): boolean {
  if (typeof given !== "string") return false;
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

/**
 * Proxy between the MedRO app and the Messages API, so the Anthropic key
 * stays in Secret Manager instead of inside the app.
 *
 * POST with header `x-medro-token` and JSON `{model, system, messages}`;
 * the request-shaping parameters (max_tokens, effort, caching, fallbacks)
 * are fixed here rather than taken from the client. Responds with the
 * Messages API response unchanged, since MedRO replays `content` (thinking
 * blocks included) verbatim on the next turn. Errors use the Messages API
 * error shape, so the app parses both paths the same way.
 */
export const medroAsistent = onRequest(
  {
    secrets: [ANTHROPIC_API_KEY, MEDRO_ACCESS_TOKEN],
    region: "europe-west1",
    cpu: 1,
    memory: "256MiB",
    // A question over a long RCP with thinking on can take a few minutes.
    timeoutSeconds: 300,
    cors: true,
  },
  async (req, res) => {
    const fail = (status: number, type: string, message: string) => {
      res.status(status).json({ type: "error", error: { type, message } });
    };

    if (req.method !== "POST") {
      fail(405, "invalid_request_error", "POST only");
      return;
    }
    if (!tokenMatches(req.get("x-medro-token"), MEDRO_ACCESS_TOKEN.value())) {
      fail(403, "permission_error", "forbidden");
      return;
    }
    const parsed = parseMedroRequest(req.body);
    if (typeof parsed === "string") {
      fail(400, "invalid_request_error", parsed);
      return;
    }

    const anthropic = new Anthropic({
      apiKey: ANTHROPIC_API_KEY.value(),
      timeout: 280_000,
      maxRetries: 1,
    });
    try {
      // Raw post rather than messages.create: the body carries parameters
      // newer than this SDK version's types (fallbacks, top-level
      // cache_control) and is forwarded as-is.
      const message = await anthropic.post("/v1/messages", {
        headers: { "anthropic-beta": FALLBACK_BETA },
        body: {
          model: parsed.model,
          max_tokens: 16000,
          fallbacks: "default",
          cache_control: { type: "ephemeral" },
          output_config: { effort: "medium" },
          system: parsed.system,
          messages: parsed.messages,
        },
      });
      res.status(200).json(message);
    } catch (error) {
      if (error instanceof Anthropic.APIError) {
        // A rejected server key is this deployment's problem, not the
        // caller's — don't surface it as "your credentials are wrong".
        const upstreamAuth = error.status === 401 || error.status === 403;
        fail(upstreamAuth ? 502 : (error.status ?? 502), "api_error", error.message);
        return;
      }
      console.error("medroAsistent failed", error);
      fail(502, "api_error", "upstream request failed");
    }
  },
);
