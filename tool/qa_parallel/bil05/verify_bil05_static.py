from __future__ import annotations
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
PACKAGE = ROOT
owned = PACKAGE / 'owned.patch'
sql = PACKAGE / 'tool/qa_parallel/bil05/sql/bil05_activity_reward_receipts_v1.sql'
receipt = PACKAGE / 'lib/features/community/activity_rewards/community_post_moderation_receipt.dart'
visit = PACKAGE / 'lib/features/community/activity_rewards/community_moderation_visit.dart'
loader = PACKAGE / 'lib/features/community/activity_rewards/community_moderation_content_loader.dart'
page = PACKAGE / 'lib/features/community/activity_rewards/community_post_receipt_page.dart'
proposal = PACKAGE / 'integration-proposal.patch'

failures=[]
def require(ok,msg):
    if not ok: failures.append(msg)

for path in (sql, receipt, visit, loader, page, proposal):
    require(path.exists(), f'missing {path.relative_to(PACKAGE)}')

s = sql.read_text() if sql.exists() else ''
require('bil_emit_post_moderation_author_receipt_v1' in s, 'missing author receipt emitter')
require("'post_approved_ai_tokens_v1'" in s, 'missing +5 approval copy key')
require("'post_approved_no_ai_tokens_v1'" in s, 'missing no-grant approval copy key')
require("'post_rejected_v1'" in s, 'missing rejection copy key')
require("on conflict (source_key) do nothing" in s.lower(), 'receipt idempotency boundary missing')
require('bil_community_moderation_polls_v1' in s, 'moderator poll projection missing')
require(not re.search(r'\b(insert\s+into|update)\s+public\.bil_ai_credit_balances\b', s, re.I),
        'BIL-05 SQL must not mutate AI credit balances')
require(not re.search(r'\b(insert\s+into|update)\s+public\.bil_community_post_approval_grants\b', s, re.I),
        'BIL-05 SQL must not create approval grants')
require('vote_count\', 0' in s and "'selected', false" in s,
        'moderation poll projection must not expose vote identity/state')

r = receipt.read_text() if receipt.exists() else ''
require("rewardReason == 'granted'" in r, 'client +5 claim is not tied to granted receipt')
require("String get route => '/community/post/$postId'" in r, 'post receipt destination missing')

v = visit.read_text() if visit.exists() else ''
require('changed || _readOwner(repository) != ownerId' in v, 'A-B-A delivered owner retirement missing')
require('invalidateCommunityModeratorStatus' in v and 'isCommunityModerator' in v,
        'fresh moderator revalidation missing')
require('runForCommunityOwner' in v, 'owner-scoped moderation operation missing')

l = loader.read_text() if loader.exists() else ''
require('bil_community_post_media_v1' in l, 'moderation multi-image hydration missing')
require('bil_community_moderation_polls_v1' in l, 'moderation poll hydration missing')
require("error.code == 'PGRST202'" in l, 'missing-RPC fail-soft boundary missing')

p = page.read_text() if page.exists() else ''
require('CommunityPostLookupContract' in p, 'owner post lookup missing')
require("mediaItems.take(4)" in p, 'receipt page does not cap/display four images')
require('runForCommunityOwner' in p, 'receipt destination owner guard missing')

q = proposal.read_text() if proposal.exists() else ''
require("path: '/community/post/:postId'" in q, 'shared receipt route proposal missing')

if owned.exists():
    o=owned.read_text()
    changed=[]
    for m in re.finditer(r'^diff --git a/(\S+) b/(\S+)$',o,re.M):
        changed.append(m.group(2))
    allowed_existing={
      'lib/features/community/presentation/community_notifications_page.dart',
      'lib/features/community/presentation/community_notification_read_receipts.dart',
      'lib/features/community/presentation/community_notifications_reference_widgets.dart',
      'lib/features/community/presentation/community_ai_reward_notice.dart',
      'lib/features/community/presentation/community_post_moderation_page.dart',
    }
    for path in changed:
        ok=(path in allowed_existing or
            path.startswith('lib/features/community/activity_rewards/') or
            path.startswith('test/parallel/bil05/') or
            path.startswith('docs/qa_parallel/bil05/') or
            path.startswith('tool/qa_parallel/bil05/'))
        require(ok,f'owned.patch escapes role ownership: {path}')
    require(not any(path.startswith('lib/app/router/') for path in changed), 'shared router leaked into owned.patch')
    require('_attentionRefreshQueued = true' in o and '_drainQueuedAttentionRefresh' in o,
            'acknowledgement-time notification queue fix missing')
    require('final headRows = await repository.loadCommunityNotifications' in o and '...arrivals' in o,
            'same-count notification arrival reconciliation missing')
    require('final headRows = await repository.loadCommunityNotifications' in o and '...arrivals' in o,
            'same-count notification arrival reconciliation missing')
    require('mediaItems.take(4)' in o, 'moderation four-image UI missing')
    require('_ModerationPollPreview' in o, 'moderation poll preview missing')

if failures:
    print('FAIL')
    for f in failures: print(' -',f)
    sys.exit(1)
print('PASS: BIL-05 static ownership/reward/receipt contracts')
