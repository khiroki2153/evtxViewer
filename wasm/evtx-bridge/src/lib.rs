// Thin wasm-bindgen boundary over the vendored `evtx` crate (see
// ../../vendor/evtx). All binary EVTX/BinXml parsing happens inside that
// vendored crate, unmodified; this file only adapts its API to JS.
//
// We deliberately keep this surface tiny and dumb: take raw file bytes, hand
// back the same `{event_record_id, data}` shape the old Python backend's
// `evtx.PyEvtxParser.records_json()` produced (see backend/main.py, now
// removed, for the shape this mirrors). Everything past that point --
// flattening `Event.System`/`EventData`/`UserData` into flat table rows --
// is application logic, not parser logic, and lives in the MoonBit layer
// instead.

use evtx::EvtxParser;
use serde_json::Value;
use std::io::Cursor;
use wasm_bindgen::prelude::*;

#[wasm_bindgen(start)]
pub fn main() {
    console_error_panic_hook::set_once();
}

/// Parses an entire .evtx file (already read into memory by the caller) and
/// returns a JSON string: an array of `{ "event_record_id": string, "data": <parsed Event JSON> }`.
///
/// `event_record_id` is returned as a string (not a JS number) because EVTX
/// record IDs are 64-bit and can exceed `Number.MAX_SAFE_INTEGER`.
///
/// Records evtx itself couldn't parse (corrupt chunk, truncated file, etc.)
/// are silently skipped, matching the old backend's behavior of catching and
/// discarding per-record errors rather than failing the whole file.
#[wasm_bindgen]
pub fn parse_evtx(data: &[u8]) -> Result<String, JsError> {
    let cursor = Cursor::new(data);
    // Default settings: System fields render as `{"#attributes": {...},
    // "#text": ...}` (see moonbit/json_util.mbt's json_attr/json_scalar),
    // and EventData/UserData render as a flat `{"FieldName": "value"}` map
    // directly -- there's no separate attributes shape to opt into for
    // those (see moonbit/evtx_message.mbt).
    let mut parser = EvtxParser::from_read_seek(cursor)
        .map_err(|e| JsError::new(&format!("Failed to open EVTX file: {e}")))?;

    let mut out: Vec<Value> = Vec::new();
    for record in parser.records_json_value() {
        let Ok(record) = record else { continue };
        out.push(serde_json::json!({
            "event_record_id": record.event_record_id.to_string(),
            "data": record.data,
        }));
    }

    serde_json::to_string(&out).map_err(|e| JsError::new(&format!("Failed to serialize records: {e}")))
}
