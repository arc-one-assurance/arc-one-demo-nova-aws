import { NextResponse } from "next/server";
import { randomUUID } from "node:crypto";
import { validateBearerToken } from "@/lib/auth";
import { checkRateLimit } from "@/lib/rate-limit";
import { getAnthropicClient, NOVA_MODEL, AGENT_VERSION } from "@/lib/client";
import { PROMPTS_BY_VERSION, DEFAULT_AGENT_VERSION } from "@/lib/prompts";

/**
 * POST /api/v1/chat
 *
 * Endpoint canónico del contrato Arc One Demo Agents.
 * Spec: arc-one-master-plan/01_Sandbox/Demo_Agents/Contrato_v1_chat.md
 */

const MAX_INPUT_CHARS = 4000;
const MAX_OUTPUT_TOKENS = 600;
const TEMPERATURE = 0.7;

type ChatRequestBody = {
  input: string;
  session_id?: string;
  metadata?: Record<string, unknown>;
};

type ChatResponseBody = {
  output: string;
  model: string;
  tokens: { input: number; output: number };
  session_id: string;
  agent_version: string;
};

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function parseBody(body: unknown): ChatRequestBody | null {
  if (!body || typeof body !== "object") return null;
  const input = Reflect.get(body, "input");
  if (typeof input !== "string" || input.trim().length === 0) return null;
  if (input.length > MAX_INPUT_CHARS) return null;

  const sessionId = Reflect.get(body, "session_id");
  if (sessionId !== undefined && typeof sessionId !== "string") return null;

  const metadata = Reflect.get(body, "metadata");
  if (metadata !== undefined && (typeof metadata !== "object" || metadata === null)) {
    return null;
  }

  return {
    input: input.trim(),
    ...(typeof sessionId === "string" ? { session_id: sessionId } : {}),
    ...(metadata && typeof metadata === "object"
      ? { metadata: metadata as Record<string, unknown> }
      : {}),
  };
}

export async function POST(request: Request): Promise<NextResponse> {
  const rateLimit = checkRateLimit(request);
  if (!rateLimit.ok) {
    return NextResponse.json(
      { error: "Rate limit exceeded", retry_after_seconds: rateLimit.retryAfterSeconds },
      {
        status: 429,
        headers: { "retry-after": String(rateLimit.retryAfterSeconds) },
      },
    );
  }

  const auth = validateBearerToken(request);
  if (!auth.ok) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let raw: unknown;
  try {
    raw = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const body = parseBody(raw);
  if (!body) {
    return NextResponse.json(
      {
        error: "Invalid body",
        expected: {
          input: "string (1-4000 chars, required)",
          session_id: "string (optional)",
          metadata: "object (optional)",
        },
      },
      { status: 400 },
    );
  }

  const sessionId = body.session_id ?? randomUUID();
  const systemPrompt = PROMPTS_BY_VERSION[AGENT_VERSION] ?? PROMPTS_BY_VERSION[DEFAULT_AGENT_VERSION];

  if (!systemPrompt) {
    return NextResponse.json(
      { error: `Unknown agent version: ${AGENT_VERSION}` },
      { status: 500 },
    );
  }

  try {
    const client = getAnthropicClient();
    const completion = await client.messages.create({
      model: NOVA_MODEL,
      max_tokens: MAX_OUTPUT_TOKENS,
      temperature: TEMPERATURE,
      system: systemPrompt,
      messages: [{ role: "user", content: body.input }],
    });

    const textBlock = completion.content.find((b) => b.type === "text");
    const output = textBlock && textBlock.type === "text" ? textBlock.text : "";

    const response: ChatResponseBody = {
      output: output.trim(),
      model: completion.model,
      tokens: {
        input: completion.usage.input_tokens,
        output: completion.usage.output_tokens,
      },
      session_id: sessionId,
      agent_version: AGENT_VERSION,
    };

    return NextResponse.json(response);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";

    // Distinguir timeout vs error genérico para devolver 504 cuando aplique
    if (message.toLowerCase().includes("timeout")) {
      console.error("[v1/chat] Anthropic timeout:", message);
      return NextResponse.json({ error: "LLM provider timeout" }, { status: 504 });
    }

    console.error("[v1/chat] Anthropic error:", message);
    return NextResponse.json({ error: "Internal agent error" }, { status: 500 });
  }
}

export function GET() {
  return NextResponse.json(
    {
      name: "Nova BBVA — AWS App Runner",
      agent_id: "nova",
      version: AGENT_VERSION,
      contract: "arc-one /v1/chat",
      method: "POST",
    },
    { status: 200 },
  );
}
