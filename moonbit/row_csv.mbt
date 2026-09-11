// Serializes a single row as CSV text (header line + value line), for the
// "Copy Row (CSV)" clipboard action -- mirrors the frontend's old
// `toCsvField`/`rowToCsv` (RFC 4180: quote a field only if it contains a
// comma, quote, or newline; escape an embedded quote by doubling it).

///|
fn csv_field(v : String) -> String {
  let needs_quoting = v.contains(",") || v.contains("\"") || v.contains("\n") || v.contains(
    "\r",
  )
  if needs_quoting {
    "\"" + v.replace_all(old="\"", new="\"\"") + "\""
  } else {
    v
  }
}

///|
/// Renders `row` as a two-line CSV string (header, then values, CRLF
/// terminated between them) in `columns` order -- the same order the table
/// UI displays columns in.
pub fn row_to_csv(columns : Array[String], row : Map[String, String]) -> String {
  let header = columns.map(fn(c) { csv_field(c) }).join(",")
  let values = columns.map(fn(c) { csv_field(row.get(c).unwrap_or("")) }).join(",")
  header + "\r\n" + values
}
