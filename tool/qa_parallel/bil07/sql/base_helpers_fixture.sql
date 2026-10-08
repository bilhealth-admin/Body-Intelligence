-- SYNTHETIC LOCAL FIXTURE: exact BASE helper bodies, not a full backend replay.
-- Sources and blob identities in base_helper_sources.json. Do not deploy.

-- https://github.com/bilhealth-admin/Body-Intelligence/blob/1744788e6bfbdffc3a168bbaf36b3abf3e2c698a/supabase/migrations/20260905160000_admin_community_access_control.sql
create or replace function public.bil_can_use_community()
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null then
    return false;
  end if;

  -- Serialize every Community mutation (including the Storage insert policy)
  -- against suspension/reinstatement for this member. This prevents an action
  -- that checked the old state from committing after a suspension commits.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_member_state:' || v_actor_id::text, 0
    )
  );

  return not exists (
    select 1
    from private.bil_community_member_access access_row
    where access_row.user_id = v_actor_id
      and access_row.suspended
  );
end
$$;

-- https://github.com/bilhealth-admin/Body-Intelligence/blob/1744788e6bfbdffc3a168bbaf36b3abf3e2c698a/supabase/migrations/20260908032057_community_policy_v1_activation.sql
create or replace function private.bil_assert_current_community_policy()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_policy_count bigint;
  v_policy_version text;
  v_policy_effective_at timestamptz;
begin
  if v_actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'community_policy_acceptance_required';
  end if;

  select
    pg_catalog.count(*),
    pg_catalog.min(policy.version),
    pg_catalog.min(policy.effective_at)
  into v_policy_count, v_policy_version, v_policy_effective_at
  from public.bil_content_policies policy
  where policy.active
    and policy.effective_at <= pg_catalog.statement_timestamp();

  if v_policy_count <> 1 then
    raise exception using
      errcode = '55000',
      message = 'community_policy_unavailable';
  end if;

  if not exists (
    select 1
    from public.bil_content_policy_acceptances acceptance
    where acceptance.user_id = v_actor_id
      and acceptance.policy_version = v_policy_version
      and acceptance.accepted_at >= v_policy_effective_at
  ) then
    raise exception using
      errcode = '42501',
      message = 'community_policy_acceptance_required';
  end if;

  return v_policy_version;
end;
$$;

-- https://github.com/bilhealth-admin/Body-Intelligence/blob/1744788e6bfbdffc3a168bbaf36b3abf3e2c698a/supabase/migrations/20260908013800_bil_community_social_v2.sql
create function public.bil_social_member_visible_v2(p_member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and p_member is not null and not exists(select 1 from public.bil_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=p_member) or (b.blocker_id=p_member and b.blocked_id=auth.uid())) and not exists(select 1 from private.bil_community_member_access a where a.user_id=p_member and a.suspended)
$$;

-- https://github.com/bilhealth-admin/Body-Intelligence/blob/1744788e6bfbdffc3a168bbaf36b3abf3e2c698a/supabase/migrations/20260908013800_bil_community_social_v2.sql
create function public.bil_social_profile_visible_v2(p_member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.bil_social_member_visible_v2(p_member) and exists(select 1 from public.bil_public_profiles p where p.user_id=p_member and (p.user_id=auth.uid() or (p.profile_visibility='public' and p.discoverable) or (p.profile_visibility='friends' and exists(select 1 from public.bil_friendships f where f.status='accepted' and ((f.requester_id=auth.uid() and f.addressee_id=p.user_id) or (f.addressee_id=auth.uid() and f.requester_id=p.user_id))))))
$$;

-- https://github.com/bilhealth-admin/Body-Intelligence/blob/1744788e6bfbdffc3a168bbaf36b3abf3e2c698a/supabase/migrations/20260908132433_community_policy_client_status_rpc.sql
create function public.bil_assert_community_publish_ready()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_policy_version text;
begin
  if v_actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'community_authentication_required';
  end if;

  if not public.bil_can_use_community() then
    raise exception using
      errcode = '42501',
      message = 'community_access_suspended';
  end if;

  v_policy_version := private.bil_assert_current_community_policy();
  return v_policy_version;
end;
$$;

-- https://github.com/bilhealth-admin/Body-Intelligence/blob/1744788e6bfbdffc3a168bbaf36b3abf3e2c698a/supabase/migrations/20260824015152_community_contact_exchange_policy.sql
create or replace function public.bil_community_contact_exchange_violation(
  p_text text
)
returns text
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_text text := lower(translate(
    coalesce(p_text, ''),
    '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹०१२३४५६७८९০১২৩৪৫৬৭৮৯０１２３４５６７８９',
    '01234567890123456789012345678901234567890123456789'
  ));
  v_match text[];
  v_candidate text;
  v_digits text;
begin
  if v_text ~* '[a-z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+' then
    return 'email';
  end if;

  if v_text ~* '(https?://|www\.)[^[:space:]<>{}]+'
     or v_text ~* '([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+(com|net|org|io|me|co|app|dev|ai|info|biz|xyz|site|online|link|health|fitness|social|chat|club|live|cloud|store|pro|world|gg|tv|ly|sa|ae|eg|uk|de|fr|es|tr|in|pk|bd|id|my|jp|kr|cn|ru|nl|pl|ua)\M' then
    return 'url_or_domain';
  end if;

  if v_text ~ '(^|[[:space:]([{])@[^[:space:]@.,;:!?/\\]{2,32}' then
    return 'social_handle';
  end if;

  for v_match in
    select regexp_matches(
      v_text,
      '(\+?([[:space:]().‐‑‒–—―−-]*[0-9]){7,20})',
      'g'
    )
  loop
    v_candidate := regexp_replace(btrim(v_match[1]), '[[:space:]]+', '', 'g');
    if regexp_replace(v_candidate, '[().‐‑‒–—―−-]+$', '', 'g') ~ '^([0-9]{4}[-/.][0-9]{1,2}[-/.][0-9]{1,2}|[0-9]{1,2}[-/.][0-9]{1,2}[-/.][0-9]{2,4})$'
       or regexp_replace(v_candidate, '[().‐‑‒–—―−-]+$', '', 'g') ~ '^((19|20)[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])|(0[1-9]|[12][0-9]|3[01])(0[1-9]|1[0-2])(19|20)[0-9]{2})$' then
      continue;
    end if;
    v_digits := regexp_replace(v_candidate, '[^0-9]', '', 'g');
    if length(v_digits) between 7 and 20 then
      return 'phone_number';
    end if;
  end loop;

  if v_text ~* '(message[[:space:]]+me|contact[[:space:]]+me|text[[:space:]]+me|add[[:space:]]+me|follow[[:space:]]+me|find[[:space:]]+me|reach[[:space:]]+me|dm[[:space:]]+me|continue|move|switch|write[[:space:]]+me|écris-moi|contacte-moi|ajoute-moi|continuer|escríbeme|contáctame|sígueme|hablemos|continuar|yaz|ulaş|ekle|takip[[:space:]]+et|konuş|devam[[:space:]]+et|راسلني|تواصل[[:space:]]+معي|كلمني|أضفني|تابعني|نكمل|ننقل|مرا[[:space:]]+رابطہ|پیغام|جاری|संपर्क|संदेश|जारी).{0,40}(whats?app|telegram|signal|instagram|insta|snapchat|snap|facebook|messenger|discord|wechat|viber|tiktok|line|واتس[[:space:]]*آب|واتساب|تلغرام|تيليجرام|انستغرام|إنستغرام|سناب|فيسبوك|ديسكورد|سيجنال|व्हाट्सएप|टेलीग्राम|इंस्टाग्राम)'
     or v_text ~* '(whats?app|telegram|signal|instagram|insta|snapchat|snap|facebook|messenger|discord|wechat|viber|tiktok|line|واتس[[:space:]]*آب|واتساب|تلغرام|تيليجرام|انستغرام|إنستغرام|سناب|فيسبوك|ديسكورد|سيجنال|व्हाट्सएप|टेलीग्राम|इंस्टाग्राम).{0,40}(message[[:space:]]+me|contact[[:space:]]+me|text[[:space:]]+me|add[[:space:]]+me|follow[[:space:]]+me|find[[:space:]]+me|reach[[:space:]]+me|dm[[:space:]]+me|continue|move|switch|write[[:space:]]+me|écris-moi|contacte-moi|ajoute-moi|continuer|escríbeme|contáctame|sígueme|hablemos|continuar|yaz|ulaş|ekle|takip[[:space:]]+et|konuş|devam[[:space:]]+et|راسلني|تواصل[[:space:]]+معي|كلمني|أضفني|تابعني|نكمل|ننقل|مرا[[:space:]]+رابطہ|پیغام|جاری|संपर्क|संदेश|जारी)'
     or v_text ~* '(schreib[[:space:]]+mir|kontaktiere[[:space:]]+mich|scrivimi|contattami|fale[[:space:]]+comigo|me[[:space:]]+chama|напиши[[:space:]]+мне|свяжись|hubungi[[:space:]]+saya|kirim[[:space:]]+pesan|連絡|メッセージ|연락|메시지|联系我|加我|私信|যোগাযোগ|বার্তা|nhắn[[:space:]]+tin|liên[[:space:]]+hệ|ติดต่อ|ส่งข้อความ|napisz[[:space:]]+do[[:space:]]+mnie|skontaktuj|stuur[[:space:]]+me|voeg[[:space:]]+me[[:space:]]+toe|напиши[[:space:]]+мені).{0,40}(whats?app|telegram|signal|instagram|insta|snapchat|snap|facebook|messenger|discord|wechat|微信|viber|tiktok|line)'
     or v_text ~* '(whats?app|telegram|signal|instagram|insta|snapchat|snap|facebook|messenger|discord|wechat|微信|viber|tiktok|line).{0,40}(schreib[[:space:]]+mir|kontaktiere[[:space:]]+mich|scrivimi|contattami|fale[[:space:]]+comigo|me[[:space:]]+chama|напиши[[:space:]]+мне|свяжись|hubungi[[:space:]]+saya|kirim[[:space:]]+pesan|連絡|メッセージ|연락|메시지|联系我|加我|私信|যোগাযোগ|বার্তা|nhắn[[:space:]]+tin|liên[[:space:]]+hệ|ติดต่อ|ส่งข้อความ|napisz[[:space:]]+do[[:space:]]+mnie|skontaktuj|stuur[[:space:]]+me|voeg[[:space:]]+me[[:space:]]+toe|напиши[[:space:]]+мені)'
     or v_text ~* '(continue|move|take|switch).{0,28}(outside|off|away[[:space:]]+from).{0,12}bil'
     or v_text ~* '(نكمل|ننقل).{0,30}(خارج|برا).{0,12}bil'
     or v_text ~* '(continuar|continuer|devam).{0,30}(fuera|hors|dışında).{0,12}bil' then
    return 'off_platform_invitation';
  end if;

  return null;
end;
$$;

revoke all on function public.bil_can_use_community(), private.bil_assert_current_community_policy(), public.bil_social_member_visible_v2(uuid), public.bil_social_profile_visible_v2(uuid), public.bil_assert_community_publish_ready(), public.bil_community_contact_exchange_violation(text) from public, anon, authenticated, service_role;
grant execute on function public.bil_can_use_community(), public.bil_assert_community_publish_ready() to authenticated;
