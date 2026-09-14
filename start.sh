#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Local dev only. For production/deployment, see Dockerfile (builds and
# serves frontend/dist as static files on $PORT) -- this script starts the
# Vite dev server, which doesn't bind $PORT and isn't meant to be exposed.
#
# Fully client-side now (see moonbit/ and wasm/evtx-bridge/) -- no backend
# process to start.
cd "$ROOT/frontend"
echo "Frontend: http://localhost:5173"
exec pnpm dev
