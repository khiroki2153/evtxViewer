// Filtering/search/sort/pagination over an in-memory session's rows,
// mirroring the old Python backend's `/api/events` endpoint
// (`get_events`). Runs entirely client-side now: a "session" is just the
// `Array[Map[String, String]]` produced by evtx_flatten.mbt/csv_parse.mbt,
// held in memory by the JS caller for as long as the tab is open.

///|
pub(all) struct EventsQuery {
  page : Int
  page_size : Int
  search : String
  sort_by : String
  sort_desc : Bool
  // column name -> filter term; a term starting with "-" excludes rows
  // containing it (same convention as `search`).
  filters : Map[String, String]
  start : String // naive datetime lower bound (inclusive), already
  // converted by the caller to whatever timezone TimeCreated is expressed in
  end : String // naive datetime upper bound (inclusive), same convention
}

///|
pub(all) struct EventsResult {
  total : Int
  page : Int
  page_size : Int
  records : Array[Map[String, String]]
}

///|
fn field_str(row : Map[String, String], col : String) -> String {
  row.get(col).unwrap_or("")
}

///|
/// Splits `term` off a leading "-" negation marker (Splunk/Gmail-style
/// exclusion), returning `(is_negated, term_without_marker)`. A bare "-"
/// (length 1) is treated as a literal term, not a negation with an empty
/// search string -- matches the old backend's `len(val) > 1` check.
fn split_negation(term : String) -> (Bool, String) {
  if term.has_prefix("-") && term.length() > 1 {
    (true, term.view(start_offset=1, end_offset=term.length()).to_owned())
  } else {
    (false, term)
  }
}

///|
fn row_matches_column_filter(
  row : Map[String, String],
  col : String,
  filter_val : String,
) -> Bool {
  let (negate, term) = split_negation(filter_val)
  let present = field_str(row, col).to_lower().contains(term.to_lower())
  present != negate
}

///|
fn row_in_date_range(
  row : Map[String, String],
  start_dt : NaiveDateTime?,
  end_dt : NaiveDateTime?,
) -> Bool {
  match parse_naive_datetime(field_str(row, "TimeCreated")) {
    None => false
    Some(dt) => {
      match start_dt {
        Some(s) => if dt < s { return false }
        None => ()
      }
      match end_dt {
        Some(e) => if dt > e { return false }
        None => ()
      }
      true
    }
  }
}

///|
fn row_matches_search_tokens(row : Map[String, String], tokens : Array[String]) -> Bool {
  for tok in tokens {
    let (negate, term) = split_negation(tok)
    let term_lower = term.to_lower()
    let mut present = false
    for v in row.values() {
      if v.to_lower().contains(term_lower) {
        present = true
        break
      }
    }
    if present == negate {
      return false
    }
  }
  true
}

///|
/// A sort key that orders numeric-looking values numerically and
/// everything else lexically after all numeric values, matching the old
/// backend's `sort_key` (tries `float(str(v))`, falls back to
/// `(1, 0.0, str(v).lower())` on failure).
priv struct SortKey {
  is_numeric : Bool
  numeric_value : Double
  string_value : String
}

///|
fn compare_sort_keys(a : SortKey, b : SortKey) -> Int {
  match (a.is_numeric, b.is_numeric) {
    (true, true) => a.numeric_value.compare(b.numeric_value)
    (false, false) => a.string_value.compare(b.string_value)
    (true, false) => -1
    (false, true) => 1
  }
}

///|
fn make_sort_key(v : String) -> SortKey {
  match try_parse_double(v) {
    Some(n) => SortKey::{ is_numeric: true, numeric_value: n, string_value: "" }
    None =>
      SortKey::{ is_numeric: false, numeric_value: 0.0, string_value: v.to_lower() }
  }
}

///|
fn try_parse_double(s : String) -> Double? {
  try {
    Some(@string.parse_double(s))
  } catch {
    _ => None
  }
}

///|
/// Runs the full filter -> date-range -> search -> sort -> paginate
/// pipeline over `records`, mirroring the old backend's `get_events`.
pub fn query_events(
  records : Array[Map[String, String]],
  query : EventsQuery,
) -> EventsResult {
  let mut result = records

  for col, val in query.filters {
    if val.length() == 0 {
      continue
    }
    result = result.filter(fn(r) { row_matches_column_filter(r, col, val) })
  }
  let start_dt = if query.start.length() > 0 {
    parse_naive_datetime(query.start)
  } else {
    None
  }
  let end_dt = if query.end.length() > 0 {
    parse_naive_datetime(query.end)
  } else {
    None
  }
  if start_dt is Some(_) || end_dt is Some(_) {
    result = result.filter(fn(r) { row_in_date_range(r, start_dt, end_dt) })
  }
  if query.search.length() > 0 {
    let tokens : Array[String] = query.search
      .split(" ")
      .map(fn(s) { s.to_owned() })
      .filter(fn(s) { s.length() > 0 })
      .collect()
    result = result.filter(fn(r) { row_matches_search_tokens(r, tokens) })
  }
  let total = result.length()
  if query.sort_by.length() > 0 {
    let sort_by = query.sort_by
    let keyed = result.map(fn(r) { (make_sort_key(field_str(r, sort_by)), r) })
    keyed.sort_by(fn(a, b) { compare_sort_keys(a.0, b.0) })
    result = keyed.map(fn(kv) { kv.1 })
    if query.sort_desc {
      result = result.rev_iter().collect()
    }
  }
  let page_start_raw = (query.page - 1) * query.page_size
  let page_start = if page_start_raw < 0 { 0 } else { page_start_raw }
  let page_end_raw = page_start + query.page_size
  let page_end = if page_end_raw > total { total } else { page_end_raw }
  let page_records = if page_start >= total {
    []
  } else {
    result[page_start:page_end].to_owned()
  }
  EventsResult::{
    total,
    page: query.page,
    page_size: query.page_size,
    records: page_records,
  }
}
