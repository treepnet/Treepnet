-- A signed-in user can change their name and username again.
--
-- missing_indexes_2.sql (2026-10-31) indexed search_key(username) and
-- search_key(full_name) for search_profiles. Postgres runs an index's
-- functions with the rights of whoever writes the row, and search_key's
-- EXECUTE had been revoked from authenticated (search_profiles.sql). Since
-- then the server refused every username or full-name change the app sent
-- ("permission denied for function search_key", 42501): the app drops such a
-- change from its upload queue and says "Couldn't save your change". Any
-- other profile edit could hit it too, whenever Postgres had to write the
-- row's index entries anew.
--
-- search_key only normalises text (case, Latin and Cyrillic folding):
-- calling it reveals nothing.

grant execute on function public.search_key(text) to authenticated;
