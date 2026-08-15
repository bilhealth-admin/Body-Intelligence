begin;

create table if not exists public.bil_public_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(display_name) between 2 and 60),
  avatar_url text,
  bio text check (length(bio) <= 280),
  locale_code text not null default 'en' check (locale_code in ('ar','en','fr','es','tr')),
  discoverable boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.bil_friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> addressee_id),
  unique (requester_id, addressee_id)
);

create table if not exists public.bil_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.bil_community_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (length(body) between 1 and 1200),
  media_url text,
  visibility text not null default 'friends' check (visibility in ('friends','community')),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create table if not exists public.bil_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  deleted_by_sender_at timestamptz,
  deleted_by_recipient_at timestamptz,
  check (sender_id <> recipient_id)
);

create table if not exists public.bil_community_food_submissions (
  id uuid primary key default gen_random_uuid(),
  contributor_id uuid not null references auth.users(id) on delete cascade,
  canonical_name text not null check (length(canonical_name) between 2 and 180),
  localized_names jsonb not null default '{}'::jsonb,
  aliases jsonb not null default '[]'::jsonb,
  barcode text check (barcode is null or length(barcode) between 6 and 32),
  country_code text check (country_code is null or length(country_code) = 2),
  serving_grams numeric check (serving_grams > 0),
  calories_kcal numeric check (calories_kcal >= 0),
  protein_g numeric check (protein_g >= 0),
  carbohydrate_g numeric check (carbohydrate_g >= 0),
  fat_g numeric check (fat_g >= 0),
  fiber_g numeric check (fiber_g >= 0),
  sodium_mg numeric check (sodium_mg >= 0),
  evidence_url text,
  status text not null default 'pending' check (status in ('pending','needs_changes','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  check (calories_kcal is null or serving_grams is not null)
);

create table if not exists public.bil_food_peer_reviews (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.bil_community_food_submissions(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id) on delete cascade,
  verdict text not null check (verdict in ('accurate','needs_changes','unsafe')),
  note text check (length(note) <= 600),
  created_at timestamptz not null default now(),
  unique (submission_id, reviewer_id)
);

create table if not exists public.bil_community_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  target_kind text not null check (target_kind in ('profile','post','message','food')),
  target_id uuid not null,
  reason text not null check (length(reason) between 3 and 500),
  status text not null default 'open' check (status in ('open','reviewing','closed')),
  created_at timestamptz not null default now()
);

create index if not exists bil_posts_feed_idx on public.bil_community_posts (created_at desc) where deleted_at is null;
create index if not exists bil_messages_parties_idx on public.bil_messages (sender_id, recipient_id, created_at desc);
create index if not exists bil_food_status_idx on public.bil_community_food_submissions (status, created_at desc);

alter table public.bil_public_profiles enable row level security;
alter table public.bil_friendships enable row level security;
alter table public.bil_blocks enable row level security;
alter table public.bil_community_posts enable row level security;
alter table public.bil_messages enable row level security;
alter table public.bil_community_food_submissions enable row level security;
alter table public.bil_food_peer_reviews enable row level security;
alter table public.bil_community_reports enable row level security;

create policy bil_profiles_read on public.bil_public_profiles for select to authenticated
using (discoverable or user_id = (select auth.uid()));
create policy bil_profiles_write_own on public.bil_public_profiles for insert to authenticated
with check (user_id = (select auth.uid()));
create policy bil_profiles_update_own on public.bil_public_profiles for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy bil_friendships_read_parties on public.bil_friendships for select to authenticated
using ((select auth.uid()) in (requester_id, addressee_id));
create policy bil_friendships_request on public.bil_friendships for insert to authenticated
with check (requester_id = (select auth.uid()));
create policy bil_friendships_respond on public.bil_friendships for update to authenticated
using (addressee_id = (select auth.uid())) with check (addressee_id = (select auth.uid()));
create policy bil_friendships_delete_parties on public.bil_friendships for delete to authenticated
using ((select auth.uid()) in (requester_id, addressee_id));

create policy bil_blocks_own on public.bil_blocks for select to authenticated using (blocker_id = (select auth.uid()));
create policy bil_blocks_insert_own on public.bil_blocks for insert to authenticated with check (blocker_id = (select auth.uid()));
create policy bil_blocks_delete_own on public.bil_blocks for delete to authenticated using (blocker_id = (select auth.uid()));

create policy bil_posts_read on public.bil_community_posts for select to authenticated using (
  deleted_at is null and not exists (
    select 1 from public.bil_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = author_id)
       or (b.blocker_id = author_id and b.blocked_id = (select auth.uid()))
  ) and (
    visibility = 'community' or author_id = (select auth.uid()) or exists (
      select 1 from public.bil_friendships f where f.status = 'accepted'
      and ((f.requester_id = author_id and f.addressee_id = (select auth.uid()))
        or (f.addressee_id = author_id and f.requester_id = (select auth.uid())))
    )
  )
);
create policy bil_posts_insert_own on public.bil_community_posts for insert to authenticated with check (author_id = (select auth.uid()));
create policy bil_posts_update_own on public.bil_community_posts for update to authenticated using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));

create policy bil_messages_read_parties on public.bil_messages for select to authenticated
using ((select auth.uid()) in (sender_id, recipient_id));
create policy bil_messages_send_friends on public.bil_messages for insert to authenticated with check (
  sender_id = (select auth.uid()) and not exists (
    select 1 from public.bil_blocks b where
      (b.blocker_id = sender_id and b.blocked_id = recipient_id) or
      (b.blocker_id = recipient_id and b.blocked_id = sender_id)
  ) and exists (
    select 1 from public.bil_friendships f where f.status = 'accepted' and
      ((f.requester_id = sender_id and f.addressee_id = recipient_id) or
       (f.addressee_id = sender_id and f.requester_id = recipient_id))
  )
);
create policy bil_messages_update_recipient on public.bil_messages for update to authenticated
using ((select auth.uid()) in (sender_id, recipient_id));

create policy bil_food_read on public.bil_community_food_submissions for select to authenticated
using (status = 'approved' or contributor_id = (select auth.uid()));
create policy bil_food_submit on public.bil_community_food_submissions for insert to authenticated
with check (contributor_id = (select auth.uid()) and status = 'pending');
create policy bil_food_update_pending_own on public.bil_community_food_submissions for update to authenticated
using (contributor_id = (select auth.uid()) and status in ('pending','needs_changes'))
with check (contributor_id = (select auth.uid()) and status in ('pending','needs_changes'));

create policy bil_reviews_read on public.bil_food_peer_reviews for select to authenticated using (true);
create policy bil_reviews_insert on public.bil_food_peer_reviews for insert to authenticated with check (
  reviewer_id = (select auth.uid()) and exists (
    select 1 from public.bil_community_food_submissions s
    where s.id = submission_id and s.contributor_id <> (select auth.uid())
  )
);
create policy bil_reviews_update_own on public.bil_food_peer_reviews for update to authenticated
using (reviewer_id = (select auth.uid())) with check (reviewer_id = (select auth.uid()));

create policy bil_reports_insert on public.bil_community_reports for insert to authenticated
with check (reporter_id = (select auth.uid()) and status = 'open');
create policy bil_reports_read_own on public.bil_community_reports for select to authenticated
using (reporter_id = (select auth.uid()));

grant select, insert, update, delete on public.bil_public_profiles, public.bil_friendships,
  public.bil_blocks, public.bil_community_posts, public.bil_messages,
  public.bil_community_food_submissions, public.bil_food_peer_reviews,
  public.bil_community_reports to authenticated;
revoke all on public.bil_public_profiles, public.bil_friendships,
  public.bil_blocks, public.bil_community_posts, public.bil_messages,
  public.bil_community_food_submissions, public.bil_food_peer_reviews,
  public.bil_community_reports from anon;

commit;
