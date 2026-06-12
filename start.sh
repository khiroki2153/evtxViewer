#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Start backend
cd "$ROOT"
.venv/bin/uvicorn backend.main:app --host 127.0.0.1 --port 8000 --reload &
BACKEND_PID=$!

# Start frontend
cd "$ROOT/frontend"
pnpm dev &
FRONTEND_PID=$!

trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null" EXIT INT TERM
echo "Backend: http://localhost:8000"
echo "Frontend: http://localhost:5173"
wait
