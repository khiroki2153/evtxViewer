# vendor/

Unmodified library source vendored from
[omerbenamram/EVTX](https://github.com/omerbenamram/EVTX)
@ `9c7d0b5429e86200d9e449bbdd2679cbe54b54ea`, MIT/Apache-2.0 (see
`LICENSE-MIT` / `LICENSE-APACHE` in this directory).

- `evtx/` — the `evtx` crate (binary EVTX/BinXml parsing). Only the library
  source (`src/`) was kept; the `evtx_dump` CLI, benchmarks, and
  `wevt_templates` feature (and their extra dependencies) were dropped from
  `Cargo.toml` since this app only ever uses it as a library, and
  `multithreading` (rayon) was dropped because it doesn't work on
  `wasm32-unknown-unknown` without extra web worker plumbing.
- `utf16-simd/` — `evtx`'s UTF-16 decoding dependency, vendored as-is
  (referenced by `evtx/Cargo.toml` via a local `path` dependency).

This is deliberately vendored rather than reimplemented: binary format
parsers are exactly the kind of code where "translate it into a different
language" throws away years of fuzzing and bug fixes and reintroduces the
same class of bugs from scratch. See `wasm/evtx-bridge/` for the thin
wasm-bindgen boundary written on top of this (new code, not vendored) that
exposes it to the browser.
