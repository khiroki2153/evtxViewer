import { useRef, useState } from 'react'

interface Props {
  onFile: (file: File) => void
  loading: boolean
}

export function DropZone({ onFile, loading }: Props) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [dragging, setDragging] = useState(false)

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setDragging(false)
    const file = e.dataTransfer.files[0]
    if (file) onFile(file)
  }

  return (
    <div
      className={`drop-zone ${dragging ? 'dragging' : ''} ${loading ? 'loading' : ''}`}
      onDragOver={(e) => { e.preventDefault(); setDragging(true) }}
      onDragLeave={(e) => {
        // ページ外へ出た時だけ解除（子要素に入ってもフラッシュしないよう）
        if (!e.currentTarget.contains(e.relatedTarget as Node)) setDragging(false)
      }}
      onDrop={handleDrop}
      onClick={() => !loading && inputRef.current?.click()}
    >
      <input
        ref={inputRef}
        type="file"
        accept=".evtx,.csv"
        style={{ display: 'none' }}
        onChange={(e) => { const f = e.target.files?.[0]; if (f) onFile(f) }}
      />
      <div className="drop-hint">
        {loading ? (
          <span>Parsing file...</span>
        ) : (
          <>
            <span className="drop-icon">↓</span>
            <span>Drop .evtx or .csv here</span>
            <span className="drop-sub">or click to open</span>
          </>
        )}
      </div>
    </div>
  )
}
