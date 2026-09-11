///|
test "flattens a representative evtx-bridge record" {
  let raw =
    #|{
    #|  "event_record_id": "111",
    #|  "data": {
    #|    "Event": {
    #|      "System": {
    #|        "Provider": {"#attributes": {"Name": "Microsoft-Windows-Security-Auditing"}},
    #|        "EventID": 4728,
    #|        "Level": 0,
    #|        "Task": 13826,
    #|        "Keywords": "0x8020000000000000",
    #|        "TimeCreated": {"#attributes": {"SystemTime": "2013-10-23T16:22:39.973500Z"}},
    #|        "Channel": "Security",
    #|        "Computer": "WIN-HOST.example.com",
    #|        "Execution": {"#attributes": {"ProcessID": 508, "ThreadID": 632}},
    #|        "Security": {"#attributes": {"UserID": "S-1-5-18"}}
    #|      },
    #|      "EventData": {
    #|        "MemberName": "alice",
    #|        "TargetGroupName": "Administrators"
    #|      }
    #|    }
    #|  }
    #|}
  guard @json.parse(raw) is Object(top) else { panic() }
  guard top.get("event_record_id") is Some(String(rid)) else { panic() }
  guard top.get("data") is Some(data) else { panic() }
  let row = flatten_evtx_record(rid, data)
  assert_eq(row.get("RecordId"), Some("111"))
  assert_eq(row.get("EventId"), Some("4728"))
  // Level 0 has no name in the Windows Event Log level table (only 1-5 do);
  // matches the old backend's `_level_name` falling back to the raw value.
  assert_eq(row.get("Level"), Some("0"))
  assert_eq(row.get("Provider"), Some("Microsoft-Windows-Security-Auditing"))
  assert_eq(row.get("TimeCreated"), Some("2013-10-23T16:22:39.973500Z"))
  assert_eq(row.get("Channel"), Some("Security"))
  assert_eq(row.get("Computer"), Some("WIN-HOST.example.com"))
  assert_eq(row.get("ProcessId"), Some("508"))
  assert_eq(row.get("ThreadId"), Some("632"))
  assert_eq(row.get("UserId"), Some("S-1-5-18"))
  assert_eq(row.get("Task"), Some("13826"))
  assert_eq(row.get("Keywords"), Some("0x8020000000000000"))
  assert_eq(row.get("Message"), Some("MemberName=alice, TargetGroupName=Administrators"))
}

///|
test "handles EventID rendered as an object with #text" {
  let raw =
    #|{
    #|  "event_record_id": "5",
    #|  "data": {
    #|    "Event": {
    #|      "System": {
    #|        "EventID": {"#attributes": {"Qualifiers": "16384"}, "#text": "999"}
    #|      }
    #|    }
    #|  }
    #|}
  guard @json.parse(raw) is Object(top) else { panic() }
  guard top.get("data") is Some(data) else { panic() }
  let row = flatten_evtx_record("5", data)
  assert_eq(row.get("EventId"), Some("999"))
}

///|
test "unknown level number falls back to the raw string" {
  let raw =
    #|{
    #|  "event_record_id": "1",
    #|  "data": {"Event": {"System": {"Level": 42}}}
    #|}
  guard @json.parse(raw) is Object(top) else { panic() }
  guard top.get("data") is Some(data) else { panic() }
  let row = flatten_evtx_record("1", data)
  assert_eq(row.get("Level"), Some("42"))
}

///|
test "produces the fixed evtx_columns order" {
  assert_eq(evtx_columns.length(), 13)
  assert_eq(evtx_columns[0], "TimeCreated")
  assert_eq(evtx_columns[4], "Message")
}
