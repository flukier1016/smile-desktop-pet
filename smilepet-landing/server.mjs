import { createReadStream } from 'node:fs'
import { readFile, readdir, stat } from 'node:fs/promises'
import { createServer } from 'node:http'
import { extname, join, resolve } from 'node:path'
import { pipeline } from 'node:stream'
import { fileURLToPath } from 'node:url'
import { brotliCompressSync, constants as zlibConstants, gzipSync } from 'node:zlib'

const root = fileURLToPath(new URL('./dist/', import.meta.url))
const contentTypes = {
  '.avif': 'image/avif', '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8', '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.png': 'image/png', '.svg': 'image/svg+xml', '.txt': 'text/plain; charset=utf-8',
  '.webp': 'image/webp',
}

const securityHeaders = {
  'Content-Security-Policy': [
    "default-src 'self'",
    "base-uri 'self'",
    "connect-src 'none'",
    "font-src 'self' data:",
    "form-action 'none'",
    "frame-ancestors 'none'",
    "img-src 'self' data:",
    "object-src 'none'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    'upgrade-insecure-requests',
  ].join('; '),
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Resource-Policy': 'same-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
  'Referrer-Policy': 'no-referrer',
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
}

const compressibleExtensions = new Set(['.css', '.html', '.js', '.json', '.svg', '.txt'])

function cacheControl(pathname) {
  if (pathname.startsWith('/assets/')) return 'public, max-age=31536000, immutable'
  if (pathname.endsWith('.html')) return 'public, max-age=60, s-maxage=3600, stale-while-revalidate=86400'
  return 'public, max-age=86400'
}

function representationFor(header, representations) {
  const qualities = new Map()
  for (const token of (header || '').split(',')) {
    const [name, ...parameters] = token.trim().toLowerCase().split(';')
    if (!name) continue
    const parameter = parameters.find((value) => value.trim().startsWith('q='))
    const quality = parameter ? Number(parameter.trim().slice(2)) : 1
    qualities.set(name, Number.isFinite(quality) && quality >= 0 && quality <= 1 ? quality : 0)
  }
  const quality = (name) => qualities.get(name)
    ?? (name === 'identity' ? (qualities.get('*') === 0 ? 0 : 1) : qualities.get('*') ?? 0)
  return ['br', 'gzip', 'identity']
    .filter((name) => representations.has(name) && quality(name) > 0)
    .sort((a, b) => quality(b) - quality(a))[0]
}

async function loadAssets(directory, prefix = '') {
  const assets = new Map()
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)
    const pathname = `${prefix}/${entry.name}`
    if (entry.isDirectory()) {
      for (const [key, value] of await loadAssets(path, pathname)) assets.set(key, value)
    } else if (entry.isFile()) {
      const metadata = await stat(path)
      const extension = extname(path).toLowerCase()
      const representations = new Map([['identity', { size: metadata.size }]])
      if (compressibleExtensions.has(extension)) {
        const data = await readFile(path)
        representations.set('identity', { data, size: data.length })
        if (data.length >= 1024) {
          const br = brotliCompressSync(data, { params: { [zlibConstants.BROTLI_PARAM_QUALITY]: 9 } })
          const gzip = gzipSync(data, { level: 9 })
          representations.set('br', { data: br, size: br.length })
          representations.set('gzip', { data: gzip, size: gzip.length })
        }
      }
      const headers = {
        'Cache-Control': cacheControl(pathname),
        'Content-Type': contentTypes[extension] || 'application/octet-stream',
        ETag: `W/"${metadata.size.toString(16)}-${Math.trunc(metadata.mtimeMs).toString(16)}"`,
        'Last-Modified': metadata.mtime.toUTCString(),
        Vary: 'Accept-Encoding',
      }
      if (extension === '.html') headers['Surrogate-Control'] = 'max-age=3600, stale-while-revalidate=86400'
      assets.set(pathname, { path, headers, representations })
    }
  }
  if (!prefix && !assets.has('/index.html')) throw new Error('Build the landing page before starting the server')
  return assets
}

// Snapshot immutable build output once at startup. Text and compressed variants
// stay in memory; requests do no stat calls and never repeat compression work.
export async function createStaticServer({ directory = root } = {}) {
  const assets = await loadAssets(directory)
  return createServer((request, response) => {
    for (const [name, value] of Object.entries(securityHeaders)) response.setHeader(name, value)
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      response.writeHead(405, { Allow: 'GET, HEAD' }).end('Method Not Allowed')
      return
    }
    let pathname
    try {
      pathname = decodeURIComponent(new URL(request.url || '/', 'http://localhost').pathname)
      if (pathname.includes('\\') || pathname.includes('\0')) throw new Error('Invalid path')
    } catch {
      response.writeHead(400).end('Bad Request')
      return
    }
    const asset = assets.get(pathname === '/' ? '/index.html' : pathname)
    if (!asset) {
      response.writeHead(404).end('Not Found')
      return
    }
    const headers = { ...asset.headers }
    const candidates = request.headers['if-none-match']
    if (candidates && (candidates.trim() === '*' || candidates.split(',').some(
      (value) => value.trim().replace(/^W\//, '') === headers.ETag.replace(/^W\//, '')
    ))) {
      response.writeHead(304, headers).end()
      return
    }
    const encoding = representationFor(request.headers['accept-encoding'], asset.representations)
    if (!encoding) {
      response.writeHead(406, { Vary: 'Accept-Encoding' }).end('Not Acceptable')
      return
    }
    const representation = asset.representations.get(encoding)
    headers['Content-Length'] = representation.size
    if (encoding !== 'identity') headers['Content-Encoding'] = encoding
    response.writeHead(200, headers)
    if (request.method === 'HEAD') response.end()
    else if (representation.data) response.end(representation.data)
    else pipeline(createReadStream(asset.path), response, (error) => {
      if (error) response.destroy(error)
    })
  })
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = await createStaticServer()
  const port = Number.parseInt(process.env.PORT || '4173', 10)
  server.listen(port, '0.0.0.0', () => console.log(`SmilePet landing is ready on port ${port}`))
}
