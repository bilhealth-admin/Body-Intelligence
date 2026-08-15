begin;

create extension if not exists pgcrypto;

create table if not exists public.bil_cloud_devices (
  owner_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (length(device_id) between 8 and 200),
  platform text not null default 'unknown',
  app_version text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (owner_id, device_id)
);

create table if not exists public.bil_cloud_records (
  owner_id uuid not null references auth.users(id) on delete cascade,
  entity_kind text not null check (entity_kind in (
    'profile', 'goal', 'weight', 'measurement', 'nutrition', 'hydration',
    'sleep', 'activity', 'decisionMemory', 'intelligenceOutput', 'coach',
    'community', 'file', 'settings'
  )),
  record_id text not null check (length(record_id) between 1 and 200),
  device_id text not null check (length(device_id) between 8 and 200),
  revision_sequence bigint not null check (revision_sequence >= 0),
  schema_version integer not null default 1 check (schema_version > 0),
  payload jsonb not null default '{}'::jsonb,
  client_updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, entity_kind, record_id),
  constraint bil_cloud_records_deleted_time_check
    check (deleted_at is null or deleted_at <= client_updated_at)
);

create index if not exists bil_cloud_records_pull_idx
  on public.bil_cloud_records (owner_id, server_updated_at, entity_kind, record_id);
create index if not exists bil_cloud_records_device_revision_idx
  on public.bil_cloud_records (owner_id, device_id, revision_sequence desc);

create or replace function public.bil_set_server_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.server_updated_at = now();
  return new;
end;
$$;

drop trigger if exists bil_cloud_records_touch on public.bil_cloud_records;
create trigger bil_cloud_records_touch before insert or update
on public.bil_cloud_records for each row
execute function public.bil_set_server_updated_at();

alter table public.bil_cloud_devices enable row level security;
alter table public.bil_cloud_records enable row level security;

drop policy if exists bil_devices_select_own on public.bil_cloud_devices;
create policy bil_devices_select_own on public.bil_cloud_devices
for select to authenticated using ((select auth.uid()) = owner_id);
drop policy if exists bil_devices_insert_own on public.bil_cloud_devices;
create policy bil_devices_insert_own on public.bil_cloud_devices
for insert to authenticated with check ((select auth.uid()) = owner_id);
drop policy if exists bil_devices_update_own on public.bil_cloud_devices;
create policy bil_devices_update_own on public.bil_cloud_devices
for update to authenticated using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
drop policy if exists bil_devices_delete_own on public.bil_cloud_devices;
create policy bil_devices_delete_own on public.bil_cloud_devices
for delete to authenticated using ((select auth.uid()) = owner_id);

drop policy if exists bil_records_select_own on public.bil_cloud_records;
create policy bil_records_select_own on public.bil_cloud_records
for select to authenticated using ((select auth.uid()) = owner_id);
drop policy if exists bil_records_insert_own on public.bil_cloud_records;
create policy bil_records_insert_own on public.bil_cloud_records
for insert to authenticated with check ((select auth.uid()) = owner_id);
drop policy if exists bil_records_update_own on public.bil_cloud_records;
create policy bil_records_update_own on public.bil_cloud_records
for update to authenticated using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);
drop policy if exists bil_records_delete_own on public.bil_cloud_records;
create policy bil_records_delete_own on public.bil_cloud_records
for delete to authenticated using ((select auth.uid()) = owner_id);

revoke all on public.bil_cloud_devices from anon;
revoke all on public.bil_cloud_records from anon;
grant select, insert, update, delete on public.bil_cloud_devices to authenticated;
grant select, insert, update, delete on public.bil_cloud_records to authenticated;

commit;
