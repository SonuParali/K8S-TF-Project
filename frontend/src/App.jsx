import React, { useEffect, useState } from 'react'

export default function App() {
  const [apiData, setApiData] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    async function fetchData() {
      try {
        const res = await fetch('/api/hello')
        if (!res.ok) throw new Error('Network response was not ok')
        const json = await res.json()
        setApiData(json)
      } catch (err) {
        setError(err.message)
      }
    }
    fetchData()
  }, [])

  return (
    <div style={{ fontFamily: 'system-ui, sans-serif', padding: 24 }}>
      <h1>Frontend (React + Vite)</h1>
      <p>This page fetches data from the backend API:</p>
      {error && <p style={{ color: 'red' }}>Error: {error}</p>}
      {apiData ? (
        <div>
          <div>
            <h2>IST Time</h2>
            <p>{apiData.timeIST || 'N/A'}</p>
          </div>
          <div>
            <h2>UTC Time</h2>
            <p>{apiData.timeUTC || 'N/A'}</p>
          </div>
          <pre style={{ background: '#f5f5f5', padding: 12 }}>
            {JSON.stringify(apiData, null, 2)}
          </pre>
        </div>
      ) : (
        <p>Loading…</p>
      )}
    </div>
  )
}