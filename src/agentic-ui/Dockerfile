# Build stage
# NODE_IMAGE defaults to the public Docker Hub image. CI/azd overrides it with the
# project ACR-hosted copy (cr*.azurecr.io/node:20-slim) to avoid Docker Hub anonymous
# pull rate limits on the remote build agents.
ARG NODE_IMAGE=node:20-slim
FROM ${NODE_IMAGE} AS base

FROM base AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY . .
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Leverage Next.js standalone output to reduce image size.
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
