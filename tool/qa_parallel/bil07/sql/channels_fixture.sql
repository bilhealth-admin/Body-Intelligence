-- Explicit synthetic directory. These are test fixtures, never a live seed.
insert into public.bil07_channels_v1(id, slug, title, description, visibility, enabled)
values
  ('10000000-0000-4000-8000-000000000001', 'general', 'General', 'Synthetic fixture', 'public', true),
  ('10000000-0000-4000-8000-000000000002', 'nutrition', 'Nutrition', 'Synthetic fixture', 'public', true),
  ('10000000-0000-4000-8000-000000000003', 'workouts', 'Workouts', 'Synthetic members fixture', 'members', true),
  ('10000000-0000-4000-8000-000000000004', 'mindset', 'Mindset', 'Synthetic fixture', 'public', true),
  ('10000000-0000-4000-8000-000000000005', 'disabled', 'Disabled', 'Synthetic disabled fixture', 'public', false);
insert into public.bil07_channel_memberships_v1(channel_id, owner_id, status)
select '10000000-0000-4000-8000-000000000001', id,
  case when id = '44444444-4444-4444-8444-444444444444' then 'banned' else 'active' end
from auth.users where id <> '33333333-3333-4333-8333-333333333333';
insert into public.bil07_channel_memberships_v1(channel_id, owner_id, status)
values
  ('10000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'active'),
  ('10000000-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', 'active'),
  ('10000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'active'),
  ('10000000-0000-4000-8000-000000000004', '22222222-2222-4222-8222-222222222222', 'active'),
  ('10000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', 'active');
