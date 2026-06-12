import { useState } from 'react'
import { DropZone } from './components/DropZone'
import { EventTable } from './components/EventTable'
import { ErrorBoundary } from './components/ErrorBoundary'
import { uploadFile, type UploadResult } from './api/client'
import type { AxiosError } from 'axios'
import './App.css'

function App() {
  const [session, setSession] = useState<UploadResult | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleFile = async (file: File) => {
    setError('')
    setLoading(true)
    try {
      const result = await uploadFile(file)
      setSession(result)
    } catch (e: unknown) {
      const axiosErr = e as AxiosError<{ detail: string }>
      const msg = axiosErr.response?.data?.detail ?? (e instanceof Error ? e.message : 'Upload failed')
      setError(String(msg))
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>evtxViewer</h1>
        {session && (
          <div className="header-meta">
            <span className="badge">{session.file_type.toUpperCase()}</span>
            <span>{session.session_id}</span>
            <button className="btn-secondary" onClick={() => setSession(null)}>Close</button>
          </div>
        )}
      </header>

      {!session ? (
        <main className="landing">
          <DropZone onFile={handleFile} loading={loading} />
          {error && <p className="error">{error}</p>}
        </main>
      ) : (
        <main className="viewer">
          <ErrorBoundary>
            <EventTable
              sessionId={session.session_id}
              columns={session.columns}
              totalRecords={session.total}
            />
          </ErrorBoundary>
        </main>
      )}
    </div>
  )
}

export default App
