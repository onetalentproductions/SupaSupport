import { readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

function spaFallback() {
  return {
    name: 'spa-fallback',
    closeBundle() {
      const indexPath = resolve(__dirname, 'dist/index.html')
      writeFileSync(resolve(__dirname, 'dist/404.html'), readFileSync(indexPath))
    },
  }
}

export default defineConfig({
  plugins: [react(), spaFallback()],
  server: {
    fs: { allow: ['..'] },
  },
})
