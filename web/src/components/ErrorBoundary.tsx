import { Component, type ErrorInfo, type ReactNode } from 'react'

interface Props {
  children: ReactNode
}

interface State {
  error: Error | null
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null }

  static getDerivedStateFromError(error: Error): State {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('App error:', error, info.componentStack)
  }

  render() {
    if (this.state.error) {
      return (
        <div className="login-card">
          <h1>Something went wrong</h1>
          <p className="error-text">{this.state.error.message}</p>
          <p className="muted">Try refreshing the page. If this persists, check the browser console.</p>
        </div>
      )
    }

    return this.props.children
  }
}
