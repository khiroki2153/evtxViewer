// Builds the "Message" column for an evtx row by flattening
// `Event.EventData`/`Event.UserData`, mirroring how Windows Event Viewer
// renders a message body from named/unnamed XML elements.
//
// The evtx crate's JSON rendering (see vendor/evtx/src/binxml/value_render.rs
// et al) represents each XML element under EventData/UserData as an object
// key -- the element's `Name` attribute becomes the JSON key directly (e.g.
// `<Data Name="AccountName">alice</Data>` -> `{"AccountName": "alice"}`) --
// *except* for `<Data>` elements with no `Name` attribute, which always
// collapse onto the fixed key `"Data"`, wrapped as `{"#text": <value-or-array>}`
// (an array when more than one nameless `<Data>` element occurs). A field's
// value can also itself be an object carrying `"#attributes"` (namespace
// declarations etc, which we ignore) alongside further named children (as
// with UserData's single wrapper element, e.g. `EventXML`/`InstallDeviceID`).

///|
priv struct NamedValue {
  name : String? // Some(name) if this value came from a named XML element
  value : String
}

///|
/// Recursively flattens an EventData/UserData subtree into (name, text)
/// pairs. Empty/None-ish leaves are dropped (evtx renders some empty
/// elements as the literal string "None" or as JSON `null`).
fn flatten_data(j : Json?, key : String?) -> Array[NamedValue] {
  match j {
    None => []
    Some(Null) => []
    Some(Object(m)) => {
      let results = []
      // `#text` is the collapsed value of a nameless `<Data>` element
      // (see module doc); everything else is a named child field.
      match m.get("#text") {
        Some(text) =>
          for nv in flatten_data(Some(text), None) {
            results.push(nv)
          }
        None => ()
      }
      for k, v in m {
        if k == "#attributes" || k == "#text" {
          continue
        }
        let label = if k == "Data" { None } else { Some(k) }
        results.push_iter(flatten_data(Some(v), label).iter())
      }
      results
    }
    Some(Array(items)) => {
      let results = []
      for item in items {
        results.push_iter(flatten_data(Some(item), key).iter())
      }
      results
    }
    Some(leaf) => {
      let s = json_leaf_to_string(leaf).trim().to_owned()
      if s.length() > 0 && s.to_lower() != "none" {
        [NamedValue::{ name: key, value: s }]
      } else {
        []
      }
    }
  }
}

///|
/// Renders EventData + UserData as a single comma-separated "Message"
/// string, e.g. `"AccountName=alice, LogonType=3, some bare text"`.
pub fn format_message(event_data : Json?, user_data : Json?) -> String {
  let pairs = flatten_data(event_data, None)
  pairs.push_iter(flatten_data(user_data, None).iter())
  let parts = pairs.map(fn(nv) {
    match nv.name {
      Some(name) => name + "=" + nv.value
      None => nv.value
    }
  })
  parts.join(", ")
}
