begin;

-- Community images are private objects. Feed clients receive short-lived
-- signed URLs after the existing post RLS proves that the post is visible.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'community-post-images',
  'community-post-images',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

alter table public.bil_community_posts
  add column if not exists media_object_path text,
  add column if not exists media_mime_type text,
  add column if not exists media_bytes integer,
  add column if not exists media_width integer,
  add column if not exists media_height integer;

alter table public.bil_community_posts
  drop constraint if exists bil_community_posts_media_all_or_none,
  drop constraint if exists bil_community_posts_media_mime,
  drop constraint if exists bil_community_posts_media_size,
  drop constraint if exists bil_community_posts_media_dimensions,
  drop constraint if exists bil_community_posts_media_owned_path;

alter table public.bil_community_posts
  add constraint bil_community_posts_media_all_or_none check (
    (media_object_path is null
      and media_mime_type is null
      and media_bytes is null
      and media_width is null
      and media_height is null)
    or
    (media_object_path is not null
      and media_mime_type is not null
      and media_bytes is not null
      and media_width is not null
      and media_height is not null)
  ),
  add constraint bil_community_posts_media_mime check (
    media_mime_type is null
    or media_mime_type in ('image/jpeg', 'image/png', 'image/webp')
  ),
  add constraint bil_community_posts_media_size check (
    media_bytes is null or media_bytes between 1 and 5242880
  ),
  add constraint bil_community_posts_media_dimensions check (
    media_width is null
    or (
      media_width between 1 and 8192
      and media_height between 1 and 8192
      and media_width::bigint * media_height::bigint <= 40000000
    )
  ),
  add constraint bil_community_posts_media_owned_path check (
    media_object_path is null
    or (
      split_part(media_object_path, '/', 1) = author_id::text
      and split_part(media_object_path, '/', 2) = id::text
      and media_object_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
    )
  );

comment on column public.bil_community_posts.media_object_path is
  'Private community-post-images object path: author UUID/post UUID/random UUID.ext';
comment on column public.bil_community_posts.media_mime_type is
  'Validated image/jpeg, image/png, or image/webp media type';

drop policy if exists community_post_image_insert_own on storage.objects;
drop policy if exists community_post_image_update_own on storage.objects;
drop policy if exists community_post_image_delete_own on storage.objects;
drop policy if exists community_post_image_read_visible on storage.objects;

create policy community_post_image_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'community-post-images'
  and owner_id = (select auth.uid()::text)
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
  and storage.extension(name) in ('jpg', 'png', 'webp')
);

-- No UPDATE policy is created. Image objects are immutable: retries use a new
-- random UUID path and `upsert: false`, preventing silent content replacement.

create policy community_post_image_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'community-post-images'
  and owner_id = (select auth.uid()::text)
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

-- SELECT is intentionally limited to object signing/authenticated reads. It
-- never authorizes object.list/list_v2, so clients cannot enumerate the bucket.
-- The nested post query is filtered by bil_community_posts RLS and therefore
-- inherits blocks, friendship visibility, and soft-delete rules.
create policy community_post_image_read_visible
on storage.objects
for select
to authenticated
using (
  bucket_id = 'community-post-images'
  and storage.allow_any_operation(array[
    'storage.object.sign',
    'storage.object.sign_many',
    'storage.object.get_authenticated',
    'object.get_authenticated_info',
    'storage.render.image_authenticated'
  ])
  and (
    owner_id = (select auth.uid()::text)
    or exists (
      select 1
      from public.bil_community_posts post
      where post.media_object_path = storage.objects.name
    )
  )
);

commit;

;
