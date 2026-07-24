-- Know Your Rights managed-auth foundation.
-- Run with `supabase db push` against the selected project.

create type public.app_role as enum
  ('reader', 'contributor', 'reviewer', 'administrator');

create table public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'reader',
  updated_at timestamptz not null default now()
);

alter table public.user_roles enable row level security;

create policy "users can read their own role"
on public.user_roles for select
to authenticated
using ((select auth.uid()) = user_id);

-- Role changes are intentionally service-role only. No client INSERT/UPDATE policy.

create or replace function public.create_default_user_role()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.user_roles(user_id, role)
  values (new.id, 'reader')
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created_role
after insert on auth.users
for each row execute procedure public.create_default_user_role();

-- Add the application role to access tokens. Enable this function as the
-- project's Custom Access Token Hook in Authentication > Hooks.
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer set search_path = ''
as $$
declare
  claims jsonb;
  assigned_role public.app_role;
begin
  select role into assigned_role
  from public.user_roles
  where user_id = (event->>'user_id')::uuid;

  claims := event->'claims';
  claims := jsonb_set(
    claims,
    '{app_metadata}',
    coalesce(claims->'app_metadata', '{}'::jsonb)
      || jsonb_build_object('app_role', coalesce(assigned_role, 'reader'))
  );
  return jsonb_set(event, '{claims}', claims);
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook(jsonb) from authenticated, anon, public;
grant select on public.user_roles to supabase_auth_admin;

