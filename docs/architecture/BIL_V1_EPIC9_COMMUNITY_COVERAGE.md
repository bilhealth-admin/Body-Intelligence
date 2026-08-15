# BIL v1 Epic 9 — Community and cloud closure

Epic 9 closes the authenticated community, friends, and messaging loop without
inventing members, conversations, or engagement.

## Closed in code

- Localized public profile editing with discoverability control.
- Authenticated people search and friend requests.
- Incoming/outgoing request handling, removal, and atomic blocking.
- Attributed community posts with author delete and member report actions.
- Direct conversations with retry, draft preservation, timestamps, and read
  receipts.
- Five-language copy across the release community surfaces.
- Server-side RPC/RLS boundaries for read receipts, blocking, friendship
  revocation, and participant-specific message soft deletion.
- Honest empty, loading, offline/network failure, and authentication states.

## Existing trusted boundary retained

Community food submissions and peer/moderator verification remain the Epic 5
trust workflow. Epic 9 does not duplicate or weaken that workflow.

## External release dependency

Production behavior still requires applying the Supabase migrations, valid
authenticated users, and network access. No fake social content is bundled.
