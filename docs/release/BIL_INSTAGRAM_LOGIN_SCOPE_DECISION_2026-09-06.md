# Instagram login scope decision — 2026-09-06

## Owner request and outcome

The request is conditional: add Instagram login **if the official route supports
the app's intended users**. BIL is a general consumer health application, not an
Instagram professional-account management product.

**Do not offer a general-consumer “Continue with Instagram” button in this
release.** This is a feasibility decision, not a claim that Instagram login was
implemented, enabled in Meta, or tested. Facebook login is a separate integration
and is not disabled by this decision.

## Primary-source evidence checked on 2026-09-06

- Meta's own Instagram API collection describes Instagram Login for business
  and creator accounts to manage their Instagram presence. Its Facebook Login
  variant explicitly excludes ordinary consumer Instagram accounts.
  [Meta Instagram API documentation](https://www.postman.com/meta/instagram/documentation/6yqw8pt/instagram-api)
- Supabase lists Facebook, Google and Apple among its built-in social providers,
  but not Instagram. It also supports compatible custom OAuth/OIDC providers.
  [Supabase social login documentation](https://supabase.com/docs/guides/auth/social-login)

Inference for BIL: a custom OAuth adapter does not expand Meta's supported
account audience or turn a professional-management permission grant into a
universal consumer identity product. We have not established a supported route
covering ordinary Instagram users for the requested general BIL login.

This does **not** claim that no professional-account integration is ever possible.
Such a feature would need a separately defined use case, eligibility disclosure,
Meta permissions/review, account-linking semantics, token custody and deletion
handling. It must not be silently substituted for the consumer-login request.

## Current source checks

- `lib/features/auth/premium_login_page.dart` offers Google, Apple and guarded
  Facebook provider buttons, not an Instagram button.
- `lib/features/auth/supabase_auth_service.dart` has no fabricated Instagram
  login method or provider mapping.
- Instagram references in Share Studio describe the **system share sheet**;
  they are not authentication claims and are not removed by this decision.
- No Instagram secret, OAuth callback, provider or permission was added; no
  account was created and no external configuration was changed.

## Gate interpretation

The conditional feasibility question is resolved for this release's audience;
there is no implemented Instagram provider to certify. Do not label this as a
successful Instagram login. The Facebook configuration/return-path, user
authorization and release gates remain independent and must still be satisfied
before any build or publication.
