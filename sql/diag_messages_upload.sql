-- Diagnose why PowerSync message inserts are rejected (upload queue stuck).
-- Read-only except the final INSERT which is wrapped in a ROLLBACK.

\echo '== 1) type enum ruxsat etilgan qiymatlari (client "text" yuboradi) =='
SELECT t.typname AS enum_type, e.enumlabel AS allowed_value
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
WHERE t.oid = (
  SELECT atttypid FROM pg_attribute
  WHERE attrelid = 'public.messages'::regclass AND attname = 'type'
)
ORDER BY e.enumsortorder;

\echo '== 2) messages RLS yoqilganmi =='
SELECT relrowsecurity AS rls_enabled, relforcerowsecurity AS rls_forced
FROM pg_class WHERE oid = 'public.messages'::regclass;

\echo '== 3) messages policylar (INSERT uchun WITH CHECK muhim) =='
SELECT polname,
       CASE polcmd WHEN 'r' THEN 'SELECT' WHEN 'a' THEN 'INSERT'
                   WHEN 'w' THEN 'UPDATE' WHEN 'd' THEN 'DELETE' ELSE polcmd::text END AS cmd,
       pg_get_expr(polqual, polrelid)      AS using_expr,
       pg_get_expr(polwithcheck, polrelid) AS with_check_expr
FROM pg_policy WHERE polrelid = 'public.messages'::regclass;

\echo '== 4) qaysi rollarga INSERT ruxsati bor =='
SELECT rolname,
       has_table_privilege(rolname, 'public.messages', 'INSERT') AS can_insert
FROM pg_roles
WHERE rolname IN ('authenticated','powersync_role','anon','service_role','authenticator','treepadmin')
ORDER BY rolname;

\echo '== 5) tiqilgan xabarni ADMIN sifatida sinov (ROLLBACK — hech narsa saqlanmaydi) =='
\echo '   xato chiqsa -> schema/enum/FK muammosi; muvaffaqiyat -> sabab RLS (app roli)'
BEGIN;
INSERT INTO public.messages
  (id, conversation_id, from_id, type, message, created_at, updated_at,
   is_read, is_deleted, is_edited, from_username)
VALUES
  ('4f42d01e-6537-40d0-a57b-5ac313da068d',
   '5ec9964c-e450-4a03-bcbc-6a72afa3c555',
   '65b08892-e188-4064-b788-c6b1f196e856',
   'text', 'Hello', '2026-08-05T16:31:29.096787', '2026-08-05T16:31:29.096869',
   0, 0, 0, 'anabella_z');
ROLLBACK;
