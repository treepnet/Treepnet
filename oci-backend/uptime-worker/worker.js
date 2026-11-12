// TreepNet uptime check from outside the server (Cloudflare Worker, cron every
// 5 minutes). The server's own watchdog (oci-backend/monitor) can't report the
// server being off or unreachable, or itself not running; this can. It tells the private Telegram log
// chat when the app's services stay unreachable for two checks in a row,
// repeats every 6 hours while that lasts, and says when they are back.
//
// Secrets (wrangler secret put): TG_BOT_TOKEN, TG_CHAT_ID. KV binding STATE
// keeps the count of failing checks in a row.

const TARGETS = [
  ['API', 'https://api.treepnet.com/profiles?select=id&limit=1'],
  ['Sign-in', 'https://api.treepnet.com/auth/health'],
  ['Sync', 'https://sync.treepnet.com/probes/liveness'],
  ['Chat', 'https://chat.treepnet.com/health'],
  ['Account deletion page', 'https://treepnet.com/delete-account/'],
];

// The server's monitor writes the time of each run (every 5 minutes) here;
// a stale one means the monitor itself stopped, which it can't report.
const HEARTBEAT = 'https://api.treepnet.com/app-config/heartbeat.txt';

async function heartbeat() {
  try {
    const res = await fetch(HEARTBEAT, { signal: AbortSignal.timeout(10000), cf: { cacheTtl: 0 } });
    if (res.status !== 200) return `HTTP ${res.status}`;
    const age = Date.now() / 1000 - Number((await res.text()).trim());
    if (!Number.isFinite(age)) return 'no time in the heartbeat';
    return age > 15 * 60 ? `last ran ${Math.round(age / 60)} min ago` : null;
  } catch (e) {
    return e && e.name === 'TimeoutError' ? 'no answer in 10 s' : 'unreachable';
  }
}

async function probe(url) {
  try {
    const res = await fetch(url, {
      signal: AbortSignal.timeout(10000),
      cf: { cacheTtl: 0 },
    });
    return res.status === 200 ? null : `HTTP ${res.status}`;
  } catch (e) {
    return e && e.name === 'TimeoutError' ? 'no answer in 10 s' : 'unreachable';
  }
}

async function telegram(env, text) {
  const res = await fetch(`https://api.telegram.org/bot${env.TG_BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ chat_id: env.TG_CHAT_ID, text, disable_web_page_preview: true }),
  });
  if (!res.ok) console.log('telegram send failed', res.status);
  return res.ok;
}

async function run(env) {
  if (!env.TG_BOT_TOKEN || !env.TG_CHAT_ID) {
    console.log('TG_BOT_TOKEN / TG_CHAT_ID not set; nothing to report to');
    return;
  }
  if (!(await env.STATE.get('installed'))) {
    const sent = await telegram(
      env,
      '✅ TreepNet uptime check (from Cloudflare) is on — every 5 min',
    );
    if (sent) await env.STATE.put('installed', '1');
  }

  const results = await Promise.all([
    ...TARGETS.map(async ([name, url]) => [name, await probe(url)]),
    (async () => ['Server monitor', await heartbeat()])(),
  ]);
  const failing = results.filter(([, error]) => error);
  const before = Number((await env.STATE.get('fails')) || 0);
  console.log(JSON.stringify({ failing, before }));

  if (failing.length > 0) {
    const fails = before + 1;
    await env.STATE.put('fails', String(fails));
    if (fails === 2 || fails % 72 === 0) {
      await telegram(
        env,
        '🔴 TreepNet unreachable from outside:\n' +
          failing.map(([name, error]) => `• ${name}: ${error}`).join('\n'),
      );
    }
  } else if (before > 0) {
    await env.STATE.delete('fails');
    if (before >= 2) await telegram(env, '✅ TreepNet is reachable again.');
  }
}

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(run(env));
  },
};
