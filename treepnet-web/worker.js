// TreepNet site Worker. Special-cases referral invite links and the iOS
// app-site-association file; everything else is served straight from the static
// assets (the Vite/React marketing site, /privacy, /.well-known/assetlinks.json,
// SPA fallback).
//
// Invite flow: when the app is installed, the Android App Link / iOS Universal
// Link opens it directly and this Worker never runs. When it is NOT installed:
//   - Android: 302 straight to Play, carrying the invite handle as the install
//     referrer (deferred attribution is reliable via the Play Install Referrer).
//   - iOS / desktop: show the marketing site (the URL keeps /invite/<handle>).
//     On iOS the App Store button on that page copies the handle to the
//     clipboard, which the freshly installed app reads on first launch — iOS has
//     no Play-style install referrer.

const ANDROID_PKG = 'com.treepnet.application';

function androidPlayUrl(handle) {
  const ref = encodeURIComponent('treepnet_invite=' + handle);
  return `https://play.google.com/store/apps/details?id=${ANDROID_PKG}&referrer=${ref}`;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // iOS Universal Links verification file. A file with no extension would get
    // a generic content-type; serve it as JSON (iOS is lenient, but correct).
    if (url.pathname === '/.well-known/apple-app-site-association') {
      const res = await env.ASSETS.fetch(request);
      const headers = new Headers(res.headers);
      headers.set('Content-Type', 'application/json');
      headers.set('Cache-Control', 'no-store');
      return new Response(res.body, { status: res.status, headers });
    }

    // /invite/<handle> (optional trailing slash), handle = a single segment.
    const match = url.pathname.match(/^\/invite\/([^/]+)\/?$/);
    if (match) {
      const handle = decodeURIComponent(match[1]);
      const ua = request.headers.get('user-agent') || '';
      if (/android/i.test(ua)) {
        // Android: straight to Play with the install referrer. Never cache.
        return new Response(null, {
          status: 302,
          headers: {
            Location: androidPlayUrl(handle),
            'Cache-Control': 'no-store',
          },
        });
      }
      // iOS / desktop: serve the marketing site at this same URL so the page
      // can read <handle> and copy it on the App Store tap (clipboard deferral).
      return env.ASSETS.fetch(request);
    }

    // Everything else: the static site (SPA fallback + real files).
    return env.ASSETS.fetch(request);
  },
};
