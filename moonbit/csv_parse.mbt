// CSV -> row parsing, mirroring the old Python backend's `_parse_csv` /
// `_detect_datetime_column` / `_rename_and_normalize_datetime`: normalizes
// a blank/duplicate-blank header into "Message"/"ColumnN", reassembles
// Windows Event Viewer's unquoted trailing message text into "Message",
// and auto-detects+normalizes a timestamp column into "TimeCreated" so CSV
// sessions get the same date-range filtering UI/behavior as evtx sessions.

///|
pub struct CsvParseResult {
  columns : Array[String]
  rows : Array[Map[String, String]]
}

///|
let datetime_header_aliases : Array[String] = [
  "timecreated", "time created", "date and time", "date/time", "datetime",
  "date time", "timestamp", "日付と時刻", "日時", "発生日時", "タイムスタンプ",
]

///|
/// Normalizes a raw CSV header row: a blank header cell becomes "Message"
/// (the first blank) or "ColumnN" (subsequent blanks), matching the old
/// backend's handling of Windows Event Viewer's unheaded message column.
fn normalize_header(header : Array[String]) -> Array[String] {
  let mut blanks_seen = 0
  header.map(fn(h) {
    let name = h.trim().to_owned()
    if name.length() == 0 {
      blanks_seen = blanks_seen + 1
      if blanks_seen == 1 {
        "Message"
      } else {
        "Column" + blanks_seen.to_string()
      }
    } else {
      name
    }
  })
}

///|
/// Parses raw CSV text into column-named rows (each also gets a
/// synthesized "RecordId"), then detects and normalizes a timestamp
/// column into "TimeCreated" if one exists.
pub fn parse_csv(text : String) -> CsvParseResult {
  let raw_rows = parse_csv_text(text)
  if raw_rows.length() == 0 {
    return CsvParseResult::{ columns: [], rows: [] }
  }
  let columns = normalize_header(raw_rows[0])
  let ncols = columns.length()
  let has_message_col = columns.contains("Message")
  let rows = []
  for i in 1..<raw_rows.length() {
    let raw_row = raw_rows[i]
    let row : Map[String, String] = Map([])
    for j = 0; j < ncols; j = j + 1 {
      row[columns[j]] = if j < raw_row.length() { raw_row[j] } else { "" }
    }
    // Windows Event Viewer's CSV export has no header at all for the
    // message text, and doesn't quote it, so a message containing commas
    // spills into extra unheaded fields at the end of the row. Reassemble
    // those trailing fields into "Message".
    if !has_message_col {
      let extra = []
      for j in ncols..<raw_row.length() {
        extra.push(raw_row[j])
      }
      row["Message"] = extra.join(",")
    }
    row["RecordId"] = (i).to_string()
    rows.push(row)
  }
  let all_columns = if has_message_col {
    columns + ["RecordId"]
  } else {
    columns + ["Message", "RecordId"]
  }
  let datetime_col = detect_datetime_column(all_columns, rows)
  match datetime_col {
    Some(col) => {
      rename_and_normalize_datetime(rows, col)
      let renamed_columns = all_columns.map(fn(c) {
        if c == col {
          "TimeCreated"
        } else {
          c
        }
      })
      CsvParseResult::{ columns: renamed_columns, rows }
    }
    None => CsvParseResult::{ columns: all_columns, rows }
  }
}

///|
/// Finds the CSV column holding the event timestamp, trying (in order): an
/// exact "TimeCreated" column (nothing to do), a header-name alias match,
/// then falling back to whichever column parses as a datetime in at least
/// 80% of a sample of its values. Mirrors the old backend's
/// `_detect_datetime_column`.
fn detect_datetime_column(
  columns : Array[String],
  rows : Array[Map[String, String]],
) -> String? {
  if columns.contains("TimeCreated") {
    return None
  }
  for c in columns {
    if datetime_header_aliases.contains(c.trim().to_owned().to_lower()) {
      return Some(c)
    }
  }
  if rows.length() == 0 {
    return None
  }
  let sample_size = if rows.length() < 50 { rows.length() } else { 50 }
  let mut best_col : String? = None
  let mut best_ratio = 0.0
  for c in columns {
    if c == "Message" || c == "RecordId" {
      continue
    }
    let mut checked = 0
    let mut matched = 0
    for i = 0; i < sample_size; i = i + 1 {
      let v = rows[i].get(c).unwrap_or("").trim().to_owned()
      if v.length() == 0 {
        continue
      }
      checked = checked + 1
      if parse_flexible_datetime(v) is Some(_) {
        matched = matched + 1
      }
    }
    if checked > 0 {
      let ratio = matched.to_double() / checked.to_double()
      if ratio > best_ratio {
        best_ratio = ratio
        best_col = Some(c)
      }
    }
  }
  if best_ratio >= 0.8 {
    best_col
  } else {
    None
  }
}

///|
/// Renames `col`'s values in place to the canonical "TimeCreated" format;
/// a value that fails to parse is left as-is (matching the old backend
/// leaving unparseable values untouched via pandas' `errors="coerce"` +
/// falling back to the raw value on NaT).
fn rename_and_normalize_datetime(
  rows : Array[Map[String, String]],
  col : String,
) -> Unit {
  for row in rows {
    match row.get(col) {
      Some(raw) => {
        let normalized = match parse_flexible_datetime(raw) {
          Some(n) => n
          None => raw
        }
        row.remove(col)
        row["TimeCreated"] = normalized
      }
      None => ()
    }
  }
}
