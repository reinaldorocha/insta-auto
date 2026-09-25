create extension if not exists pgcrypto;
create schema if not exists uaiflow;



create table if not exists uaiflow.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists uaiflow.workspaces (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null,
  plan text not null default 'free' check (plan in ('free', 'pro', 'business')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists uaiflow.workspace_members (
  workspace_id uuid not null references uaiflow.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner', 'admin', 'member')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);
create table if not exists uaiflow.config (
  id boolean primary key default true check (id = true),
  instagram_access_token text,
  instagram_user_id text,
  instagram_username text,
  instagram_name text,
  instagram_profile_picture_url text,
  token_expires_at timestamptz,
  last_token_refresh_at timestamptz,
  webhook_subscribed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists uaiflow.instagram_accounts (
  id uuid primary key default gen_random_uuid(),
  instagram_access_token text not null,
  instagram_user_id text not null unique,
  instagram_username text not null,
  instagram_name text,
  instagram_profile_picture_url text,
  token_expires_at timestamptz,
  last_token_refresh_at timestamptz,
  webhook_subscribed_at timestamptz,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists uaiflow.automations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  active boolean not null default true,
  triggers text[] not null default array['comments'],
  keywords text[] not null default '{}',
  match_type text not null default 'contains' check (match_type in ('contains', 'exact', 'any')),
  post_id text,
  public_replies text[] not null default '{}',
  public_reply_mode text not null default 'random' check (public_reply_mode in ('fixed', 'random')),
  welcome_dm text not null default '',
  quick_reply_label text not null default 'Quero receber',
  quick_replies jsonb not null default '[]'::jsonb,
  link_text text not null default '',
  link_button_label text not null default 'Abrir link',
  link_url text not null default '',
  reply_delay_seconds integer not null default 0 check (reply_delay_seconds >= 0),
  reply_delay_mode text not null default 'fixed' check (reply_delay_mode in ('fixed', 'random')),
  reply_delay_min_seconds integer not null default 0 check (reply_delay_min_seconds >= 0),
  reply_delay_max_seconds integer not null default 0 check (reply_delay_max_seconds >= 0),
  reminder_text text not null default '',
  reminder_delay_minutes integer not null default 1440 check (reminder_delay_minutes >= 0),
  reminder_delay_seconds integer not null default 86400 check (reminder_delay_seconds >= 0),
  reminder_delay_mode text not null default 'fixed' check (reminder_delay_mode in ('fixed', 'random')),
  reminder_delay_min_seconds integer not null default 86400 check (reminder_delay_min_seconds >= 0),
  reminder_delay_max_seconds integer not null default 86400 check (reminder_delay_max_seconds >= 0),
  require_follower boolean not null default false,
  non_follower_dm text not null default 'Primeiro precisa me seguir para receber o acesso, depois que me seguir digite novamente a palavra que enviou acima.',
  non_follower_button_label text not null default 'Seguir no Insta',
  follower_confirmation_text text not null default 'Digite Eu Quero aqui em baixo para liberar.',
  follower_confirmation_greetings text[] not null default array['Oii','Ola','Eii','Eae','Opa'],
  flow_nodes jsonb not null default '[]'::jsonb,
  flow_edges jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists uaiflow.followups (
  id uuid primary key default gen_random_uuid(),
  automation_id uuid not null references uaiflow.automations(id) on delete cascade,
  step_order integer not null,
  message_type text not null default 'text' check (message_type in ('text', 'link', 'reminder')),
  body text not null,
  button_label text,
  url text,
  delay_minutes integer not null default 0 check (delay_minutes >= 0),
  delay_seconds integer not null default 0 check (delay_seconds >= 0),
  delay_mode text not null default 'fixed' check (delay_mode in ('fixed', 'random')),
  delay_min_seconds integer not null default 0 check (delay_min_seconds >= 0),
  delay_max_seconds integer not null default 0 check (delay_max_seconds >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (automation_id, step_order)
);

create table if not exists uaiflow.contacts (
  id uuid primary key default gen_random_uuid(),
  instagram_user_id text not null unique,
  instagram_username text,
  instagram_name text,
  instagram_profile_picture_url text,
  tags text[] not null default '{}',
  instagram_follower_count integer,
  is_user_follow_business boolean,
  is_business_follow_user boolean,
  follower_checked_at timestamptz,
  first_contact_at timestamptz not null default now(),
  last_response_at timestamptz,
  last_automation_id uuid references uaiflow.automations(id) on delete set null,
  updated_at timestamptz not null default now()
);


create table if not exists uaiflow.profile_settings (
  id boolean primary key default true,
  channel_active boolean not null default true,
  default_automation_id uuid references uaiflow.automations(id) on delete set null,
  opt_in_automation_id uuid references uaiflow.automations(id) on delete set null,
  opt_out_automation_id uuid references uaiflow.automations(id) on delete set null,
  story_mention_automation_id uuid references uaiflow.automations(id) on delete set null,
  persistent_menu_items jsonb not null default '[]'::jsonb,
  ice_breakers jsonb not null default '[]'::jsonb,
  persistent_menu_synced_at timestamptz,
  ice_breakers_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists uaiflow.events (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'instagram',
  event_type text not null,
  instagram_event_id text,
  instagram_user_id text,
  instagram_username text,
  instagram_comment_id text,
  instagram_media_id text,
  payload jsonb not null default '{}'::jsonb,
  received_at timestamptz not null default now()
);

create unique index if not exists events_instagram_event_id_unique
  on uaiflow.events (instagram_event_id)
  where instagram_event_id is not null;


create table if not exists uaiflow.content_posts (
  id uuid primary key default gen_random_uuid(),
  account_id uuid references uaiflow.instagram_accounts(id) on delete cascade,
  publish_type text not null check (publish_type in ('feed_image', 'feed_video', 'reel_video', 'story_image', 'story_video', 'carousel')),
  caption text not null default '',
  media_url text not null,
  cover_url text,
  media_items jsonb not null default '[]'::jsonb,
  container_id text,
  published_media_id text,
  permalink text,
  status text not null default 'draft' check (status in ('draft', 'publishing', 'published', 'failed')),
  last_error text,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists content_posts_account_created_idx
  on uaiflow.content_posts (account_id, created_at desc);

alter table uaiflow.content_posts
  add column if not exists media_items jsonb not null default '[]'::jsonb;
create table if not exists uaiflow.queue (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references uaiflow.events(id) on delete set null,
  contact_id uuid references uaiflow.contacts(id) on delete set null,
  automation_id uuid references uaiflow.automations(id) on delete set null,
  instagram_recipient_id text,
  instagram_comment_id text,
  send_type text not null check (send_type in ('private_reply', 'dm', 'public_reply')),
  payload jsonb not null default '{}'::jsonb,
  available_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending', 'sending', 'sent', 'failed', 'skipped')),
  attempts integer not null default 0,
  claimed_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists queue_one_private_reply_per_comment
  on uaiflow.queue (instagram_comment_id, send_type)
  where send_type = 'private_reply' and instagram_comment_id is not null;

create index if not exists queue_pending_available_idx
  on uaiflow.queue (available_at, status)
  where status = 'pending';

create index if not exists contacts_last_response_idx
  on uaiflow.contacts (last_response_at);

insert into uaiflow.instagram_accounts (
  instagram_access_token, instagram_user_id, instagram_username, instagram_name,
  instagram_profile_picture_url, token_expires_at, last_token_refresh_at,
  webhook_subscribed_at, is_default
)
select
  instagram_access_token, instagram_user_id, coalesce(instagram_username, instagram_user_id),
  instagram_name, instagram_profile_picture_url, token_expires_at,
  last_token_refresh_at, webhook_subscribed_at, true
from uaiflow.config
where instagram_access_token is not null and instagram_user_id is not null
on conflict (instagram_user_id) do update set
  instagram_access_token = excluded.instagram_access_token,
  instagram_username = excluded.instagram_username,
  instagram_name = excluded.instagram_name,
  instagram_profile_picture_url = excluded.instagram_profile_picture_url,
  token_expires_at = excluded.token_expires_at,
  last_token_refresh_at = excluded.last_token_refresh_at,
  webhook_subscribed_at = excluded.webhook_subscribed_at,
  is_default = excluded.is_default;

alter table uaiflow.automations
  add column if not exists account_id uuid references uaiflow.instagram_accounts(id) on delete cascade;

alter table uaiflow.contacts
  add column if not exists account_id uuid references uaiflow.instagram_accounts(id) on delete cascade,
  add column if not exists human_paused_at timestamptz,
  add column if not exists human_paused_until timestamptz,
  add column if not exists human_pause_reason text,
  add column if not exists tags text[] not null default '{}',
  add column if not exists automation_cooldown_until timestamptz;

alter table uaiflow.profile_settings
  add column if not exists account_id uuid references uaiflow.instagram_accounts(id) on delete cascade;

alter table uaiflow.events
  add column if not exists account_id uuid references uaiflow.instagram_accounts(id) on delete cascade;

alter table uaiflow.queue
  add column if not exists account_id uuid references uaiflow.instagram_accounts(id) on delete cascade;

update uaiflow.automations set account_id = (select id from uaiflow.instagram_accounts order by is_default desc, created_at asc limit 1) where account_id is null;
update uaiflow.contacts set account_id = (select id from uaiflow.instagram_accounts order by is_default desc, created_at asc limit 1) where account_id is null;
update uaiflow.profile_settings
set account_id = (select id from uaiflow.instagram_accounts order by is_default desc, created_at asc limit 1)
where account_id is null
  and not exists (
    select 1
    from uaiflow.profile_settings existing
    where existing.account_id = (select id from uaiflow.instagram_accounts order by is_default desc, created_at asc limit 1)
  );
update uaiflow.events set account_id = (select id from uaiflow.instagram_accounts order by is_default desc, created_at asc limit 1) where account_id is null;
update uaiflow.queue set account_id = (select id from uaiflow.instagram_accounts order by is_default desc, created_at asc limit 1) where account_id is null;

alter table uaiflow.contacts drop constraint if exists contacts_instagram_user_id_key;
drop index if exists contacts_account_instagram_user_unique;
create unique index contacts_account_instagram_user_unique
  on uaiflow.contacts (account_id, instagram_user_id);

create index if not exists contacts_tags_idx
  on uaiflow.contacts using gin (tags);

alter table uaiflow.profile_settings drop constraint if exists profile_settings_pkey;
create unique index if not exists profile_settings_account_id_key
  on uaiflow.profile_settings (account_id);

drop index if exists events_instagram_event_id_unique;
create unique index if not exists events_account_instagram_event_id_unique
  on uaiflow.events (account_id, instagram_event_id)
  where instagram_event_id is not null;

drop index if exists queue_one_private_reply_per_comment;
create unique index if not exists queue_one_private_reply_per_comment
  on uaiflow.queue (account_id, instagram_comment_id, send_type)
  where send_type = 'private_reply' and instagram_comment_id is not null;

alter table uaiflow.automations
  add column if not exists reply_delay_seconds integer not null default 0,
  add column if not exists reply_delay_mode text not null default 'fixed',
  add column if not exists reply_delay_min_seconds integer not null default 0,
  add column if not exists reply_delay_max_seconds integer not null default 0,
  add column if not exists public_reply_mode text not null default 'random',
  add column if not exists reminder_delay_seconds integer not null default 86400,
  add column if not exists reminder_delay_mode text not null default 'fixed',
  add column if not exists reminder_delay_min_seconds integer not null default 86400,
  add column if not exists reminder_delay_max_seconds integer not null default 86400,
  add column if not exists quick_replies jsonb not null default '[]'::jsonb,
  add column if not exists require_follower boolean not null default false,
  add column if not exists non_follower_dm text not null default 'Primeiro precisa me seguir para receber o acesso, depois que me seguir digite novamente a palavra que enviou acima.',
  add column if not exists non_follower_button_label text not null default 'Seguir no Insta',
  add column if not exists follower_confirmation_text text not null default 'Digite Eu Quero aqui em baixo para liberar.',
  add column if not exists follower_confirmation_greetings text[] not null default array['Oii','Ola','Eii','Eae','Opa'],
  add column if not exists flow_nodes jsonb not null default '[]'::jsonb,
  add column if not exists flow_edges jsonb not null default '[]'::jsonb;

alter table uaiflow.followups
  add column if not exists delay_seconds integer not null default 0,
  add column if not exists delay_mode text not null default 'fixed',
  add column if not exists delay_min_seconds integer not null default 0,
  add column if not exists delay_max_seconds integer not null default 0;

alter table uaiflow.contacts
  add column if not exists instagram_name text,
  add column if not exists instagram_profile_picture_url text,
  add column if not exists instagram_follower_count integer,
  add column if not exists is_user_follow_business boolean,
  add column if not exists is_business_follow_user boolean,
  add column if not exists follower_checked_at timestamptz;

alter table uaiflow.contacts
  add column if not exists opted_out_at timestamptz;

create or replace function uaiflow.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;


drop trigger if exists set_profiles_updated_at on uaiflow.profiles;
create trigger set_profiles_updated_at
  before update on uaiflow.profiles
  for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_workspaces_updated_at on uaiflow.workspaces;
create trigger set_workspaces_updated_at
  before update on uaiflow.workspaces
  for each row execute function uaiflow.set_updated_at();
drop trigger if exists set_profile_settings_updated_at on uaiflow.profile_settings;
create trigger set_profile_settings_updated_at
  before update on uaiflow.profile_settings
  for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_instagram_accounts_updated_at on uaiflow.instagram_accounts;
create trigger set_instagram_accounts_updated_at
  before update on uaiflow.instagram_accounts
  for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_config_updated_at on uaiflow.config;
create trigger set_config_updated_at
  before update on uaiflow.config
  for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_automations_updated_at on uaiflow.automations;
create trigger set_automations_updated_at
  before update on uaiflow.automations
  for each row execute function uaiflow.set_updated_at();

drop trigger if exists set_contacts_updated_at on uaiflow.contacts;
create trigger set_contacts_updated_at
  before update on uaiflow.contacts
  for each row execute function uaiflow.set_updated_at();


drop trigger if exists set_content_posts_updated_at on uaiflow.content_posts;
create trigger set_content_posts_updated_at
  before update on uaiflow.content_posts
  for each row execute function uaiflow.set_updated_at();
drop trigger if exists set_queue_updated_at on uaiflow.queue;
create trigger set_queue_updated_at
  before update on uaiflow.queue
  for each row execute function uaiflow.set_updated_at();

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


alter table uaiflow.profiles enable row level security;
alter table uaiflow.workspaces enable row level security;
alter table uaiflow.workspace_members enable row level security;

drop policy if exists "profiles_select_own" on uaiflow.profiles;
create policy "profiles_select_own" on uaiflow.profiles
  for select using (auth.uid() = user_id);

drop policy if exists "profiles_update_own" on uaiflow.profiles;
create policy "profiles_update_own" on uaiflow.profiles
  for update using (auth.uid() = user_id);

drop policy if exists "workspaces_select_member" on uaiflow.workspaces;
create policy "workspaces_select_member" on uaiflow.workspaces
  for select using (
    exists (
      select 1 from uaiflow.workspace_members wm
      where wm.workspace_id = workspaces.id and wm.user_id = auth.uid()
    )
  );

drop policy if exists "workspace_members_select_own" on uaiflow.workspace_members;
create policy "workspace_members_select_own" on uaiflow.workspace_members
  for select using (auth.uid() = user_id);
alter table uaiflow.config enable row level security;
alter table uaiflow.instagram_accounts enable row level security;
alter table uaiflow.profile_settings enable row level security;
alter table uaiflow.automations enable row level security;
alter table uaiflow.followups enable row level security;
alter table uaiflow.contacts enable row level security;
alter table uaiflow.queue enable row level security;
alter table uaiflow.events enable row level security;
alter table uaiflow.content_posts enable row level security;


do $$
begin
  if exists (select 1 from information_schema.tables where table_schema = 'auth' and table_name = 'users') then
    insert into uaiflow.profiles (user_id, email, full_name, avatar_url)
    select
      u.id,
      coalesce(u.email, u.id::text),
      coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name'),
      coalesce(u.raw_user_meta_data->>'avatar_url', u.raw_user_meta_data->>'picture')
    from auth.users u
    where u.email is not null
    on conflict (user_id) do update set
      email = excluded.email,
      full_name = coalesce(excluded.full_name, uaiflow.profiles.full_name),
      avatar_url = coalesce(excluded.avatar_url, uaiflow.profiles.avatar_url);

    insert into uaiflow.workspaces (owner_user_id, name)
    select
      u.id,
      concat(split_part(coalesce(u.email, u.id::text), '@', 1), ' Workspace')
    from auth.users u
    where u.email is not null
    on conflict (owner_user_id) do nothing;

    insert into uaiflow.workspace_members (workspace_id, user_id, role)
    select w.id, w.owner_user_id, 'owner'
    from uaiflow.workspaces w
    on conflict (workspace_id, user_id) do nothing;
  end if;
exception when others then
  null;
end $$;

insert into uaiflow.config (id)
values (true)
on conflict (id) do nothing;

grant usage on schema uaiflow to postgres, anon, authenticated, service_role, authenticator;
grant all privileges on all tables in schema uaiflow to postgres, anon, authenticated, service_role, authenticator;
grant all privileges on all sequences in schema uaiflow to postgres, anon, authenticated, service_role, authenticator;
grant all privileges on all routines in schema uaiflow to postgres, anon, authenticated, service_role, authenticator;
alter default privileges in schema uaiflow grant all on tables to postgres, anon, authenticated, service_role, authenticator;
alter default privileges in schema uaiflow grant all on sequences to postgres, anon, authenticated, service_role, authenticator;
alter default privileges in schema uaiflow grant all on routines to postgres, anon, authenticated, service_role, authenticator;
