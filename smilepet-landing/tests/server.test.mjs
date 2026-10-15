import assert from 'node:assert/strict'
import { once } from 'node:events'
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises'
import { request } from 'node:http'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { after, before, test } from 'node:test'
import { brotliDecompressSync, gunzipSync } from 'node:zlib'
import { createStaticServer } from '../server.mjs'

let directory, server, port
const html = '<h1>笑笑桌宠</h1>'.repeat(200)
const javascript = 'console.log("SmilePet");'.repeat(200)

before(async () => {
  directory = await mkdtemp(join(tmpdir(), 'smilepet-server-'))
  await mkdir(join(directory, 'assets'))
  await writeFile(join(directory, 'index.html'), html)
  await writeFile(join(directory, 'assets/app-a1b2.js'), javascript)
  await writeFile(join(directory, 'pet.png'), Buffer.from([1, 2, 3]))
  server = await createStaticServer({ directory })
  server.listen(0, '127.0.0.1')
  await once(server, 'listening')
  port = server.address().port
})
after(async () => {
  await new Promise((resolve) => server.close(resolve))
  await rm(directory, { recursive: true })
})

function get(path = '/', headers = {}, method = 'GET') {
  return new Promise((resolve, reject) => {
    const req = request({ hostname: '127.0.0.1', port, path, headers, method }, (response) => {
      const chunks = []
      response.on('data', (chunk) => chunks.push(chunk))
      response.on('end', () => resolve({ status: response.statusCode, headers: response.headers, body: Buffer.concat(chunks) }))
    })
    req.on('error', reject)
    req.end()
  })
}

test('HTML is immediately readable, secured, and retains Railway edge headers', async () => {
  const response = await get()
  assert.equal(response.status, 200)
  assert.equal(response.body.toString(), html)
  assert.match(response.headers['cache-control'], /s-maxage=3600/)
  assert.match(response.headers['surrogate-control'], /max-age=3600/)
  assert.match(response.headers['content-security-policy'], /connect-src 'none'/)
  assert.equal(response.headers['x-content-type-options'], 'nosniff')
})
test('Brotli and gzip responses decompress to identical content', async () => {
  const br = await get('/', { 'Accept-Encoding': 'gzip, br' })
  assert.equal(br.headers['content-encoding'], 'br')
  assert.equal(brotliDecompressSync(br.body).toString(), html)
  assert.equal(Number(br.headers['content-length']), br.body.length)
  const gzip = await get('/', { 'Accept-Encoding': 'br;q=0, gzip' })
  assert.equal(gzip.headers['content-encoding'], 'gzip')
  assert.equal(gunzipSync(gzip.body).toString(), html)
})
test('encoding exclusions and quality weights are respected', async () => {
  const identity = await get('/', { 'Accept-Encoding': 'br;q=0, gzip;q=0' })
  assert.equal(identity.headers['content-encoding'], undefined)
  assert.equal(identity.body.toString(), html)
  const gzip = await get('/', { 'Accept-Encoding': 'br;q=0.2, gzip;q=0.8, identity;q=0' })
  assert.equal(gzip.headers['content-encoding'], 'gzip')
  assert.equal((await get('/', { 'Accept-Encoding': '*;q=0' })).status, 406)
})
test('HEAD uses the same encoded length and headers as GET', async () => {
  const headers = { 'Accept-Encoding': 'br' }
  const full = await get('/', headers)
  const head = await get('/', headers, 'HEAD')
  assert.equal(head.headers['content-length'], full.headers['content-length'])
  assert.equal(head.headers['content-encoding'], 'br')
  assert.equal(head.body.length, 0)
})
test('conditional requests return an empty 304 for weak, strong, and wildcard ETags', async () => {
  const full = await get()
  for (const etag of [full.headers.etag, full.headers.etag.replace(/^W\//, ''), '*']) {
    const response = await get('/', { 'If-None-Match': etag })
    assert.equal(response.status, 304)
    assert.equal(response.body.length, 0)
  }
})
test('hashed assets use immutable caching and a consistent in-memory build snapshot', async () => {
  await writeFile(join(directory, 'assets/app-a1b2.js'), 'changed after server startup')
  const response = await get('/assets/app-a1b2.js')
  assert.match(response.headers['cache-control'], /immutable/)
  assert.equal(response.body.toString(), javascript)
  const responses = await Promise.all(Array.from({ length: 30 }, () => get('/assets/app-a1b2.js', { 'Accept-Encoding': 'br' })))
  assert.ok(responses.every((item) => brotliDecompressSync(item.body).toString() === javascript))
})
test('missing files, malformed paths, traversal, binary assets, and unsupported methods are handled', async () => {
  assert.equal((await get('/missing.js')).status, 404)
  assert.equal((await get('/%E0%A4%A')).status, 400)
  assert.equal((await get('/%00')).status, 400)
  assert.equal((await get('/%2e%2e/server.mjs')).status, 404)
  assert.equal((await get('/', {}, 'POST')).status, 405)
  assert.deepEqual((await get('/pet.png')).body, Buffer.from([1, 2, 3]))
})
