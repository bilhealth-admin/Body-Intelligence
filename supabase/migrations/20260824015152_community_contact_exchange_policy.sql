-- Keep Community focused on health support rather than contact exchange or
-- dating. This database boundary backs up the client policy for every direct
-- table write and every SECURITY DEFINER RPC that writes these tables.
begin;

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

revoke all on function public.bil_community_contact_exchange_violation(text)
from public, anon, authenticated;

create or replace function public.bil_enforce_community_contact_exchange()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
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
$$;

revoke all on function public.bil_enforce_community_contact_exchange()
from public, anon, authenticated;

drop trigger if exists bil_00_profiles_contact_exchange_guard
  on public.bil_public_profiles;
create trigger bil_00_profiles_contact_exchange_guard
before insert or update of display_name, bio
on public.bil_public_profiles
for each row execute function public.bil_enforce_community_contact_exchange();

drop trigger if exists bil_00_posts_contact_exchange_guard
  on public.bil_community_posts;
create trigger bil_00_posts_contact_exchange_guard
before insert or update of body
on public.bil_community_posts
for each row execute function public.bil_enforce_community_contact_exchange();

drop trigger if exists bil_00_messages_contact_exchange_guard
  on public.bil_messages;
create trigger bil_00_messages_contact_exchange_guard
before insert or update of body
on public.bil_messages
for each row execute function public.bil_enforce_community_contact_exchange();

drop trigger if exists bil_00_food_submissions_contact_exchange_guard
  on public.bil_community_food_submissions;
create trigger bil_00_food_submissions_contact_exchange_guard
before insert or update of canonical_name, localized_names, aliases, brand, review_note
on public.bil_community_food_submissions
for each row execute function public.bil_enforce_community_contact_exchange();

drop trigger if exists bil_00_food_peer_reviews_contact_exchange_guard
  on public.bil_food_peer_reviews;
create trigger bil_00_food_peer_reviews_contact_exchange_guard
before insert or update of note
on public.bil_food_peer_reviews
for each row execute function public.bil_enforce_community_contact_exchange();

commit;

;
