import io
import json
import csv
import tempfile
import os
from pathlib import Path
from typing import Any

import pandas as pd
from fastapi import FastAPI, File, UploadFile, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import evtx

app = FastAPI(title="evtxViewer API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:4173"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# in-memory store: session_id -> list of records
_sessions: dict[str, list[dict]] = {}


def _parse_evtx(data: bytes) -> list[dict]:
    records = []
    with tempfile.NamedTemporaryFile(suffix=".evtx", delete=False) as f:
        f.write(data)
        tmp_path = f.name
    try:
        parser = evtx.PyEvtxParser(tmp_path)
        for record in parser.records_json():
            try:
                event = json.loads(record["data"])
                sys = event.get("Event", {}).get("System", {})
                event_data = event.get("Event", {}).get("EventData", {})
                user_data = event.get("Event", {}).get("UserData", {})

                extra: dict = {}
                if event_data:
                    for k, v in (event_data.items() if isinstance(event_data, dict) else {}):
                        if k != "#attributes":
                            extra[k] = v
                if user_data:
                    for section_val in (user_data.values() if isinstance(user_data, dict) else {}):
                        if isinstance(section_val, dict):
                            for k, v in section_val.items():
                                if k != "#attributes":
                                    extra[k] = v

                provider = sys.get("Provider", {})
                if isinstance(provider, dict):
                    provider_name = provider.get("#attributes", {}).get("Name", "")
                else:
                    provider_name = str(provider)

                execution = sys.get("Execution", {})
                if isinstance(execution, dict):
                    pid = execution.get("#attributes", {}).get("ProcessID", "")
                    tid = execution.get("#attributes", {}).get("ThreadID", "")
                else:
                    pid = tid = ""

                security = sys.get("Security", {})
                if isinstance(security, dict):
                    user_id = security.get("#attributes", {}).get("UserID", "")
                else:
                    user_id = ""

                event_id_raw = sys.get("EventID", "")
                if isinstance(event_id_raw, dict):
                    event_id = str(event_id_raw.get("#text", ""))
                else:
                    event_id = str(event_id_raw) if event_id_raw != "" else ""

                row = {
                    "RecordId": str(record.get("event_record_id", "")),
                    "TimeCreated": sys.get("TimeCreated", {}).get("#attributes", {}).get("SystemTime", ""),
                    "EventId": event_id,
                    "Level": _level_name(sys.get("Level", "")),
                    "Channel": _scalar(sys.get("Channel", "")),
                    "Provider": provider_name,
                    "Computer": _scalar(sys.get("Computer", "")),
                    "ProcessId": str(pid),
                    "ThreadId": str(tid),
                    "UserId": str(user_id),
                    "Task": _scalar(sys.get("Task", "")),
                    "Keywords": _scalar(sys.get("Keywords", "")),
                    "Data": json.dumps(extra, ensure_ascii=False) if extra else "",
                }
                records.append(row)
            except Exception:
                continue
    finally:
        os.unlink(tmp_path)
    return records


def _scalar(v: Any) -> str:
    if isinstance(v, dict):
        return str(v.get("#text", ""))
    return str(v) if v != "" and v is not None else ""


def _level_name(level: Any) -> str:
    mapping = {"1": "Critical", "2": "Error", "3": "Warning", "4": "Information", "5": "Verbose",
               1: "Critical", 2: "Error", 3: "Warning", 4: "Information", 5: "Verbose"}
    return mapping.get(level, str(level) if level != "" else "")


def _parse_csv(data: bytes) -> list[dict]:
    for enc in ("utf-8-sig", "utf-8", "cp932", "latin-1"):
        try:
            text = data.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    else:
        text = data.decode("utf-8", errors="replace")

    reader = csv.DictReader(io.StringIO(text))
    records = []
    for i, row in enumerate(reader):
        clean = {k: str(v) if v is not None else "" for k, v in row.items() if k is not None}
        clean["RecordId"] = str(i + 1)
        records.append(clean)
    return records


@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    data = await file.read()
    filename = file.filename or ""

    if filename.lower().endswith(".evtx"):
        records = _parse_evtx(data)
        file_type = "evtx"
    elif filename.lower().endswith(".csv"):
        records = _parse_csv(data)
        file_type = "csv"
    else:
        raise HTTPException(400, "Unsupported file type. Use .evtx or .csv")

    session_id = filename
    _sessions[session_id] = records
    columns = list(records[0].keys()) if records else []

    return {"session_id": session_id, "total": len(records), "columns": columns, "file_type": file_type}


@app.get("/api/events")
def get_events(
    session_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(100, ge=1, le=1000),
    search: str = Query(""),
    sort_by: str = Query(""),
    sort_desc: bool = Query(False),
    filters: str = Query("{}"),
):
    records = _sessions.get(session_id)
    if records is None:
        raise HTTPException(404, "Session not found")

    try:
        filter_map: dict = json.loads(filters)
    except Exception:
        filter_map = {}

    result = records

    # column filters
    for col, val in filter_map.items():
        if val:
            result = [r for r in result if val.lower() in str(r.get(col, "")).lower()]

    # full-text search
    if search:
        search_lower = search.lower()
        result = [r for r in result if any(search_lower in str(v).lower() for v in r.values())]

    total_filtered = len(result)

    # sort: try numeric, fall back to string
    if sort_by and result and sort_by in result[0]:
        def sort_key(r: dict):
            v = r.get(sort_by, "")
            try:
                return (0, float(str(v)), "")
            except (ValueError, TypeError):
                return (1, 0.0, str(v).lower())
        result = sorted(result, key=sort_key, reverse=sort_desc)

    # paginate
    start = (page - 1) * page_size
    end = start + page_size
    page_records = result[start:end]

    return {
        "total": total_filtered,
        "page": page,
        "page_size": page_size,
        "records": page_records,
    }


@app.delete("/api/session/{session_id}")
def delete_session(session_id: str):
    _sessions.pop(session_id, None)
    return {"ok": True}
