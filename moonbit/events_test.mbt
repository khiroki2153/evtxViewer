///|
fn row(pairs : Array[(String, String)]) -> Map[String, String] {
  let m : Map[String, String] = {}
  for p in pairs {
    m[p.0] = p.1
  }
  m
}

///|
fn make_query(
  page~ : Int = 1,
  page_size~ : Int = 100,
  search~ : String = "",
  sort_by~ : String = "",
  sort_desc~ : Bool = false,
  filters~ : Map[String, String] = {},
  start~ : String = "",
  end~ : String = "",
) -> EventsQuery {
  EventsQuery::{
    page: page,
    page_size: page_size,
    search: search,
    sort_by: sort_by,
    sort_desc: sort_desc,
    filters: filters,
    start: start,
    end: end,
  }
}

///|
test "returns all rows unfiltered, respecting page_size" {
  let rows = [
    row([("Message", "hello")]),
    row([("Message", "world")]),
  ]
  let result = query_events(rows, make_query())
  assert_eq(result.total, 2)
  assert_eq(result.records.length(), 2)
}

///|
test "column filter matches case-insensitively" {
  let rows = [row([("Provider", "Microsoft-Windows-Security")]), row([("Provider", "Okta Verify")])]
  let q = make_query(filters={ "Provider": "okta" })
  let result = query_events(rows, q)
  assert_eq(result.total, 1)
  assert_eq(result.records[0].get("Provider"), Some("Okta Verify"))
}

///|
test "a column filter prefixed with - excludes matching rows" {
  let rows = [row([("Level", "Error")]), row([("Level", "Information")])]
  let q = make_query(filters={ "Level": "-error" })
  let result = query_events(rows, q)
  assert_eq(result.total, 1)
  assert_eq(result.records[0].get("Level"), Some("Information"))
}

///|
test "search ANDs space-separated tokens across all fields" {
  let rows = [
    row([("Message", "logon failure for alice")]),
    row([("Message", "logon success for bob")]),
  ]
  let q = make_query(search="logon failure")
  let result = query_events(rows, q)
  assert_eq(result.total, 1)
  assert_eq(result.records[0].get("Message"), Some("logon failure for alice"))
}

///|
test "a search token prefixed with - excludes rows containing it anywhere" {
  let rows = [
    row([("Message", "logon failure")]),
    row([("Message", "logon success")]),
  ]
  let q = make_query(search="logon -failure")
  let result = query_events(rows, q)
  assert_eq(result.total, 1)
  assert_eq(result.records[0].get("Message"), Some("logon success"))
}

///|
test "date range filter keeps rows within [start, end] inclusive" {
  let rows = [
    row([("TimeCreated", "2026-01-01T00:00:00")]),
    row([("TimeCreated", "2026-01-05T00:00:00")]),
    row([("TimeCreated", "2026-01-10T00:00:00")]),
  ]
  let q = make_query(start="2026-01-02T00:00:00", end="2026-01-08T00:00:00")
  let result = query_events(rows, q)
  assert_eq(result.total, 1)
  assert_eq(result.records[0].get("TimeCreated"), Some("2026-01-05T00:00:00"))
}

///|
test "a row with an unparseable TimeCreated is excluded once a date filter is active" {
  let rows = [row([("TimeCreated", "not a date")]), row([("TimeCreated", "2026-01-05T00:00:00")])]
  let q = make_query(start="2026-01-01T00:00:00")
  let result = query_events(rows, q)
  assert_eq(result.total, 1)
}

///|
test "sorts numerically when values parse as numbers" {
  let rows = [row([("EventId", "100")]), row([("EventId", "20")]), row([("EventId", "3")])]
  let q = make_query(sort_by="EventId")
  let result = query_events(rows, q)
  assert_eq(result.records.map(fn(r) { r.get("EventId") }), [Some("3"), Some("20"), Some("100")])
}

///|
test "numeric values sort before non-numeric values, ascending" {
  let rows = [row([("V", "abc")]), row([("V", "5")])]
  let q = make_query(sort_by="V")
  let result = query_events(rows, q)
  assert_eq(result.records.map(fn(r) { r.get("V") }), [Some("5"), Some("abc")])
}

///|
test "sort_desc reverses the sort order" {
  let rows = [row([("EventId", "1")]), row([("EventId", "2")]), row([("EventId", "3")])]
  let q = make_query(sort_by="EventId", sort_desc=true)
  let result = query_events(rows, q)
  assert_eq(
    result.records.map(fn(r) { r.get("EventId") }),
    [Some("3"), Some("2"), Some("1")],
  )
}

///|
test "sorts strings lexically case-insensitively" {
  let rows = [row([("V", "banana")]), row([("V", "Apple")]), row([("V", "cherry")])]
  let q = make_query(sort_by="V")
  let result = query_events(rows, q)
  assert_eq(
    result.records.map(fn(r) { r.get("V") }),
    [Some("Apple"), Some("banana"), Some("cherry")],
  )
}

///|
test "pagination slices by page/page_size and total reflects the filtered count" {
  let rows = [
    row([("Id", "1")]), row([("Id", "2")]), row([("Id", "3")]), row([("Id", "4")]),
    row([("Id", "5")]),
  ]
  let q = make_query(page=2, page_size=2)
  let result = query_events(rows, q)
  assert_eq(result.total, 5)
  assert_eq(result.records.map(fn(r) { r.get("Id") }), [Some("3"), Some("4")])
}

///|
test "a page past the end returns an empty record list, not an error" {
  let rows = [row([("Id", "1")])]
  let q = make_query(page=5, page_size=10)
  let result = query_events(rows, q)
  assert_eq(result.total, 1)
  assert_eq(result.records.length(), 0)
}

///|
test "filters, date range, search, and sort all compose together" {
  let rows = [
    row([("Level", "Error"), ("TimeCreated", "2026-01-05T00:00:00"), ("Message", "disk full")]),
    row([("Level", "Error"), ("TimeCreated", "2026-01-15T00:00:00"), ("Message", "disk full")]),
    row([("Level", "Information"), ("TimeCreated", "2026-01-05T00:00:00"), ("Message", "disk full")]),
  ]
  let q = make_query(
    filters={ "Level": "error" },
    start="2026-01-01T00:00:00",
    end="2026-01-10T00:00:00",
    search="disk",
  )
  let result = query_events(rows, q)
  assert_eq(result.total, 1)
  assert_eq(result.records[0].get("TimeCreated"), Some("2026-01-05T00:00:00"))
}
