import assert from 'node:assert/strict'
import { readFile, readdir, stat } from 'node:fs/promises'
import { test } from 'node:test'

test('production HTML contains the product and download link before JavaScript executes', async () => {
  const html = await readFile(new URL('../dist/index.html', import.meta.url), 'utf8')
  assert.match(html, /<h1[\s>]/)
  assert.match(html, /会懂你的搭子/)
  assert.match(html, /github.com\/flukier1016\/smile-desktop-pet\/releases\/download/)
  assert.doesNotMatch(html, /<div id="root"><\/div>/)
  assert.equal((html.match(/data-scene-index=/g) || []).length, 4)
  assert.doesNotMatch(html, /src="\/spritesheet.webp"/, 'The large sprite must remain lazy')
})

test('production JavaScript stays under 16 KiB without shipping the template runtime', async () => {
  const assets = new URL('../dist/assets/', import.meta.url)
  const scripts = (await readdir(assets)).filter((file) => file.endsWith('.js'))
  assert.ok(scripts.length > 0)
  const sizes = await Promise.all(scripts.map(async (file) => (await stat(new URL(file, assets))).size))
  assert.ok(sizes.reduce((sum, size) => sum + size, 0) < 16 * 1024,
    `JavaScript budget exceeded: ${sizes.join(', ')} bytes`)
})
