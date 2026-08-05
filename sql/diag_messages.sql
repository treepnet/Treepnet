-- Read-only diagnostics for the chat unread/is_read issue.

\echo '== is_read ustuni tipi =='
select column_name, data_type, column_default, is_nullable
from information_schema.columns
where table_name = 'messages' and column_name in ('is_read','is_deleted');

\echo '== is_read taqsimoti (backend) =='
select is_read, count(*) from public.messages group by 1 order by 1;

\echo '== messages jadvalining HAMMA ustunlari (client kutgani bilan solishtirish uchun) =='
select column_name, data_type
from information_schema.columns
where table_name = 'messages'
order by ordinal_position;

\echo '== oxirgi 5 xabar: is_read holati =='
select id, from_id, is_read, is_deleted, left(coalesce(message,''), 15) as msg, created_at
from public.messages
order by created_at desc
limit 5;
