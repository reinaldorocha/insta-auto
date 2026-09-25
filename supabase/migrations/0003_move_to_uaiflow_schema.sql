-- ==============================================================================
-- Migration 0003: Mover tabelas do UaiFlow para o schema dedicado 'uaiflow'
-- Isso isola o UaiFlow no Supabase permitindo que outros apps fiquem no 'public'.
-- ==============================================================================

-- 1. Criar o schema dedicado uaiflow
create schema if not exists uaiflow;

-- 2. Mover as tabelas do UaiFlow de public para uaiflow (preserva 100% dos dados)
alter table if exists public.profiles set schema uaiflow;
alter table if exists public.workspaces set schema uaiflow;
alter table if exists public.workspace_members set schema uaiflow;
alter table if exists public.config set schema uaiflow;
alter table if exists public.instagram_accounts set schema uaiflow;
alter table if exists public.automations set schema uaiflow;
alter table if exists public.followups set schema uaiflow;
alter table if exists public.contacts set schema uaiflow;
alter table if exists public.profile_settings set schema uaiflow;
alter table if exists public.events set schema uaiflow;
alter table if exists public.content_posts set schema uaiflow;
alter table if exists public.queue set schema uaiflow;

-- 3. Mover a funcao set_updated_at para uaiflow
alter function if exists public.set_updated_at() set schema uaiflow;

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

-- 5. Conceder todas as permissoes para o Postgres, Supabase Auth e Studio
grant usage on schema uaiflow to postgres, anon, authenticated, service_role;
grant all privileges on all tables in schema uaiflow to postgres, anon, authenticated, service_role;
grant all privileges on all sequences in schema uaiflow to postgres, anon, authenticated, service_role;
grant all privileges on all routines in schema uaiflow to postgres, anon, authenticated, service_role;

alter default privileges in schema uaiflow grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema uaiflow grant all on sequences to postgres, anon, authenticated, service_role;
alter default privileges in schema uaiflow grant all on routines to postgres, anon, authenticated, service_role;
