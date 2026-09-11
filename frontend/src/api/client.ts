// Fully client-side "API": no server, no network hop. `.evtx` bytes are
// parsed by evtx-bridge (Rust's `evtx` crate compiled to wasm, see
// wasm/evtx-bridge/), everything else -- CSV parsing, filtering, sorting,
// pagination, CSV row export -- runs in evtxviewer (MoonBit compiled to JS,
// see moonbit/). A "session" is just this module holding the parsed rows
// in memory for as long as the tab stays open.

import initEvtxBridge, { parse_evtx } from '../wasm/evtx-bridge/evtx_bridge.js'
import evtxBridgeWasmUrl from '../wasm/evtx-bridge/evtx_bridge_bg.wasm?url'
import {
  parse_csv_records,
  parse_evtx_records,
  query_events_json,
  row_to_csv_json,
} from '../wasm/evtxviewer/evtxviewer.js'

export interface UploadResult {
  session_id: string
  total: number
  columns: string[]
  file_type: 'evtx' | 'csv'
}

export interface EventsResult {
  total: number
  page: number
  page_size: number
  records: Record<string, string>[]
}

type Row = Record<string, string>

interface Session {
  columns: string[]
  rows: Row[]
  fileType: 'evtx' | 'csv'
}

const sessions = new Map<string, Session>()

let evtxBridgeReady: Promise<void> | null = null

function ensureEvtxBridgeInit(): Promise<void> {
  if (!evtxBridgeReady) {
    evtxBridgeReady = initEvtxBridge({ module_or_path: evtxBridgeWasmUrl }).then(() => undefined)
  }
  return evtxBridgeReady
}

export async function uploadFile(file: File): Promise<UploadResult> {
  const filename = file.name || ''
  let columns: string[]
  let rows: Row[]
  let fileType: 'evtx' | 'csv'

  if (filename.toLowerCase().endsWith('.evtx')) {
    await ensureEvtxBridgeInit()
    const bytes = new Uint8Array(await file.arrayBuffer())
    const recordsJson = parse_evtx(bytes)
    const parsed = JSON.parse(parse_evtx_records(recordsJson)) as { columns: string[]; rows: Row[] }
    columns = parsed.columns
    rows = parsed.rows
    fileType = 'evtx'
  } else if (filename.toLowerCase().endsWith('.csv')) {
    const text = await file.text()
    const parsed = JSON.parse(parse_csv_records(text)) as { columns: string[]; rows: Row[] }
    columns = parsed.columns
    rows = parsed.rows
    fileType = 'csv'
  } else {
    throw new Error('Unsupported file type. Use .evtx or .csv')
  }

  const sessionId = filename
  sessions.set(sessionId, { columns, rows, fileType })

  return { session_id: sessionId, total: rows.length, columns, file_type: fileType }
}

export async function fetchEvents(params: {
  session_id: string
  page: number
  page_size: number
  search: string
  sort_by: string
  sort_desc: boolean
  filters: Record<string, string>
  start: string
  end: string
}): Promise<EventsResult> {
  const session = sessions.get(params.session_id)
  if (!session) {
    throw new Error('Session not found')
  }
  const query = {
    page: params.page,
    page_size: params.page_size,
    search: params.search,
    sort_by: params.sort_by,
    sort_desc: params.sort_desc,
    filters: params.filters,
    start: params.start,
    end: params.end,
  }
  const out = JSON.parse(
    query_events_json(JSON.stringify(session.rows), JSON.stringify(query)),
  ) as EventsResult
  return out
}

/** Serializes a single row as CSV text (header + values) for the "Copy Row (CSV)" action. */
export function rowToCsv(columns: string[], row: Row): string {
  return row_to_csv_json(JSON.stringify(columns), JSON.stringify(row))
}

export function closeSession(sessionId: string): void {
  sessions.delete(sessionId)
}
