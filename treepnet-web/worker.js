// TreepNet site Worker. Only special-cases referral invite links; everything
// else is served straight from the static assets (the Vite/React marketing
// site, /privacy, /delete-account, /.well-known/assetlinks.json, SPA fallback).
//
// Invite flow: when the app is installed, the Android App Link / iOS Universal
// Link opens it directly and this Worker never runs. When it is NOT installed,
// the browser hits this Worker, which 302-redirects to the store — carrying the
// invite handle as the Play install referrer so the invite still counts after
// a deferred install.

const ANDROID_PKG = 'com.treepnet.application';
// TreepNet on the App Store.
const IOS_APPSTORE_ID = '6801508746';

function storeUrlFor(handle, userAgent) {
  const ua = userAgent || '';
  const isAndroid = /android/i.test(ua);
  const isIOS = /iphone|ipad|ipod/i.test(ua);
  if (isAndroid) {
    const ref = encodeURIComponent('treepnet_invite=' + handle);
    return `https://play.google.com/store/apps/details?id=${ANDROID_PKG}&referrer=${ref}`;
  }
  if (isIOS) {
    return IOS_APPSTORE_ID
      ? `https://apps.apple.com/app/id${IOS_APPSTORE_ID}`
      : 'https://apps.apple.com/';
  }
  // Desktop / other: the Play listing (referrer only matters on-device).
  return `https://play.google.com/store/apps/details?id=${ANDROID_PKG}`;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    // /invite/<handle> (optional trailing slash), handle = a single segment.
    const match = url.pathname.match(/^\/invite\/([^/]+)\/?$/);
    if (match) {
      const handle = decodeURIComponent(match[1]);
      const dest = storeUrlFor(handle, request.headers.get('user-agent'));
      return Response.redirect(dest, 302);
    }
    // Everything else: the static site (assets binding respects SPA fallback
    // and serves real files like /.well-known/assetlinks.json directly).
    return env.ASSETS.fetch(request);
  },
};
