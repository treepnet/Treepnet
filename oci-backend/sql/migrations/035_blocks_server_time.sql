-- A block's time is the server's.
--
-- The app writes a local time without a zone, so blocked_users.created_at
-- was hours off (UTC+5: about five). The other tables the app writes into
-- already get the server's time from server_created_at(); blocked_users
-- was left out (P3 #185).

create trigger server_created_at
  before insert or update on public.blocked_users
  for each row execute function public.server_created_at();
