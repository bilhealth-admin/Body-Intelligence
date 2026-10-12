-- Exact read-only column/constraint/policy catalog, 2026-10-11. No user rows.
create sequence public.bil_cloud_change_sequence;
create table public.bil_cloud_devices (
  "owner_id" uuid not null,
  "device_id" text not null,
  "platform" text default 'unknown'::text not null,
  "app_version" text,
  "created_at" timestamp with time zone default now() not null,
  "last_seen_at" timestamp with time zone default now() not null,
  "revoked_at" timestamp with time zone
);
create table public.bil_cloud_records (
  "owner_id" uuid not null,
  "entity_kind" text not null,
  "record_id" text not null,
  "device_id" text not null,
  "revision_sequence" bigint not null,
  "schema_version" integer default 1 not null,
  "payload" jsonb default '{}'::jsonb not null,
  "client_updated_at" timestamp with time zone not null,
  "deleted_at" timestamp with time zone,
  "server_updated_at" timestamp with time zone default now() not null,
  "revision_device_id" text not null,
  "updated_at" timestamp with time zone not null,
  "change_sequence" bigint default nextval('bil_cloud_change_sequence'::regclass) not null
);
create table public.bil_cloud_operations (
  "owner_id" uuid not null,
  "operation_id" text not null,
  "device_id" text not null,
  "recorded_at" timestamp with time zone default now() not null
);
create table public.bil_consent_receipts (
  "user_id" uuid not null,
  "purpose" text not null,
  "policy_version" text not null,
  "granted" boolean not null,
  "recorded_at" timestamp with time zone default now() not null
);
alter table public.bil_cloud_devices add constraint "bil_cloud_devices_device_id_check" CHECK (((length(device_id) >= 8) AND (length(device_id) <= 200)));
alter table public.bil_cloud_devices add constraint "bil_cloud_devices_pkey" PRIMARY KEY (owner_id, device_id);
alter table public.bil_cloud_operations add constraint "bil_cloud_operations_pkey" PRIMARY KEY (owner_id, operation_id);
alter table public.bil_cloud_records add constraint "bil_cloud_records_deleted_time_check" CHECK (((deleted_at IS NULL) OR (deleted_at <= client_updated_at)));
alter table public.bil_cloud_records add constraint "bil_cloud_records_device_id_check" CHECK (((length(device_id) >= 8) AND (length(device_id) <= 200)));
alter table public.bil_cloud_records add constraint "bil_cloud_records_entity_kind_check" CHECK ((entity_kind = ANY (ARRAY['profile'::text, 'goal'::text, 'weight'::text, 'measurement'::text, 'nutrition'::text, 'hydration'::text, 'sleep'::text, 'activity'::text, 'decisionMemory'::text, 'intelligenceOutput'::text, 'coach'::text, 'community'::text, 'file'::text, 'settings'::text])));
alter table public.bil_cloud_records add constraint "bil_cloud_records_pkey" PRIMARY KEY (owner_id, entity_kind, record_id);
alter table public.bil_cloud_records add constraint "bil_cloud_records_record_id_check" CHECK (((length(record_id) >= 1) AND (length(record_id) <= 200)));
alter table public.bil_cloud_records add constraint "bil_cloud_records_revision_sequence_check" CHECK ((revision_sequence >= 0));
alter table public.bil_cloud_records add constraint "bil_cloud_records_schema_version_check" CHECK ((schema_version > 0));
alter table public.bil_consent_receipts add constraint "bil_consent_receipts_pkey" PRIMARY KEY (user_id, purpose, policy_version);
alter table public.bil_consent_receipts add constraint "bil_consent_receipts_purpose_check" CHECK ((purpose = ANY (ARRAY['health'::text, 'camera'::text, 'microphone'::text, 'photos'::text, 'notifications'::text, 'devices'::text, 'remote_ai'::text, 'cloud_sync'::text, 'meal_vision_ai'::text])));
alter table public.bil_cloud_devices add constraint "bil_cloud_devices_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_cloud_operations add constraint "bil_cloud_operations_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_cloud_records add constraint "bil_cloud_records_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_consent_receipts add constraint "bil_consent_receipts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_cloud_devices enable row level security;
alter table public.bil_cloud_records enable row level security;
alter table public.bil_cloud_operations enable row level security;
alter table public.bil_consent_receipts enable row level security;
create policy "bil_devices_delete_own" on public.bil_cloud_devices for DELETE to authenticated using ((( SELECT auth.uid() AS uid) = owner_id));
create policy "bil_devices_insert_own" on public.bil_cloud_devices for INSERT to authenticated with check ((( SELECT auth.uid() AS uid) = owner_id));
create policy "bil_devices_select_own" on public.bil_cloud_devices for SELECT to authenticated using ((( SELECT auth.uid() AS uid) = owner_id));
create policy "bil_devices_update_own" on public.bil_cloud_devices for UPDATE to authenticated using ((( SELECT auth.uid() AS uid) = owner_id)) with check ((( SELECT auth.uid() AS uid) = owner_id));
create policy "bil_cloud_operations_current_consent_select_v1" on public.bil_cloud_operations as restrictive for SELECT to authenticated using (COALESCE(( SELECT (receipt.granted AND (receipt.policy_version = '1'::text))
   FROM bil_consent_receipts receipt
  WHERE ((receipt.user_id = ( SELECT auth.uid() AS uid)) AND (receipt.purpose = 'cloud_sync'::text))
  ORDER BY receipt.recorded_at DESC, receipt.granted, receipt.policy_version DESC
 LIMIT 1), false));
create policy "bil_cloud_operations_owner_insert" on public.bil_cloud_operations for INSERT to authenticated with check ((owner_id = ( SELECT auth.uid() AS uid)));
create policy "bil_cloud_operations_owner_select" on public.bil_cloud_operations for SELECT to authenticated using ((owner_id = ( SELECT auth.uid() AS uid)));
create policy "bil_cloud_records_current_consent_select_v1" on public.bil_cloud_records as restrictive for SELECT to authenticated using (COALESCE(( SELECT (receipt.granted AND (receipt.policy_version = '1'::text))
   FROM bil_consent_receipts receipt
  WHERE ((receipt.user_id = ( SELECT auth.uid() AS uid)) AND (receipt.purpose = 'cloud_sync'::text))
  ORDER BY receipt.recorded_at DESC, receipt.granted, receipt.policy_version DESC
 LIMIT 1), false));
create policy "bil_cloud_records_owner_insert" on public.bil_cloud_records for INSERT to authenticated with check ((owner_id = ( SELECT auth.uid() AS uid)));
create policy "bil_cloud_records_owner_select" on public.bil_cloud_records for SELECT to authenticated using ((owner_id = ( SELECT auth.uid() AS uid)));
create policy "bil_cloud_records_owner_update" on public.bil_cloud_records for UPDATE to authenticated using ((owner_id = ( SELECT auth.uid() AS uid))) with check ((owner_id = ( SELECT auth.uid() AS uid)));
create policy "bil_records_delete_own" on public.bil_cloud_records for DELETE to authenticated using ((( SELECT auth.uid() AS uid) = owner_id));
create policy "bil_consent_receipts_own_read" on public.bil_consent_receipts for SELECT to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
grant select on public.bil_cloud_devices, public.bil_cloud_records, public.bil_cloud_operations, public.bil_consent_receipts to authenticated;
revoke insert,update,delete on public.bil_cloud_records, public.bil_cloud_operations from authenticated;
