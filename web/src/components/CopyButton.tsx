import { useState } from 'react'

export function CopyButton({ text, label = 'Copy' }: { text: string; label?: string }) {
  const [copied, setCopied] = useState(false)

  async function handleCopy() {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 2000)
    } catch {
      window.prompt('Copy this text:', text)
    }
  }

  return (
    <button type="button" className="btn btn-small" onClick={handleCopy}>
      {copied ? 'Copied!' : label}
    </button>
  )
}
