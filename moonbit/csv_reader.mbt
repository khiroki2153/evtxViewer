// A minimal RFC 4180 CSV reader, standing in for Python's `csv.reader`.
// Handles quoted fields (with `""` as an escaped quote), commas/newlines
// inside quoted fields, and `\r\n` / `\r` / `\n` line endings -- but nothing
// fancier (no custom delimiters/dialects), since that's all the old
// backend's `_parse_csv` ever needed.

///|
/// Splits `text` into rows of fields. Unlike a naive `split("\n")` +
/// `split(",")`, this understands quoting, so a quoted field can contain
/// literal commas and newlines.
pub fn parse_csv_text(text : String) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  let mut fields : Array[String] = []
  let mut field = StringBuilder()
  let mut in_quotes = false
  let mut saw_any_char_in_record = false
  let chars = text.to_array()
  let n = chars.length()
  let mut i = 0
  fn end_field() -> Unit {
    fields.push(field.to_string())
    field = StringBuilder()
  }

  fn end_row() -> Unit {
    end_field()
    rows.push(fields)
    fields = []
    saw_any_char_in_record = false
  }

  while i < n {
    let ch = chars[i]
    if in_quotes {
      if ch == '"' {
        if i + 1 < n && chars[i + 1] == '"' {
          field.write_char('"')
          i = i + 2
          continue
        } else {
          in_quotes = false
          i = i + 1
          continue
        }
      } else {
        field.write_char(ch)
        i = i + 1
        continue
      }
    } else {
      match ch {
        '"' => {
          in_quotes = true
          saw_any_char_in_record = true
          i = i + 1
        }
        ',' => {
          end_field()
          saw_any_char_in_record = true
          i = i + 1
        }
        '\r' => {
          end_row()
          if i + 1 < n && chars[i + 1] == '\n' {
            i = i + 2
          } else {
            i = i + 1
          }
        }
        '\n' => {
          end_row()
          i = i + 1
        }
        _ => {
          field.write_char(ch)
          saw_any_char_in_record = true
          i = i + 1
        }
      }
    }
  }
  // Flush a trailing record that wasn't newline-terminated, but not a
  // phantom empty row from a file that ends cleanly on a newline.
  if saw_any_char_in_record || field.to_string().length() > 0 {
    end_row()
  }
  rows
}
