// Parsing/comparison for the naive "YYYY-MM-DDTHH:MM:SS[.ffffff]" timestamps
// used throughout this app (TimeCreated values, and the start/end bounds of
// a date-range filter). Mirrors the old Python backend's
// `_parse_naive_datetime`: no timezone math here -- by the time a string
// reaches this function it's already been reinterpreted into whatever zone
// the comparison should happen in (see the JS timezone helpers).

///|
/// A parsed naive timestamp, comparable via `Compare`. Packs
/// year/month/.../microsecond into a single ordering key so two instants can
/// be compared with a plain `<`/`>` without allocating.
pub struct NaiveDateTime {
  key : Int64
} derive(Eq, Debug)

///|
pub impl Compare for NaiveDateTime with compare(self, other) {
  self.key.compare(other.key)
}

///|
fn digits_to_int(view : StringView) -> Int? {
  let mut n = 0
  for ch in view {
    let code : Int = ch.to_int()
    if code < 48 || code > 57 {
      return None
    }
    n = n * 10 + (code - 48)
  }
  Some(n)
}

///|
/// Parses a naive "YYYY-MM-DD[T ]HH:MM:SS[.f+]" string (an optional
/// trailing "Z" or "+HH:MM"/"-HH:MM" offset is stripped first, same as the
/// old backend did, since by this point the string should already be
/// timezone-naive). Returns `None` on empty input or a shape mismatch,
/// exactly like the old `_parse_naive_datetime` returning `None`.
pub fn parse_naive_datetime(raw : String) -> NaiveDateTime? {
  let s = strip_tz_suffix(raw.trim().to_owned())
  if s.length() < 19 {
    return None
  }
  let sv = s[:]
  // Fixed-width fields: "YYYY-MM-DDTHH:MM:SS" is exactly 19 chars, with a
  // '-' at 4/7, a 'T' or ' ' at 10, and ':' at 13/16.
  if sv[4] != '-' || sv[7] != '-' || sv[13] != ':' || sv[16] != ':' {
    return None
  }
  let sep = sv[10]
  if sep != 'T' && sep != ' ' {
    return None
  }
  let year = digits_to_int(sv.view(start_offset=0, end_offset=4))
  let month = digits_to_int(sv.view(start_offset=5, end_offset=7))
  let day = digits_to_int(sv.view(start_offset=8, end_offset=10))
  let hour = digits_to_int(sv.view(start_offset=11, end_offset=13))
  let minute = digits_to_int(sv.view(start_offset=14, end_offset=16))
  let second = digits_to_int(sv.view(start_offset=17, end_offset=19))
  guard year is Some(year) else { return None }
  guard month is Some(month) else { return None }
  guard day is Some(day) else { return None }
  guard hour is Some(hour) else { return None }
  guard minute is Some(minute) else { return None }
  guard second is Some(second) else { return None }
  if month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31 ||
    hour > 23 ||
    minute > 59 ||
    second > 59 {
    return None
  }

  // Fractional seconds, if present: ".123" / ".123456" / etc, normalized to
  // microsecond precision (truncated if more precise, right-padded if less).
  let mut micros = 0
  if s.length() > 19 {
    if sv[19] != '.' {
      return None
    }
    let frac_view = sv.view(start_offset=20, end_offset=s.length())
    guard digits_to_int(frac_view) is Some(frac_digits) else { return None }
    let frac_len = frac_view.length()
    if frac_len >= 6 {
      // truncate to 6 digits by dividing out the extra precision
      let mut divisor = 1
      for _ in 0..<(frac_len - 6) {
        divisor = divisor * 10
      }
      micros = frac_digits / divisor
    } else {
      let mut multiplier = 1
      for _ in 0..<(6 - frac_len) {
        multiplier = multiplier * 10
      }
      micros = frac_digits * multiplier
    }
  }
  let key = ((((((year.to_int64() * 100L + month.to_int64()) * 100L + day.to_int64()) *
        24L +
        hour.to_int64()) *
        60L +
        minute.to_int64()) *
        60L +
        second.to_int64()) *
      1000000L +
    micros.to_int64())
  Some(NaiveDateTime::{ key, })
}

///|
/// Strips a trailing "Z" or a "+HH:MM"/"-HH:MM" numeric UTC offset, mirroring
/// the old backend's handling -- by the time a timestamp reaches this
/// parser it has already been converted into the comparison timezone, so
/// any leftover marker is noise to discard, not something to convert by.
fn strip_tz_suffix(s : String) -> String {
  if s.has_suffix("Z") {
    return s.view(start_offset=0, end_offset=s.length() - 1).to_owned()
  }
  if s.length() >= 6 {
    let offset_start = s.length() - 6
    let sign = s[offset_start]
    let colon = s[offset_start + 3]
    if (sign == '+' || sign == '-') && colon == ':' {
      return s.view(start_offset=0, end_offset=offset_start).to_owned()
    }
  }
  s
}
