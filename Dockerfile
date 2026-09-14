FROM node:20-slim
WORKDIR /app
RUN npm install -g pnpm serve
COPY frontend/ ./frontend/
WORKDIR /app/frontend
RUN pnpm install --frozen-lockfile && pnpm build
EXPOSE 8080
CMD ["sh", "-c", "serve dist -l ${PORT:-8080} -s"]
