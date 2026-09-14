# Build stage: any Node image works here, since this stage's output isn't
# what ships -- only frontend/dist and serve.mjs get copied into the
# runtime stage below.
FROM node:20-slim AS build
WORKDIR /app
RUN npm install -g pnpm
COPY frontend/ ./frontend/
WORKDIR /app/frontend
RUN pnpm install --frozen-lockfile && pnpm build

# Runtime stage: must be a Chainguard image per internal policy. This is
# node's *distroless* tag (no shell, no npm) -- serve.mjs is plain Node
# with no dependencies so nothing needs installing here.
FROM cgr.dev/chainguard/node:latest
WORKDIR /app
COPY --from=build --chown=node:node /app/frontend/dist ./dist
COPY --chown=node:node serve.mjs .
ENV PORT=8080
EXPOSE 8080
CMD ["serve.mjs"]
