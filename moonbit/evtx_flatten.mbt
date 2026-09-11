// Turns one evtx-bridge record (`{"event_record_id": "...", "data": <Event
// JSON>}`, see wasm/evtx-bridge/src/lib.rs) into the same flat
// column->string row shape the old Python backend's `_parse_evtx` produced,
// so the rest of the app (filtering/sorting/CSV export/UI) doesn't need to
// know whether a session came from an .evtx or .csv file.

///|
let evtx_level_names : Map[String, String] = {
  "1": "Critical",
  "2": "Error",
  "3": "Warning",
  "4": "Information",
  "5": "Verbose",
}

///|
fn level_name(level : Json?) -> String {
  let raw = json_leaf_to_string_opt(level)
  match evtx_level_names.get(raw) {
    Some(name) => name
    None => raw
  }
}

///|
fn json_leaf_to_string_opt(j : Json?) -> String {
  match j {
    None => ""
    Some(v) => json_leaf_to_string(v)
  }
}

///|
/// EventID sometimes renders as a bare number and sometimes as
/// `{"#text": ..., "#attributes": {...}}` (when a Qualifiers attribute is
/// present); handle both, matching the old backend's `event_id_raw` logic.
fn event_id_string(sys : Json?) -> String {
  let raw = sys.bind(fn(s) { json_get(s, "EventID") })
  match raw {
    Some(Object(m)) =>
      match m.get("#text") {
        Some(v) => json_leaf_to_string(v)
        None => ""
      }
    Some(v) => json_leaf_to_string(v)
    None => ""
  }
}

///|
/// Flattens one evtx-bridge record into the row shape used everywhere else
/// in the app: TimeCreated, Level, EventId, Provider, Message, Channel,
/// Computer, RecordId, ProcessId, ThreadId, UserId, Task, Keywords.
pub fn flatten_evtx_record(
  event_record_id : String,
  data : Json,
) -> Map[String, String] {
  let sys = json_get(data, "Event").bind(fn(e) { json_get(e, "System") })
  let event_data = json_get(data, "Event").bind(fn(e) { json_get(e, "EventData") })
  let user_data = json_get(data, "Event").bind(fn(e) { json_get(e, "UserData") })
  let provider = sys.bind(fn(s) { json_get(s, "Provider") })
  let execution = sys.bind(fn(s) { json_get(s, "Execution") })
  let security = sys.bind(fn(s) { json_get(s, "Security") })
  let row : Map[String, String] = Map([])
  row["TimeCreated"] = json_attr(
    sys.bind(fn(s) { json_get(s, "TimeCreated") }),
    "SystemTime",
  )
  row["Level"] = level_name(sys.bind(fn(s) { json_get(s, "Level") }))
  row["EventId"] = event_id_string(sys)
  row["Provider"] = json_attr(provider, "Name")
  row["Message"] = format_message(event_data, user_data)
  row["Channel"] = json_scalar(sys.bind(fn(s) { json_get(s, "Channel") }))
  row["Computer"] = json_scalar(sys.bind(fn(s) { json_get(s, "Computer") }))
  row["RecordId"] = event_record_id
  row["ProcessId"] = json_attr(execution, "ProcessID")
  row["ThreadId"] = json_attr(execution, "ThreadID")
  row["UserId"] = json_attr(security, "UserID")
  row["Task"] = json_scalar(sys.bind(fn(s) { json_get(s, "Task") }))
  row["Keywords"] = json_scalar(sys.bind(fn(s) { json_get(s, "Keywords") }))
  row
}

///|
/// The fixed column order rows from `flatten_evtx_record` are always
/// produced in; mirrors the old backend returning `list(records[0].keys())`
/// on upload, but as a constant since these column names never vary by file.
pub let evtx_columns : Array[String] = [
  "TimeCreated", "Level", "EventId", "Provider", "Message", "Channel", "Computer",
  "RecordId", "ProcessId", "ThreadId", "UserId", "Task", "Keywords",
]
