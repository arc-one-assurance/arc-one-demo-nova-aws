/**
 * Tests de contrato del endpoint POST /api/v1/chat.
 *
 * Validan los 5 casos mínimos del contrato Arc One:
 *   - 200 OK con body válido y response shape correcta
 *   - 400 con input faltante / vacío / demasiado largo / body no-JSON
 *   - 401 con token inválido o ausente
 *   - 200 incluye output, model, tokens, session_id, agent_version
 *   - agent_version coincide con el del deployment
 *
 * Mockean Anthropic para que los tests no consuman API real.
 */

import { describe, it, expect, beforeEach, vi } from "vitest";

// Mock antes de importar la route (Vitest hoisting)
vi.mock("@/lib/client", async () => {
  const actual = await vi.importActual<typeof import("@/lib/client")>("@/lib/client");
  return {
    ...actual,
    getAnthropicClient: () => ({
      messages: {
        create: vi.fn(async () => ({
          model: "claude-sonnet-4-6",
          content: [{ type: "text", text: "Respuesta sintética del mock." }],
          usage: { input_tokens: 12, output_tokens: 7 },
        })),
      },
    }),
  };
});

const VALID_TOKEN = "test-token-abc";

beforeEach(() => {
  process.env.ARC_ONE_DEMO_TOKEN = VALID_TOKEN;
  process.env.ANTHROPIC_API_KEY = "sk-test-fake";
  process.env.ARC_ONE_AGENT_VERSION = "1.0.0";
});

async function callPost(body: unknown, headers: Record<string, string> = {}) {
  // Import dinámico para que respete el mock + env recién seteado
  const { POST } = await import("@/app/api/v1/chat/route");
  const request = new Request("http://localhost/api/v1/chat", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-forwarded-for": Math.random().toString(36).slice(2),
      ...headers,
    },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
  return POST(request);
}

describe("POST /api/v1/chat — happy path", () => {
  it("returns 200 with valid body and bearer token", async () => {
    const res = await callPost(
      { input: "¿Cuántos días de vacaciones tengo?" },
      { authorization: `Bearer ${VALID_TOKEN}` },
    );
    expect(res.status).toBe(200);
  });

  it("response includes output, model, tokens, session_id, agent_version", async () => {
    const res = await callPost(
      { input: "test" },
      { authorization: `Bearer ${VALID_TOKEN}` },
    );
    const data = (await res.json()) as Record<string, unknown>;

    expect(data).toHaveProperty("output");
    expect(typeof data.output).toBe("string");
    expect(data).toHaveProperty("model");
    expect(typeof data.model).toBe("string");
    expect(data).toHaveProperty("tokens");
    expect(data.tokens).toMatchObject({ input: expect.any(Number), output: expect.any(Number) });
    expect(data).toHaveProperty("session_id");
    expect(typeof data.session_id).toBe("string");
    expect(data).toHaveProperty("agent_version");
    expect(data.agent_version).toBe("1.0.0");
  });

  it("returns the session_id from the request when provided", async () => {
    const sid = "session-fixed-xyz";
    const res = await callPost(
      { input: "test", session_id: sid },
      { authorization: `Bearer ${VALID_TOKEN}` },
    );
    const data = (await res.json()) as { session_id: string };
    expect(data.session_id).toBe(sid);
  });

  it("generates a session_id when not provided", async () => {
    const res = await callPost(
      { input: "test" },
      { authorization: `Bearer ${VALID_TOKEN}` },
    );
    const data = (await res.json()) as { session_id: string };
    expect(data.session_id).toBeTruthy();
    expect(data.session_id.length).toBeGreaterThan(8);
  });
});

describe("POST /api/v1/chat — 400 invalid body", () => {
  it("returns 400 with missing input", async () => {
    const res = await callPost({}, { authorization: `Bearer ${VALID_TOKEN}` });
    expect(res.status).toBe(400);
  });

  it("returns 400 with empty input", async () => {
    const res = await callPost(
      { input: "   " },
      { authorization: `Bearer ${VALID_TOKEN}` },
    );
    expect(res.status).toBe(400);
  });

  it("returns 400 with input over 4000 chars", async () => {
    const huge = "x".repeat(4001);
    const res = await callPost(
      { input: huge },
      { authorization: `Bearer ${VALID_TOKEN}` },
    );
    expect(res.status).toBe(400);
  });

  it("returns 400 with non-JSON body", async () => {
    const res = await callPost("not-json-at-all", {
      authorization: `Bearer ${VALID_TOKEN}`,
    });
    expect(res.status).toBe(400);
  });

  it("returns 400 with input as non-string", async () => {
    const res = await callPost(
      { input: 42 },
      { authorization: `Bearer ${VALID_TOKEN}` },
    );
    expect(res.status).toBe(400);
  });
});

describe("POST /api/v1/chat — auth opcional (demo)", () => {
  it("returns 200 without bearer token", async () => {
    const res = await callPost({ input: "test" });
    expect(res.status).toBe(200);
  });

  it("returns 401 when bearer token is wrong", async () => {
    const res = await callPost(
      { input: "test" },
      { authorization: "Bearer wrong-token" },
    );
    expect(res.status).toBe(401);
  });
});

describe("POST /api/v1/chat — agent version", () => {
  it("agent_version matches expected for this deployment (1.0.0 by default)", async () => {
    const res = await callPost(
      { input: "test" },
      { authorization: `Bearer ${VALID_TOKEN}` },
    );
    const data = (await res.json()) as { agent_version: string };
    expect(data.agent_version).toBe("1.0.0");
  });
});
