import { Component, type ReactNode } from 'react'

interface State { error: Error | null }

export class ErrorBoundary extends Component<{ children: ReactNode }, State> {
  state: State = { error: null }

  static getDerivedStateFromError(error: Error): State {
    return { error }
  }

  render() {
    if (this.state.error) {
      return (
        <div style={{ padding: 32, color: '#e94560' }}>
          <h2>Rendering error</h2>
          <pre style={{ marginTop: 12, fontSize: 12, whiteSpace: 'pre-wrap', color: '#ccc' }}>
            {this.state.error.message}
            {'\n'}
            {this.state.error.stack}
          </pre>
          <button
            style={{ marginTop: 16, padding: '6px 16px', cursor: 'pointer' }}
            onClick={() => this.setState({ error: null })}
          >
            Dismiss
          </button>
        </div>
      )
    }
    return this.props.children
  }
}
