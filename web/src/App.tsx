import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import { ProtectedRoute } from './components/ProtectedRoute'
import { ErrorBoundary } from './components/ErrorBoundary'
import { ConnectPage } from './pages/ConnectPage'
import { SetupPage } from './pages/SetupPage'
import { LoginPage } from './pages/LoginPage'
import { AuthCallbackPage } from './pages/AuthCallbackPage'
import { TicketsPage } from './pages/TicketsPage'
import { ArchivePage } from './pages/ArchivePage'
import { AnalyticsPage } from './pages/AnalyticsPage'
import { CreateTicketPage } from './pages/CreateTicketPage'
import { TicketDetailPage } from './pages/TicketDetailPage'
import { PrivacyPage } from './pages/PrivacyPage'
import { loadTenant } from './lib/tenant'
import './index.css'

function RequireTenant({ children }: { children: React.ReactNode }) {
  if (!loadTenant()) return <Navigate to="/connect" replace />
  return <>{children}</>
}

export default function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<Navigate to="/connect" replace />} />
            <Route path="/connect" element={<ConnectPage />} />
            <Route path="/setup" element={<SetupPage />} />
            <Route path="/login" element={<RequireTenant><LoginPage /></RequireTenant>} />
            <Route path="/auth/callback" element={<RequireTenant><AuthCallbackPage /></RequireTenant>} />
            <Route path="/privacy" element={<PrivacyPage />} />
            <Route element={<ProtectedRoute />}>
              <Route path="/tickets" element={<TicketsPage />} />
              <Route path="/archive" element={<ArchivePage />} />
              <Route path="/analytics" element={<AnalyticsPage />} />
              <Route path="/tickets/new" element={<CreateTicketPage />} />
              <Route path="/tickets/:id" element={<TicketDetailPage />} />
            </Route>
            <Route path="*" element={<Navigate to="/connect" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ErrorBoundary>
  )
}
