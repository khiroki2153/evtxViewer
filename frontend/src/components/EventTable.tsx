import { useEffect, useMemo, useRef, useState, useCallback } from 'react'
import { useVirtualizer } from '@tanstack/react-virtual'
import { fetchEvents } from '../api/client'

const PAGE_SIZE = 200

interface Props {
  sessionId: string
  columns: string[]
  totalRecords: number
}

type Row = Record<string, string>

export function EventTable({ sessionId, columns, totalRecords }: Props) {
  const [records, setRecords] = useState<Row[]>([])
  const [filteredTotal, setFilteredTotal] = useState(totalRecords)
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [sortBy, setSortBy] = useState('')
  const [sortDesc, setSortDesc] = useState(false)
  const [colFilters, setColFilters] = useState<Record<string, string>>({})
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(false)
  const [detailRow, setDetailRow] = useState<Row | null>(null)

  const totalPages = Math.ceil(filteredTotal / PAGE_SIZE)

  useEffect(() => {
    const t = setTimeout(() => { setDebouncedSearch(search); setPage(1) }, 300)
    return () => clearTimeout(t)
  }, [search])

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetchEvents({
        session_id: sessionId,
        page,
        page_size: PAGE_SIZE,
        search: debouncedSearch,
        sort_by: sortBy,
        sort_desc: sortDesc,
        filters: colFilters,
      })
      setRecords(res.records)
      setFilteredTotal(res.total)
    } finally {
      setLoading(false)
    }
  }, [sessionId, page, debouncedSearch, sortBy, sortDesc, colFilters])

  useEffect(() => { load() }, [load])

  const parentRef = useRef<HTMLDivElement>(null)
  const rowVirtualizer = useVirtualizer({
    count: records.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 30,
    overscan: 15,
  })

  const virtualItems = rowVirtualizer.getVirtualItems()
  const totalVirtualSize = rowVirtualizer.getTotalSize()
  const paddingTop = virtualItems.length > 0 ? virtualItems[0].start : 0
  const paddingBottom = virtualItems.length > 0
    ? totalVirtualSize - virtualItems[virtualItems.length - 1].end
    : 0

  const handleSort = (col: string) => {
    if (sortBy === col) {
      setSortDesc((d) => !d)
    } else {
      setSortBy(col)
      setSortDesc(false)
    }
    setPage(1)
  }

  const handleColFilter = (col: string, val: string) => {
    setColFilters((prev) => ({ ...prev, [col]: val }))
    setPage(1)
  }

  const hasData = records.length > 0
  const colWidths = useMemo(() => {
    const widths: Record<string, number> = {}
    const sample = records.slice(0, 50)
    for (const col of columns) {
      const maxLen = Math.max(col.length, ...sample.map((r) => String(r[col] ?? '').length))
      widths[col] = Math.min(Math.max(maxLen * 7 + 24, 80), 320)
    }
    return widths
  }, [columns, hasData])  // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="table-wrapper">
      <div className="toolbar">
        <input
          className="search-input"
          placeholder="Full-text search..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <span className="record-count">
          {loading ? 'Loading...' : `${filteredTotal.toLocaleString()} / ${totalRecords.toLocaleString()} records`}
        </span>
        <div className="pagination">
          <button disabled={page <= 1} onClick={() => setPage(1)}>«</button>
          <button disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>‹</button>
          <span>{page} / {totalPages || 1}</span>
          <button disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>›</button>
          <button disabled={page >= totalPages} onClick={() => setPage(totalPages)}>»</button>
        </div>
      </div>

      <div className="table-scroll" ref={parentRef}>
        <table>
          <colgroup>
            {columns.map((col) => (
              <col key={col} style={{ width: colWidths[col] ?? 120 }} />
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
                    placeholder="filter..."
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
                  onClick={() => setDetailRow(row)}
                >
                  {columns.map((col) => {
                    const val = String(row[col] ?? '')
                    return <td key={col} title={val}>{val}</td>
                  })}
                </tr>
              )
            })}
            {paddingBottom > 0 && (
              <tr><td colSpan={columns.length} style={{ height: paddingBottom, padding: 0, border: 'none' }} /></tr>
            )}
          </tbody>
        </table>
      </div>

      {detailRow && (
        <div className="detail-overlay" onClick={() => setDetailRow(null)}>
          <div className="detail-panel" onClick={(e) => e.stopPropagation()}>
            <button className="detail-close" onClick={() => setDetailRow(null)}>✕</button>
            <h3>Event Detail</h3>
            <table className="detail-table">
              <tbody>
                {Object.entries(detailRow).map(([k, v]) => (
                  <tr key={k}>
                    <th>{k}</th>
                    <td><pre>{v}</pre></td>
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
