import Anthropic from "@anthropic-ai/sdk";

/**
 * Cliente Anthropic singleton.
 *
 * Lee `ANTHROPIC_API_KEY` del env. La key se inyecta en Cloud Run vía Secret Manager
 * — no se commitea bajo ninguna circunstancia.
 */

let cachedClient: Anthropic | null = null;

export function getAnthropicClient(): Anthropic {
  if (cachedClient) return cachedClient;

  const apiKey = process.env.ANTHROPIC_API_KEY;

  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY no está configurada");
  }

  cachedClient = new Anthropic({ apiKey });
  return cachedClient;
}

/** Modelo por default para Nova. Configurable vía env. */
export const NOVA_MODEL = process.env.NOVA_MODEL ?? "claude-sonnet-4-6";

/** Versión del agente por default. */
export const AGENT_VERSION = process.env.ARC_ONE_AGENT_VERSION ?? "1.0.0";
