create extension if not exists pgcrypto;


create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null,
  plan text not null default 'free' check (plan in ('free', 'pro', 'business')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner', 'admin', 'member')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);
create table if not exists public.config (
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

create table if not exists public.instagram_accounts (
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

create table if not exists public.automations (
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

create table if not exists public.followups (
  id uuid primary key default gen_random_uuid(),
  automation_id uuid not null references public.automations(id) on delete cascade,
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

create table if not exists public.contacts (
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
  last_automation_id uuid references public.automations(id) on delete set null,
  updated_at timestamptz not null default now()
);


create table if not exists public.profile_settings (
  id boolean primary key default true,
  channel_active boolean not null default true,
  default_automation_id uuid references public.automations(id) on delete set null,
  opt_in_automation_id uuid references public.automations(id) on delete set null,
  opt_out_automation_id uuid references public.automations(id) on delete set null,
  story_mention_automation_id uuid references public.automations(id) on delete set null,
  persistent_menu_items jsonb not null default '[]'::jsonb,
  ice_breakers jsonb not null default '[]'::jsonb,
  persistent_menu_synced_at timestamptz,
  ice_breakers_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.events (
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
  on public.events (instagram_event_id)
  where instagram_event_id is not null;


create table if not exists public.content_posts (
  id uuid primary key default gen_random_uuid(),
  account_id uuid references public.instagram_accounts(id) on delete cascade,
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
  on public.content_posts (account_id, created_at desc);

alter table public.content_posts
  add column if not exists media_items jsonb not null default '[]'::jsonb;
create table if not exists public.queue (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete set null,
  contact_id uuid references public.contacts(id) on delete set null,
  automation_id uuid references public.automations(id) on delete set null,
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
  on public.queue (instagram_comment_id, send_type)
  where send_type = 'private_reply' and instagram_comment_id is not null;

create index if not exists queue_pending_available_idx
  on public.queue (available_at, status)
  where status = 'pending';

create index if not exists contacts_last_response_idx
  on public.contacts (last_response_at);

insert into public.instagram_accounts (
  instagram_access_token, instagram_user_id, instagram_username, instagram_name,
  instagram_profile_picture_url, token_expires_at, last_token_refresh_at,
  webhook_subscribed_at, is_default
)
select
  instagram_access_token, instagram_user_id, coalesce(instagram_username, instagram_user_id),
  instagram_name, instagram_profile_picture_url, token_expires_at,
  last_token_refresh_at, webhook_subscribed_at, true
from public.config
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

alter table public.automations
  add column if not exists account_id uuid references public.instagram_accounts(id) on delete cascade;

alter table public.contacts
  add column if not exists account_id uuid references public.instagram_accounts(id) on delete cascade,
  add column if not exists human_paused_at timestamptz,
  add column if not exists human_paused_until timestamptz,
  add column if not exists human_pause_reason text,
  add column if not exists tags text[] not null default '{}',
  add column if not exists automation_cooldown_until timestamptz;

alter table public.profile_settings
  add column if not exists account_id uuid references public.instagram_accounts(id) on delete cascade;

alter table public.events
  add column if not exists account_id uuid references public.instagram_accounts(id) on delete cascade;

alter table public.queue
  add column if not exists account_id uuid references public.instagram_accounts(id) on delete cascade;

update public.automations set account_id = (select id from public.instagram_accounts order by is_default desc, created_at asc limit 1) where account_id is null;
update public.contacts set account_id = (select id from public.instagram_accounts order by is_default desc, created_at asc limit 1) where account_id is null;
update public.profile_settings
set account_id = (select id from public.instagram_accounts order by is_default desc, created_at asc limit 1)
where account_id is null
  and not exists (
    select 1
    from public.profile_settings existing
    where existing.account_id = (select id from public.instagram_accounts order by is_default desc, created_at asc limit 1)
  );
update public.events set account_id = (select id from public.instagram_accounts order by is_default desc, created_at asc limit 1) where account_id is null;
update public.queue set account_id = (select id from public.instagram_accounts order by is_default desc, created_at asc limit 1) where account_id is null;

alter table public.contacts drop constraint if exists contacts_instagram_user_id_key;
drop index if exists contacts_account_instagram_user_unique;
create unique index contacts_account_instagram_user_unique
  on public.contacts (account_id, instagram_user_id);

create index if not exists contacts_tags_idx
  on public.contacts using gin (tags);

alter table public.profile_settings drop constraint if exists profile_settings_pkey;
create unique index if not exists profile_settings_account_id_key
  on public.profile_settings (account_id);

drop index if exists events_instagram_event_id_unique;
create unique index if not exists events_account_instagram_event_id_unique
  on public.events (account_id, instagram_event_id)
  where instagram_event_id is not null;

drop index if exists queue_one_private_reply_per_comment;
create unique index if not exists queue_one_private_reply_per_comment
  on public.queue (account_id, instagram_comment_id, send_type)
  where send_type = 'private_reply' and instagram_comment_id is not null;

alter table public.automations
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

alter table public.followups
  add column if not exists delay_seconds integer not null default 0,
  add column if not exists delay_mode text not null default 'fixed',
  add column if not exists delay_min_seconds integer not null default 0,
  add column if not exists delay_max_seconds integer not null default 0;

alter table public.contacts
  add column if not exists instagram_name text,
  add column if not exists instagram_profile_picture_url text,
  add column if not exists instagram_follower_count integer,
  add column if not exists is_user_follow_business boolean,
  add column if not exists is_business_follow_user boolean,
  add column if not exists follower_checked_at timestamptz;

alter table public.contacts
  add column if not exists opted_out_at timestamptz;

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;


drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists set_workspaces_updated_at on public.workspaces;
create trigger set_workspaces_updated_at
  before update on public.workspaces
  for each row execute function public.set_updated_at();
drop trigger if exists set_profile_settings_updated_at on public.profile_settings;
create trigger set_profile_settings_updated_at
  before update on public.profile_settings
  for each row execute function public.set_updated_at();

drop trigger if exists set_instagram_accounts_updated_at on public.instagram_accounts;
create trigger set_instagram_accounts_updated_at
  before update on public.instagram_accounts
  for each row execute function public.set_updated_at();

drop trigger if exists set_config_updated_at on public.config;
create trigger set_config_updated_at
  before update on public.config
  for each row execute function public.set_updated_at();

drop trigger if exists set_automations_updated_at on public.automations;
create trigger set_automations_updated_at
  before update on public.automations
  for each row execute function public.set_updated_at();

drop trigger if exists set_contacts_updated_at on public.contacts;
create trigger set_contacts_updated_at
  before update on public.contacts
  for each row execute function public.set_updated_at();


drop trigger if exists set_content_posts_updated_at on public.content_posts;
create trigger set_content_posts_updated_at
  before update on public.content_posts
  for each row execute function public.set_updated_at();
drop trigger if exists set_queue_updated_at on public.queue;
create trigger set_queue_updated_at
  before update on public.queue
  for each row execute function public.set_updated_at();

create or replace function public.claim_queue_jobs(job_limit integer default 10)
returns setof public.queue as $$
begin
  return query
  with candidate_jobs as (
    select q.id
    from public.queue q
    where q.status = 'pending'
      and q.available_at <= now()
      and (
        q.send_type in ('private_reply', 'public_reply')
        or exists (
          select 1
          from public.contacts c
          where c.id = q.contact_id
            and c.last_response_at is not null
            and c.last_response_at >= now() - interval '24 hours'
        )
      )
    order by q.available_at asc, q.created_at asc
    limit job_limit
    for update of q skip locked
  )
  update public.queue q
  set status = 'sending', claimed_at = now(), attempts = attempts + 1
  from candidate_jobs
  where q.id = candidate_jobs.id
  returning q.*;
end;
$$ language plpgsql;


alter table public.profiles enable row level security;
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = user_id);

drop policy if exists "workspaces_select_member" on public.workspaces;
create policy "workspaces_select_member" on public.workspaces
  for select using (
    exists (
      select 1 from public.workspace_members wm
      where wm.workspace_id = workspaces.id and wm.user_id = auth.uid()
    )
  );

drop policy if exists "workspace_members_select_own" on public.workspace_members;
create policy "workspace_members_select_own" on public.workspace_members
  for select using (auth.uid() = user_id);
alter table public.config enable row level security;
alter table public.instagram_accounts enable row level security;
alter table public.profile_settings enable row level security;
alter table public.automations enable row level security;
alter table public.followups enable row level security;
alter table public.contacts enable row level security;
alter table public.queue enable row level security;
alter table public.events enable row level security;
alter table public.content_posts enable row level security;


insert into public.profiles (user_id, email, full_name, avatar_url)
select
  u.id,
  coalesce(u.email, u.id::text),
  coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name'),
  coalesce(u.raw_user_meta_data->>'avatar_url', u.raw_user_meta_data->>'picture')
from auth.users u
where u.email is not null
on conflict (user_id) do update set
  email = excluded.email,
  full_name = coalesce(excluded.full_name, public.profiles.full_name),
  avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url);

insert into public.workspaces (owner_user_id, name)
select
  u.id,
  concat(split_part(coalesce(u.email, u.id::text), '@', 1), ' Workspace')
from auth.users u
where u.email is not null
on conflict (owner_user_id) do nothing;

insert into public.workspace_members (workspace_id, user_id, role)
select w.id, w.owner_user_id, 'owner'
from public.workspaces w
on conflict (workspace_id, user_id) do nothing;
insert into public.config (id)
values (true)
on conflict (id) do nothing;
