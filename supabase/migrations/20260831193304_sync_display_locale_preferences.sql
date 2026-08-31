begin;

-- Community profiles originally launched with only five locales. Keep the
-- public profile compatible with the app's reviewed 25-locale BCP-47 catalog.
alter table public.bil_public_profiles
  drop constraint if exists bil_public_profiles_locale_code_check;

alter table public.bil_public_profiles
  add constraint bil_public_profiles_locale_code_check
  check (
    locale_code in (
      'ar','en','fr','es','tr','de','it','pt-BR','pt-PT','ur','fa','hi','id',
      'ms','ja','ko','zh-Hans','zh-Hant','ru','bn','vi','th','pl','nl','uk'
    )
  );

-- This preference is user-controlled presentation data only. It must never be
-- consumed as authorization, entitlement, subscription, or quota evidence.
create table public.bil_user_locale_preferences (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  locale_code text not null,
  updated_at timestamptz not null default now(),
  constraint bil_user_locale_preferences_locale_code_check
    check (
      locale_code in (
        'ar','en','fr','es','tr','de','it','pt-BR','pt-PT','ur','fa','hi','id',
        'ms','ja','ko','zh-Hans','zh-Hant','ru','bn','vi','th','pl','nl','uk'
      )
    )
);

alter table public.bil_user_locale_preferences enable row level security;

drop policy if exists bil_user_locale_preferences_select_own
  on public.bil_user_locale_preferences;
create policy bil_user_locale_preferences_select_own
  on public.bil_user_locale_preferences
  for select
  to authenticated
  using (owner_id = (select auth.uid()));

drop policy if exists bil_user_locale_preferences_insert_own
  on public.bil_user_locale_preferences;
create policy bil_user_locale_preferences_insert_own
  on public.bil_user_locale_preferences
  for insert
  to authenticated
  with check (owner_id = (select auth.uid()));

drop policy if exists bil_user_locale_preferences_update_own
  on public.bil_user_locale_preferences;
create policy bil_user_locale_preferences_update_own
  on public.bil_user_locale_preferences
  for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

revoke all on table public.bil_user_locale_preferences
  from public, anon, authenticated;
grant select, insert, update on table public.bil_user_locale_preferences
  to authenticated;

create or replace function private.bil_touch_user_locale_preference()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

drop trigger if exists bil_user_locale_preferences_touch_updated_at
  on public.bil_user_locale_preferences;
create trigger bil_user_locale_preferences_touch_updated_at
before update on public.bil_user_locale_preferences
for each row execute function private.bil_touch_user_locale_preference();

revoke all on function private.bil_touch_user_locale_preference()
  from public, anon, authenticated;

-- Prefer the explicit app display-language preference for canned notices.
-- Auth metadata remains a compatibility fallback only and is never authority.
create or replace function private.bil_admin_notification_locale(
  p_owner_id uuid
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    case
      when lower(replace(coalesce(lp.locale_code, ''), '_', '-'))
        in (
          'ar','en','fr','es','tr','de','it','pt-br','pt-pt','ur','fa',
          'hi','id','ms','ja','ko','zh-hans','zh-hant','ru','bn','vi',
          'th','pl','nl','uk'
        )
      then lower(replace(lp.locale_code, '_', '-'))
    end,
    case
      when lower(replace(coalesce(u.raw_app_meta_data->>'locale', ''), '_', '-'))
        in (
          'ar','en','fr','es','tr','de','it','pt-br','pt-pt','ur','fa',
          'hi','id','ms','ja','ko','zh-hans','zh-hant','ru','bn','vi',
          'th','pl','nl','uk'
        )
      then lower(replace(u.raw_app_meta_data->>'locale', '_', '-'))
    end,
    case
      when lower(replace(coalesce(p.locale_code, ''), '_', '-'))
        in (
          'ar','en','fr','es','tr','de','it','pt-br','pt-pt','ur','fa',
          'hi','id','ms','ja','ko','zh-hans','zh-hant','ru','bn','vi',
          'th','pl','nl','uk'
        )
      then lower(replace(p.locale_code, '_', '-'))
    end,
    case
      when lower(replace(coalesce(u.raw_user_meta_data->>'locale', ''), '_', '-'))
        in (
          'ar','en','fr','es','tr','de','it','pt-br','pt-pt','ur','fa',
          'hi','id','ms','ja','ko','zh-hans','zh-hant','ru','bn','vi',
          'th','pl','nl','uk'
        )
      then lower(replace(u.raw_user_meta_data->>'locale', '_', '-'))
    end,
    'en'
  )
  from auth.users u
  left join public.bil_user_locale_preferences lp on lp.owner_id = u.id
  left join public.bil_public_profiles p on p.user_id = u.id
  where u.id = p_owner_id
$$;

revoke all on function private.bil_admin_notification_locale(uuid)
  from public, anon, authenticated;

comment on table public.bil_user_locale_preferences is
  'Own-row display-language preference used to localize server-authored copy. Presentation data only; never authorization or entitlement evidence.';
comment on column public.bil_user_locale_preferences.locale_code is
  'Canonical BCP-47 tag from the reviewed BIL 25-locale allowlist.';

commit;
