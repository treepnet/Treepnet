// Finds photo files in the media bucket that nothing uses any more and queues
// them for deletion; the clean-up worker (cleanup.js) checks each again, then
// deletes it. They are files of posts, stories and accounts deleted before the
// deletion queue (2026-10-31), and uploads whose post or story was never made.
//   docker exec treepnet-deleteaccount node media-sweep.js                    # list only
//   docker exec treepnet-deleteaccount node media-sweep.js --apply            # queue them
//   docker exec treepnet-deleteaccount node media-sweep.js --apply --max 200  # a bigger batch
// Weekly from cron with --apply (oci-backend/crontab.txt).
//
// Used means media_refs holds the file's key (posts, stories, highlight
// covers, avatars; 011_media_refs.sql). Keys are stored as the links have
// them, each path segment percent-encoded (an avatar's ':' as %3A), while the
// object's name is the decoded one, so both forms are compared: matching
// them raw would make every avatar look unused.
// Safety: nothing changed in the last 7 days is touched (an upload whose post
// is still being made); it stops when media_refs differs from the tables or
// is empty, and when more than --max files (default 50) turn up at once — so
// many means something is wrong: list them, look, then run it by hand.
const { Pool } = require('pg');
const { createCleanup } = require('./cleanup');

const PREFIXES = ['avatars/', 'posts/', 'stories/'];
const MIN_AGE_DAYS = 7;

const apply = process.argv.includes('--apply');
const maxAt = process.argv.indexOf('--max');
const max = maxAt > 0 ? Number(process.argv[maxAt + 1]) : 50;

(async () => {
  const pool = new Pool({ connectionString: process.env.PG_CONNECTION_STRING, ssl: false, max: 1 });
  const cleanup = createCleanup({ pool, admin: null });
  try {
    if (!Number.isInteger(max) || max < 0) throw new Error('--max takes a whole number');
    await pool.query('select media_refs_check()'); // raises when media_refs differs from the tables
    const refs = await pool.query('select key from media_refs');
    if (refs.rowCount === 0) throw new Error('media_refs is empty; refusing to continue');
    const used = new Set();
    for (const { key } of refs.rows) {
      used.add(key);
      try {
        used.add(decodeURIComponent(key));
      } catch (_) {
        // Not valid percent-encoding: the raw key is all there is.
      }
    }

    const cutoff = Date.now() - MIN_AGE_DAYS * 86400 * 1000;
    const unused = [];
    let total = 0;
    for (const prefix of PREFIXES) {
      for (const o of await cleanup.listMedia(prefix)) { // eslint-disable-line no-await-in-loop
        total += 1;
        const changed = Math.max(
          new Date(o.timeCreated).getTime(),
          new Date(o.timeModified || o.timeCreated).getTime(),
        );
        if (!(changed < cutoff)) continue;
        const encoded = o.name.split('/').map(encodeURIComponent).join('/');
        if (used.has(o.name) || used.has(encoded)) continue;
        unused.push({ name: o.name, size: Number(o.size) || 0, days: Math.floor((Date.now() - changed) / 86400000) });
      }
    }

    unused.sort((a, b) => a.name.localeCompare(b.name));
    for (const f of unused) console.log(`${f.name}\t${(f.size / 1024).toFixed(0)} KB\t${f.days} days`);
    const mb = (unused.reduce((n, f) => n + f.size, 0) / 1e6).toFixed(1);
    console.log(`${new Date().toISOString()} bucket: ${total} files; unused and older than ${MIN_AGE_DAYS} days: ${unused.length} (${mb} MB)`);

    if (!apply || unused.length === 0) return;
    if (unused.length > max) {
      throw new Error(`${unused.length} unused files, more than --max ${max}; nothing queued. List them first: node media-sweep.js`);
    }
    const urls = unused.map((f) => cleanup.mediaUrl(f.name));
    await pool.query('select queue_media_deletion($1::text[])', [urls]);
    const queued = await pool.query('select count(*)::int n from media_deletion_queue where url = any($1)', [urls]);
    console.log(`queued for deletion: ${queued.rows[0].n}`);
  } catch (e) {
    console.error(`[media-sweep] ${new Date().toISOString()} ${e.message}`);
    process.exitCode = 1;
  } finally {
    await pool.end().catch(() => {});
    if (cleanup.chatPool) await cleanup.chatPool.end().catch(() => {});
  }
})();
