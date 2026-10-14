-- Captured definition SHA256 7c1ff2ecbe653c9358b3115a2607db9573f88a2944ae4eca9e296a89cc5186a7

CREATE OR REPLACE FUNCTION auth.uid()
 RETURNS uuid
 LANGUAGE sql
 STABLE
AS $function$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$function$;

-- Captured definition SHA256 7ce3ad8fb99f7ad5f5cd869fbd5479a6325e9444da472c26394cfa66c83b2d11

CREATE OR REPLACE FUNCTION auth.jwt()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$function$;

-- Captured definition SHA256 2dfffad914abd0531e4c706ec5368be167fdfb361e06ae7293fb2aa053029189

CREATE OR REPLACE FUNCTION public.bil_community_contact_exchange_violation(p_text text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$;

-- Captured definition SHA256 0255e691258fb6f610b66c87fa3641ec9e9cfd9d4d1df1107e52b7d2ca7c3681

CREATE OR REPLACE FUNCTION private.bil_is_blocked_with(p_other uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  select auth.uid() is null
    or p_other is null
    or exists (
      select 1
      from public.bil_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p_other)
         or (b.blocker_id = p_other and b.blocked_id = auth.uid())
    );
$function$;

-- Captured definition SHA256 aa3c11ba18d434da581a756a9b041821fe8c0112f43ec83ef26d5d6f561d03a8

CREATE OR REPLACE FUNCTION private.bil_assert_current_community_policy()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

-- Captured definition SHA256 cb0a29f6681cebd51fea6005f9cec17ac191277624e2c8e873cbe70784402ade

CREATE OR REPLACE FUNCTION private.bil_guard_unblocked_community_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET row_security TO 'off'
AS $function$
declare
  v_actor_id uuid := (select auth.uid());
  v_left_id uuid;
  v_right_id uuid;
begin
  if v_actor_id is null or new.sender_id <> v_actor_id then
    raise exception using
      errcode = '42501',
      message = 'community_message_sender_required';
  end if;

  if new.sender_id::text < new.recipient_id::text then
    v_left_id := new.sender_id;
    v_right_id := new.recipient_id;
  else
    v_left_id := new.recipient_id;
    v_right_id := new.sender_id;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_block_pair:' || v_left_id::text || ':' || v_right_id::text,
      0
    )
  );

  if exists (
    select 1
    from public.bil_blocks block_row
    where (block_row.blocker_id = new.sender_id
           and block_row.blocked_id = new.recipient_id)
       or (block_row.blocker_id = new.recipient_id
           and block_row.blocked_id = new.sender_id)
  ) then
    raise exception using
      errcode = '42501',
      message = 'community_relationship_blocked';
  end if;

  return new;
end;
$function$;

-- Captured definition SHA256 85d6ae43e87fab77338be784e70fe8c58599e0d1087fab7c326353ba05db8ab2

CREATE OR REPLACE FUNCTION private.bil_lock_community_block_pair()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_blocker_id uuid := case when tg_op = 'DELETE'
    then old.blocker_id else new.blocker_id end;
  v_blocked_id uuid := case when tg_op = 'DELETE'
    then old.blocked_id else new.blocked_id end;
  v_left_id uuid;
  v_right_id uuid;
begin
  if v_blocker_id::text < v_blocked_id::text then
    v_left_id := v_blocker_id;
    v_right_id := v_blocked_id;
  else
    v_left_id := v_blocked_id;
    v_right_id := v_blocker_id;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_block_pair:' || v_left_id::text || ':' || v_right_id::text,
      0
    )
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$function$;

-- Captured definition SHA256 85100cd0b3e793cc18b71a451699fe8c3f279d3e775250aaa64bfec21052040a

CREATE OR REPLACE FUNCTION private.bil_validate_community_policy_acceptance()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor_id uuid := (select auth.uid());
  v_policy_count bigint;
  v_policy_version text;
begin
  if v_actor_id is null or new.user_id <> v_actor_id then
    raise exception using
      errcode = '42501',
      message = 'community_policy_acceptance_required';
  end if;

  select pg_catalog.count(*), pg_catalog.min(policy.version)
  into v_policy_count, v_policy_version
  from public.bil_content_policies policy
  where policy.active
    and policy.effective_at <= pg_catalog.statement_timestamp();

  if v_policy_count <> 1 then
    raise exception using
      errcode = '55000',
      message = 'community_policy_unavailable';
  end if;

  if new.policy_version <> v_policy_version then
    raise exception using
      errcode = '42501',
      message = 'community_policy_acceptance_required';
  end if;

  new.accepted_at := pg_catalog.clock_timestamp();
  return new;
end;
$function$;

-- Captured definition SHA256 85bb84b21849759e553b5a8ee14f83206392dc05277bb5095e6195276791f57b

CREATE OR REPLACE FUNCTION public.bil_audit_community_action()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into bil_community_audit_events(actor_id,event_kind,target_kind,target_id)
  values(auth.uid(),tg_op,replace(tg_table_name,'bil_',''),coalesce(new.id::text,old.id::text));
  return coalesce(new,old);
end $function$;

-- Captured definition SHA256 3b834dee13d16df6cc906f7b145788b220b7c26b60a84f536f10550eb96d9934

CREATE OR REPLACE FUNCTION public.bil_can_use_community()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

-- Captured definition SHA256 c940307c14c80d3e5862c4410dd69023042b38c0c279babb2ede078e77cf65c3

CREATE OR REPLACE FUNCTION public.bil_consume_rate_limit(p_action text, p_limit integer, p_window_seconds integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user_id uuid := (select auth.uid());
  v_window_started_at timestamp with time zone;
  v_hit_count integer;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  if pg_catalog.octet_length(p_action) not between 1 and 64
     or not exists (
       select 1
       from (
         values
           ('account_deletion', 3, 3600),
           ('account_deletion', 3, 86400),
           ('account_export', 3, 3600),
           ('ai_boost_purchase_verification', 20, 3600),
           ('app_attest_issue', 60, 3600),
           ('admin_ai_coach_global_reset', 3, 3600),
           ('admin_ai_coach_individual_reset', 20, 3600),
           ('admin_community_member_list', 120, 3600),
           ('admin_community_member_reinstate', 30, 3600),
           ('admin_community_member_suspend', 30, 3600),
           ('admin_community_moderator_add', 30, 3600),
           ('admin_community_moderator_list', 120, 3600),
           ('admin_community_moderator_remove', 30, 3600),
           ('admin_subscription_list', 120, 3600),
           ('admin_subscription_grant', 60, 3600),
           ('admin_subscription_revoke', 60, 3600),
           ('admin_notification_all', 10, 3600),
           ('admin_notification_individual', 50, 3600),
           ('community_comment_report_v2', 20, 3600),
           ('community_comment_v2', 60, 3600),
           ('community_handle_claim_v2', 10, 3600),
           ('community_handle_search_v2', 60, 60),
           ('community_mention_search_v1', 60, 60),
           ('community_like_v2', 120, 60),
           ('community_post_save_v2', 120, 60),
           ('community_public_code_resolve_v2', 60, 60),
           ('community_public_code_rotate_v2', 5, 86400),
           ('follow', 40, 3600),
           ('food_search_hour', 60, 3600),
           ('food_search_minute', 10, 60),
           ('friend_request', 20, 3600),
           ('meal_image_analysis', 30, 3600),
           ('message', 60, 3600),
           ('play_integrity_issue', 60, 3600),
           ('post', 12, 3600),
           ('shared_diary_locked_read', 30, 3600),
           ('store_purchase_verification', 20, 3600)
       ) allowed(action_name, limit_count, window_seconds)
       where allowed.action_name = p_action
         and allowed.limit_count = p_limit
         and allowed.window_seconds = p_window_seconds
     ) then
    raise exception 'invalid_rate_limit_contract' using errcode = '22023';
  end if;

  v_window_started_at := pg_catalog.to_timestamp(
    pg_catalog.floor(
      extract(epoch from pg_catalog.statement_timestamp()) /
      p_window_seconds
    ) * p_window_seconds
  );

  insert into public.bil_rate_limit_buckets(
    user_id, action, window_started_at, hit_count
  ) values (
    v_user_id, p_action, v_window_started_at, 1
  )
  on conflict (user_id, action, window_started_at)
  do update
  set hit_count = bil_rate_limit_buckets.hit_count + 1
  returning hit_count into v_hit_count;

  if v_hit_count > p_limit then
    raise exception 'rate limit exceeded' using errcode = 'P0001';
  end if;
end
$function$;

-- Captured definition SHA256 d7bce34b36de7ef40a9714858c5439a41ba9f47082cdabbd0ba1e3914d6020f1

CREATE OR REPLACE FUNCTION public.bil_enforce_community_contact_exchange()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_surface text;
  v_text text;
  v_reason text;
begin
  case tg_table_name
    when 'bil_public_profiles' then
      v_surface := 'profile';
      v_text := concat_ws(' ', new.display_name, new.bio);
    when 'bil_community_posts' then
      v_surface := 'post';
      v_text := new.body;
    when 'bil_messages' then
      v_surface := 'message';
      v_text := new.body;
    when 'bil_community_food_submissions' then
      v_surface := 'community_food';
      v_text := concat_ws(
        ' ',
        new.canonical_name,
        new.brand,
        new.review_note,
        (
          select string_agg(value, ' ')
          from jsonb_each_text(coalesce(new.localized_names, '{}'::jsonb))
        ),
        (
          select string_agg(value, ' ')
          from jsonb_array_elements_text(coalesce(new.aliases, '[]'::jsonb))
        )
      );
    when 'bil_food_peer_reviews' then
      v_surface := 'food_peer_review';
      v_text := new.note;
    else
      raise exception using
        errcode = 'P0001',
        message = 'community_contact_policy_configuration_error';
  end case;

  v_reason := public.bil_community_contact_exchange_violation(v_text);
  if v_reason is not null then
    raise exception using
      errcode = 'P0001',
      message = 'community_contact_exchange_not_allowed',
      detail = format('surface=%s;reason=%s', v_surface, v_reason),
      hint = 'Remove contact details or off-platform invitations.';
  end if;
  return new;
end;
$function$;

-- Captured definition SHA256 5da2c52df2eeb8bd26a637803cfc931c618f02c91e353613f2b817576bf3f02c

CREATE OR REPLACE FUNCTION public.bil_enqueue_private_push()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_table_name = 'bil_messages' then
    insert into bil_push_outbox(recipient_id, category, body, deep_link)
    values(new.recipient_id, 'message', 'You have a new private message.',
           'bil://community/chat/' || new.sender_id::text);
  elsif tg_table_name = 'bil_friendships' and new.status='pending' then
    insert into bil_push_outbox(recipient_id, category, body, deep_link)
    values(new.addressee_id, 'friend_request', 'You have a new friend request.',
           'bil://community/connections');
  end if;
  return new;
end
$function$;

-- Captured definition SHA256 d6e14295e7a847299f925a110d261c3552c609b94732e61173714c303dd3f8a3

CREATE OR REPLACE FUNCTION public.bil_guard_community_member_access()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if public.bil_can_use_community() then
    return new;
  end if;

  -- The mobile delete flow is an owner-scoped soft delete followed by media
  -- reference cleanup. Preserve that privacy action for a suspended member,
  -- but compare every other row field so this exception cannot edit or
  -- republish content.
  if tg_op = 'UPDATE'
     and tg_table_schema = 'public'
     and tg_table_name = 'bil_community_posts' then
    -- Keep OLD/NEW post-field access inside this table-specific branch. The
    -- same function is also attached to tables with different row shapes.
    if new.author_id = (select auth.uid())
       and new.deleted_at is not null
       and new.media_url is null
       and new.media_object_path is null
       and new.media_mime_type is null
       and new.media_bytes is null
       and new.media_width is null
       and new.media_height is null
       and new.location_label is null
       and (
         pg_catalog.to_jsonb(new) - array[
           'deleted_at', 'media_url', 'media_object_path', 'media_mime_type',
           'media_bytes', 'media_width', 'media_height', 'location_label'
         ]::text[]
       ) = (
         pg_catalog.to_jsonb(old) - array[
           'deleted_at', 'media_url', 'media_object_path', 'media_mime_type',
           'media_bytes', 'media_width', 'media_height', 'location_label'
         ]::text[]
       ) then
      return new;
    end if;
  end if;

  raise exception 'community_access_suspended' using errcode = '42501';
end
$function$;

-- Captured definition SHA256 dbdcd6ca8375881df1369a27b1c0e3881bb9795c6a096af6726d6cdf061a8e7f

CREATE OR REPLACE FUNCTION public.bil_recipient_allows_community_message(p_recipient_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor_id uuid := (select auth.uid());
  v_role text := coalesce((select auth.jwt()->>'role'), '');
begin
  if p_recipient_id is null then
    return false;
  end if;

  if v_role <> 'service_role' then
    if v_actor_id is null then
      return false;
    end if;

    if not exists (
      select 1
      from public.bil_friendships friendship
      where friendship.status = 'accepted'
        and (
          (friendship.requester_id = v_actor_id
           and friendship.addressee_id = p_recipient_id)
          or
          (friendship.addressee_id = v_actor_id
           and friendship.requester_id = p_recipient_id)
        )
    ) then
      return false;
    end if;
  end if;

  return coalesce(
    (
      select profile.allow_messages_from = 'friends'
      from public.bil_public_profiles profile
      where profile.user_id = p_recipient_id
    ),
    true
  );
end
$function$;

-- Captured definition SHA256 39567a5ef431f02589f9feb570bf1e92d410ceb9f820b5d0c8a21de6892952a6

CREATE OR REPLACE FUNCTION public.bil_require_community_policy()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform private.bil_assert_current_community_policy();
  perform public.bil_consume_rate_limit(
    case when tg_table_name = 'bil_messages' then 'message' else 'post' end,
    case when tg_table_name = 'bil_messages' then 60 else 12 end,
    3600
  );
  return new;
end;
$function$;
