// End-to-end regression test: real output from evtx-bridge's parse_evtx
// (wasm/evtx-bridge, built from the vendored `evtx` crate) against a real
// sample file (omerbenamram/EVTX's samples/new-user-security.evtx, MIT/
// Apache-2.0, see vendor/evtx/README.md), run through flatten_evtx_record.
// This exists to catch drift if the vendored evtx crate or evtx-bridge's
// settings ever change the JSON shape flatten_evtx_record assumes.

///|
let e2e_sample_json : String =
    #|[
    #|  {
    #|    "event_record_id": "1",
    #|    "data": {
    #|      "Event": {
    #|        "#attributes": {
    #|          "xmlns": "http://schemas.microsoft.com/win/2004/08/events/event"
    #|        },
    #|        "System": {
    #|          "Provider": {
    #|            "#attributes": {
    #|              "Name": "Microsoft-Windows-Security-Auditing",
    #|              "Guid": "54849625-5478-4994-A5BA-3E3B0328C30D"
    #|            }
    #|          },
    #|          "EventID": 4728,
    #|          "Version": 0,
    #|          "Level": 0,
    #|          "Task": 13826,
    #|          "Opcode": 0,
    #|          "Keywords": "0x8020000000000000",
    #|          "TimeCreated": {
    #|            "#attributes": {
    #|              "SystemTime": "2013-10-23T16:22:39.973500Z"
    #|            }
    #|          },
    #|          "EventRecordID": 111,
    #|          "Correlation": null,
    #|          "Execution": {
    #|            "#attributes": {
    #|              "ProcessID": 508,
    #|              "ThreadID": 1032
    #|            }
    #|          },
    #|          "Channel": "Security",
    #|          "Computer": "IE8Win7",
    #|          "Security": null
    #|        },
    #|        "EventData": {
    #|          "MemberName": "-",
    #|          "MemberSid": "S-1-5-21-3463664321-2923530833-3546627382-1000",
    #|          "TargetUserName": "None",
    #|          "TargetDomainName": "IE8Win7",
    #|          "TargetSid": "S-1-5-21-3463664321-2923530833-3546627382-513",
    #|          "SubjectUserSid": "S-1-5-18",
    #|          "SubjectUserName": "WIN-QALA5Q3KJ43$",
    #|          "SubjectDomainName": "WORKGROUP",
    #|          "SubjectLogonId": "0x3e7",
    #|          "PrivilegeList": "-"
    #|        }
    #|      }
    #|    }
    #|  },
    #|  {
    #|    "event_record_id": "2",
    #|    "data": {
    #|      "Event": {
    #|        "#attributes": {
    #|          "xmlns": "http://schemas.microsoft.com/win/2004/08/events/event"
    #|        },
    #|        "System": {
    #|          "Provider": {
    #|            "#attributes": {
    #|              "Name": "Microsoft-Windows-Security-Auditing",
    #|              "Guid": "54849625-5478-4994-A5BA-3E3B0328C30D"
    #|            }
    #|          },
    #|          "EventID": 4720,
    #|          "Version": 0,
    #|          "Level": 0,
    #|          "Task": 13824,
    #|          "Opcode": 0,
    #|          "Keywords": "0x8020000000000000",
    #|          "TimeCreated": {
    #|            "#attributes": {
    #|              "SystemTime": "2013-10-23T16:22:39.973500Z"
    #|            }
    #|          },
    #|          "EventRecordID": 112,
    #|          "Correlation": null,
    #|          "Execution": {
    #|            "#attributes": {
    #|              "ProcessID": 508,
    #|              "ThreadID": 1032
    #|            }
    #|          },
    #|          "Channel": "Security",
    #|          "Computer": "IE8Win7",
    #|          "Security": null
    #|        },
    #|        "EventData": {
    #|          "TargetUserName": "IEUser",
    #|          "TargetDomainName": "IE8Win7",
    #|          "TargetSid": "S-1-5-21-3463664321-2923530833-3546627382-1000",
    #|          "SubjectUserSid": "S-1-5-18",
    #|          "SubjectUserName": "WIN-QALA5Q3KJ43$",
    #|          "SubjectDomainName": "WORKGROUP",
    #|          "SubjectLogonId": "0x3e7",
    #|          "PrivilegeList": "-",
    #|          "SamAccountName": "IEUser",
    #|          "DisplayName": "%%1793",
    #|          "UserPrincipalName": "-",
    #|          "HomeDirectory": "%%1793",
    #|          "HomePath": "%%1793",
    #|          "ScriptPath": "%%1793",
    #|          "ProfilePath": "%%1793",
    #|          "UserWorkstations": "%%1793",
    #|          "PasswordLastSet": "%%1794",
    #|          "AccountExpires": "%%1794",
    #|          "PrimaryGroupId": "513",
    #|          "AllowedToDelegateTo": "-",
    #|          "OldUacValue": "0x0",
    #|          "NewUacValue": "0x15",
    #|          "UserAccountControl": "\r\n\t\t%%2080\r\n\t\t%%2082\r\n\t\t%%2084",
    #|          "UserParameters": "%%1793",
    #|          "SidHistory": "-",
    #|          "LogonHours": "%%1797"
    #|        }
    #|      }
    #|    }
    #|  },
    #|  {
    #|    "event_record_id": "3",
    #|    "data": {
    #|      "Event": {
    #|        "#attributes": {
    #|          "xmlns": "http://schemas.microsoft.com/win/2004/08/events/event"
    #|        },
    #|        "System": {
    #|          "Provider": {
    #|            "#attributes": {
    #|              "Name": "Microsoft-Windows-Security-Auditing",
    #|              "Guid": "54849625-5478-4994-A5BA-3E3B0328C30D"
    #|            }
    #|          },
    #|          "EventID": 4732,
    #|          "Version": 0,
    #|          "Level": 0,
    #|          "Task": 13826,
    #|          "Opcode": 0,
    #|          "Keywords": "0x8020000000000000",
    #|          "TimeCreated": {
    #|            "#attributes": {
    #|              "SystemTime": "2013-10-23T16:22:39.973500Z"
    #|            }
    #|          },
    #|          "EventRecordID": 113,
    #|          "Correlation": null,
    #|          "Execution": {
    #|            "#attributes": {
    #|              "ProcessID": 508,
    #|              "ThreadID": 1032
    #|            }
    #|          },
    #|          "Channel": "Security",
    #|          "Computer": "IE8Win7",
    #|          "Security": null
    #|        },
    #|        "EventData": {
    #|          "MemberName": "-",
    #|          "MemberSid": "S-1-5-21-3463664321-2923530833-3546627382-1000",
    #|          "TargetUserName": "Users",
    #|          "TargetDomainName": "Builtin",
    #|          "TargetSid": "S-1-5-32-545",
    #|          "SubjectUserSid": "S-1-5-18",
    #|          "SubjectUserName": "WIN-QALA5Q3KJ43$",
    #|          "SubjectDomainName": "WORKGROUP",
    #|          "SubjectLogonId": "0x3e7",
    #|          "PrivilegeList": "-"
    #|        }
    #|      }
    #|    }
    #|  },
    #|  {
    #|    "event_record_id": "4",
    #|    "data": {
    #|      "Event": {
    #|        "#attributes": {
    #|          "xmlns": "http://schemas.microsoft.com/win/2004/08/events/event"
    #|        },
    #|        "System": {
    #|          "Provider": {
    #|            "#attributes": {
    #|              "Name": "Microsoft-Windows-Security-Auditing",
    #|              "Guid": "54849625-5478-4994-A5BA-3E3B0328C30D"
    #|            }
    #|          },
    #|          "EventID": 4732,
    #|          "Version": 0,
    #|          "Level": 0,
    #|          "Task": 13826,
    #|          "Opcode": 0,
    #|          "Keywords": "0x8020000000000000",
    #|          "TimeCreated": {
    #|            "#attributes": {
    #|              "SystemTime": "2013-10-23T16:22:40.004750Z"
    #|            }
    #|          },
    #|          "EventRecordID": 116,
    #|          "Correlation": null,
    #|          "Execution": {
    #|            "#attributes": {
    #|              "ProcessID": 508,
    #|              "ThreadID": 1032
    #|            }
    #|          },
    #|          "Channel": "Security",
    #|          "Computer": "IE8Win7",
    #|          "Security": null
    #|        },
    #|        "EventData": {
    #|          "MemberName": "-",
    #|          "MemberSid": "S-1-5-21-3463664321-2923530833-3546627382-1000",
    #|          "TargetUserName": "Administrators",
    #|          "TargetDomainName": "Builtin",
    #|          "TargetSid": "S-1-5-32-544",
    #|          "SubjectUserSid": "S-1-5-18",
    #|          "SubjectUserName": "WIN-QALA5Q3KJ43$",
    #|          "SubjectDomainName": "WORKGROUP",
    #|          "SubjectLogonId": "0x3e7",
    #|          "PrivilegeList": "-"
    #|        }
    #|      }
    #|    }
    #|  }
    #|]

///|
test "flattens a real evtx-bridge parse_evtx() output end to end" {
  guard @json.parse(e2e_sample_json) is Array(records) else { panic() }
  assert_eq(records.length(), 4)
  let rows = records.map(fn(rec) {
    guard rec is Object(m) else { panic() }
    guard m.get("event_record_id") is Some(String(rid)) else { panic() }
    guard m.get("data") is Some(data) else { panic() }
    flatten_evtx_record(rid, data)
  })

  // first record: a group-membership-add event (4728) with two named
  // EventData fields worth checking end to end
  let r0 = rows[0]
  assert_eq(r0.get("RecordId"), Some("1"))
  assert_eq(r0.get("EventId"), Some("4728"))
  assert_eq(r0.get("Provider"), Some("Microsoft-Windows-Security-Auditing"))
  assert_eq(r0.get("Channel"), Some("Security"))
  assert_eq(r0.get("Computer"), Some("IE8Win7"))
  assert_eq(r0.get("ProcessId"), Some("508"))
  assert_eq(r0.get("ThreadId"), Some("1032"))
  assert_eq(r0.get("TimeCreated"), Some("2013-10-23T16:22:39.973500Z"))
  // "None" (the literal string, from TargetUserName) must be dropped, "-"
  // (MemberSid placeholder) is a real value and must be kept
  assert_eq(
    r0.get("Message"),
    Some(
      "MemberName=-, MemberSid=S-1-5-21-3463664321-2923530833-3546627382-1000, TargetDomainName=IE8Win7, TargetSid=S-1-5-21-3463664321-2923530833-3546627382-513, SubjectUserSid=S-1-5-18, SubjectUserName=WIN-QALA5Q3KJ43$, SubjectDomainName=WORKGROUP, SubjectLogonId=0x3e7, PrivilegeList=-",
    ),
  )

  // sanity: every row has all 13 fixed columns populated (never a missing
  // key -- a missing key would mean a column silently dropped out)
  for row in rows {
    for col in evtx_columns {
      assert_true(row.get(col) is Some(_))
    }
  }
}
