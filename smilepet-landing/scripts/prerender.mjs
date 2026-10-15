import { readFile, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { createElement } from 'react'
import { renderToString } from 'react-dom/server'
import { createServer } from 'vite'

// React only generates HTML at build time. Production ships that HTML and a
// small DOM controller, without a client template runtime or hydration work.
const root = fileURLToPath(new URL('../', import.meta.url))
const vite = await createServer({ root, server: { middlewareMode: true }, appType: 'custom' })
try {
  const { default: App } = await vite.ssrLoadModule('/src/App.tsx')
  const path = new URL('../dist/index.html', import.meta.url)
  const template = await readFile(path, 'utf8')
  const rendered = renderToString(createElement(App))
  if (!template.includes('<div id="root"></div>')) throw new Error('Missing root placeholder')
  await writeFile(path, template.replace('<div id="root"></div>', `<div id="root">${rendered}</div>`))
  console.log(`Prerendered ${Buffer.byteLength(rendered)} bytes of visible content`)
} finally {
  await vite.close()
}
