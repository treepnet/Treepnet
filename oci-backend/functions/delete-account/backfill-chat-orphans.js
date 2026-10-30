// One-off: deletes chat-server users whose account no longer exists (deleted
// before the cleanup worker), with every conversation they were in.
//   docker exec treepnet-deleteaccount node backfill-chat-orphans.js          # list only
//   docker exec treepnet-deleteaccount node backfill-chat-orphans.js --apply  # delete
const { Pool } = require('pg');
const { createCleanup } = require('./cleanup');

const apply = process.argv.includes('--apply');

(async () => {
  const pool = new Pool({ connectionString: process.env.PG_CONNECTION_STRING, ssl: false, max: 1 });
  const cleanup = createCleanup({ pool, admin: null });
  try {
    const profiles = await pool.query('select id::text id from profiles');
    // An empty result would make every chat user look orphaned — never act on it.
    if (profiles.rowCount === 0) throw new Error('no profiles found; refusing to continue');
    const known = new Set(profiles.rows.map((r) => r.id));

    const chat = await cleanup.chatPool.query(
      `select distinct u.uuid from "User" u join "Project" p on p.id = u."projectId"
        where p.name = $1`,
      [process.env.CHAT_PROJECT || 'treepnet'],
    );
    const orphans = chat.rows.map((r) => r.uuid).filter((uuid) => !known.has(uuid));
    console.log(`chat users: ${chat.rowCount}, without an account: ${orphans.length}`);

    if (!apply) return;
    for (const uuid of orphans) {
      const conversations = await cleanup.deleteChatUser(uuid); // eslint-disable-line no-await-in-loop
      console.log(`deleted ${uuid.slice(0, 8)}… with ${conversations} conversation(s)`);
    }
  } finally {
    await pool.end();
    await cleanup.chatPool?.end();
  }
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
