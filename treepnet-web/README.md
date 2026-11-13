# treepnet-web

The treepnet.com website: the landing page (React, pre-rendered to HTML), the
legal pages in `public/` (`privacy/`, `delete-account/`, `child-safety-standards/`),
the app-link files in `public/.well-known/` (`assetlinks.json` for Android,
`apple-app-site-association` for iOS — the only copies; don't edit others), and
`worker.js`, a Cloudflare Worker that sends `/invite/<handle>` links on Android
straight to Google Play with the invite as the install referrer.

## Deploy

```bash
npm install          # once
npm run deploy       # cleans dist/, builds, pre-renders, deploys to Cloudflare
```

Always deploy with `npm run deploy`: it rebuilds from scratch. A bare
`wrangler deploy` publishes whatever is in `dist/` from the last build.

## Work on it

```bash
npm run dev          # local dev server
npx vite preview     # after `npm run build`: the built site at :4173
```

Texts are in `src/i18n.js` (en, ru). The page opens in the language chosen
before, or Russian for a browser set to Russian or Uzbek, else English.
