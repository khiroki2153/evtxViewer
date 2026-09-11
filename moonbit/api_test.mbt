///|
test "parse_evtx_records flattens evtx-bridge JSON into columns+rows" {
  let records_json =
    #|[{"event_record_id": "1", "data": {"Event": {"System": {"EventID": 4728, "Channel": "Security"}}}}]
  let out = parse_evtx_records(records_json)
  guard @json.parse(out) is Object(m) else { panic() }
  guard m.get("columns") is Some(Array(cols)) else { panic() }
  assert_eq(cols.length(), 13)
  guard m.get("rows") is Some(Array(rows)) else { panic() }
  assert_eq(rows.length(), 1)
  guard rows[0] is Object(row) else { panic() }
  guard row.get("EventId") is Some(String(event_id)) else { panic() }
  assert_eq(event_id, "4728")
  guard row.get("Channel") is Some(String(channel)) else { panic() }
  assert_eq(channel, "Security")
}

///|
test "parse_csv_records normalizes headers and detects TimeCreated" {
  let csv =
    "レベル,日付と時刻,ソース,イベント ID,タスクのカテゴリ\n情報,2026/08/21 15:09:48,Okta Verify,8140,なし,some message\n"
  let out = parse_csv_records(csv)
  guard @json.parse(out) is Object(m) else { panic() }
  guard m.get("columns") is Some(Array(cols)) else { panic() }
  let col_names = cols.filter_map(fn(c) {
    match c {
      String(s) => Some(s)
      _ => None
    }
  })
  assert_eq(col_names.contains("TimeCreated"), true)
  assert_eq(col_names.contains("Message"), true)
  guard m.get("rows") is Some(Array(rows)) else { panic() }
  guard rows[0] is Object(row) else { panic() }
  guard row.get("TimeCreated") is Some(String(time_created)) else { panic() }
  assert_eq(time_created, "2026-08-21T15:09:48")
  guard row.get("Message") is Some(String(message)) else { panic() }
  assert_eq(message, "some message")
}

///|
test "query_events_json round-trips filtering through JSON" {
  let rows_json =
    #|[{"Level": "Error"}, {"Level": "Information"}]
  let query_json =
    #|{"filters": {"Level": "error"}}
  let out = query_events_json(rows_json, query_json)
  guard @json.parse(out) is Object(m) else { panic() }
  guard m.get("total") is Some(Number(total, ..)) else { panic() }
  assert_eq(total, 1.0)
  guard m.get("records") is Some(Array(records)) else { panic() }
  assert_eq(records.length(), 1)
  guard records[0] is Object(row) else { panic() }
  guard row.get("Level") is Some(String(level)) else { panic() }
  assert_eq(level, "Error")
}

///|
test "query_events_json applies default page/page_size when omitted" {
  let rows_json =
    #|[{"Id": "1"}, {"Id": "2"}]
  let out = query_events_json(rows_json, "{}")
  guard @json.parse(out) is Object(m) else { panic() }
  guard m.get("page") is Some(Number(page, ..)) else { panic() }
  assert_eq(page, 1.0)
  guard m.get("page_size") is Some(Number(page_size, ..)) else { panic() }
  assert_eq(page_size, 100.0)
  guard m.get("total") is Some(Number(total, ..)) else { panic() }
  assert_eq(total, 2.0)
}

///|
test "row_to_csv_json serializes the requested columns in order" {
  let columns_json =
    #|["a", "b"]
  let row_json =
    #|{"a": "1", "b": "hello, world"}
  let out = row_to_csv_json(columns_json, row_json)
  assert_eq(out, "a,b\r\n1,\"hello, world\"")
}
