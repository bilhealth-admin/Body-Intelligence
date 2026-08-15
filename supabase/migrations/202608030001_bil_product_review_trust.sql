begin;

alter table public.bil_community_food_submissions
  add column if not exists product_kind text not null default 'food',
  add column if not exists brand text,
  add column if not exists submission_source text not null default 'user_submission',
  add column if not exists submission_confidence text not null default 'low',
  add column if not exists observed_source text,
  add column if not exists observed_confidence text,
  add column if not exists review_note text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'bil_food_submission_product_kind_check') then
    alter table public.bil_community_food_submissions add constraint bil_food_submission_product_kind_check check (
      product_kind in ('food','beverage','alcohol','supplement','medicine','tobacco','personal_care','pet_food','household','general_product','unknown')
    );
  end if;
  if not exists (select 1 from pg_constraint where conname = 'bil_food_submission_confidence_check') then
    alter table public.bil_community_food_submissions add constraint bil_food_submission_confidence_check check (
      submission_confidence in ('high','medium','low') and
      (observed_confidence is null or observed_confidence in ('high','medium','low'))
    );
  end if;
  if not exists (select 1 from pg_constraint where conname = 'bil_food_submission_review_note_check') then
    alter table public.bil_community_food_submissions add constraint bil_food_submission_review_note_check check (
      review_note is null or char_length(review_note) <= 1000
    );
  end if;
end $$;

create index if not exists bil_food_submission_barcode_status_idx
  on public.bil_community_food_submissions (barcode, status)
  where barcode is not null;

create or replace function public.bil_list_reviewable_products()
returns setof public.bil_community_food_submissions
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from public.bil_community_moderators where user_id = auth.uid()
  ) then
    raise exception 'moderator_required';
  end if;
  return query
    select * from public.bil_community_food_submissions
    where status in ('pending', 'needs_changes')
    order by created_at desc
    limit 40;
end;
$$;

revoke all on function public.bil_list_reviewable_products() from public, anon;
grant execute on function public.bil_list_reviewable_products() to authenticated;

commit;
