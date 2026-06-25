import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import { validateConfig } from './lib/config'
import './index.css'

const configError = validateConfig()
const root = document.getElementById('root')

if (!root) {
  throw new Error('Root element not found')
}

if (configError) {
  root.innerHTML = `
    <div class="login-card">
      <h1>Configuration error</h1>
      <p class="error-text">${configError}</p>
      <p class="muted">Redeploy after adding build environment variables in Cloudflare.</p>
    </div>
  `
} else {
  createRoot(root).render(
    <StrictMode>
      <App />
    </StrictMode>
  )
}
