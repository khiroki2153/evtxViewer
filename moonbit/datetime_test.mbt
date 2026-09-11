///|
test "parses a plain naive datetime" {
  let d = parse_naive_datetime("2013-10-23T16:22:39")
  assert_true(d is Some(_))
}

///|
test "parses fractional seconds of varying precision consistently" {
  let a = parse_naive_datetime("2013-10-23T16:22:39.5")
  let b = parse_naive_datetime("2013-10-23T16:22:39.500000")
  guard! a is Some(a)
  guard! b is Some(b)
  assert_eq(a, b)
}

///|
test "strips trailing Z" {
  let a = parse_naive_datetime("2013-10-23T16:22:39Z")
  let b = parse_naive_datetime("2013-10-23T16:22:39")
  guard! a is Some(a)
  guard! b is Some(b)
  assert_eq(a, b)
}

///|
test "strips trailing numeric UTC offset" {
  let a = parse_naive_datetime("2013-10-23T16:22:39+09:00")
  let b = parse_naive_datetime("2013-10-23T16:22:39")
  guard! a is Some(a)
  guard! b is Some(b)
  assert_eq(a, b)
}

///|
test "accepts space as date/time separator" {
  let a = parse_naive_datetime("2013-10-23 16:22:39")
  assert_true(a is Some(_))
}

///|
test "orders chronologically, not lexically, across differing fractional precision" {
  guard! parse_naive_datetime("2013-10-23T16:22:39.9") is Some(earlier)
  guard! parse_naive_datetime("2013-10-23T16:22:40.1") is Some(later)
  assert_true(earlier < later)
}

///|
test "rejects empty string" {
  assert_true(parse_naive_datetime("") is None)
}

///|
test "rejects malformed shape" {
  assert_true(parse_naive_datetime("not-a-date") is None)
}

///|
test "rejects out-of-range month" {
  assert_true(parse_naive_datetime("2013-13-23T16:22:39") is None)
}
