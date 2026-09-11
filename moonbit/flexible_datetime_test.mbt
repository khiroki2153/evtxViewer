///|
test "parses YYYY/MM/DD HH:MM:SS (Windows Event Viewer CSV export style)" {
  assert_eq(
    parse_flexible_datetime("2026/08/21 15:09:48"),
    Some("2026-08-21T15:09:48"),
  )
}

///|
test "parses ISO-shaped YYYY-MM-DDTHH:MM:SS" {
  assert_eq(
    parse_flexible_datetime("2026-08-21T15:09:48"),
    Some("2026-08-21T15:09:48"),
  )
}

///|
test "parses US-style MM/DD/YYYY HH:MM:SS" {
  assert_eq(
    parse_flexible_datetime("08/21/2026 15:09:48"),
    Some("2026-08-21T15:09:48"),
  )
}

///|
test "zero-pads single-digit month/day/hour/minute/second" {
  assert_eq(parse_flexible_datetime("2026/1/2 3:4:5"), Some("2026-01-02T03:04:05"))
}

///|
test "rejects plain text" {
  assert_eq(parse_flexible_datetime("not a date"), None)
}

///|
test "rejects a bare value like a record ID" {
  assert_eq(parse_flexible_datetime("42"), None)
}

///|
test "rejects an out-of-range month" {
  assert_eq(parse_flexible_datetime("2026/13/21 15:09:48"), None)
}

///|
test "rejects empty string" {
  assert_eq(parse_flexible_datetime(""), None)
}
