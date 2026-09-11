import { useEffect, useMemo, useRef, useState, useCallback } from 'react'
import { useVirtualizer } from '@tanstack/react-virtual'
import { fetchEvents, rowToCsv } from '../api/client'
import { formatTimeCreated, getBrowserTimeZone, listTimeZones, targetInputToSourceNaive, utcInstantToZonedNaiveString } from '../lib/timezone'

const CHUNK_SIZE = 500
const LOAD_MORE_THRESHOLD = 20
const ROW_HEIGHT = 46

const NARROW_WIDTHS: Record<string, number> = {
  TimeCreated: 135,
  Level: 65,
  EventId: 55,
  Provider: 120,
  Channel: 90,
  Computer: 85,
  RecordId: 48,
  ProcessId: 48,
  ThreadId: 48,
  UserId: 48,
  Task: 42,
  Keywords: 60,
}

const DEFAULT_NARROW_WIDTH = 150

const RELATIVE_PRESETS: { label: string; minutes: number }[] = [
  { label: '15m', minutes: 15 },
  { label: '1h', minutes: 60 },
  { label: '24h', minutes: 60 * 24 },
  { label: '7d', minutes: 60 * 24 * 7 },
]

function shiftDateStr(dateStr: string, days: number): string {
  const [y, m, d] = dateStr.split('-').map(Number)
  const dt = new Date(Date.UTC(y, m - 1, d))
  dt.setUTCDate(dt.getUTCDate() + days)
  return dt.toISOString().slice(0, 10)
}

interface Props {
  sessionId: string
  columns: string[]
  totalRecords: number
}

type Row = Record<string, string>

export function EventTable({ sessionId, columns, totalRecords }: Props) {
  const hasTimeCreated = columns.includes('TimeCreated')

  const [records, setRecords] = useState<Row[]>([])
  const [filteredTotal, setFilteredTotal] = useState(totalRecords)
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [sortBy, setSortBy] = useState('')
  const [sortDesc, setSortDesc] = useState(false)
  const [colFilters, setColFilters] = useState<Record<string, string>>({})
  const [startInput, setStartInput] = useState('')
  const [endInput, setEndInput] = useState('')
  const [debouncedStart, setDebouncedStart] = useState('')
  const [debouncedEnd, setDebouncedEnd] = useState('')
  const [sourceTz, setSourceTz] = useState('UTC')
  const [targetTz, setTargetTz] = useState(() => getBrowserTimeZone())
  const [loading, setLoading] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [detailRow, setDetailRow] = useState<Row | null>(null)
  const [copied, setCopied] = useState(false)

  const timeZones = useMemo(() => listTimeZones(), [])

  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(search), 300)
    return () => clearTimeout(t)
  }, [search])

  useEffect(() => {
    const t = setTimeout(() => setDebouncedStart(startInput), 400)
    return () => clearTimeout(t)
  }, [startInput])

  useEffect(() => {
    const t = setTimeout(() => setDebouncedEnd(endInput), 400)
    return () => clearTimeout(t)
  }, [endInput])

  const startParam = useMemo(
    () => (hasTimeCreated && debouncedStart ? targetInputToSourceNaive(debouncedStart, sourceTz, targetTz) : ''),
    [hasTimeCreated, debouncedStart, sourceTz, targetTz],
  )
  const endParam = useMemo(
    () => (hasTimeCreated && debouncedEnd ? targetInputToSourceNaive(debouncedEnd, sourceTz, targetTz) : ''),
    [hasTimeCreated, debouncedEnd, sourceTz, targetTz],
  )

  const parentRef = useRef<HTMLDivElement>(null)
  const nextPageRef = useRef(1)
  const loadingMoreRef = useRef(false)

  const loadChunk = useCallback(async (page: number, replace: boolean) => {
    if (replace) setLoading(true)
    else setLoadingMore(true)
    try {
      const res = await fetchEvents({
        session_id: sessionId,
        page,
        page_size: CHUNK_SIZE,
        search: debouncedSearch,
        sort_by: sortBy,
        sort_desc: sortDesc,
        filters: colFilters,
        start: startParam,
        end: endParam,
      })
      setRecords((prev) => (replace ? res.records : [...prev, ...res.records]))
      setFilteredTotal(res.total)
      nextPageRef.current = page + 1
    } finally {
      if (replace) setLoading(false)
      else setLoadingMore(false)
      loadingMoreRef.current = false
    }
  }, [sessionId, debouncedSearch, sortBy, sortDesc, colFilters, startParam, endParam])

  useEffect(() => {
    nextPageRef.current = 1
    loadChunk(1, true)
    parentRef.current?.scrollTo({ top: 0 })
  }, [loadChunk])

  const rowVirtualizer = useVirtualizer({
    count: records.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => ROW_HEIGHT,
    overscan: 15,
  })

  const virtualItems = rowVirtualizer.getVirtualItems()
  const totalVirtualSize = rowVirtualizer.getTotalSize()
  const paddingTop = virtualItems.length > 0 ? virtualItems[0].start : 0
  const paddingBottom = virtualItems.length > 0
    ? totalVirtualSize - virtualItems[virtualItems.length - 1].end
    : 0

  const hasMore = records.length < filteredTotal

  useEffect(() => {
    const last = virtualItems[virtualItems.length - 1]
    if (!last || loadingMoreRef.current || loading || !hasMore) return
    if (last.index >= records.length - LOAD_MORE_THRESHOLD) {
      loadingMoreRef.current = true
      loadChunk(nextPageRef.current, false)
    }
  }, [virtualItems, records.length, hasMore, loading, loadChunk])

  const handleSort = (col: string) => {
    if (sortBy === col) {
      setSortDesc((d) => !d)
    } else {
      setSortBy(col)
      setSortDesc(false)
    }
  }

  const handleColFilter = (col: string, val: string) => {
    setColFilters((prev) => ({ ...prev, [col]: val }))
  }

  const handleCopyRow = async (row: Row) => {
    try {
      await navigator.clipboard.writeText(rowToCsv(columns, row))
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    } catch {
      // clipboard access denied/unavailable; nothing else to do
    }
  }

  const clearDateFilter = () => {
    setStartInput('')
    setEndInput('')
    setDebouncedStart('')
    setDebouncedEnd('')
  }

  const applyRelativePreset = (minutes: number) => {
    const now = new Date()
    const start = new Date(now.getTime() - minutes * 60000)
    setStartInput(utcInstantToZonedNaiveString(start, targetTz).slice(0, 19))
    setEndInput(utcInstantToZonedNaiveString(now, targetTz).slice(0, 19))
  }

  const applyDayPreset = (offsetDays: number) => {
    const today = utcInstantToZonedNaiveString(new Date(), targetTz).slice(0, 10)
    const dayStr = shiftDateStr(today, offsetDays)
    setStartInput(`${dayStr}T00:00:00`)
    setEndInput(`${shiftDateStr(dayStr, 1)}T00:00:00`)
  }

  const applySingleDay = (dayStr: string) => {
    if (!dayStr) return
    setStartInput(`${dayStr}T00:00:00`)
    setEndInput(`${shiftDateStr(dayStr, 1)}T00:00:00`)
  }

  const renderCell = (row: Row, col: string): string => {
    const val = String(row[col] ?? '')
    if (col === 'TimeCreated') return formatTimeCreated(val, sourceTz, targetTz)
    return val
  }

  const colWidths = useMemo(() => {
    // "Message" always gets whatever space is left over; every other column
    // (regardless of file type / header language) gets a fixed narrow width
    // so Message doesn't have to split space evenly with everything else.
    const fixedCols = columns.filter((c) => c !== 'Message')
    const fixedSum = fixedCols.reduce((sum, c) => sum + (NARROW_WIDTHS[c] ?? DEFAULT_NARROW_WIDTH), 0)
    const widths: Record<string, string> = {}
    for (const c of fixedCols) {
      widths[c] = `${NARROW_WIDTHS[c] ?? DEFAULT_NARROW_WIDTH}px`
    }
    if (columns.includes('Message')) {
      widths['Message'] = `calc(100% - ${fixedSum}px)`
    }
    return widths
  }, [columns])

  return (
    <div className="table-wrapper">
      <div className="toolbar">
        <input
          className="search-input"
          placeholder="Full-text search... (-word to exclude)"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <span className="record-count">
          {loading ? 'Loading...' : `${records.length.toLocaleString()} / ${filteredTotal.toLocaleString()} loaded (${totalRecords.toLocaleString()} total)`}
        </span>
      </div>

      {hasTimeCreated && (
        <div className="toolbar filter-bar">
          <div className="preset-group">
            {RELATIVE_PRESETS.map((p) => (
              <button key={p.label} className="btn-secondary" onClick={() => applyRelativePreset(p.minutes)}>{p.label}</button>
            ))}
            <button className="btn-secondary" onClick={() => applyDayPreset(0)}>Today</button>
            <button className="btn-secondary" onClick={() => applyDayPreset(-1)}>Yday</button>
          </div>
          <label className="filter-label">Day
            <input type="date" onChange={(e) => applySingleDay(e.target.value)} />
          </label>
          <label className="filter-label">From
            <input
              type="datetime-local"
              step="1"
              value={startInput}
              onChange={(e) => setStartInput(e.target.value)}
            />
          </label>
          <label className="filter-label">To
            <input
              type="datetime-local"
              step="1"
              value={endInput}
              onChange={(e) => setEndInput(e.target.value)}
            />
          </label>
          <button className="btn-secondary" onClick={clearDateFilter}>Clear</button>
          <label className="filter-label">Source TZ
            <select value={sourceTz} onChange={(e) => setSourceTz(e.target.value)}>
              {timeZones.map((tz) => <option key={tz} value={tz}>{tz}</option>)}
            </select>
          </label>
          <label className="filter-label">Display TZ
            <select value={targetTz} onChange={(e) => setTargetTz(e.target.value)}>
              {timeZones.map((tz) => <option key={tz} value={tz}>{tz}</option>)}
            </select>
          </label>
        </div>
      )}

      <div className="table-scroll" ref={parentRef}>
        <table>
          <colgroup>
            {columns.map((col) => (
              <col key={col} style={{ width: colWidths[col] }} />
            ))}
          </colgroup>
          <thead>
            <tr>
              {columns.map((col) => (
                <th key={col}>
                  <div className="th-content" onClick={() => handleSort(col)}>
                    {col}
                    {sortBy === col && (
                      <span className="sort-indicator">{sortDesc ? ' ▼' : ' ▲'}</span>
                    )}
                  </div>
                  <input
                    className="col-filter"
                    placeholder="filter... (-x excl.)"
                    value={colFilters[col] ?? ''}
                    onChange={(e) => handleColFilter(col, e.target.value)}
                    onClick={(e) => e.stopPropagation()}
                  />
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {paddingTop > 0 && (
              <tr><td colSpan={columns.length} style={{ height: paddingTop, padding: 0, border: 'none' }} /></tr>
            )}
            {virtualItems.map((virtualRow) => {
              const row = records[virtualRow.index]
              if (!row) return null
              const level = String(row['Level'] ?? '').toLowerCase()
              return (
                <tr
                  key={virtualRow.index}
                  className={`level-${level}`}
                  onClick={() => { setDetailRow(row); setCopied(false) }}
                >
                  {columns.map((col) => {
                    const val = renderCell(row, col)
                    const isMessage = col === 'Message'
                    return (
                      <td key={col} title={val} className={isMessage ? 'cell-message' : undefined}>
                        {isMessage ? <span className="msg-clamp">{val}</span> : val}
                      </td>
                    )
                  })}
                </tr>
              )
            })}
            {paddingBottom > 0 && (
              <tr><td colSpan={columns.length} style={{ height: paddingBottom, padding: 0, border: 'none' }} /></tr>
            )}
            {loadingMore && (
              <tr><td colSpan={columns.length} className="load-more-row">Loading more...</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {detailRow && (
        <div className="detail-overlay" onClick={() => setDetailRow(null)}>
          <div className="detail-panel" onClick={(e) => e.stopPropagation()}>
            <div className="detail-titlebar">
              <span>Event Detail</span>
              <div className="detail-titlebar-actions">
                <button className="detail-copy" onClick={() => handleCopyRow(detailRow)}>
                  {copied ? 'Copied!' : 'Copy Row (CSV)'}
                </button>
                <button className="detail-close" onClick={() => setDetailRow(null)}>✕</button>
              </div>
            </div>
            <table className="detail-table">
              <tbody>
                {Object.entries(detailRow).map(([k, v]) => (
                  <tr key={k}>
                    <th>{k}</th>
                    <td><pre>{k === 'TimeCreated' ? formatTimeCreated(v, sourceTz, targetTz) : v}</pre></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
