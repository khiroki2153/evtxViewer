// Small helpers for navigating parsed EVTX-shaped JSON (the
// `{"Event": {"System": {...}, "EventData": {...}, "UserData": {...}}}`
// documents evtx-bridge hands us), mirroring the little dict-navigation
// helpers the old Python backend inlined (`.get(...)`, `_scalar`).

///|
/// Looks up `key` on `j` if it's an Object; `None` for any other shape or a
/// missing key (mirrors Python's `dict.get(key)` returning `None`).
pub fn json_get(j : Json, key : String) -> Json? {
  match j {
    Object(m) => m.get(key)
    _ => None
  }
}

///|
/// Stringifies a JSON leaf value the way Python's `str()` would for the
/// values evtx-bridge ever produces here (string/number/bool); `Null` and
/// object/array shapes (which shouldn't occur where this is called) become
/// `""`, matching the old backend's fallback-to-empty-string behavior.
pub fn json_leaf_to_string(j : Json) -> String {
  match j {
    String(s) => s
    Number(n, ..) => n.to_string()
    True => "true"
    False => "false"
    _ => ""
  }
}

///|
/// Mirrors the old backend's `_scalar`: XML-to-JSON via evtx wraps a bare
/// element's text content as `{"#text": ...}` when the element also carries
/// attributes; this unwraps that, and otherwise just stringifies the leaf.
pub fn json_scalar(j : Json?) -> String {
  match j {
    None => ""
    Some(Object(m)) =>
      match m.get("#text") {
        Some(text) => json_leaf_to_string(text)
        None => ""
      }
    Some(v) => json_leaf_to_string(v)
  }
}

///|
/// Reads a string-valued attribute (e.g. `Provider`'s `Name`, or
/// `Execution`'s `ProcessID`) out of a `{"#attributes": {...}}` wrapper.
pub fn json_attr(j : Json?, attr : String) -> String {
  match j {
    Some(Object(m)) =>
      match m.get("#attributes") {
        Some(Object(am)) =>
          match am.get(attr) {
            Some(v) => json_leaf_to_string(v)
            None => ""
          }
        _ => ""
      }
    _ => ""
  }
}
