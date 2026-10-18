-- Synthetic PG17 fixture. No BIL Production accounts/rows used.
CREATE ROLE service_role NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE anon NOLOGIN;
CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE
AS $$ SELECT jsonb_build_object('role', current_setting('app.test_role',true)) $$;
CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,deleted_at timestamptz);
CREATE TABLE private.bil_ai_coach_admins(user_id uuid PRIMARY KEY,active boolean NOT NULL DEFAULT false);
CREATE TABLE private.bil_ai_coach_safety_reports_v1(report_id uuid PRIMARY KEY,owner_id uuid,status text,reviewed_at timestamptz);
CREATE TABLE public.bil_community_reports(id uuid PRIMARY KEY,reporter_id uuid,status text);
CREATE TABLE public.bil_community_posts(id uuid PRIMARY KEY,author_id uuid,moderation_status text,deleted_at timestamptz);
INSERT INTO private.bil_ai_coach_admins VALUES
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',true),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',false);
INSERT INTO auth.users VALUES
('11111111-1111-4111-8111-111111111111','safety.reporter@example.invalid',NULL),
('22222222-2222-4222-8222-222222222222','community.reporter@example.invalid',NULL),
('33333333-3333-4333-8333-333333333333','post.author@example.invalid',NULL),
('44444444-4444-4444-8444-444444444444','deleted@example.invalid',now());
INSERT INTO private.bil_ai_coach_safety_reports_v1 VALUES
('aaa00000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111','open',NULL),
('aaa00000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111','closed',now()-interval '40 days'),
('aaa00000-0000-4000-8000-000000000003','44444444-4444-4444-8444-444444444444','open',NULL);
INSERT INTO public.bil_community_reports VALUES
('bbb00000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','open'),
('bbb00000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222','closed');
INSERT INTO public.bil_community_posts VALUES
('ccc00000-0000-4000-8000-000000000001','33333333-3333-4333-8333-333333333333','pending',NULL),
('ccc00000-0000-4000-8000-000000000002','33333333-3333-4333-8333-333333333333','approved',NULL);
