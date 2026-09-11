///|
test "parses a simple csv with a proper header, no datetime column detected" {
  let result = parse_csv("a,b\n1,2\n3,4\n")
  // no "Message" header and no trailing overflow fields -> Message is
  // synthesized as empty, matching the old backend's behavior exactly
  // (`if not has_message_col: clean["Message"] = ",".join(row[ncols:])`,
  // which is "" when there's no overflow).
  assert_eq(result.columns, ["a", "b", "Message", "RecordId"])
  assert_eq(result.rows.length(), 2)
  assert_eq(result.rows[0].get("a"), Some("1"))
  assert_eq(result.rows[0].get("b"), Some("2"))
  assert_eq(result.rows[0].get("Message"), Some(""))
  assert_eq(result.rows[0].get("RecordId"), Some("1"))
  assert_eq(result.rows[1].get("RecordId"), Some("2"))
}

///|
test "reassembles Windows Event Viewer's unheaded trailing message text" {
  // the exact real-world sample the user reported: 5 header columns, but
  // the (unheaded, unquoted) message text spills the row to 6 fields.
  let text =
    "レベル,日付と時刻,ソース,イベント ID,タスクのカテゴリ\n情報,2026/08/21 15:09:48,Okta Verify,8140,なし,MainViewBase.OnAppStateRequested: Changing application state: NormalOutOfFocus | None\n"
  let result = parse_csv(text)
  assert_eq(result.columns.contains("Message"), true)
  assert_eq(result.columns.contains("TimeCreated"), true)
  let row = result.rows[0]
  assert_eq(
    row.get("Message"),
    Some("MainViewBase.OnAppStateRequested: Changing application state: NormalOutOfFocus | None"),
  )
  assert_eq(row.get("TimeCreated"), Some("2026-08-21T15:09:48"))
  assert_eq(row.get("レベル"), Some("情報"))
  assert_eq(row.get("ソース"), Some("Okta Verify"))
  assert_eq(row.get("イベント ID"), Some("8140"))
}

///|
test "a message containing a literal comma is rejoined correctly" {
  let text = "H1,H2\nv1,v2,part-a,part-b\n"
  let result = parse_csv(text)
  let row = result.rows[0]
  assert_eq(row.get("Message"), Some("part-a,part-b"))
}

///|
test "detects a datetime column by header alias" {
  let result = parse_csv("Timestamp,Message\n2026-01-02T03:04:05,hi\n")
  assert_eq(result.columns.contains("TimeCreated"), true)
  assert_eq(result.rows[0].get("TimeCreated"), Some("2026-01-02T03:04:05"))
}

///|
test "detects a datetime column by content when no header alias matches" {
  let result = parse_csv("WhenItHappened,Msg\n2026/01/02 03:04:05,hi\n2026/01/03 04:05:06,bye\n")
  assert_eq(result.columns.contains("TimeCreated"), true)
  assert_eq(result.columns.contains("WhenItHappened"), false)
}

///|
test "does not misdetect a non-datetime column" {
  let result = parse_csv("Id,Msg\n1,hi\n2,bye\n3,yo\n")
  assert_eq(result.columns.contains("TimeCreated"), false)
}

///|
test "leaves an existing TimeCreated column alone" {
  let result = parse_csv("TimeCreated,Msg\n2026-01-02T03:04:05,hi\n")
  assert_eq(result.columns, ["TimeCreated", "Msg", "Message", "RecordId"])
  assert_eq(result.rows[0].get("TimeCreated"), Some("2026-01-02T03:04:05"))
}

///|
test "handles an empty csv" {
  let result = parse_csv("")
  assert_eq(result.columns, [])
  assert_eq(result.rows.length(), 0)
}

///|
test "handles a header-only csv with no data rows" {
  let result = parse_csv("a,b\n")
  assert_eq(result.rows.length(), 0)
}
