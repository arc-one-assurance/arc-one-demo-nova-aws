/**
 * Validación opcional de Bearer token (demo infra).
 *
 * Demo agents en Cloud Run son endpoints públicos de laboratorio: si el cliente
 * no envía Authorization, la request pasa. Si envía Bearer incorrecto → 401.
 * Si el servidor no tiene ARC_ONE_DEMO_TOKEN configurado → siempre abierto.
 */

export type AuthResult =
  | { ok: true }
  | { ok: false; reason: "invalid-token" };

const BEARER_PREFIX = "Bearer ";

export function validateBearerToken(request: Request): AuthResult {
  const expected = process.env.ARC_ONE_DEMO_TOKEN;

  if (!expected) {
    return { ok: true };
  }

  const header = request.headers.get("authorization");

  if (!header || !header.startsWith(BEARER_PREFIX)) {
    return { ok: true };
  }

  const provided = header.slice(BEARER_PREFIX.length).trim();

  if (provided !== expected) {
    return { ok: false, reason: "invalid-token" };
  }

  return { ok: true };
}
