do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'auth') then
    execute 'create schema auth';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on p.pronamespace = n.oid where p.proname = 'uid' and n.nspname = 'auth') then
    execute 'create function auth.uid() returns uuid as $f$ select null::uuid; $f$ language sql stable';
  end if;
exception when others then
  null;
end $$;

alter table if exists public.profiles drop constraint if exists profiles_user_id_fkey;
alter table if exists public.workspaces drop constraint if exists workspaces_owner_user_id_fkey;
alter table if exists public.workspace_members drop constraint if exists workspace_members_user_id_fkey;
