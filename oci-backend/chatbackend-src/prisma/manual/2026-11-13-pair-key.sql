-- One conversation per pair, and the indexes per-person queries need.
-- Chat database. Applied by hand BEFORE the chat backend with the matching
-- schema.prisma is started: its `prisma db push` stops on a new unique index
-- (a "data loss" warning) and chat would not come up. Afterwards
-- `prisma migrate diff --from-schema-datasource ... --to-schema-datamodel
-- prisma/schema.prisma` must print nothing to do. The statements are the ones
-- Prisma generates for the schema, plus the clean-up and the backfill.
begin;

-- Extra conversations of the same pair. Only empty ones are removed (the one
-- with messages, else the oldest, stays); a pair whose duplicates both have
-- messages stops this for a manual merge.
create temp table dup on commit drop as
select c.id,
       k.pair,
       exists (select 1 from "DirectMessage" m where m."conversationId" = c.id) as has_messages
  from "Conversation" c
  join (select "conversationId" id, min("userId") || ':' || max("userId") pair
          from "ConversationParticipant" group by 1 having count(*) = 2) k on k.id = c.id
 where k.pair in (
   select p.pair
     from (select min("userId") || ':' || max("userId") pair
             from "ConversationParticipant"
            group by "conversationId" having count(*) = 2) p
    group by p.pair having count(*) > 1);

do $$
begin
  if exists (select pair from dup where has_messages group by pair having count(*) > 1) then
    raise exception 'a pair has two conversations with messages: merge them by hand first';
  end if;
end $$;

create temp table doomed on commit drop as
select d.id from dup d
 where d.id <> (select d2.id from dup d2 where d2.pair = d.pair
                 order by d2.has_messages desc, d2.id limit 1);

delete from "ConversationParticipant" where "conversationId" in (select id from doomed);
delete from "Conversation" where id in (select id from doomed);

-- AlterTable
ALTER TABLE "Conversation" ADD COLUMN "pairKey" TEXT;

update "Conversation" c
   set "pairKey" = k.pair
  from (select "conversationId" id, min("userId") || ':' || max("userId") pair
          from "ConversationParticipant" group by 1 having count(*) = 2) k
 where k.id = c.id;

-- CreateIndex
CREATE UNIQUE INDEX "Conversation_pairKey_key" ON "Conversation"("pairKey");

-- CreateIndex
CREATE INDEX "ConversationParticipant_userId_idx" ON "ConversationParticipant"("userId");

-- CreateIndex
CREATE INDEX "DirectMessage_senderId_idx" ON "DirectMessage"("senderId");

select 'removed empty duplicates: ' || count(*) from doomed;
select 'conversations with a pair key: ' || count("pairKey") || ' of ' || count(*) from "Conversation";
commit;
