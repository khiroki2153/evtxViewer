///|
test "renders a plain row without quoting" {
  let row : Map[String, String] = { "a": "1", "b": "2" }
  assert_eq(row_to_csv(["a", "b"], row), "a,b\r\n1,2")
}

///|
test "quotes a field containing a comma" {
  let row : Map[String, String] = { "Message": "hello, world" }
  assert_eq(row_to_csv(["Message"], row), "Message\r\n\"hello, world\"")
}

///|
test "escapes an embedded quote by doubling it" {
  let row : Map[String, String] = { "Message": "she said \"hi\"" }
  assert_eq(row_to_csv(["Message"], row), "Message\r\n\"she said \"\"hi\"\"\"")
}

///|
test "quotes a field containing a newline" {
  let row : Map[String, String] = { "Message": "line1\nline2" }
  assert_eq(row_to_csv(["Message"], row), "Message\r\n\"line1\nline2\"")
}

///|
test "uses an empty string for a missing column" {
  let row : Map[String, String] = { "a": "1" }
  assert_eq(row_to_csv(["a", "missing"], row), "a,missing\r\n1,")
}
