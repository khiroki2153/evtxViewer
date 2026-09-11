// A permissive datetime parser for CSV timestamp columns, standing in for
// pandas' `pd.to_datetime(series, format="mixed")` (used by the old
// backend's `_detect_datetime_column`/`_rename_and_normalize_datetime`).
// Real-world exported CSVs use all sorts of shapes -- Windows Event
// Viewer's own CSV export uses "YYYY/MM/DD HH:MM:SS" (see the sample in
// csv_reader_test.mbt), spreadsheets often use "MM/DD/YYYY", etc. This
// tries a handful of common shapes and normalizes whichever matches to the
// canonical "YYYY-MM-DDTHH:MM:SS" string the rest of the app expects in
// "TimeCreated".

///|
priv struct DateParts {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
}

///|
fn valid_date_parts(p : DateParts) -> Bool {
  p.month >= 1 &&
  p.month <= 12 &&
  p.day >= 1 &&
  p.day <= 31 &&
  p.hour >= 0 &&
  p.hour <= 23 &&
  p.minute >= 0 &&
  p.minute <= 59 &&
  p.second >= 0 &&
  p.second <= 59
}

///|
/// Formats parsed date parts as the canonical naive
/// "YYYY-MM-DDTHH:MM:SS" string (zero-padded, no fractional seconds --
/// none of the shapes this parser accepts carry sub-second precision).
fn format_canonical(p : DateParts) -> String {
  fn pad2(n : Int) -> String {
    if n < 10 {
      "0" + n.to_string()
    } else {
      n.to_string()
    }
  }

  fn pad4(n : Int) -> String {
    if n < 10 {
      "000" + n.to_string()
    } else if n < 100 {
      "00" + n.to_string()
    } else if n < 1000 {
      "0" + n.to_string()
    } else {
      n.to_string()
    }
  }

  pad4(p.year) +
  "-" +
  pad2(p.month) +
  "-" +
  pad2(p.day) +
  "T" +
  pad2(p.hour) +
  ":" +
  pad2(p.minute) +
  ":" +
  pad2(p.second)
}

///|
/// Splits `s` on any run of non-digit characters, returning the digit
/// groups in order (e.g. "2026/08/21 15:09:48" -> ["2026","08","21","15","09","48"]).
/// This is deliberately loose about which punctuation separates fields --
/// pandas' "mixed" format is loose too -- and relies on `try_parse_groups`
/// to reject a group count/shape it doesn't recognize.
fn digit_groups(s : String) -> Array[String] {
  let groups = []
  let mut current = StringBuilder()
  let mut in_digits = false
  for ch in s {
    let code : Int = ch.to_int()
    if code >= 48 && code <= 57 {
      current.write_char(ch)
      in_digits = true
    } else if in_digits {
      groups.push(current.to_string())
      current = StringBuilder()
      in_digits = false
    }
  }
  if in_digits {
    groups.push(current.to_string())
  }
  groups
}

///|
fn group_to_int(g : String) -> Int? {
  if g.length() == 0 {
    return None
  }
  let sv = g[:]
  let mut n = 0
  for ch in sv {
    let code : Int = ch.to_int()
    if code < 48 || code > 57 {
      return None
    }
    n = n * 10 + (code - 48)
  }
  Some(n)
}

///|
/// Tries to interpret 6 or 7 digit-groups as a date. The first group's
/// width disambiguates year-first ("2026-08-21...", 4-digit) from
/// month/day-first ("08/21/2026...", where the year group is the 3rd and is
/// 4 digits); a 2-digit year is not supported (too ambiguous to guess
/// which century, and none of this app's known CSV sources produce one).
fn try_parse_groups(groups : Array[String]) -> DateParts? {
  if groups.length() < 6 {
    return None
  }
  let nums = []
  for g in groups {
    match group_to_int(g) {
      Some(n) => nums.push(n)
      None => return None
    }
  }
  let year_first = groups[0].length() == 4
  let (year, month, day) = if year_first {
    (nums[0], nums[1], nums[2])
  } else {
    // month/day/year (US-style); "day/month/year" is not attempted since
    // it's indistinguishable from month/day/year without a locale hint,
    // and month/day/year is what this app's actual CSV sources use.
    (nums[2], nums[0], nums[1])
  }
  let parts = DateParts::{
    year,
    month,
    day,
    hour: nums[3],
    minute: nums[4],
    second: nums[5],
  }
  if valid_date_parts(parts) {
    Some(parts)
  } else {
    None
  }
}

///|
/// Parses a loosely-formatted date+time string (see module doc for
/// examples) and returns it normalized to "YYYY-MM-DDTHH:MM:SS", or `None`
/// if it doesn't look like a date+time at all.
pub fn parse_flexible_datetime(raw : String) -> String? {
  let s = raw.trim().to_owned()
  if s.length() == 0 {
    return None
  }
  match try_parse_groups(digit_groups(s)) {
    Some(parts) => Some(format_canonical(parts))
    None => None
  }
}
