# local/evtxviewer

New code (not vendored) written specifically for this app, compiled to JS
(`--target js`) so it runs alongside `../wasm/evtx-bridge`'s wasm output
in the browser with no server involved.

Covers everything except binary EVTX parsing (that's `../vendor/evtx`,
bridged via `../wasm/evtx-bridge`):

- `csv_reader.mbt` / `csv_parse.mbt` — CSV parsing, header normalization,
  and timestamp-column auto-detection/normalization
- `evtx_flatten.mbt` / `evtx_message.mbt` / `json_util.mbt` — flattening
  evtx-bridge's parsed JSON into this app's flat row shape
- `datetime.mbt` / `flexible_datetime.mbt` — naive-datetime parsing/
  comparison for date-range filtering
- `events.mbt` — filter/search/sort/paginate over an in-memory session
- `row_csv.mbt` — CSV row serialization for the "Copy Row (CSV)" action
- `api.mbt` — the JS-facing entry points (JSON in, JSON out; see
  `moon.pkg`'s `link.js.exports`)

## Building

```sh
moon build --target js --release
```

Output lands in `_build/js/release/build/evtxviewer.js`, copied to
`../frontend/src/wasm/evtxviewer/` (committed, so the app runs without a
build step for this package).

## Testing

```sh
moon test --target js
```
