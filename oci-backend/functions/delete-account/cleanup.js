// Finishes account deletions outside the main database.
//
// delete_account_by_id() (called by the app's delete_account() and by the
// website) removes the account's rows and queues an account_deletion_jobs row.
// This worker then removes what lives elsewhere:
//   firebase — the Firebase Auth user, so the account can't sign in again;
//   chat     — the chat-server user and EVERY conversation they were in, both
//              sides, with its uploaded files and the user's push tokens;
//   media    — the account's photos in object storage.
// Each step is retried until it succeeds (finished steps are remembered), then
// the job row is deleted so no trace of the account is kept.
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const POLL_MS = 30 * 1000;
const CHAT_PROJECT = process.env.CHAT_PROJECT || 'treepnet';
const CHAT_UPLOADS_DIR = process.env.CHAT_UPLOADS_DIR || '/chat-uploads';
const MEDIA_NAMESPACE = 'fryarohmp0gm';
const MEDIA_BUCKET = 'treepnet-media';
// Report a job to Telegram once it has failed this many times in a row.
const ALERT_AFTER = 3;

/** A step that can't run yet (e.g. no permission) — retried later, not a failure. */
class NotYet extends Error {}

function createCleanup({ pool, admin }) {
  const chatPool = process.env.CHAT_PG_CONNECTION_STRING
    ? new Pool({ connectionString: process.env.CHAT_PG_CONNECTION_STRING, ssl: false, max: 2 })
    : null;

  async function deleteFirebaseUser(uid) {
    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
    }
  }

  /**
   * Deletes the chat-server user [uuid] with every conversation they were in.
   * Returns how many conversations went. Files are removed after the commit.
   */
  async function deleteChatUser(uuid) {
    if (!chatPool) throw new Error('CHAT_PG_CONNECTION_STRING is not set');
    const client = await chatPool.connect();
    let files = [];
    let conversations = 0;
    try {
      await client.query('begin');
      const users = await client.query(
        `select u.id from "User" u join "Project" p on p.id = u."projectId"
          where u.uuid = $1 and p.name = $2`,
        [uuid, CHAT_PROJECT],
      );
      const userIds = users.rows.map((r) => r.id);
      if (userIds.length > 0) {
        const convs = await client.query(
          'select distinct "conversationId" id from "ConversationParticipant" where "userId" = any($1)',
          [userIds],
        );
        const convIds = convs.rows.map((r) => r.id);
        conversations = convIds.length;
        const media = await client.query(
          `select content, svg, png from "DirectMessage"
            where ("conversationId" = any($1) or "senderId" = any($2))
              and "contentType" <> 'text'`,
          [convIds, userIds],
        );
        files = media.rows.flatMap((r) => [r.content, r.svg, r.png]);
        await client.query(
          'delete from "DirectMessage" where "conversationId" = any($1) or "senderId" = any($2)',
          [convIds, userIds],
        );
        await client.query(
          'delete from "ConversationParticipant" where "conversationId" = any($1) or "userId" = any($2)',
          [convIds, userIds],
        );
        await client.query('delete from "Conversation" where id = any($1)', [convIds]);
        await client.query('delete from "DeviceToken" where "userId" = any($1)', [userIds]);
        await client.query('delete from "User" where id = any($1)', [userIds]);
      }
      await client.query('commit');
    } catch (e) {
      await client.query('rollback').catch(() => {});
      throw e;
    } finally {
      client.release();
    }
    removeChatFiles(files);
    return conversations;
  }

  // Only plain `/uploads/<name>` paths, so a stored value can't point outside.
  function removeChatFiles(paths) {
    for (const p of paths) {
      const m = /^\/uploads\/([^/\\]+)$/.exec(String(p || ''));
      if (!m || m[1] === '.' || m[1] === '..') continue;
      try {
        fs.unlinkSync(path.join(CHAT_UPLOADS_DIR, m[1]));
      } catch (e) {
        if (e.code !== 'ENOENT') console.error('[cleanup] chat file not removed:', m[1], e.message);
      }
    }
  }

  // Object storage client, signed in as this server (OCI instance principal).
  // Built on first use: the SDK is only needed once there are media files.
  // Permission (created 2026-10-31): dynamic group `treepnet-server` (this VM)
  // and policy `treepnet-server-media-delete`, limited to the treepnet-media
  // bucket: object delete / inspect (this worker), object create / overwrite
  // and PAR_MANAGE (auth-service's per-file upload links).
  let storage = null;
  async function objectStorage() {
    if (!storage) {
      const common = require('oci-common');
      const { ObjectStorageClient } = require('oci-objectstorage');
      const provider = await new common.InstancePrincipalsAuthenticationDetailsProviderBuilder().build();
      storage = new ObjectStorageClient({ authenticationDetailsProvider: provider });
      storage.regionId = 'eu-frankfurt-1';
    }
    return storage;
  }

  // A media URL is the bucket's own or the media.treepnet.com CDN in front of
  // it (oci-backend/media-cdn), which serves <object> from the same bucket.
  function objectOf(url) {
    const cdn = /^https:\/\/media\.treepnet\.com\/([^?#]+)/.exec(String(url || ''));
    if (cdn) {
      return { namespaceName: MEDIA_NAMESPACE, bucketName: MEDIA_BUCKET, objectName: decodeURIComponent(cdn[1]) };
    }
    const m = /^https:\/\/objectstorage\.[a-z0-9-]+\.oraclecloud\.com\/n\/([^/]+)\/b\/([^/]+)\/o\/([^?#]+)/.exec(
      String(url || ''),
    );
    if (!m || m[2] !== MEDIA_BUCKET) return null;
    return { namespaceName: m[1], bucketName: m[2], objectName: decodeURIComponent(m[3]) };
  }

  async function deleteMedia(urls) {
    const objects = urls.map(objectOf).filter(Boolean);
    if (objects.length === 0) return;
    let client;
    try {
      client = await objectStorage();
    } catch (e) {
      storage = null;
      throw new NotYet(`object storage sign-in failed: ${e.message}`);
    }
    for (const o of objects) {
      try {
        await client.deleteObject(o); // eslint-disable-line no-await-in-loop
      } catch (e) {
        if (e.statusCode === 404 && e.serviceCode === 'ObjectNotFound') continue;
        // Without a policy OCI answers 404 BucketNotFound / NotAuthorizedOrNotFound.
        if (e.statusCode === 401 || e.statusCode === 403 || e.statusCode === 404) {
          throw new NotYet(`no permission to delete media (${e.serviceCode || e.statusCode})`);
        }
        throw e;
      }
    }
  }

  async function alert(message) {
    if (!process.env.LOG_APP_KEY) return;
    try {
      await fetch('http://errorlogger:4200/error', {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-app-key': process.env.LOG_APP_KEY },
        body: JSON.stringify({ env: 'server', kind: 'account-deletion', message }),
      });
    } catch (_) {
      // The alert is best-effort; the job is retried regardless.
    }
  }

  const STEPS = [
    ['firebase', (job) => deleteFirebaseUser(job.user_id)],
    ['chat', (job) => deleteChatUser(job.user_id)],
    ['media', (job) => deleteMedia(job.media)],
  ];

  async function processJob(job) {
    const done = new Set(job.done_steps);
    let waiting = null;
    try {
      for (const [name, step] of STEPS) {
        if (done.has(name)) continue;
        try {
          await step(job); // eslint-disable-line no-await-in-loop
          done.add(name);
        } catch (e) {
          if (!(e instanceof NotYet)) throw e;
          waiting = e.message;
        }
      }
      if (!waiting) {
        await pool.query('delete from account_deletion_jobs where id = $1', [job.id]);
        console.log(`[cleanup] account deletion job ${job.id} finished`);
        return;
      }
      await pool.query(
        `update account_deletion_jobs
            set done_steps = $2, last_error = $3, next_attempt_at = now() + interval '6 hours'
          where id = $1`,
        [job.id, [...done], waiting],
      );
      console.warn(`[cleanup] job ${job.id} waiting: ${waiting}`);
    } catch (e) {
      const attempts = job.attempts + 1;
      const message = String((e && e.message) || e).slice(0, 500);
      await pool.query(
        `update account_deletion_jobs
            set attempts = $2, last_error = $3, done_steps = $4,
                next_attempt_at = now() + make_interval(mins => $5)
          where id = $1`,
        [job.id, attempts, message, [...done], Math.min(2 ** attempts, 360)],
      );
      console.error(`[cleanup] job ${job.id} failed (attempt ${attempts}):`, message);
      if (attempts === ALERT_AFTER) {
        await alert(`Account deletion job ${job.id} keeps failing: ${message}`);
      }
    }
  }

  let running = false;
  async function runOnce() {
    if (running) return;
    running = true;
    try {
      const { rows } = await pool.query(
        `select id, user_id, media, attempts, done_steps from account_deletion_jobs
          where next_attempt_at <= now() order by id limit 20`,
      );
      for (const job of rows) await processJob(job); // eslint-disable-line no-await-in-loop
    } catch (e) {
      console.error('[cleanup] run failed:', e.message);
    } finally {
      running = false;
    }
  }

  function start() {
    setTimeout(runOnce, 5 * 1000).unref();
    setInterval(runOnce, POLL_MS).unref();
  }

  return { start, runOnce, deleteChatUser, chatPool };
}

module.exports = { createCleanup };
