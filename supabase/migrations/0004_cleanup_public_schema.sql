-- ==============================================================================
-- Migration 0004: Limpar tabelas legadas do UaiFlow que ficaram no schema 'public'
-- Garante que o schema public fique 100% limpo, já que todos os dados agora vivem em 'uaiflow'
-- ==============================================================================

-- 1. Sincronizar qualquer dado residual de config do public para uaiflow antes de remover
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'config') then
    update uaiflow.config u
    set 
      instagram_access_token = coalesce(u.instagram_access_token, p.instagram_access_token),
      instagram_user_id = coalesce(u.instagram_user_id, p.instagram_user_id),
      instagram_username = coalesce(u.instagram_username, p.instagram_username),
      instagram_name = coalesce(u.instagram_name, p.instagram_name),
      instagram_profile_picture_url = coalesce(u.instagram_profile_picture_url, p.instagram_profile_picture_url),
      token_expires_at = coalesce(u.token_expires_at, p.token_expires_at),
      last_token_refresh_at = coalesce(u.last_token_refresh_at, p.last_token_refresh_at),
      webhook_subscribed_at = coalesce(u.webhook_subscribed_at, p.webhook_subscribed_at)
    from public.config p
    where u.id = p.id;
  end if;
end $$;

-- 2. Remover com seguranca as tabelas antigas do public
drop table if exists public.events cascade;
drop table if exists public.queue cascade;
drop table if exists public.followups cascade;
drop table if exists public.contacts cascade;
drop table if exists public.automations cascade;
drop table if exists public.content_posts cascade;
drop table if exists public.profile_settings cascade;
drop table if exists public.instagram_accounts cascade;
drop table if exists public.config cascade;
drop table if exists public.schema_migrations cascade;

-- 3. Notificar o PostgREST para recarregar o schema cache
select pg_notify('pgrst', 'reload schema');
