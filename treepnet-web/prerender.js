// After `vite build`: puts App's HTML into dist/client/index.html and the
// stylesheet inline, so the page shows its text, styling and store links with
// no further downloads — in the first ~14 KB on the wire. Russian ISPs cut
// Cloudflare connections after about the first 16 KB (oci-backend/media-cdn),
// and crawlers that run no JavaScript read it too. The script, when it loads,
// takes the HTML over (src/main.jsx).
import { readFileSync, writeFileSync, rmSync } from 'node:fs'
import { gzipSync } from 'node:zlib'
import { render } from './dist-ssr/entry-server.js'

const PAGE = 'dist/client/index.html'
let html = readFileSync(PAGE, 'utf8')

function replaceOnce(pattern, replacement, what) {
  const matches = html.match(new RegExp(pattern.source, 'g')) || []
  if (matches.length !== 1) throw new Error(`prerender: expected one ${what}, found ${matches.length}`)
  html = html.replace(pattern, replacement)
}

replaceOnce(/<div id="root"><\/div>/, () => `<div id="root">${render()}</div>`, 'empty root')

const link = html.match(/<link rel="stylesheet"[^>]*href="(\/assets\/[^"]+\.css)"[^>]*>/)
if (!link) throw new Error('prerender: no stylesheet link found')
const css = readFileSync(`dist/client${link[1]}`, 'utf8')
replaceOnce(/<link rel="stylesheet"[^>]*href="\/assets\/[^"]+\.css"[^>]*>/, () => `<style>${css}</style>`, 'stylesheet link')

writeFileSync(PAGE, html)
rmSync('dist-ssr', { recursive: true, force: true })

const gz = gzipSync(html).length
console.log(`prerender: ${PAGE} ${(html.length / 1024).toFixed(1)} KB, ${(gz / 1024).toFixed(1)} KB gzipped`)
if (gz > 14 * 1024) console.warn('prerender: over 14 KB gzipped — the end of the page may not arrive on throttled networks')
