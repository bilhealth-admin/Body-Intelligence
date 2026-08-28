begin;

alter table public.bil_barcode_shared_cache
  drop constraint if exists bil_barcode_shared_cache_source_check;
alter table public.bil_barcode_shared_cache
  add constraint bil_barcode_shared_cache_source_check
  check (source in ('bil','usda','open_facts'));

create or replace function public.bil_put_cached_barcode(
  p_gtin text,
  p_source text,
  p_payload jsonb,
  p_ttl_days integer default 30
) returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.role()<>'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_gtin !~ '^[0-9]{8,14}$'
     or p_source not in ('bil','usda','open_facts')
     or jsonb_typeof(p_payload)<>'object'
     or p_ttl_days not between 1 and 90 then
    raise exception 'invalid_barcode_cache_entry';
  end if;
  insert into public.bil_barcode_shared_cache(
    gtin,source,payload,validated_at,expires_at
  ) values(
    p_gtin,p_source,p_payload,now(),now()+make_interval(days=>p_ttl_days)
  )
  on conflict(gtin) do update set
    source=excluded.source,
    payload=excluded.payload,
    validated_at=excluded.validated_at,
    expires_at=excluded.expires_at;
end
$$;

revoke all on function public.bil_put_cached_barcode(text,text,jsonb,integer)
  from public,anon,authenticated;
grant execute on function public.bil_put_cached_barcode(text,text,jsonb,integer)
  to service_role;

commit;

;
