\echo === Custom roles ===
SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname NOT LIKE 'pg\_%' ESCAPE '\' AND rolname <> 'treepnet' ORDER BY 1;
\echo === auth/public helper functions ===
SELECT n.nspname, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname IN ('uid','jwt','role','email') ORDER BY 1,2;
\echo === RLS policies count + rls-enabled tables ===
SELECT count(*) AS policies FROM pg_policies;
SELECT count(*) AS rls_tables FROM pg_class WHERE relrowsecurity AND relkind='r';
