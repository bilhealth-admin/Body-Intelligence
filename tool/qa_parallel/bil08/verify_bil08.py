from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
owned = (ROOT / 'owned.patch').read_text()
integration = (ROOT / 'integration-proposal.patch').read_text()
profile = (ROOT / 'lib/features/community/home_profile/community_profile_activity_slivers.dart').read_text()
data = (ROOT / 'lib/features/community/home_profile/community_profile_activity_repository.dart').read_text()
home = (ROOT / 'lib/features/community/home_profile/community_home_owner_scope.dart').read_text()
feed_scope = (ROOT / 'lib/features/community/home_profile/community_feed_owner_scope.dart').read_text()
sql = (ROOT / 'tool/qa_parallel/bil08/sql/20261007_bil08_community_profile_activity_v1.sql').read_text()

checks = []

def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f'MISSING {needle!r} in {label}')
    checks.append(f'OK {label}: {needle}')

for key in (
    'community-profile-tab-posts',
    'community-profile-tab-replies',
    'community-profile-tab-media',
    'community-profile-tab-likes',
):
    require(profile, key, 'profile activity slivers')
require(profile, 'for (final media in post.mediaItems)', 'profile activity slivers')
require(profile, 'community-profile-replies-page-retry', 'profile activity slivers')
require(profile, 'community-profile-likes-private', 'profile activity slivers')
require(data, "'bil_community_profile_replies_v1'", 'profile activity repository')
require(data, "'bil_community_profile_likes_v1'", 'profile activity repository')
require(data, 'loadPostsByIds(postIds)', 'profile activity repository')
require(data, 'if (userId != repository.currentUserId)', 'profile activity repository')
require(home, 'epoch != _homeVisitEpoch', 'home owner scope')
require(home, '_deliveredOwnerId', 'home owner scope')
require(feed_scope, 'parentVisit?.call() ?? true', 'feed owner scope')
require(sql, 'bil_social_profile_visible_v2(p_user_id)', 'local SQL proposal')
require(sql, "raise exception 'community_profile_likes_private'", 'local SQL proposal')
require(sql, 'comment.deleted_at is null', 'local SQL proposal')
require(sql, 'root.removed_at is null', 'local SQL proposal')

# Existing owned-file edits are represented by patch additions in this artifact.
plus = '\n'.join(
    line[1:]
    for line in owned.splitlines()
    if line.startswith('+') and not line.startswith('+++')
)
require(plus, 'ownerIsCurrent: visit.isCurrent', 'owned.patch additions')
require(plus, 'ownerChanges: visit.changes', 'owned.patch additions')
require(plus, '_profilePrimaryContentSlivers(profile)', 'owned.patch additions')
require(plus, '_profileActivity.reset()', 'owned.patch additions')
require(plus, 'await visit.run(() async {', 'owned.patch additions')
feed_section = owned.split(
    'diff --git a/lib/features/community/presentation/community_feed_tab.dart ', 1
)[1].split('diff --git ', 1)[0]
feed_plus = '\n'.join(
    line[1:]
    for line in feed_section.splitlines()
    if line.startswith('+') and not line.startswith('+++')
)
if 'setState(() => _feed = refreshedFeed)' in feed_plus:
    raise SystemExit('Future-return setState regression reintroduced in Feed additions')
checks.append('OK owned.patch: Feed Future-return setState regression absent')

# Shared wiring is intentionally separate from owned.patch.
require(integration, 'ownerIsCurrent', 'integration-proposal.patch')
require(integration, 'bil_community_profile_replies_v1', 'integration-proposal.patch')
changed = re.findall(r'^diff --git a/(\S+) b/', owned, flags=re.M)
if any(path.startswith('supabase/migrations/') for path in changed):
    raise SystemExit('Shared Supabase migration leaked into owned.patch')
checks.append('OK owned.patch: no shared Supabase migration path')

for forbidden in (
    'lib/features/community/presentation/community_member_profile_drafts.dart',
    'lib/features/community/data/community_repository.dart',
    'lib/features/community/presentation/community_post_card.dart',
):
    if forbidden in changed:
        raise SystemExit(f'Forbidden shared file in owned.patch: {forbidden}')
checks.append('OK owned.patch: Drafts/root repository/post card remain untouched')

print('\n'.join(checks))
