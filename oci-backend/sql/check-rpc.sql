\echo === delete_account va account funksiyalari ===
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname ILIKE '%delete_account%' OR p.proname ILIKE '%account_del%'
ORDER BY 1,2;
\echo === PostgREST public schema dagi RPC lar (SECURITY DEFINER) ===
SELECT p.proname
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind='f' AND p.prosecdef
ORDER BY 1;
