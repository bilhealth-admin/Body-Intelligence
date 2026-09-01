begin;

-- Administrative notices are notification-only. They do not grant or reset
-- AI usage, entitlements, subscriptions, tiers, Boost balances, or any other
-- commercial state. Authorization stays in the existing private, UUID-based
-- administrator allow-list and never trusts client-editable metadata.
create table if not exists private.bil_admin_notification_audit (
  notification_id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique
    check (char_length(idempotency_key) between 16 and 128),
  actor_id uuid references auth.users(id) on delete set null,
  notification_kind text not null
    check (notification_kind in ('compensation', 'gift', 'custom')),
  audience text not null check (audience in ('all', 'email')),
  target_id uuid references auth.users(id) on delete set null,
  message_digest text not null
    check (message_digest ~ '^[0-9a-f]{64}$'),
  requested_at timestamptz not null default now(),
  recipients_enqueued integer not null default 0
    check (recipients_enqueued >= 0),
  push_rows_enqueued integer not null default 0
    check (push_rows_enqueued >= 0)
);

alter table private.bil_admin_notification_audit enable row level security;
revoke all on table private.bil_admin_notification_audit
  from public, anon, authenticated;

-- The durable own-row inbox makes these messages available on the next app
-- open even when OS push is disabled or a provider is not configured.
create table if not exists public.bil_admin_notices (
  owner_id uuid not null references auth.users(id) on delete cascade,
  notification_id uuid not null,
  notification_kind text not null
    check (notification_kind in ('compensation', 'gift', 'custom')),
  title text not null check (char_length(title) between 1 and 80),
  body text not null check (char_length(body) between 1 and 180),
  created_at timestamptz not null default now(),
  seen_at timestamptz,
  primary key (owner_id, notification_id),
  check (seen_at is null or seen_at >= created_at)
);

alter table public.bil_admin_notices enable row level security;
revoke all on table public.bil_admin_notices
  from public, anon, authenticated;
-- Explicitly expose only own-row reads to the Data API. Dismissal is through
-- the narrow RPC below, so clients receive no direct UPDATE grant.
grant select on table public.bil_admin_notices to authenticated;

drop policy if exists bil_admin_notices_read_own
  on public.bil_admin_notices;
create policy bil_admin_notices_read_own
on public.bil_admin_notices
for select to authenticated
using (owner_id = (select auth.uid()));

create index if not exists bil_admin_notices_owner_unseen_idx
  on public.bil_admin_notices(owner_id, created_at desc)
  where seen_at is null;

create or replace function public.bil_dismiss_admin_notice(
  p_owner_id uuid,
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner_id uuid := (select auth.uid());
  v_changed integer := 0;
begin
  if v_owner_id is null
     or p_owner_id is distinct from v_owner_id
     or p_notification_id is null then
    return false;
  end if;

  update public.bil_admin_notices n
  set seen_at = now()
  where n.owner_id = v_owner_id
    and n.notification_id = p_notification_id
    and n.seen_at is null;
  get diagnostics v_changed = row_count;
  return v_changed = 1;
end
$$;

revoke all on function public.bil_dismiss_admin_notice(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.bil_dismiss_admin_notice(uuid, uuid)
  to authenticated;

-- Exact email resolution is service-only and repeats the dedicated database
-- administrator check. It returns a UUID only to the trusted Edge Function;
-- ordinary clients never query auth.users or receive account identifiers.
create or replace function public.bil_resolve_admin_notification_target(
  p_actor_id uuid,
  p_normalized_email text
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(coalesce(p_normalized_email, '')));
  v_target_id uuid;
  v_match_count integer := 0;
begin
  if coalesce((select auth.jwt()->>'role'), '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_actor_id is null or not exists (
    select 1
    from private.bil_ai_coach_admins a
    where a.user_id = p_actor_id and a.active
  ) then
    raise exception 'ai_coach_admin_required' using errcode = '42501';
  end if;
  if char_length(v_email) not between 3 and 254
     or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then
    raise exception 'invalid_target_email';
  end if;

  select count(*), min(u.id::text)::uuid
    into v_match_count, v_target_id
  from auth.users u
  where u.email is not null
    and lower(trim(u.email)) = v_email;

  if v_match_count > 1 then
    raise exception 'ambiguous_target_email';
  end if;
  return v_target_id;
end
$$;

-- User locale is used only to choose canned copy. It is never an authority
-- input. App metadata is preferred; the public profile and user metadata are
-- safe fallbacks for presentation only.
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
  left join public.bil_public_profiles p on p.user_id = u.id
  where u.id = p_owner_id
$$;

create or replace function private.bil_admin_notification_title(
  p_kind text
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select case p_kind
    when 'compensation' then 'BIL 💛'
    when 'gift' then 'BIL 🎁'
    else 'BIL'
  end
$$;

-- Canned copy covers the same 25-locale policy as the existing AI Coach reset
-- notice. Custom copy is preserved exactly after trimming outer whitespace.
create or replace function private.bil_admin_notification_body(
  p_kind text,
  p_locale text,
  p_custom_body text
)
returns text
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  v_locale text := lower(replace(coalesce(p_locale, 'en'), '_', '-'));
begin
  if p_kind = 'custom' then
    return trim(p_custom_body);
  end if;

  if p_kind = 'compensation' then
    return case v_locale
      when 'ar' then 'تعويض من BIL 💛 نعتذر عن الإزعاج ونقدّر ثقتك بنا. شكرًا لمنحنا فرصة تحسين تجربتك.'
      when 'fr' then 'Un geste de BIL 💛 Nous sommes désolés pour le désagrément et apprécions votre confiance. Merci de nous permettre d’améliorer votre expérience.'
      when 'es' then 'Una atención de BIL 💛 Lamentamos las molestias y valoramos tu confianza. Gracias por permitirnos mejorar tu experiencia.'
      when 'tr' then 'BIL’den bir telafi 💛 Yaşanan aksaklık için üzgünüz ve güveninize değer veriyoruz. Deneyiminizi iyileştirme fırsatı verdiğiniz için teşekkürler.'
      when 'de' then 'Eine Kulanz von BIL 💛 Wir entschuldigen uns für die Unannehmlichkeiten und schätzen dein Vertrauen. Danke für die Chance, dein Erlebnis zu verbessern.'
      when 'it' then 'Un gesto da BIL 💛 Ci scusiamo per il disagio e apprezziamo la tua fiducia. Grazie per l’opportunità di migliorare la tua esperienza.'
      when 'pt-br' then 'Uma cortesia da BIL 💛 Lamentamos o inconveniente e valorizamos sua confiança. Obrigado pela oportunidade de melhorar sua experiência.'
      when 'pt-pt' then 'Uma cortesia da BIL 💛 Lamentamos o incómodo e valorizamos a sua confiança. Obrigado pela oportunidade de melhorar a sua experiência.'
      when 'ur' then 'BIL کی جانب سے تلافی 💛 تکلیف کے لیے معذرت، ہم آپ کے اعتماد کی قدر کرتے ہیں۔ ہمیں آپ کا تجربہ بہتر بنانے کا موقع دینے کا شکریہ۔'
      when 'fa' then 'جبران از طرف BIL 💛 بابت ناراحتی پیش‌آمده متأسفیم و از اعتماد شما سپاسگزاریم. ممنون که فرصت بهبود تجربه‌تان را به ما دادید.'
      when 'hi' then 'BIL की ओर से क्षतिपूर्ति 💛 असुविधा के लिए हमें खेद है और हम आपके भरोसे की कद्र करते हैं। अनुभव बेहतर करने का अवसर देने के लिए धन्यवाद।'
      when 'id' then 'Kompensasi dari BIL 💛 Kami mohon maaf atas ketidaknyamanan ini dan menghargai kepercayaan Anda. Terima kasih atas kesempatan untuk memperbaiki pengalaman Anda.'
      when 'ms' then 'Pampasan daripada BIL 💛 Kami memohon maaf atas kesulitan dan menghargai kepercayaan anda. Terima kasih atas peluang untuk menambah baik pengalaman anda.'
      when 'ja' then 'BILからのお詫びです💛 ご不便をおかけし申し訳ありません。信頼に感謝し、より良い体験へ改善する機会をいただきありがとうございます。'
      when 'ko' then 'BIL의 보상 안내입니다 💛 불편을 드려 죄송하며 보내주신 신뢰에 감사드립니다. 더 나은 경험으로 개선할 기회를 주셔서 감사합니다.'
      when 'zh-hans' then '来自 BIL 的补偿 💛 对给你带来的不便我们深表歉意，也感谢你的信任。谢谢你给予我们改善体验的机会。'
      when 'zh-hant' then '來自 BIL 的補償 💛 對造成的不便我們深感抱歉，也感謝你的信任。謝謝你給予我們改善體驗的機會。'
      when 'ru' then 'Компенсация от BIL 💛 Приносим извинения за неудобство и ценим ваше доверие. Спасибо за возможность улучшить ваш опыт.'
      when 'bn' then 'BIL-এর পক্ষ থেকে ক্ষতিপূরণ 💛 অসুবিধার জন্য আমরা দুঃখিত এবং আপনার আস্থাকে মূল্য দিই। অভিজ্ঞতা উন্নত করার সুযোগ দেওয়ার জন্য ধন্যবাদ।'
      when 'vi' then 'Một lời bù đắp từ BIL 💛 Chúng tôi xin lỗi vì sự bất tiện và trân trọng niềm tin của bạn. Cảm ơn bạn đã cho chúng tôi cơ hội cải thiện trải nghiệm.'
      when 'th' then 'การชดเชยจาก BIL 💛 เราขออภัยในความไม่สะดวกและขอบคุณที่ไว้วางใจ ขอบคุณที่ให้โอกาสเราปรับปรุงประสบการณ์ของคุณ'
      when 'pl' then 'Rekompensata od BIL 💛 Przepraszamy za niedogodność i cenimy Twoje zaufanie. Dziękujemy za szansę ulepszenia Twoich doświadczeń.'
      when 'nl' then 'Een tegemoetkoming van BIL 💛 Excuses voor het ongemak; we waarderen je vertrouwen. Bedankt voor de kans om je ervaring te verbeteren.'
      when 'uk' then 'Компенсація від BIL 💛 Перепрошуємо за незручності й цінуємо вашу довіру. Дякуємо за можливість покращити ваш досвід.'
      else 'A courtesy from BIL 💛 We’re sorry for the inconvenience and truly value your trust. Thank you for giving us the chance to improve your experience.'
    end;
  end if;

  return case v_locale
    when 'ar' then 'هدية من BIL 🎁 شكرًا لكونك جزءًا من BIL. هذه اللفتة الخاصة تعبير عن تقديرنا لك.'
    when 'fr' then 'Un cadeau de BIL 🎁 Merci de faire partie de BIL. Cette attention spéciale exprime toute notre reconnaissance.'
    when 'es' then 'Un regalo de BIL 🎁 Gracias por formar parte de BIL. Este detalle especial expresa cuánto te valoramos.'
    when 'tr' then 'BIL’den bir hediye 🎁 BIL’in bir parçası olduğunuz için teşekkürler. Bu özel jest, size verdiğimiz değerin bir ifadesidir.'
    when 'de' then 'Ein Geschenk von BIL 🎁 Danke, dass du Teil von BIL bist. Diese besondere Geste zeigt unsere Wertschätzung.'
    when 'it' then 'Un regalo da BIL 🎁 Grazie per essere parte di BIL. Questo gesto speciale esprime quanto ti apprezziamo.'
    when 'pt-br' then 'Um presente da BIL 🎁 Obrigado por fazer parte da BIL. Este gesto especial mostra o quanto valorizamos você.'
    when 'pt-pt' then 'Um presente da BIL 🎁 Obrigado por fazer parte da BIL. Este gesto especial mostra o quanto o valorizamos.'
    when 'ur' then 'BIL کی طرف سے تحفہ 🎁 BIL کا حصہ بننے کا شکریہ۔ یہ خصوصی پیغام آپ کے لیے ہماری قدر کا اظہار ہے۔'
    when 'fa' then 'هدیه‌ای از BIL 🎁 از اینکه بخشی از BIL هستید سپاسگزاریم. این توجه ویژه نشانه قدردانی ما از شماست.'
    when 'hi' then 'BIL की ओर से उपहार 🎁 BIL का हिस्सा बनने के लिए धन्यवाद। यह खास संदेश आपके प्रति हमारी सराहना का प्रतीक है।'
    when 'id' then 'Hadiah dari BIL 🎁 Terima kasih telah menjadi bagian dari BIL. Perhatian istimewa ini adalah bentuk penghargaan kami kepada Anda.'
    when 'ms' then 'Hadiah daripada BIL 🎁 Terima kasih kerana menjadi sebahagian daripada BIL. Tanda istimewa ini melambangkan penghargaan kami kepada anda.'
    when 'ja' then 'BILからのプレゼントです🎁 BILをご利用いただきありがとうございます。この特別なメッセージに感謝の気持ちを込めました。'
    when 'ko' then 'BIL의 선물입니다 🎁 BIL과 함께해 주셔서 감사합니다. 이 특별한 메시지에 감사의 마음을 담았습니다.'
    when 'zh-hans' then '来自 BIL 的礼物 🎁 感谢你成为 BIL 的一员。这份特别心意代表我们对你的珍视。'
    when 'zh-hant' then '來自 BIL 的禮物 🎁 感謝你成為 BIL 的一員。這份特別心意代表我們對你的珍視。'
    when 'ru' then 'Подарок от BIL 🎁 Спасибо, что вы с BIL. Этот особый знак выражает нашу признательность вам.'
    when 'bn' then 'BIL-এর পক্ষ থেকে উপহার 🎁 BIL-এর অংশ হওয়ার জন্য ধন্যবাদ। এই বিশেষ বার্তাটি আপনার প্রতি আমাদের কৃতজ্ঞতার প্রকাশ।'
    when 'vi' then 'Quà tặng từ BIL 🎁 Cảm ơn bạn đã đồng hành cùng BIL. Lời nhắn đặc biệt này thể hiện sự trân trọng của chúng tôi dành cho bạn.'
    when 'th' then 'ของขวัญจาก BIL 🎁 ขอบคุณที่เป็นส่วนหนึ่งของ BIL ข้อความพิเศษนี้แทนคำขอบคุณและความใส่ใจจากเรา'
    when 'pl' then 'Prezent od BIL 🎁 Dziękujemy, że jesteś częścią BIL. Ten wyjątkowy gest wyraża nasze uznanie dla Ciebie.'
    when 'nl' then 'Een cadeau van BIL 🎁 Bedankt dat je deel uitmaakt van BIL. Met dit bijzondere gebaar tonen we onze waardering.'
    when 'uk' then 'Подарунок від BIL 🎁 Дякуємо, що ви з BIL. Цей особливий знак виражає нашу вдячність вам.'
    else 'A gift from BIL 🎁 Thank you for being part of BIL. This special message is our way of showing how much we value you.'
  end;
end
$$;

-- Service-only atomic fan-out to the durable inbox and best-effort push
-- outbox. The same idempotency key can be retried, but cannot be reused for a
-- different actor, audience, target, kind, or custom message.
create or replace function public.bil_enqueue_admin_notification(
  p_actor_id uuid,
  p_notification_kind text,
  p_audience text,
  p_target_id uuid,
  p_custom_body text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := now();
  v_kind text := lower(trim(coalesce(p_notification_kind, '')));
  v_audience text := lower(trim(coalesce(p_audience, '')));
  v_custom_body text := trim(coalesce(p_custom_body, ''));
  v_message_digest text;
  v_notification_id uuid;
  v_recipients integer := 0;
  v_push_rows integer := 0;
  v_existing private.bil_admin_notification_audit%rowtype;
begin
  if coalesce((select auth.jwt()->>'role'), '') <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_actor_id is null or not exists (
    select 1
    from private.bil_ai_coach_admins a
    where a.user_id = p_actor_id and a.active
  ) then
    raise exception 'ai_coach_admin_required' using errcode = '42501';
  end if;
  if v_kind not in ('compensation', 'gift', 'custom') then
    raise exception 'invalid_notification_kind';
  end if;
  if v_audience not in ('all', 'email') then
    raise exception 'invalid_notification_audience';
  end if;
  if (v_audience = 'all' and p_target_id is not null)
     or (v_audience = 'email' and (
       p_target_id is null
       or not exists (select 1 from auth.users u where u.id = p_target_id)
     )) then
    raise exception 'invalid_notification_target';
  end if;
  if p_idempotency_key is null
     or char_length(trim(p_idempotency_key)) not between 16 and 128
     or trim(p_idempotency_key) !~ '^[A-Za-z0-9:_-]+$' then
    raise exception 'invalid_idempotency_key';
  end if;
  if v_kind = 'custom' then
    if char_length(v_custom_body) not between 1 and 180
       or v_custom_body ~ '[[:cntrl:]]' then
      raise exception 'invalid_custom_notification';
    end if;
  elsif v_custom_body <> '' then
    raise exception 'unexpected_custom_notification';
  end if;

  v_message_digest := encode(
    extensions.digest(
      convert_to(
        case when v_kind = 'custom' then v_custom_body else v_kind end,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  insert into private.bil_admin_notification_audit(
    idempotency_key,
    actor_id,
    notification_kind,
    audience,
    target_id,
    message_digest,
    requested_at
  ) values (
    trim(p_idempotency_key),
    p_actor_id,
    v_kind,
    v_audience,
    p_target_id,
    v_message_digest,
    v_now
  )
  on conflict (idempotency_key) do nothing
  returning notification_id into v_notification_id;

  if v_notification_id is null then
    select * into strict v_existing
    from private.bil_admin_notification_audit a
    where a.idempotency_key = trim(p_idempotency_key);

    if v_existing.actor_id is distinct from p_actor_id
       or v_existing.notification_kind is distinct from v_kind
       or v_existing.audience is distinct from v_audience
       or v_existing.target_id is distinct from p_target_id
       or v_existing.message_digest is distinct from v_message_digest then
      raise exception 'idempotency_key_request_mismatch'
        using errcode = '42501';
    end if;

    return jsonb_build_object(
      'duplicate', true,
      'recipients_enqueued', v_existing.recipients_enqueued,
      'push_rows_enqueued', v_existing.push_rows_enqueued
    );
  end if;

  insert into public.bil_admin_notices(
    owner_id,
    notification_id,
    notification_kind,
    title,
    body,
    created_at
  )
  select
    u.id,
    v_notification_id,
    v_kind,
    private.bil_admin_notification_title(v_kind),
    private.bil_admin_notification_body(
      v_kind,
      private.bil_admin_notification_locale(u.id),
      v_custom_body
    ),
    v_now
  from auth.users u
  where v_audience = 'all' or u.id = p_target_id
  on conflict (owner_id, notification_id) do nothing;
  get diagnostics v_recipients = row_count;

  insert into public.bil_push_outbox(
    recipient_id,
    category,
    title,
    body,
    deep_link,
    copy_key,
    source_key,
    created_at
  )
  select
    n.owner_id,
    'account',
    n.title,
    n.body,
    'bil://settings',
    'admin_notification_' || v_kind || '_v1',
    'admin-notification:' || v_notification_id::text,
    v_now
  from public.bil_admin_notices n
  where n.notification_id = v_notification_id
  on conflict do nothing;
  get diagnostics v_push_rows = row_count;

  update private.bil_admin_notification_audit
  set recipients_enqueued = v_recipients,
      push_rows_enqueued = v_push_rows
  where notification_id = v_notification_id;

  return jsonb_build_object(
    'duplicate', false,
    'recipients_enqueued', v_recipients,
    'push_rows_enqueued', v_push_rows
  );
end
$$;

revoke all on function public.bil_resolve_admin_notification_target(uuid, text),
  public.bil_enqueue_admin_notification(uuid, text, text, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.bil_resolve_admin_notification_target(uuid, text),
  public.bil_enqueue_admin_notification(uuid, text, text, uuid, text, text)
  to service_role;

revoke all on function private.bil_admin_notification_locale(uuid),
  private.bil_admin_notification_title(text),
  private.bil_admin_notification_body(text, text, text)
  from public, anon, authenticated;

comment on function public.bil_enqueue_admin_notification(
  uuid, text, text, uuid, text, text
) is
  'Service-only, idempotent admin notification fan-out. Creates an own-row durable inbox notice and a push outbox row without changing AI usage, subscriptions, entitlements, plans, tiers, or balances.';

commit;
