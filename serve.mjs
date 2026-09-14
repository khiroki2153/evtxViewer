// Minimal static file server for frontend/dist, used only by the
// Dockerfile's runtime stage. No dependencies (Chainguard's runtime image
// has no npm/shell to install one with) -- just Node's built-in http/fs.
// SPA-style fallback: any path with no matching file serves index.html,
// so client-side routing (if ever added) and direct deep links both work.

import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import url from 'node:url'

const DIST_DIR = path.join(path.dirname(url.fileURLToPath(import.meta.url)), 'dist')
const PORT = Number(process.env.PORT) || 8080

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.map': 'application/json; charset=utf-8',
}

function contentTypeFor(filePath) {
  return MIME_TYPES[path.extname(filePath)] ?? 'application/octet-stream'
}

const server = http.createServer((req, res) => {
  const requestPath = decodeURIComponent(new URL(req.url ?? '/', 'http://localhost').pathname)
  const candidate = path.normalize(path.join(DIST_DIR, requestPath))

  // Reject any path that escaped DIST_DIR via ".." traversal.
  if (!candidate.startsWith(DIST_DIR)) {
    res.writeHead(400)
    res.end('Bad request')
    return
  }

  fs.readFile(candidate, (err, data) => {
    if (!err) {
      res.writeHead(200, { 'Content-Type': contentTypeFor(candidate) })
      res.end(data)
      return
    }
    // No exact file match: fall back to index.html (SPA-style routing).
    fs.readFile(path.join(DIST_DIR, 'index.html'), (fallbackErr, fallbackData) => {
      if (fallbackErr) {
        res.writeHead(404)
        res.end('Not found')
        return
      }
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' })
      res.end(fallbackData)
    })
  })
})

server.listen(PORT, () => {
  console.log(`Serving ${DIST_DIR} on port ${PORT}`)
})
