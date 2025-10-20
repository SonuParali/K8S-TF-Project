const express = require('express')
const cors = require('cors')
const morgan = require('morgan')

const app = express()

app.use(cors())
app.use(express.json())
app.use(morgan('combined'))

app.get('/api/hello', (req, res) => {
  const now = new Date()
  const timeIST = new Intl.DateTimeFormat('en-IN', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  }).format(now)

  res.json({
    message: 'Hello from backend API!',
    timeUTC: now.toISOString(),
    timeIST,
    timeZone: 'Asia/Kolkata',
    service: 'backend-express'
  })
})

app.get('/healthz', (req, res) => res.status(200).send('ok'))

module.exports = app