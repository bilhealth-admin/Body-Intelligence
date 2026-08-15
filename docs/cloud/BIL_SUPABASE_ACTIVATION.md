# BIL Supabase activation

The Flutter client receives only the public project URL and publishable key via
`--dart-define`. Database passwords, secret keys, and service-role keys never
belong in the application or source repository.

The foundation migration creates an authenticated owner-isolated cloud
envelope store. Row Level Security requires `auth.uid() = owner_id` for every
read and write. Anonymous clients receive no table privileges.

Apply migrations in order from `supabase/migrations`, then verify that RLS is
enabled before activating `BIL_USE_SUPABASE` in a build.
# Authentication delivery modes

BIL keeps email confirmation honest across development and production:

- Default builds use Supabase's confirmation link. No custom SMTP account is
  required and the app never asks for a code that the current template cannot
  deliver.
- Branded six-digit email confirmation is enabled only with
  `--dart-define=BIL_EMAIL_OTP_ENABLED=true`, after custom SMTP is configured
  and the hosted `Confirm sign up` template contains `{{ .Token }}`.
- A phone number collected during registration is account metadata only. It
  must never be described as verified until Supabase Phone Auth and a real SMS
  provider are configured and an OTP challenge succeeds.

Before enabling email OTP in a release, verify custom sender-domain DNS, SMTP
delivery, Arabic/English templates, resend rate limits, expiry behavior, and
the in-app verification screen. Before enabling phone verification, verify the
SMS provider, E.164 normalization, country availability, abuse protection,
rate limits, consent copy, and real-device delivery.
