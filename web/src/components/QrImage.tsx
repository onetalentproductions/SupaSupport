import { useEffect, useState } from 'react'
import QRCode from 'qrcode'

export function QrImage({ value, size = 200 }: { value: string; size?: number }) {
  const [dataUrl, setDataUrl] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    QRCode.toDataURL(value, { width: size, margin: 2, color: { dark: '#0f4724', light: '#ffffff' } })
      .then((url) => {
        if (!cancelled) setDataUrl(url)
      })
      .catch(() => {
        if (!cancelled) setDataUrl(null)
      })
    return () => {
      cancelled = true
    }
  }, [value, size])

  if (!dataUrl) return <p className="muted">Generating QR…</p>

  return (
    <img
      src={dataUrl}
      alt="QR code"
      width={size}
      height={size}
      style={{ borderRadius: 12, background: 'white', padding: 8 }}
    />
  )
}
