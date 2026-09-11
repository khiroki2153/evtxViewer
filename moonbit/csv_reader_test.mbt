///|
test "parses a simple two-row csv" {
  let rows = parse_csv_text("a,b,c\n1,2,3\n")
  assert_eq(rows.length(), 2)
  assert_eq(rows[0], ["a", "b", "c"])
  assert_eq(rows[1], ["1", "2", "3"])
}

///|
test "handles a quoted field containing a comma" {
  let rows = parse_csv_text("a,\"b,c\",d\n")
  assert_eq(rows[0], ["a", "b,c", "d"])
}

///|
test "handles an escaped quote inside a quoted field" {
  let rows = parse_csv_text("\"she said \"\"hi\"\"\",b\n")
  assert_eq(rows[0], ["she said \"hi\"", "b"])
}

///|
test "handles a quoted field containing a newline" {
  let rows = parse_csv_text("a,\"line1\nline2\",c\n")
  assert_eq(rows.length(), 1)
  assert_eq(rows[0], ["a", "line1\nline2", "c"])
}

///|
test "handles CRLF line endings" {
  let rows = parse_csv_text("a,b\r\n1,2\r\n")
  assert_eq(rows.length(), 2)
  assert_eq(rows[0], ["a", "b"])
  assert_eq(rows[1], ["1", "2"])
}

///|
test "handles a trailing row with no final newline" {
  let rows = parse_csv_text("a,b\n1,2")
  assert_eq(rows.length(), 2)
  assert_eq(rows[1], ["1", "2"])
}

///|
test "does not produce a phantom empty row for a trailing newline" {
  let rows = parse_csv_text("a,b\n1,2\n")
  assert_eq(rows.length(), 2)
}

///|
test "windows event viewer style: extra unquoted trailing fields spill past the header count" {
  // this is the real-world case the old backend's _parse_csv worked around:
  // Event Viewer's CSV export leaves the message column unheaded and
  // unquoted, so a comma in the message text produces more fields than the
  // header has columns.
  let rows = parse_csv_text(
    "レベル,日付と時刻,ソース,イベント ID,タスクのカテゴリ\n情報,2026/08/21 15:09:48,Okta Verify,8140,なし,MainViewBase.OnAppStateRequested: Changing application state: NormalOutOfFocus | None\n",
  )
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].length(), 5)
  assert_eq(rows[1].length(), 6)
}

///|
test "handles an empty input" {
  let rows = parse_csv_text("")
  assert_eq(rows.length(), 0)
}
