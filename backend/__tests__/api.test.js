const request = require('supertest')
const app = require('../src/app')

describe('GET /api/hello', () => {
  it('responds with JSON incl. IST and UTC', async () => {
    const res = await request(app).get('/api/hello')
    expect(res.statusCode).toBe(200)
    expect(res.headers['content-type']).toMatch(/json/)
    expect(res.body).toHaveProperty('message')
    expect(res.body).toHaveProperty('timeUTC')
    expect(res.body).toHaveProperty('timeIST')
    expect(res.body).toHaveProperty('timeZone', 'Asia/Kolkata')
  })
})