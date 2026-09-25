-- ==============================================================================
-- Migration 0003: Mover tabelas do UaiFlow para o schema dedicado 'uaiflow'
-- Isso isola o UaiFlow no Supabase permitindo que outros apps fiquem no 'public'.
-- ==============================================================================

-- 1. Criar o schema dedicado uaiflow
create schema if not exists uaiflow;

-- 2. Mover tabelas de public para uaiflow apenas se nao existirem em uaiflow
do $$
declare
  tbl text;
begin
  for tbl in select unnest(array['profiles', 'workspaces', 'workspace_members', 'config', 'instagram_accounts', 'automations', 'followups', 'contacts', 'profile_settings', 'events', 'content_posts', 'queue']) loop
    if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = tbl)
       and not exists (select 1 from information_schema.tables where table_schema = 'uaiflow' and table_name = tbl) then
      execute format('alter table public.%I set schema uaiflow', tbl);
    end if;
  end loop;
end $$;

-- 3. Criar a funcao set_updated_at no schema uaiflow e atualizar triggers
create or replace function uaiflow.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_profiles_updated_at on uaiflow.profiles;
create trigger set_profiles_updated_at before update on uaiflow.profiles for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_workspaces_updated_at on uaiflow.workspaces;
create trigger set_workspaces_updated_at before update on uaiflow.workspaces for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_profile_settings_updated_at on uaiflow.profile_settings;
create trigger set_profile_settings_updated_at before update on uaiflow.profile_settings for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_instagram_accounts_updated_at on uaiflow.instagram_accounts;
create trigger set_instagram_accounts_updated_at before update on uaiflow.instagram_accounts for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_config_updated_at on uaiflow.config;
create trigger set_config_updated_at before update on uaiflow.config for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_automations_updated_at on uaiflow.automations;
create trigger set_automations_updated_at before update on uaiflow.automations for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_contacts_updated_at on uaiflow.contacts;
create trigger set_contacts_updated_at before update on uaiflow.contacts for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_content_posts_updated_at on uaiflow.content_posts;
create trigger set_content_posts_updated_at before update on uaiflow.content_posts for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_queue_updated_at on uaiflow.queue;
create trigger set_queue_updated_at before update on uaiflow.queue for each row execute function uaiflow.set_updated_at();

-- 4. Criar a funcao claim_queue_jobs dentro do schema uaiflow
create or replace function uaiflow.claim_queue_jobs(job_limit integer default 10)
returns setof uaiflow.queue as $$
begin
  return query
  with candidate_jobs as (
    select q.id
    from uaiflow.queue q
    where q.status = 'pending'
      and q.available_at <= now()
      and (
        q.send_type in ('private_reply', 'public_reply')
        or exists (
          select 1
          from uaiflow.contacts c
          where c.id = q.contact_id
            and c.last_response_at is not null
            and c.last_response_at >= now() - interval '24 hours'
        )
      )
    order by q.available_at asc, q.created_at asc
    limit job_limit
    for update of q skip locked
  )
  update uaiflow.queue q
  set status = 'sending', claimed_at = now(), attempts = attempts + 1
  from candidate_jobs
  where q.id = candidate_jobs.id
  returning q.*;
end;
$$ language plpgsql;

-- 5. Conceder todas as permissoes de forma segura para os papeis existentes
do $$
declare
  r text;
begin
  for r in select unnest(array['postgres', 'anon', 'authenticated', 'service_role', 'authenticator', 'supabase_admin', 'dashboard_user']) loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('grant usage on schema uaiflow to %I', r);
      execute format('grant all privileges on all tables in schema uaiflow to %I', r);
      execute format('grant all privileges on all sequences in schema uaiflow to %I', r);
      execute format('grant all privileges on all routines in schema uaiflow to %I', r);
      execute format('alter default privileges in schema uaiflow grant all on tables to %I', r);
      execute format('alter default privileges in schema uaiflow grant all on sequences to %I', r);
      execute format('alter default privileges in schema uaiflow grant all on routines to %I', r);
    end if;
  end loop;
  perform pg_notify('pgrst', 'reload schema');
end $$;
