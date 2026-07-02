/**
 * Rate limiter in-memory por IP.
 *
 * 10 req/min default según el contrato del Sandbox. In-memory funciona porque
 * cada instancia de Cloud Run mantiene su contador — para demos con tráfico
 * bajo es aceptable. Si se necesita rate limit cross-instance, migrar a Redis.
 */

const WINDOW_MS = 60_000;
const DEFAULT_MAX_REQ_PER_WINDOW = 10;

type Bucket = { count: number; resetAt: number };

const buckets = new Map<string, Bucket>();

function clientKey(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for");
  if (forwarded) return forwarded.split(",")[0]?.trim() ?? "unknown";
  return request.headers.get("x-real-ip") ?? "unknown";
}

export type RateLimitResult =
  | { ok: true; remaining: number }
  | { ok: false; retryAfterSeconds: number };

export function checkRateLimit(
  request: Request,
  max: number = DEFAULT_MAX_REQ_PER_WINDOW,
): RateLimitResult {
  const key = clientKey(request);
  const now = Date.now();
  const existing = buckets.get(key);

  if (!existing || existing.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + WINDOW_MS });
    return { ok: true, remaining: max - 1 };
  }

  if (existing.count >= max) {
    return {
      ok: false,
      retryAfterSeconds: Math.ceil((existing.resetAt - now) / 1000),
    };
  }

  existing.count += 1;
  return { ok: true, remaining: max - existing.count };
}
