import { Link, NavLink } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { DEPARTMENT_LABELS } from '../types'
import './Layout.css'

export function AppShell({ children }: { children: React.ReactNode }) {
  const { email, isAdmin, adminDepartment, signOut } = useAuth()

  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="header-inner">
          <Link to="/tickets" className="brand">
            <span className="brand-mark">F</span>
            <span>FBCVR Tickets</span>
          </Link>
          <div className="header-actions">
            {isAdmin && adminDepartment && (
              <span className="admin-pill">{DEPARTMENT_LABELS[adminDepartment]} Admin</span>
            )}
            <Link to="/tickets/new" className="btn btn-header">
              New Ticket
            </Link>
            <span className="user-email">{email}</span>
            <button type="button" className="btn btn-ghost" onClick={() => signOut()}>
              Sign out
            </button>
          </div>
        </div>
        {isAdmin && (
          <nav className="admin-nav" aria-label="Admin sections">
            <NavLink to="/tickets" className={({ isActive }) => (isActive ? 'active' : undefined)}>
              Tickets
            </NavLink>
            <NavLink to="/archive" className={({ isActive }) => (isActive ? 'active' : undefined)}>
              Archive
            </NavLink>
            <NavLink to="/analytics" className={({ isActive }) => (isActive ? 'active' : undefined)}>
              Analytics
            </NavLink>
          </nav>
        )}
      </header>
      <main className="app-main">{children}</main>
      <footer className="app-footer">
        <Link to="/privacy">Privacy Policy</Link>
        <span>© {new Date().getFullYear()} FBCVR</span>
      </footer>
    </div>
  )
}

export function PublicShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="app-shell public-shell">
      <main className="app-main public-main">{children}</main>
      <footer className="app-footer">
        <Link to="/privacy">Privacy Policy</Link>
      </footer>
    </div>
  )
}
