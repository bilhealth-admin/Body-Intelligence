begin;

-- Dedicated authority for the BIL administration panel. Membership is
-- provisioned by a trusted server-side operator after resolving the approved
-- owner's auth.users UUID; no email address or client-editable metadata is an
-- authorization source.
create schema if not exists private;

create table if not exists private.bil_ai_coach_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active boolean not null default true,
  granted_at timestamptz not null default now(),
  granted_by uuid references auth.users(id) on delete set null,
  reason text not null default 'owner_approved'
    check (char_length(reason) between 3 and 160)
);

create table if not exists private.bil_ai_coach_global_reset_audit (
  reset_id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique
    check (char_length(idempotency_key) between 16 and 128),
  actor_id uuid references auth.users(id) on delete set null,
  executed_at timestamptz not null default now(),
  usage_rows_reset integer not null default 0 check (usage_rows_reset >= 0),
  monthly_rows_reset integer not null default 0
    check (monthly_rows_reset >= 0),
  legacy_rows_reset integer not null default 0 check (legacy_rows_reset >= 0),
  users_notified integer not null default 0 check (users_notified >= 0),
  push_rows_enqueued integer not null default 0
    check (push_rows_enqueued >= 0)
);

create table if not exists private.bil_ai_coach_individual_reset_audit (
  reset_id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique
    check (char_length(idempotency_key) between 16 and 128),
  actor_id uuid references auth.users(id) on delete set null,
  target_id uuid references auth.users(id) on delete set null,
  reason text,
  executed_at timestamptz not null default now(),
  usage_rows_reset integer not null default 0 check (usage_rows_reset >= 0),
  monthly_rows_reset integer not null default 0
    check (monthly_rows_reset >= 0),
  legacy_rows_reset integer not null default 0 check (legacy_rows_reset >= 0),
  users_notified integer not null default 0 check (users_notified >= 0),
  push_rows_enqueued integer not null default 0
    check (push_rows_enqueued >= 0),
  check (
    reason is null
    or (
      char_length(reason) between 2 and 160
      and reason !~ '[[:cntrl:]]'
    )
  )
);

revoke all on schema private from public, anon, authenticated;
revoke all on table private.bil_ai_coach_admins,
  private.bil_ai_coach_global_reset_audit,
  private.bil_ai_coach_individual_reset_audit
  from public, anon, authenticated;

-- A durable in-app notice is separate from the push delivery queue. The app
-- can read and dismiss only its own row; reset creation remains server-only.
create table if not exists public.bil_ai_coach_reset_notices (
  owner_id uuid not null references auth.users(id) on delete cascade,
  reset_id uuid not null,
  created_at timestamptz not null default now(),
  seen_at timestamptz,
  primary key (owner_id, reset_id),
  check (seen_at is null or seen_at >= created_at)
);

alter table public.bil_ai_coach_reset_notices enable row level security;
revoke all on table public.bil_ai_coach_reset_notices
  from public, anon, authenticated;
grant select on table public.bil_ai_coach_reset_notices to authenticated;

drop policy if exists bil_ai_coach_reset_notices_read_own
  on public.bil_ai_coach_reset_notices;
create policy bil_ai_coach_reset_notices_read_own
on public.bil_ai_coach_reset_notices
for select to authenticated
using (owner_id = (select auth.uid()));

drop policy if exists bil_ai_coach_reset_notices_dismiss_own
  on public.bil_ai_coach_reset_notices;
create policy bil_ai_coach_reset_notices_dismiss_own
on public.bil_ai_coach_reset_notices
for update to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

-- Use database time for acknowledgement so device clock skew can never break
-- the seen_at >= created_at invariant. A caller can affect only its own row and
-- receives the same false result for an absent or another user's reset id.
create or replace function public.bil_dismiss_ai_coach_reset_notice(
  p_owner_id uuid,
  p_reset_id uuid
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
     or p_reset_id is null then
    return false;
  end if;
  update public.bil_ai_coach_reset_notices n
  set seen_at = now()
  where n.owner_id = v_owner_id
    and n.reset_id = p_reset_id
    and n.seen_at is null;
  get diagnostics v_changed = row_count;
  return v_changed = 1;
end
$$;

revoke all on function public.bil_dismiss_ai_coach_reset_notice(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.bil_dismiss_ai_coach_reset_notice(uuid, uuid)
  to authenticated;

-- Reuse the established notification outbox and add a deterministic source
-- key so a retried reset cannot enqueue a second notification for any user.
alter table public.bil_push_outbox
  add column if not exists copy_key text,
  add column if not exists source_key text;

alter table public.bil_push_outbox
  drop constraint if exists bil_push_outbox_category_check;
alter table public.bil_push_outbox
  add constraint bil_push_outbox_category_check
  check (category in (
    'friend_request', 'message', 'community', 'account', 'ai_coach'
  ));
alter table public.bil_push_outbox
  drop constraint if exists bil_push_outbox_copy_key_check;
alter table public.bil_push_outbox
  add constraint bil_push_outbox_copy_key_check
  check (copy_key is null or char_length(copy_key) between 3 and 80);
alter table public.bil_push_outbox
  drop constraint if exists bil_push_outbox_source_key_check;
alter table public.bil_push_outbox
  add constraint bil_push_outbox_source_key_check
  check (source_key is null or char_length(source_key) between 16 and 128);

create unique index if not exists bil_push_outbox_recipient_source_uidx
  on public.bil_push_outbox(recipient_id, source_key)
  where source_key is not null;

-- The public read probe exposes one boolean and nothing about the allow-list.
-- The mutation below independently repeats the authority check.
create or replace function public.bil_can_manage_ai_coach()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from private.bil_ai_coach_admins a
      where a.user_id = (select auth.uid())
        and a.active
    )
$$;

revoke all on function public.bil_can_manage_ai_coach()
  from public, anon, authenticated;
grant execute on function public.bil_can_manage_ai_coach()
  to authenticated;

-- Delegate trial selection to the same live authority used by reserve/status;
-- all other accounts keep the existing UTC calendar-week boundary.
create or replace function private.bil_current_ai_week_start(
  p_owner_id uuid,
  p_at timestamptz
)
returns date
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_plan text := public.bil_resolve_ai_allowance_plan(p_owner_id);
  v_anchor date;
begin
  if v_plan = 'trial' then
    v_anchor := public.bil_resolve_ai_trial_anchor(p_owner_id);
    if v_anchor is null then
      raise exception 'ai_trial_anchor_missing';
    end if;
    return v_anchor;
  end if;

  return date_trunc('week', p_at at time zone 'utc')::date;
end
$$;

create or replace function private.bil_current_ai_month_start(
  p_owner_id uuid,
  p_at timestamptz
)
returns date
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_plan text := public.bil_resolve_ai_allowance_plan(p_owner_id);
  v_anchor date;
begin
  if v_plan = 'trial' then
    v_anchor := public.bil_resolve_ai_trial_anchor(p_owner_id);
    if v_anchor is null then
      raise exception 'ai_trial_anchor_missing';
    end if;
    return v_anchor;
  end if;

  return date_trunc('month', p_at at time zone 'utc')::date;
end
$$;

-- Reviewed reset notice in every one of BIL's 25 production locales. Locale
-- metadata is used only to select copy; it never participates in authority.
create or replace function private.bil_ai_coach_reset_notification_body(
  p_locale text
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select case lower(replace(coalesce(p_locale, 'en'), '_', '-'))
    when 'ar' then 'هدية من BIL 🎁 تمت إعادة ضبط استخدام AI Coach بالكامل، ويمكنك الاستفادة من حصتك مجددًا حتى نهاية دورتك الحالية.'
    when 'fr' then 'Un cadeau de BIL 🎁 L’utilisation d’AI Coach a été entièrement réinitialisée. Profitez de nouveau de votre quota jusqu’à la fin de votre cycle actuel.'
    when 'es' then 'Un regalo de BIL 🎁 El uso de AI Coach se restableció por completo. Puedes volver a usar tu cuota hasta el final de tu ciclo actual.'
    when 'tr' then 'BIL’den bir hediye 🎁 AI Coach kullanımınız tamamen sıfırlandı. Mevcut döneminiz bitene kadar kotanızı yeniden kullanabilirsiniz.'
    when 'de' then 'Ein Geschenk von BIL 🎁 Deine AI-Coach-Nutzung wurde vollständig zurückgesetzt. Nutze dein Kontingent bis zum Ende deines aktuellen Zyklus erneut.'
    when 'it' then 'Un regalo da BIL 🎁 L’utilizzo di AI Coach è stato azzerato. Puoi usare di nuovo la tua quota fino alla fine del ciclo attuale.'
    when 'pt-br' then 'Um presente da BIL 🎁 O uso do AI Coach foi totalmente zerado. Você pode usar sua cota novamente até o fim do ciclo atual.'
    when 'pt-pt' then 'Um presente da BIL 🎁 A utilização do AI Coach foi totalmente reposta. Pode voltar a usar a sua quota até ao fim do ciclo atual.'
    when 'ur' then 'BIL کی طرف سے تحفہ 🎁 AI Coach کا استعمال مکمل طور پر ری سیٹ ہو گیا ہے۔ موجودہ دور کے اختتام تک اپنا کوٹہ دوبارہ استعمال کریں۔'
    when 'fa' then 'هدیه‌ای از BIL 🎁 میزان استفاده از AI Coach کاملاً بازنشانی شد. تا پایان دوره فعلی دوباره از سهمیه خود استفاده کنید.'
    when 'hi' then 'BIL की ओर से उपहार 🎁 AI Coach का उपयोग पूरी तरह रीसेट हो गया है। मौजूदा अवधि के अंत तक अपना कोटा फिर से इस्तेमाल करें।'
    when 'id' then 'Hadiah dari BIL 🎁 Penggunaan AI Coach telah direset sepenuhnya. Gunakan kembali kuota Anda hingga siklus saat ini berakhir.'
    when 'ms' then 'Hadiah daripada BIL 🎁 Penggunaan AI Coach telah ditetapkan semula sepenuhnya. Gunakan semula kuota anda hingga kitaran semasa berakhir.'
    when 'ja' then 'BILからのプレゼントです🎁 AI Coachの利用回数を完全にリセットしました。現在のサイクル終了まで、割り当てを再び利用できます。'
    when 'ko' then 'BIL의 선물입니다 🎁 AI Coach 사용량이 완전히 초기화되었습니다. 현재 주기가 끝날 때까지 할당량을 다시 이용하세요.'
    when 'zh-hans' then '来自 BIL 的礼物 🎁 AI Coach 使用量已全部重置。你可以在当前周期结束前再次使用配额。'
    when 'zh-hant' then '來自 BIL 的禮物 🎁 AI Coach 使用量已全部重設。你可以在目前週期結束前再次使用配額。'
    when 'ru' then 'Подарок от BIL 🎁 Использование AI Coach полностью сброшено. Снова используйте свою квоту до конца текущего цикла.'
    when 'bn' then 'BIL-এর পক্ষ থেকে উপহার 🎁 AI Coach-এর ব্যবহার পুরোপুরি রিসেট হয়েছে। বর্তমান চক্র শেষ হওয়া পর্যন্ত আবার আপনার কোটা ব্যবহার করুন।'
    when 'vi' then 'Quà tặng từ BIL 🎁 Mức sử dụng AI Coach đã được đặt lại hoàn toàn. Bạn có thể dùng lại hạn mức đến hết chu kỳ hiện tại.'
    when 'th' then 'ของขวัญจาก BIL 🎁 รีเซ็ตการใช้งาน AI Coach ทั้งหมดแล้ว คุณใช้โควตาได้อีกครั้งจนกว่ารอบปัจจุบันจะสิ้นสุด'
    when 'pl' then 'Prezent od BIL 🎁 Użycie AI Coach zostało całkowicie wyzerowane. Możesz ponownie korzystać z limitu do końca bieżącego cyklu.'
    when 'nl' then 'Een cadeau van BIL 🎁 Je AI Coach-gebruik is volledig gereset. Je kunt je tegoed opnieuw gebruiken tot het einde van je huidige cyclus.'
    when 'uk' then 'Подарунок від BIL 🎁 Використання AI Coach повністю скинуто. Знову користуйтеся своєю квотою до кінця поточного циклу.'
    else 'A gift from BIL 🎁 Your AI Coach usage has been fully reset. You can use your allowance again until the end of your current cycle.'
  end
$$;

-- Decreasing consumed usage must remain possible when a trial/grant expires
-- while an older reservation is still in flight. Only a net-positive delta is
-- subject to the current plan ceiling; settlement conversions and admin
-- resets can then preserve the reservation ledger without touching Boost.
create or replace function public.bil_sync_ai_monthly_usage()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_plan text := public.bil_resolve_ai_allowance_plan(new.owner_id);
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_used_delta bigint;
  v_reserved_delta bigint;
  v_limit bigint;
  v_total bigint;
begin
  if v_plan = 'trial' then
    select public.bil_resolve_ai_trial_anchor(new.owner_id) into v_month;
    if v_month is null then raise exception 'trial_period_missing'; end if;
  end if;

  if tg_op = 'INSERT' then
    v_used_delta := new.used;
    v_reserved_delta := new.reserved;
  else
    v_used_delta := new.used - old.used;
    v_reserved_delta := new.reserved - old.reserved;
  end if;

  insert into public.bil_ai_credit_monthly_usage(owner_id, month_start)
    values(new.owner_id, v_month) on conflict do nothing;
  select monthly_limit into v_limit
  from public.bil_ai_credit_config
  where plan_id = v_plan;

  update public.bil_ai_credit_monthly_usage set
    used = greatest(used + v_used_delta, 0),
    reserved = greatest(reserved + v_reserved_delta, 0),
    updated_at = now()
  where owner_id = new.owner_id and month_start = v_month
  returning used + reserved into v_total;

  if v_used_delta + v_reserved_delta > 0
     and v_limit is not null
     and v_total > v_limit then
    raise exception 'ai_monthly_usage_exhausted';
  end if;
  return new;
end
$$;

-- One set-based, transaction-scoped operation. It resets only consumed usage in
-- each owner's already-current week. It never writes period keys, limits,
-- paid balances, entitlements, subscription rows, or tier records. Reserved
-- usage remains attached to in-flight events so later settlement stays ledger-
-- coherent and cannot spill into a purchased AI Boost balance.
create or replace function public.bil_global_reset_ai_coach(
  p_actor_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := now();
  v_reset_id uuid;
  v_usage_rows integer := 0;
  v_monthly_rows integer := 0;
  v_legacy_rows integer := 0;
  v_users_notified integer := 0;
  v_push_rows integer := 0;
  v_existing private.bil_ai_coach_global_reset_audit%rowtype;
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
  if p_idempotency_key is null
     or char_length(trim(p_idempotency_key)) not between 16 and 128
     or trim(p_idempotency_key) !~ '^[A-Za-z0-9:_-]+$' then
    raise exception 'invalid_idempotency_key';
  end if;

  insert into private.bil_ai_coach_global_reset_audit(
    idempotency_key, actor_id, executed_at
  ) values (trim(p_idempotency_key), p_actor_id, v_now)
  on conflict (idempotency_key) do nothing
  returning reset_id into v_reset_id;

  if v_reset_id is null then
    select * into strict v_existing
    from private.bil_ai_coach_global_reset_audit a
    where a.idempotency_key = trim(p_idempotency_key);
    if v_existing.actor_id is distinct from p_actor_id then
      raise exception 'idempotency_key_owned_by_another_admin'
        using errcode = '42501';
    end if;
    return jsonb_build_object(
      'duplicate', true,
      'reset_id', v_existing.reset_id,
      'executed_at', v_existing.executed_at,
      'usage_rows_reset', v_existing.usage_rows_reset,
      'monthly_rows_reset', v_existing.monthly_rows_reset,
      'legacy_rows_reset', v_existing.legacy_rows_reset,
      'users_notified', v_existing.users_notified,
      'push_rows_enqueued', v_existing.push_rows_enqueued
    );
  end if;

  -- Acquire every counter-table writer lock as one NOWAIT barrier before any
  -- row mutation. A concurrent reserve/settle keeps serving the user and this
  -- rare admin transaction rolls back for a bounded idempotent Edge retry,
  -- preventing monthly/weekly/legacy lock-order cycles in either direction.
  lock table public.bil_ai_credit_monthly_usage, public.bil_ai_credit_weekly_usage, public.bil_ai_weekly_usage in share row exclusive mode nowait;

  -- Restore the matching current monthly allowance first, matching the live
  -- reservation path's monthly -> weekly lock order. A prior week in the
  -- same month can otherwise keep a monthly-capped account locked even after
  -- its current weekly row was reset. The period key and reservations stay.
  update public.bil_ai_credit_monthly_usage u
  set used = 0,
      updated_at = v_now
  where u.month_start = private.bil_current_ai_month_start(u.owner_id, v_now)
    and u.used <> 0;
  get diagnostics v_monthly_rows = row_count;

  update public.bil_ai_credit_weekly_usage u
  set used = 0,
      updated_at = v_now
  where u.week_start = private.bil_current_ai_week_start(u.owner_id, v_now)
    and u.used <> 0;
  get diagnostics v_usage_rows = row_count;

  -- Keep the retired capability counters coherent without granting or
  -- consuming any paid Boost balance.
  update public.bil_ai_weekly_usage u
  set used = 0,
      updated_at = v_now
  where u.week_start = private.bil_current_ai_week_start(u.owner_id, v_now)
    and u.used <> 0;
  get diagnostics v_legacy_rows = row_count;

  insert into public.bil_ai_coach_reset_notices(
    owner_id, reset_id, created_at
  )
  select u.id, v_reset_id, v_now
  from auth.users u
  on conflict (owner_id, reset_id) do nothing;
  get diagnostics v_users_notified = row_count;

  insert into public.bil_push_outbox(
    recipient_id, category, title, body, deep_link, copy_key, source_key,
    created_at
  )
  select
    u.id,
    'ai_coach',
    'BIL 🎁',
    private.bil_ai_coach_reset_notification_body(
      coalesce(
        case
          when lower(replace(coalesce(u.raw_app_meta_data->>'locale', ''), '_', '-'))
            in (
              'ar','en','fr','es','tr','de','it','pt-br','pt-pt','ur','fa',
              'hi','id','ms','ja','ko','zh-hans','zh-hant','ru','bn','vi',
              'th','pl','nl','uk'
            )
          then u.raw_app_meta_data->>'locale'
        end,
        case
          when lower(replace(coalesce(u.raw_user_meta_data->>'locale', ''), '_', '-'))
            in (
              'ar','en','fr','es','tr','de','it','pt-br','pt-pt','ur','fa',
              'hi','id','ms','ja','ko','zh-hans','zh-hant','ru','bn','vi',
              'th','pl','nl','uk'
            )
          then u.raw_user_meta_data->>'locale'
        end,
        p.locale_code,
        'en'
      )
    ),
    'bil://settings/ai-coach',
    'ai_coach_global_reset_gift_v1',
    'ai-coach-global-reset:' || v_reset_id::text,
    v_now
  from auth.users u
  left join public.bil_public_profiles p on p.user_id = u.id
  on conflict do nothing;
  get diagnostics v_push_rows = row_count;

  update private.bil_ai_coach_global_reset_audit
  set usage_rows_reset = v_usage_rows,
      monthly_rows_reset = v_monthly_rows,
      legacy_rows_reset = v_legacy_rows,
      users_notified = v_users_notified,
      push_rows_enqueued = v_push_rows
  where reset_id = v_reset_id;

  return jsonb_build_object(
    'duplicate', false,
    'reset_id', v_reset_id,
    'executed_at', v_now,
    'usage_rows_reset', v_usage_rows,
    'monthly_rows_reset', v_monthly_rows,
    'legacy_rows_reset', v_legacy_rows,
    'users_notified', v_users_notified,
    'push_rows_enqueued', v_push_rows
  );
end
$$;

-- Email lookup remains behind the service role and repeats the dedicated
-- administration check. The Flutter client never queries auth.users or
-- receives a UUID/account record; the Edge response exposes only a matched
-- boolean to an already-authorized administrator.
create or replace function public.bil_resolve_ai_coach_reset_target(
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

  select u.id into v_target_id
  from auth.users u
  where u.email is not null
    and lower(trim(u.email)) = v_email
  order by u.created_at
  limit 1;

  return v_target_id;
end
$$;

-- A single-account courtesy reset uses the same period resolver and ledger
-- semantics as the global operation. Its private audit stores the actor,
-- target, optional reason, idempotency key, and all affected row counts.
create or replace function public.bil_individual_reset_ai_coach(
  p_actor_id uuid,
  p_target_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := now();
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_reset_id uuid;
  v_usage_rows integer := 0;
  v_monthly_rows integer := 0;
  v_legacy_rows integer := 0;
  v_users_notified integer := 0;
  v_push_rows integer := 0;
  v_locale text := 'en';
  v_existing private.bil_ai_coach_individual_reset_audit%rowtype;
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
  if p_target_id is null or not exists (
    select 1 from auth.users u where u.id = p_target_id
  ) then
    raise exception 'invalid_reset_target';
  end if;
  if p_idempotency_key is null
     or char_length(trim(p_idempotency_key)) not between 16 and 128
     or trim(p_idempotency_key) !~ '^[A-Za-z0-9:_-]+$' then
    raise exception 'invalid_idempotency_key';
  end if;
  if v_reason is not null and (
    char_length(v_reason) not between 2 and 160
    or v_reason ~ '[[:cntrl:]]'
  ) then
    raise exception 'invalid_reset_reason';
  end if;

  insert into private.bil_ai_coach_individual_reset_audit(
    idempotency_key, actor_id, target_id, reason, executed_at
  ) values (
    trim(p_idempotency_key), p_actor_id, p_target_id, v_reason, v_now
  )
  on conflict (idempotency_key) do nothing
  returning reset_id into v_reset_id;

  if v_reset_id is null then
    select * into strict v_existing
    from private.bil_ai_coach_individual_reset_audit a
    where a.idempotency_key = trim(p_idempotency_key);
    if v_existing.actor_id is distinct from p_actor_id
       or v_existing.target_id is distinct from p_target_id
       or v_existing.reason is distinct from v_reason then
      raise exception 'idempotency_key_request_mismatch'
        using errcode = '42501';
    end if;
    return jsonb_build_object(
      'duplicate', true,
      'reset_id', v_existing.reset_id,
      'executed_at', v_existing.executed_at,
      'usage_rows_reset', v_existing.usage_rows_reset,
      'monthly_rows_reset', v_existing.monthly_rows_reset,
      'legacy_rows_reset', v_existing.legacy_rows_reset,
      'users_notified', v_existing.users_notified,
      'push_rows_enqueued', v_existing.push_rows_enqueued
    );
  end if;

  -- Keep the same fail-fast all-counter barrier as the global reset. This is
  -- intentionally after the idempotency duplicate return and before updates.
  lock table public.bil_ai_credit_monthly_usage, public.bil_ai_credit_weekly_usage, public.bil_ai_weekly_usage in share row exclusive mode nowait;

  update public.bil_ai_credit_monthly_usage u
  set used = 0,
      updated_at = v_now
  where u.owner_id = p_target_id
    and u.month_start = private.bil_current_ai_month_start(p_target_id, v_now)
    and u.used <> 0;
  get diagnostics v_monthly_rows = row_count;

  update public.bil_ai_credit_weekly_usage u
  set used = 0,
      updated_at = v_now
  where u.owner_id = p_target_id
    and u.week_start = private.bil_current_ai_week_start(p_target_id, v_now)
    and u.used <> 0;
  get diagnostics v_usage_rows = row_count;

  update public.bil_ai_weekly_usage u
  set used = 0,
      updated_at = v_now
  where u.owner_id = p_target_id
    and u.week_start = private.bil_current_ai_week_start(p_target_id, v_now)
    and u.used <> 0;
  get diagnostics v_legacy_rows = row_count;

  insert into public.bil_ai_coach_reset_notices(
    owner_id, reset_id, created_at
  ) values (p_target_id, v_reset_id, v_now)
  on conflict (owner_id, reset_id) do nothing;
  get diagnostics v_users_notified = row_count;

  select coalesce(
    case
      when lower(replace(coalesce(u.raw_app_meta_data->>'locale', ''), '_', '-'))
        in (
          'ar','en','fr','es','tr','de','it','pt-br','pt-pt','ur','fa',
          'hi','id','ms','ja','ko','zh-hans','zh-hant','ru','bn','vi',
          'th','pl','nl','uk'
        )
      then u.raw_app_meta_data->>'locale'
    end,
    case
      when lower(replace(coalesce(u.raw_user_meta_data->>'locale', ''), '_', '-'))
        in (
          'ar','en','fr','es','tr','de','it','pt-br','pt-pt','ur','fa',
          'hi','id','ms','ja','ko','zh-hans','zh-hant','ru','bn','vi',
          'th','pl','nl','uk'
        )
      then u.raw_user_meta_data->>'locale'
    end,
    p.locale_code,
    'en'
  ) into v_locale
  from auth.users u
  left join public.bil_public_profiles p on p.user_id = u.id
  where u.id = p_target_id;

  insert into public.bil_push_outbox(
    recipient_id, category, title, body, deep_link, copy_key, source_key,
    created_at
  ) values (
    p_target_id,
    'ai_coach',
    'BIL 🎁',
    private.bil_ai_coach_reset_notification_body(v_locale),
    'bil://settings/ai-coach',
    'ai_coach_reset_gift_v1',
    'ai-coach-individual-reset:' || v_reset_id::text,
    v_now
  )
  on conflict do nothing;
  get diagnostics v_push_rows = row_count;

  update private.bil_ai_coach_individual_reset_audit
  set usage_rows_reset = v_usage_rows,
      monthly_rows_reset = v_monthly_rows,
      legacy_rows_reset = v_legacy_rows,
      users_notified = v_users_notified,
      push_rows_enqueued = v_push_rows
  where reset_id = v_reset_id;

  return jsonb_build_object(
    'duplicate', false,
    'reset_id', v_reset_id,
    'executed_at', v_now,
    'usage_rows_reset', v_usage_rows,
    'monthly_rows_reset', v_monthly_rows,
    'legacy_rows_reset', v_legacy_rows,
    'users_notified', v_users_notified,
    'push_rows_enqueued', v_push_rows
  );
end
$$;

revoke all on function public.bil_global_reset_ai_coach(uuid, text)
  from public, anon, authenticated;
grant execute on function public.bil_global_reset_ai_coach(uuid, text)
  to service_role;

revoke all on function public.bil_resolve_ai_coach_reset_target(uuid, text),
  public.bil_individual_reset_ai_coach(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.bil_resolve_ai_coach_reset_target(uuid, text),
  public.bil_individual_reset_ai_coach(uuid, uuid, text, text)
  to service_role;

revoke all on function private.bil_current_ai_week_start(uuid, timestamptz),
  private.bil_current_ai_month_start(uuid, timestamptz),
  private.bil_ai_coach_reset_notification_body(text)
  from public, anon, authenticated;

comment on function public.bil_global_reset_ai_coach(uuid, text) is
  'Service-only atomic reset invoked after an authenticated admin check. Resets current weekly/monthly consumed AI usage, preserves in-flight reservations and every period/tier/subscription/paid balance, audits once, and notifies every user once.';

comment on function public.bil_individual_reset_ai_coach(
  uuid, uuid, text, text
) is
  'Service-only atomic courtesy reset for one server-resolved account. Resets only current weekly/monthly consumed usage, preserves reservations and commercial state, audits the actor/target/reason once, and notifies only the target.';

commit;
