import { useState } from 'react'
import { DropZone } from './components/DropZone'
import { EventTable } from './components/EventTable'
import { ErrorBoundary } from './components/ErrorBoundary'
import { uploadFile, closeSession, type UploadResult } from './api/client'
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
      setError(e instanceof Error ? e.message : 'Upload failed')
    } finally {
      setLoading(false)
    }
  }

  const handleClose = () => {
    if (session) closeSession(session.session_id)
    setSession(null)
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>evtxViewer</h1>
        {session && (
          <div className="header-meta">
            <span className="badge">{session.file_type.toUpperCase()}</span>
            <span>{session.session_id}</span>
            <button className="btn-secondary" onClick={handleClose}>Close</button>
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
