import io
import json
import csv
import tempfile
import os
from datetime import datetime
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
                    "TimeCreated": sys.get("TimeCreated", {}).get("#attributes", {}).get("SystemTime", ""),
                    "Level": _level_name(sys.get("Level", "")),
                    "EventId": event_id,
                    "Provider": provider_name,
                    "Message": _format_message(event_data, user_data),
                    "Channel": _scalar(sys.get("Channel", "")),
                    "Computer": _scalar(sys.get("Computer", "")),
                    "RecordId": str(record.get("event_record_id", "")),
                    "ProcessId": str(pid),
                    "ThreadId": str(tid),
                    "UserId": str(user_id),
                    "Task": _scalar(sys.get("Task", "")),
                    "Keywords": _scalar(sys.get("Keywords", "")),
                }
                records.append(row)
            except Exception:
                continue
    finally:
        os.unlink(tmp_path)
    return records


def _flatten_data(obj: Any) -> list[tuple[str | None, str]]:
    """Flattens an EventData/UserData XML-to-dict subtree into (name, text)
    pairs, the way Event Viewer renders a message body: a field gets a
    "Name=value" label only when the XML element had an explicit Name
    attribute, otherwise just its bare text is kept. XML parsing artifacts
    (#attributes / #text wrappers) and empty/None values are dropped.
    """
    if obj is None:
        return []
    if isinstance(obj, dict):
        attrs = obj.get("#attributes")
        name = attrs.get("Name") if isinstance(attrs, dict) else None
        results: list[tuple[str | None, str]] = []
        text = obj.get("#text")
        if text is not None:
            results.extend((name, val) for _, val in _flatten_data(text))
        for k, v in obj.items():
            if k in ("#attributes", "#text"):
                continue
            results.extend(_flatten_data(v))
        return results
    if isinstance(obj, list):
        results = []
        for item in obj:
            results.extend(_flatten_data(item))
        return results
    s = str(obj).strip()
    return [(None, s)] if s and s.lower() != "none" else []


def _format_message(event_data: Any, user_data: Any) -> str:
    pairs = _flatten_data(event_data) + _flatten_data(user_data)
    parts = [f"{name}={val}" if name else val for name, val in pairs]
    return ", ".join(parts)


def _parse_naive_datetime(s: str) -> datetime | None:
    if not s:
        return None
    s = s.strip()
    if s.endswith("Z"):
        s = s[:-1]
    else:
        # strip a trailing numeric UTC offset like +09:00 / -05:00, if present
        if len(s) >= 6 and s[-6] in "+-" and s[-3] == ":":
            s = s[:-6]
    try:
        return datetime.fromisoformat(s)
    except ValueError:
        return None


def _scalar(v: Any) -> str:
    if isinstance(v, dict):
        return str(v.get("#text", ""))
    return str(v) if v != "" and v is not None else ""


def _level_name(level: Any) -> str:
    mapping = {"1": "Critical", "2": "Error", "3": "Warning", "4": "Information", "5": "Verbose",
               1: "Critical", 2: "Error", 3: "Warning", 4: "Information", 5: "Verbose"}
    return mapping.get(level, str(level) if level != "" else "")


_DATETIME_HEADER_ALIASES = {
    "timecreated", "time created", "date and time", "date/time", "datetime",
    "date time", "timestamp", "日付と時刻", "日時", "発生日時", "タイムスタンプ",
}


def _detect_datetime_column(columns: list[str], records: list[dict]) -> str | None:
    """Finds the CSV column holding the event timestamp so it can be
    normalized to "TimeCreated", giving CSV files the same date-range
    filtering UI/behavior as evtx files."""
    if "TimeCreated" in columns:
        return None
    for c in columns:
        if c.strip().lower() in _DATETIME_HEADER_ALIASES:
            return c
    if not records:
        return None
    sample = records[: min(50, len(records))]
    best_col, best_ratio = None, 0.0
    for c in columns:
        if c in ("Message", "RecordId"):
            continue
        values = [str(r.get(c, "")).strip() for r in sample if str(r.get(c, "")).strip()]
        if not values:
            continue
        parsed = pd.to_datetime(pd.Series(values), errors="coerce", format="mixed")
        ratio = parsed.notna().mean()
        if ratio > best_ratio:
            best_ratio, best_col = ratio, c
    return best_col if best_ratio >= 0.8 else None


def _rename_and_normalize_datetime(records: list[dict], col: str | None) -> list[dict]:
    """Renames `col` to "TimeCreated" and rewrites its values to the naive
    ISO "YYYY-MM-DDTHH:MM:SS" format the rest of the app assumes."""
    if not col or col == "TimeCreated":
        return records
    raws = [r.get(col, "") for r in records]
    parsed = pd.to_datetime(pd.Series(raws), errors="coerce", format="mixed")
    normalized = parsed.dt.strftime("%Y-%m-%dT%H:%M:%S")
    out = []
    for i, r in enumerate(records):
        norm_val = normalized.iloc[i]
        new_val = norm_val if isinstance(norm_val, str) else raws[i]
        out.append({("TimeCreated" if k == col else k): (new_val if k == col else v) for k, v in r.items()})
    return out


def _parse_csv(data: bytes) -> list[dict]:
    for enc in ("utf-8-sig", "utf-8", "cp932", "latin-1"):
        try:
            text = data.decode(enc)
            break
        except UnicodeDecodeError:
            continue
    else:
        text = data.decode("utf-8", errors="replace")

    reader = csv.reader(io.StringIO(text))
    try:
        header = next(reader)
    except StopIteration:
        return []

    # some evtx-to-csv exporters leave the message/description column
    # header blank; name it "Message" so it lines up with the evtx parser's
    # column and gets the wide/clamped treatment in the UI
    blanks_seen = 0
    columns = []
    for h in header:
        name = h.strip()
        if not name:
            blanks_seen += 1
            name = "Message" if blanks_seen == 1 else f"Column{blanks_seen}"
        columns.append(name)

    ncols = len(columns)
    has_message_col = "Message" in columns

    # Windows Event Viewer's CSV export has no header at all for the message
    # text, and doesn't quote it, so a message containing commas spills into
    # extra unheaded fields at the end of the row (e.g. 5 header columns but
    # 6+ data fields). Reassemble those trailing fields into "Message".
    records = []
    for i, row in enumerate(reader):
        clean = {columns[j]: row[j] for j in range(ncols) if j < len(row)}
        for j in range(len(row), ncols):
            clean[columns[j]] = ""
        if not has_message_col:
            clean["Message"] = ",".join(row[ncols:]) if len(row) > ncols else ""
        clean["RecordId"] = str(i + 1)
        records.append(clean)

    datetime_col = _detect_datetime_column(columns, records)
    records = _rename_and_normalize_datetime(records, datetime_col)
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
    start: str = Query(""),
    end: str = Query(""),
):
    records = _sessions.get(session_id)
    if records is None:
        raise HTTPException(404, "Session not found")

    try:
        filter_map: dict = json.loads(filters)
    except Exception:
        filter_map = {}

    result = records

    # column filters (a leading "-" negates: exclude rows containing the term)
    for col, val in filter_map.items():
        if not val:
            continue
        negate = val.startswith("-") and len(val) > 1
        term = val[1:].lower() if negate else val.lower()
        result = [r for r in result if (term in str(r.get(col, "")).lower()) != negate]

    # date/time range filter (naive comparison; caller pre-converts to the
    # timezone TimeCreated is expressed in)
    start_dt = _parse_naive_datetime(start)
    end_dt = _parse_naive_datetime(end)
    if start_dt or end_dt:
        def _in_range(r: dict) -> bool:
            dt = _parse_naive_datetime(str(r.get("TimeCreated", "")))
            if dt is None:
                return False
            if start_dt and dt < start_dt:
                return False
            if end_dt and dt > end_dt:
                return False
            return True
        result = [r for r in result if _in_range(r)]

    # full-text search: space-separated tokens are ANDed together; a token
    # prefixed with "-" must NOT be present in any field (Splunk/Gmail-style
    # exclusion, e.g. "logon -failure")
    if search:
        tokens = search.split()

        def _row_matches(r: dict) -> bool:
            for tok in tokens:
                negate = tok.startswith("-") and len(tok) > 1
                term = tok[1:].lower() if negate else tok.lower()
                present = any(term in str(v).lower() for v in r.values())
                if present == negate:
                    return False
            return True

        result = [r for r in result if _row_matches(r)]

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
    page_start = (page - 1) * page_size
    page_end = page_start + page_size
    page_records = result[page_start:page_end]

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
