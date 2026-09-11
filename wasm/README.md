# wasm/

New code (not vendored) written specifically for this app.

- `evtx-bridge/` — a thin `wasm-bindgen` boundary over `../vendor/evtx`
  (the vendored, unmodified `evtx` crate). Exposes exactly one function,
  `parse_evtx(data: &[u8]) -> String`, that hands back the parsed
  records as a JSON string. All binary EVTX/BinXml parsing happens inside
  the vendored crate; this file only adapts its API to JS.

## Rebuilding

```sh
cd wasm/evtx-bridge
wasm-pack build --target web --release --out-dir ../../frontend/src/wasm/evtx-bridge
```

Requires `rustc`/`cargo` (with the `wasm32-unknown-unknown` target) and
`wasm-pack`. The build output under `frontend/src/wasm/evtx-bridge/` is
committed so the app runs without a build step for this crate.
