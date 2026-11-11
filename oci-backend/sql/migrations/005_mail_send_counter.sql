-- How many emails the auth and deletion services sent each day (UTC).
--
-- Every code email (sign-up, password reset, website account deletion) goes
-- out through one Gmail account, which stops at about 500 a day; past that,
-- nobody can sign up, reset a password or delete their account until the next
-- day. Both services count each send here, and the first one to reach the
-- warning mark tells the private Telegram error bot.

create table if not exists public.mail_sends (
  day date primary key,
  sent integer not null default 0
);

-- New tables are granted to the API roles by default; this one is the
-- services' own.
revoke all on table public.mail_sends from public, anon, authenticated;
