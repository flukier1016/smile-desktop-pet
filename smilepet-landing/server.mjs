import { createReadStream } from 'node:fs'
import { stat } from 'node:fs/promises'
import { createServer } from 'node:http'
import { extname, join, normalize } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  constants as zlibConstants,
  createBrotliCompress,
  createGzip,
} from 'node:zlib'

const root = fileURLToPath(new URL('./dist/', import.meta.url))
const port = Number.parseInt(process.env.PORT || '4173', 10)

const contentTypes = {
  '.avif': 'image/avif',
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.txt': 'text/plain; charset=utf-8',
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
const compressionThreshold = 1024

function resolveRequestPath(requestUrl) {
  const pathname = decodeURIComponent(new URL(requestUrl, 'http://localhost').pathname)
  const requested = pathname === '/' ? 'index.html' : pathname.slice(1)
  const safePath = normalize(requested).replace(/^(\.\.(\/|\\|$))+/, '')
  const candidate = join(root, safePath)
  return candidate.startsWith(root) ? candidate : null
}

function cacheControl(pathname) {
  if (pathname.includes('/assets/')) {
    return 'public, max-age=31536000, immutable'
  }
  if (pathname.endsWith('.html')) {
    return 'no-cache'
  }
  return 'public, max-age=86400'
}

function acceptedCompression(request, extension, size) {
  if (
    request.method !== 'GET' ||
    size < compressionThreshold ||
    !compressibleExtensions.has(extension)
  ) {
    return null
  }

  const accepted = request.headers['accept-encoding'] || ''
  if (/\bbr\b/.test(accepted)) {
    return 'br'
  }
  if (/\bgzip\b/.test(accepted)) {
    return 'gzip'
  }
  return null
}

const server = createServer(async (request, response) => {
  for (const [name, value] of Object.entries(securityHeaders)) {
    response.setHeader(name, value)
  }

  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.writeHead(405, { Allow: 'GET, HEAD' })
    response.end('Method Not Allowed')
    return
  }

  let filePath
  try {
    filePath = resolveRequestPath(request.url || '/')
  } catch {
    response.writeHead(400)
    response.end('Bad Request')
    return
  }

  if (!filePath) {
    response.writeHead(403)
    response.end('Forbidden')
    return
  }

  try {
    const file = await stat(filePath)
    if (!file.isFile()) {
      throw new Error('Not a file')
    }

    const extension = extname(filePath).toLowerCase()
    const compression = acceptedCompression(request, extension, file.size)
    const headers = {
      'Cache-Control': cacheControl(filePath),
      'Content-Type': contentTypes[extension] || 'application/octet-stream',
      Vary: 'Accept-Encoding',
    }

    if (compression) {
      headers['Content-Encoding'] = compression
    } else {
      headers['Content-Length'] = file.size
    }
    response.writeHead(200, headers)

    if (request.method === 'HEAD') {
      response.end()
      return
    }

    const stream = createReadStream(filePath)
    if (compression === 'br') {
      stream
        .pipe(
          createBrotliCompress({
            params: {
              [zlibConstants.BROTLI_PARAM_QUALITY]: 4,
            },
          }),
        )
        .pipe(response)
      return
    }
    if (compression === 'gzip') {
      stream.pipe(createGzip({ level: 6 })).pipe(response)
      return
    }
    stream.pipe(response)
  } catch {
    response.writeHead(404)
    response.end('Not Found')
  }
})

server.listen(port, '0.0.0.0', () => {
  console.log(`SmilePet landing is ready on port ${port}`)
})
