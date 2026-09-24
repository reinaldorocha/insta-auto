-- Remove restricoes de chave estrangeira com auth.users para permitir banco isolado/multi-tenant
create schema if not exists auth;

create or replace function auth.uid() returns uuid as $$
  select null::uuid;
$$ language sql stable;

alter table if exists public.profiles drop constraint if exists profiles_user_id_fkey;
alter table if exists public.workspaces drop constraint if exists workspaces_owner_user_id_fkey;
alter table if exists public.workspace_members drop constraint if exists workspace_members_user_id_fkey;
