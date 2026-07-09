# ── Stage 1: Install dependencies ──────────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files first — Docker caches this layer separately.
# If you only change src code (not package.json), Docker skips npm ci on rebuild.
COPY package*.json ./
RUN npm ci

COPY . .


# ── Stage 2: Production image ───────────────────────────────────────────────
FROM node:18-alpine AS production

# Create a non-root user — running as root inside a container is a security risk
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

# Copy only the source code from the builder stage (not node_modules or dev files)
COPY --from=builder /app/src ./src

RUN chown -R nodeuser:nodejs /app
USER nodeuser

EXPOSE 3000

# Docker will ping /health every 30s. If it fails 3 times, the container is marked unhealthy.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
