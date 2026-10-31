-- PostgREST reloads its schema by itself after every schema change.
--
-- It only learnt of a new table, column or function when someone ran
-- `notify pgrst, 'reload schema'` by hand. Forgotten, the app's next upload
-- naming a new column came back "column not in the schema cache" — an error
-- the app retries — and every phone's upload queue stuck behind it.
--
-- PostgREST's own recipe: an event trigger after each DDL command and drop
-- sends the signal. Temporary objects don't count. The signal goes out when
-- the change commits (a rolled-back one sends nothing); several in one
-- transaction are one reload.

create or replace function public.pgrst_ddl_watch()
returns event_trigger
language plpgsql
as $$
declare
  cmd record;
begin
  for cmd in select * from pg_event_trigger_ddl_commands() loop
    if cmd.schema_name is distinct from 'pg_temp' then
      notify pgrst, 'reload schema';
      return;
    end if;
  end loop;
end;
$$;

create or replace function public.pgrst_drop_watch()
returns event_trigger
language plpgsql
as $$
declare
  obj record;
begin
  for obj in select * from pg_event_trigger_dropped_objects() loop
    if not obj.is_temporary then
      notify pgrst, 'reload schema';
      return;
    end if;
  end loop;
end;
$$;

revoke all on function public.pgrst_ddl_watch() from public, anon, authenticated;
revoke all on function public.pgrst_drop_watch() from public, anon, authenticated;

drop event trigger if exists pgrst_ddl_watch;
create event trigger pgrst_ddl_watch on ddl_command_end
  execute function public.pgrst_ddl_watch();

drop event trigger if exists pgrst_drop_watch;
create event trigger pgrst_drop_watch on sql_drop
  execute function public.pgrst_drop_watch();

comment on table public.schema_migrations is
  'Which files of oci-backend/sql/migrations the database has had (sql/migrate.sh).';
