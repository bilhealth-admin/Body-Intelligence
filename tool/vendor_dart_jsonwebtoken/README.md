# BIL fail-closed JWT compatibility shim

This local package exposes only the API surface required by the pinned
Supabase Auth dependency. BIL does not call Supabase's optional local
`getClaims()` verification path. `JWT.verify()` therefore throws and
`JWT.tryVerify()` returns `null`; no local signature algorithm is bundled.

Authentication and session refresh continue through Supabase's server-verified
Auth APIs. If BIL ever needs local JWT verification, this shim must not be
expanded with a Dart cryptographic implementation; use an audited operating-
system bridge and add native integration coverage first.
