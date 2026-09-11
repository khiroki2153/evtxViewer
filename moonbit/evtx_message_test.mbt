///|
test "a named field renders as Name=value" {
  // evtx renders `<Data Name="AccountName">alice</Data>` as
  // `{"AccountName": "alice"}` -- the Name attribute becomes the JSON key
  // directly, there's no separate #attributes wrapper for named fields.
  let event_data = @json.parse("{\"AccountName\": \"alice\"}") catch {
    _ => panic()
  }
  let msg = format_message(Some(event_data), None)
  assert_eq(msg, "AccountName=alice")
}

///|
test "a nameless Data element renders as bare text" {
  // `<Data>just some text</Data>` (no Name attribute) collapses onto the
  // fixed key "Data", wrapped in {"#text": ...}.
  let event_data = @json.parse("{\"Data\": {\"#text\": \"just some text\"}}") catch {
    _ => panic()
  }
  let msg = format_message(Some(event_data), None)
  assert_eq(msg, "just some text")
}

///|
test "multiple nameless Data elements render as an array under #text" {
  let event_data = @json.parse("{\"Data\": {\"#text\": [\"first\", \"second\"]}}") catch {
    _ => panic()
  }
  let msg = format_message(Some(event_data), None)
  assert_eq(msg, "first, second")
}

///|
test "joins multiple named fields with comma-space, in map order" {
  let event_data = @json.parse("{\"A\": \"1\", \"B\": \"2\"}") catch {
    _ => panic()
  }
  let msg = format_message(Some(event_data), None)
  assert_eq(msg, "A=1, B=2")
}

///|
test "drops the literal string None" {
  let event_data = @json.parse("{\"TargetUserName\": \"None\"}") catch {
    _ => panic()
  }
  let msg = format_message(Some(event_data), None)
  assert_eq(msg, "")
}

///|
test "drops JSON null" {
  let event_data = @json.parse("{\"Binary\": null}") catch {
    _ => panic()
  }
  let msg = format_message(Some(event_data), None)
  assert_eq(msg, "")
}

///|
test "ignores a top-level #attributes key (template metadata, not a field)" {
  let event_data = @json.parse(
      "{\"#attributes\": {\"Name\": \"SOME_TEMPLATE\"}, \"Detail\": \"hi\"}",
    )
    catch {
      _ => panic()
    }
  let msg = format_message(Some(event_data), None)
  assert_eq(msg, "Detail=hi")
}

///|
test "descends into a single wrapper element (UserData shape)" {
  // UserData typically has one child element (e.g. EventXML/InstallDeviceID)
  // wrapping #attributes (namespace decls, ignored) plus named fields.
  let user_data = @json.parse(
      "{\"EventXML\": {\"#attributes\": {\"xmlns\": \"Event_NS\"}, \"Param1\": \"A\", \"Param2\": null}}",
    )
    catch {
      _ => panic()
    }
  let msg = format_message(None, Some(user_data))
  assert_eq(msg, "Param1=A")
}

///|
test "concatenates EventData and UserData" {
  let event_data = @json.parse("{\"Field\": \"from event\"}") catch {
    _ => panic()
  }
  let user_data = @json.parse("{\"Wrapper\": {\"Field2\": \"from user\"}}") catch {
    _ => panic()
  }
  let msg = format_message(Some(event_data), Some(user_data))
  assert_eq(msg, "Field=from event, Field2=from user")
}

///|
test "handles missing EventData/UserData" {
  let msg = format_message(None, None)
  assert_eq(msg, "")
}
