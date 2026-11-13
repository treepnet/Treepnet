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
  const base = `https://play.google.com/store/apps/details?id=${ANDROID_PKG}`;
  if (!handle) return base;
  return `${base}&referrer=${encodeURIComponent('treepnet_invite=' + handle)}`;
}

// The invite handle in a link, or null for one that isn't a username (or an
// account id). Links get cut or mangled when pasted in messengers: a broken
// %-escape threw here and answered 500 instead of the store page. Lowercased:
// usernames are, and the server looks them up exactly.
const USERNAME = /^[a-z0-9_.]{1,30}$/;
const ACCOUNT_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
function inviteHandle(raw) {
  let handle;
  try {
    handle = decodeURIComponent(raw).trim().toLowerCase();
  } catch {
    return null;
  }
  return USERNAME.test(handle) || ACCOUNT_ID.test(handle) ? handle : null;
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
      const handle = inviteHandle(match[1]);
      const ua = request.headers.get('user-agent') || '';
      if (/android/i.test(ua)) {
        // Android: straight to Play with the install referrer (none for a
        // broken link: still the store page). Never cache.
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
      // A broken link gets the home page as it is: the static-asset layer
      // answers such a path with a redirect, or a 400 when it has a query.
      if (!handle) return env.ASSETS.fetch(new Request(new URL('/', url), request));
      return env.ASSETS.fetch(request);
    }

    // Everything else: the static site (SPA fallback + real files).
    return env.ASSETS.fetch(request);
  },
};
