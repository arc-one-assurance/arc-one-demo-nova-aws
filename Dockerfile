# syntax=docker/dockerfile:1.7

# Multi-stage Dockerfile for Nova on AWS App Runner (same image as GCP Cloud Run).
# Aprovecha output: "standalone" de Next.js 15 para minimizar la imagen final.

# ----------------------------------------------------------------------------
# Stage 1 — deps: instala dependencias congeladas
# ----------------------------------------------------------------------------
FROM node:24-alpine AS deps
RUN corepack enable
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack pnpm install --frozen-lockfile

# ----------------------------------------------------------------------------
# Stage 2 — builder: compila el proyecto
# ----------------------------------------------------------------------------
FROM node:24-alpine AS builder
RUN corepack enable
WORKDIR /app

ENV NEXT_TELEMETRY_DISABLED=1
# Stubs para que el build no falle por env ausente — no se usan en build.
ENV ANTHROPIC_API_KEY=sk-build-stub
ENV ARC_ONE_DEMO_TOKEN=build-stub

COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN corepack pnpm build

# ----------------------------------------------------------------------------
# Stage 3 — runner: imagen final mínima
# ----------------------------------------------------------------------------
FROM node:24-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=8080
ENV HOSTNAME=0.0.0.0

# Usuario no-root
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Standalone output ya incluye node_modules necesarios + server.js
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 8080

CMD ["node", "server.js"]
