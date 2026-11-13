# Chat schema changes on a live database

The server no longer runs `prisma db push` when it starts (Dockerfile). A
change to `schema.prisma` reaches the live chat database by hand, before the
server with that schema is built:

1. Change `schema.prisma`.
2. Ask Prisma for the SQL, against the live database, read-only:
   copy the new schema into the running container and run
   `npx prisma migrate diff --from-schema-datasource /app/prisma/schema.prisma --to-schema-datamodel /tmp/schema.new.prisma --script`.
3. Write `prisma/manual/YYYY-MM-DD-name.sql`: those statements, plus any
   clean-up or backfill, in one transaction. Try it on a copy of the database.
4. Back up the tables it touches, then apply it
   (`psql -d chat -v ON_ERROR_STOP=1 < file.sql`).
5. Run step 2 again with the new schema: it must say "This is an empty
   migration."
6. Then rebuild and restart the chat backend.

Example: `2026-11-13-pair-key.sql`.
