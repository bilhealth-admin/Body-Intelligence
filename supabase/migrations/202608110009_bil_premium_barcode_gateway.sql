begin;

create table if not exists public.bil_barcode_shared_cache(
  gtin text primary key check (gtin ~ '^[0-9]{8,14}$'),
  source text not null check (source in ('bil','usda')),
  payload jsonb not null,
  validated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (jsonb_typeof(payload)='object')
);
alter table public.bil_barcode_shared_cache enable row level security;
revoke all on public.bil_barcode_shared_cache from public,anon,authenticated;

create or replace function public.bil_has_premium_barcode_access(p_owner_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.bil_subscriptions s
    where s.owner_id=p_owner_id and s.plan_id in ('pro','premium','premium_ai_coach')
      and s.lifecycle in ('trial','active','grace_period','cancelled')
      and coalesce(case when s.lifecycle='grace_period' then s.grace_period_ends_at
                        else s.expires_at end,'-infinity'::timestamptz)>=now()
  ) or exists(
    select 1 from public.bil_entitlements e where e.owner_id=p_owner_id
      and e.entitlement_id in ('plan:pro','plan:premium','plan:premium_ai_coach')
      and e.active=true and (e.expires_at is null or e.expires_at>=now())
  );
$$;

create or replace function public.bil_get_cached_barcode(p_gtin text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_row public.bil_barcode_shared_cache%rowtype;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  select * into v_row from public.bil_barcode_shared_cache
    where gtin=p_gtin and expires_at>now();
  if not found then return null; end if;
  return jsonb_build_object('gtin',v_row.gtin,'source',v_row.source,
    'payload',v_row.payload,'validated_at',v_row.validated_at,'expires_at',v_row.expires_at);
end $$;

create or replace function public.bil_put_cached_barcode(
  p_gtin text,p_source text,p_payload jsonb,p_ttl_days integer default 30
) returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  if p_gtin !~ '^[0-9]{8,14}$' or p_source not in ('bil','usda')
     or jsonb_typeof(p_payload)<>'object' or p_ttl_days not between 1 and 90 then
    raise exception 'invalid_barcode_cache_entry';
  end if;
  insert into public.bil_barcode_shared_cache(gtin,source,payload,validated_at,expires_at)
    values(p_gtin,p_source,p_payload,now(),now()+make_interval(days=>p_ttl_days))
  on conflict(gtin) do update set source=excluded.source,payload=excluded.payload,
    validated_at=excluded.validated_at,expires_at=excluded.expires_at;
end $$;

revoke all on function public.bil_has_premium_barcode_access(uuid),
  public.bil_get_cached_barcode(text),public.bil_put_cached_barcode(text,text,jsonb,integer)
  from public,anon,authenticated;
grant execute on function public.bil_has_premium_barcode_access(uuid),
  public.bil_get_cached_barcode(text),public.bil_put_cached_barcode(text,text,jsonb,integer)
  to service_role;

commit;
