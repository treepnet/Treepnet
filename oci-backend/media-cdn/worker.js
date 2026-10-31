// media.treepnet.com — the app's photos through Cloudflare's cache.
//
// NOT IN USE (2026-10-31): stored URLs point at the bucket again
// (sql/media_cdn_urls_rollback.sql). Russian ISPs throttle Cloudflare to the
// first ~16 KB of each file, so photos would never finish loading there.
//
// Every photo used to come straight from the OCI bucket in Frankfurt. This
// Worker serves https://media.treepnet.com/<object> from the nearest Cloudflare
// edge, fetching it from the bucket only on a miss. Only the app's own media
// prefixes are served; nothing can be written through here.
//
// Edge copies live for a day, so a deleted account's photos stop being served
// within a day of the bucket losing them (the app keeps its own longer disk
// cache). Free Workers plan: 100k requests/day — move to the paid plan before
// daily traffic gets near that.

const ORIGIN =
  'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/';
const EDGE_TTL = 24 * 60 * 60;
const PREFIXES = /^(posts|stories|avatars)\//;

export default {
  async fetch(request, env, ctx) {
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method not allowed', { status: 405 });
    }
    const url = new URL(request.url);
    const object = url.pathname.replace(/^\/+/, '');
    if (!PREFIXES.test(object)) return new Response('Not found', { status: 404 });

    const cacheKey = new Request(`${url.origin}/${object}${url.search}`, { method: 'GET' });
    const cache = caches.default;
    const hit = await cache.match(cacheKey);
    if (hit) return request.method === 'HEAD' ? new Response(null, hit) : hit;

    const upstream = await fetch(`${ORIGIN}${object}${url.search}`);
    if (upstream.status !== 200) {
      // Misses and errors aren't kept, so an upload that lands later shows up.
      return new Response(upstream.body, {
        status: upstream.status,
        headers: { 'content-type': upstream.headers.get('content-type') || 'text/plain' },
      });
    }

    const headers = new Headers();
    for (const name of ['content-type', 'content-length', 'etag', 'last-modified']) {
      const value = upstream.headers.get(name);
      if (value) headers.set(name, value);
    }
    headers.set('cache-control', `public, max-age=${EDGE_TTL}`);
    headers.set('access-control-allow-origin', '*');
    const response = new Response(upstream.body, { status: 200, headers });
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return request.method === 'HEAD' ? new Response(null, response) : response;
  },
};
