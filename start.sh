#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Fully client-side now (see moonbit/ and wasm/evtx-bridge/) -- no backend
# process to start.
cd "$ROOT/frontend"
echo "Frontend: http://localhost:5173"
exec pnpm dev
