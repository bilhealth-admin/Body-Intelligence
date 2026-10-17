-- Explicit CI-only identities and rooms; migrations themselves create none.
insert into auth.users(id) values
 ('35000000-0000-4000-8000-000000000001'),
 ('35000000-0000-4000-8000-000000000002'),
 ('35000000-0000-4000-8000-000000000003');
insert into public.bil_public_profiles(user_id,display_name) values
 ('35000000-0000-4000-8000-000000000001','Fixture Sender'),
 ('35000000-0000-4000-8000-000000000002','Fixture Reader'),
 ('35000000-0000-4000-8000-000000000003','Fixture Moderator');
insert into public.bil07_channels_v1(id,slug,title,description,visibility,enabled)
values
 ('35000000-0000-4000-8000-000000000010','general-fixture','Test Public Room','','public',true),
 ('35000000-0000-4000-8000-000000000011','private-fixture','Test Members Room','','members',true);
insert into public.bil07_channel_memberships_v1(channel_id,owner_id,status)
values ('35000000-0000-4000-8000-000000000011','35000000-0000-4000-8000-000000000002','active');
insert into public.bil_community_moderators(user_id)
values ('35000000-0000-4000-8000-000000000003');
