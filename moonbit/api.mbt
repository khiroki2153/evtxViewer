// JS-facing entry points, exported via moon.pkg's link.js.exports. Every
// function here takes/returns plain strings (JSON in, JSON out) so the JS
// side never needs to know about MoonBit's Map/Array/Json types -- it's
// just JSON.parse/JSON.stringify on both ends, same as talking to a REST
// API, except there's no network hop and no server.

///|
fn json_to_row(j : Json) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  match j {
    Object(m) =>
      for k, v in m {
        out[k] = json_leaf_to_string(v)
      }
    _ => ()
  }
  out
}

///|
fn row_to_json(row : Map[String, String]) -> Json {
  let obj : Map[String, Json] = Map([])
  for k, v in row {
    obj[k] = Json::string(v)
  }
  Json::object(obj)
}

///|
fn rows_to_json(rows : Array[Map[String, String]]) -> Json {
  Json::array(rows.map(fn(r) { row_to_json(r) }))
}

///|
/// Parses evtx-bridge's `parse_evtx()` JSON output (an array of
/// `{"event_record_id": string, "data": <Event JSON>}`) into this app's
/// row shape, and returns `{"columns": [...], "rows": [...]}` as JSON.
pub fn parse_evtx_records(records_json : String) -> String {
  let records = match (try @json.parse(records_json) catch { _ => Json::array([]) }) {
    Array(items) => items
    _ => []
  }
  let rows = []
  for record in records {
    match record {
      Object(m) => {
        let rid = match m.get("event_record_id") {
          Some(v) => json_leaf_to_string(v)
          None => ""
        }
        match m.get("data") {
          Some(data) => rows.push(flatten_evtx_record(rid, data))
          None => ()
        }
      }
      _ => ()
    }
  }
  let out : Map[String, Json] = {
    "columns": Json::array(evtx_columns.map(fn(c) { Json::string(c) })),
    "rows": rows_to_json(rows),
  }
  Json::object(out).stringify()
}

///|
/// Parses raw CSV text into `{"columns": [...], "rows": [...]}` JSON (see
/// csv_parse.mbt for header normalization / datetime detection).
pub fn parse_csv_records(csv_text : String) -> String {
  let result = parse_csv(csv_text)
  let out : Map[String, Json] = {
    "columns": Json::array(result.columns.map(fn(c) { Json::string(c) })),
    "rows": rows_to_json(result.rows),
  }
  Json::object(out).stringify()
}

///|
fn json_to_string_array(j : Json?) -> Array[String] {
  match j {
    Some(Array(items)) =>
      items.filter_map(fn(item) {
        match item {
          String(s) => Some(s)
          _ => None
        }
      })
    _ => []
  }
}

///|
fn json_to_string_map(j : Json?) -> Map[String, String] {
  match j {
    Some(Object(m)) => {
      let out : Map[String, String] = Map([])
      for k, v in m {
        out[k] = json_leaf_to_string(v)
      }
      out
    }
    _ => Map([])
  }
}

///|
fn json_to_int(j : Json?, default_val : Int) -> Int {
  match j {
    Some(Number(n, ..)) => n.to_int()
    _ => default_val
  }
}

///|
fn json_to_bool(j : Json?, default_val : Bool) -> Bool {
  match j {
    Some(True) => true
    Some(False) => false
    _ => default_val
  }
}

///|
fn json_to_string(j : Json?, default_val : String) -> String {
  match j {
    Some(String(s)) => s
    _ => default_val
  }
}

///|
/// Runs the filter/search/date-range/sort/paginate pipeline. `rows_json` is
/// an array of row objects (as produced by `parse_evtx_records`/
/// `parse_csv_records`); `query_json` is
/// `{page, page_size, search, sort_by, sort_desc, filters, start, end}`
/// (every field optional; see `EventsQuery`'s defaults). Returns
/// `{"total", "page", "page_size", "records"}` as JSON.
pub fn query_events_json(rows_json : String, query_json : String) -> String {
  let rows = match (try @json.parse(rows_json) catch { _ => Json::array([]) }) {
    Array(items) => items.map(fn(item) { json_to_row(item) })
    _ => []
  }
  let q = try @json.parse(query_json) catch { _ => Json::object({}) }
  let query = EventsQuery::{
    page: json_to_int(json_get(q, "page"), 1),
    page_size: json_to_int(json_get(q, "page_size"), 100),
    search: json_to_string(json_get(q, "search"), ""),
    sort_by: json_to_string(json_get(q, "sort_by"), ""),
    sort_desc: json_to_bool(json_get(q, "sort_desc"), false),
    filters: json_to_string_map(json_get(q, "filters")),
    start: json_to_string(json_get(q, "start"), ""),
    end: json_to_string(json_get(q, "end"), ""),
  }
  let result = query_events(rows, query)
  let out : Map[String, Json] = {
    "total": Json::number(result.total.to_double()),
    "page": Json::number(result.page.to_double()),
    "page_size": Json::number(result.page_size.to_double()),
    "records": rows_to_json(result.records),
  }
  Json::object(out).stringify()
}

///|
/// Serializes one row as CSV text (see row_csv.mbt) for the "Copy Row
/// (CSV)" clipboard action. `columns_json` is a JSON string array;
/// `row_json` is a JSON row object.
pub fn row_to_csv_json(columns_json : String, row_json : String) -> String {
  let columns = json_to_string_array(
    Some(try @json.parse(columns_json) catch { _ => Json::array([]) }),
  )
  let row = json_to_row(try @json.parse(row_json) catch { _ => Json::object({}) })
  row_to_csv(columns, row)
}
