# evtxViewer

A browser-based viewer for Windows Event Log (`.evtx`) and CSV exports —
search, filter by date range, sort, and copy individual rows as CSV for
evidence.

Fully client-side: files are never uploaded anywhere. `.evtx` parsing runs
in the browser via a Rust `evtx` crate compiled to WebAssembly
([`wasm/evtx-bridge/`](wasm/), on top of the unmodified, vendored parser in
[`vendor/evtx/`](vendor/)); everything else (CSV parsing, filtering,
sorting, pagination, CSV row export) runs in MoonBit compiled to JS
([`moonbit/`](moonbit/)). There is no backend and no server-side session
state — `pnpm build` produces static files you can host anywhere.

## Running

```sh
./start.sh
```

or, equivalently:

```sh
cd frontend && pnpm dev
```

Then open http://localhost:5173 and drop in a `.evtx` or `.csv` file.

## Building for deployment

```sh
cd frontend && pnpm build
```

Static output lands in `frontend/dist/` — serve it with any static file
host (no server-side runtime required).

For container-based platforms, use the root `Dockerfile`: it runs
`pnpm build` and serves `frontend/dist/` with [`serve`](https://github.com/vercel/serve)
on `$PORT` (defaults to 8080). `start.sh` is for local dev only (it starts
the Vite dev server, which doesn't bind `$PORT`) — don't point a deployment
platform's start command at it.

## Rebuilding the wasm/MoonBit layers

Only needed if you change `wasm/evtx-bridge/` or `moonbit/` — their build
output is committed under `frontend/src/wasm/`, so day-to-day frontend work
doesn't need these toolchains. See [`wasm/README.md`](wasm/README.md) and
[`moonbit/README.mbt.md`](moonbit/README.mbt.md) for exact commands.
