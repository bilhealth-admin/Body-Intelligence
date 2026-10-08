# BIL-08 Home & Profile implementation contract

Base: `1744788e6bfbdffc3a168bbaf36b3abf3e2c698a`.

## Profile data surfaces

- **Posts**: existing authorized `loadProfilePosts` read, with list/grid presentation and owner moderation-status filter preserved.
- **Media**: a dedicated projection over every actual `CommunityPost.mediaItems` item from authorized profile posts. Grid mode on Posts is not treated as Media.
- **Replies**: `bil_community_profile_replies_v1`; visible only when the target profile/posts are visible to the viewer. Deleted/removed comments, orphaned replies whose root is deleted/removed, blocked members, and unavailable source posts are excluded. Paging is `(created_at,id)` descending.
- **Likes**: strictly self-only. The UI never calls the Likes data source for another profile, the Dart data source rejects that request, and `bil_community_profile_likes_v1` independently rejects it server-side. Paging is `(liked_at,post_id)` descending.

The client still performs post readback through the authorized post store before rendering Reply/Like source posts, so an RPC reference cannot resurrect a post that is no longer readable.

## Owner and visit lifetime

Home captures repository + owner + monotonically invalidated visit epoch. Every delivered owner change invalidates the epoch, including queued `A -> B -> A`; returning to A creates a new visit and cannot reactivate callbacks from the first A visit.

Feed captures that Home predicate plus its own repository/owner. Reads, pagination, composer, post actions, profile/topic navigation, cards, detail, likes/saves and polls inherit the captured visit. The shared reference header requires the integration proposal so direct story/AI navigation also checks the same visit.

Profile continues using its existing permanent binding generation and target/repository/owner capture. New Replies/Likes reads run through that exact visit and their own per-tab generation.

## Preserved boundaries

- `community_member_profile_drafts.dart` is not modified.
- Drafts and Saved remain separate routes and stores.
- Existing photo/cover/privacy/R5 handling is unchanged.
- No production SQL, GitHub write, CI rerun, store build, pricing, Trial, version-code, or build-number mutation is performed by BIL-08.
