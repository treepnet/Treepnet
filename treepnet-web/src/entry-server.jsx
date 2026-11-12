// Build-time only (prerender.js): App as HTML, so the page reads without
// JavaScript and its first bytes already hold the text and the store links.
import { StrictMode } from 'react'
import { renderToString } from 'react-dom/server'
import App from './App.jsx'

export function render() {
  return renderToString(
    <StrictMode>
      <App />
    </StrictMode>,
  )
}
