"""R4: integrate automatic visible receipts into the exact green QA source."""
from pathlib import Path
import os
import subprocess

BASE = '8f42b54027580dcaab8a0e702c5a174e8145d15a'
if os.environ.get('GITHUB_REF') != 'refs/heads/qa/coach-community-next-20261005':
    raise RuntimeError('QA branch only')
subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, 'HEAD'], check=True)
changed = []
def edit(name, old, new, count=1):
    p = Path(name)
    text = p.read_text()
    if text.count(old) != count:
        raise RuntimeError('Source drift: ' + name + ': ' + repr(old[:90]))
    p.write_text(text.replace(old, new))
    changed.append(name)

p = 'lib/features/community/presentation/community_notifications_page.dart'
edit(p, "import 'community_attention_scope.dart';", "import 'dart:async';\n\nimport 'community_attention_scope.dart';\nimport 'community_visible_activity_scope.dart';")
edit(p, "part 'community_notifications_rendering.dart';", "part 'community_notifications_rendering.dart';\npart 'community_notification_read_receipts.dart';")
edit(p, '  String? _beforeId;\n', '''  String? _beforeId;
  final _activityReadWindows = <_ActivityReadWindow>[];
  StreamSubscription<AuthState>? _receiptAuth;
  String? _loadedOwnerId;
  String? _receiptSessionOwner;
  bool _receiptSignedOut = false;
  bool _visibleReadBusy = false;
  Object? _visibleReadOperation;

  void _updateReceiptState(VoidCallback update) => setState(update);

  @override
  void didUpdateWidget(covariant CommunityNotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _repository = widget.repository ?? _productionRepository();
      _loadedOwnerId = null;
      _receiptSignedOut = false;
      _bindReceiptSession();
      _updates = _load();
    }
  }
''')
edit(p, '''    _repository = widget.repository ?? _productionRepository();
    _updates = _load();''', '''    _repository = widget.repository ?? _productionRepository();
    _bindReceiptSession();
    _updates = _load();''')
edit(p, '    if (mounted) _retry();\n  }\n\n  @override\n  void dispose()', '    if (mounted && !_visibleReadBusy) _retry();\n  }\n\n  @override\n  void dispose()')
edit(p, '''  void dispose() {
    _attentionController?.removeListener(_onAttentionChanged);''', '''  void dispose() {
    unawaited(_receiptAuth?.cancel());
    _loadGeneration++;
    _attentionController?.removeListener(_onAttentionChanged);''')
edit(p, '''    final repository = _repository;
    try {
      if (repository == null) return const _CommunityUpdates.signedOut();''', '''    final repository = _repository;
    final owner = _receiptOwner(repository);
    _loadedOwnerId = null;
    _activityReadWindows.clear();
    try {
      if (repository == null || _receiptSignedOut) {
        return const _CommunityUpdates.signedOut();
      }''')
edit(p, '''      if (mounted && generation == _loadGeneration) {
        _setCursor(notifications);
      }''', '''      if (mounted && generation == _loadGeneration) {
        if (!identical(repository, _repository) ||
            (owner != null && _receiptOwner(repository) != owner)) {
          return const _CommunityUpdates.signedOut();
        }
        _loadedOwnerId = owner;
        _activityReadWindows.add(_ActivityReadWindow(
          ids: notifications.map((row) => row.id).toSet(),
        ));
        _setCursor(notifications);
      }''')
edit(p, '''    final generation = _loadGeneration;
    setState(() => _loadingMore = true);''', '''    final generation = _loadGeneration;
    final owner = _loadedOwnerId;
    final requestedBefore = _before;
    final requestedBeforeId = _beforeId;
    setState(() => _loadingMore = true);''')
edit(p, '''        before: _before,
        beforeId: _beforeId,''', '''        before: requestedBefore,
        beforeId: requestedBeforeId,''')
edit(p, '''      final known = visible.notifications.map((item) => item.id).toSet();''', '''      if (owner != null && _receiptOwner(repository) != owner) return;
      final known = visible.notifications.map((item) => item.id).toSet();
      _activityReadWindows.add(_ActivityReadWindow(
        ids: page.map((row) => row.id).toSet(),
        before: requestedBefore,
        beforeId: requestedBeforeId,
      ));''')
p = 'lib/features/community/presentation/community_notification_read_receipts.dart'
edit(p, '''        _receiptSessionOwner = owner;
        _loadedOwnerId = null;''', '''        _receiptSessionOwner = owner;
        _receiptSignedOut = owner == null;
        _loadedOwnerId = null;''')
p = 'lib/features/community/presentation/community_notifications_rendering.dart'
edit(p, '''        return ListView(
          padding:''', '''        return CommunityVisibleActivityScope(
          key: ValueKey('community-visible-read-$_loadedOwnerId-${_filter.name}'),
          ownerId: _loadedOwnerId ?? '',
          unreadIds: {
            for (final row in filteredNotifications)
              if (!row.seen) row.id,
          },
          enabled: !_loadingFirst && !_loadingMore && !_markingPageSeen,
          retryKey: _loadGeneration,
          onSeen: (ids) => _markVisibleActivityRead(persisted, ids),
          builder: (context, marker) => ListView(
          key: const PageStorageKey('community-activity-list'),
          padding:''')
edit(p, '''              Card(
                color: notification.seen''', '''              Card(
                key: marker(notification.id),
                color: notification.seen''')
edit(p, '''          ],
        );
      },
    ),''', '''          ],
          ),
        );
      },
    ),''')
changed += [
    'lib/features/community/presentation/community_visible_activity_scope.dart',
    'lib/features/community/presentation/community_notification_read_receipts.dart',
    'test/features/community/community_visible_activity_scope_test.dart',
    'test/features/community/community_activity_auto_read_test.dart',
]
subprocess.run(['dart', 'format', *dict.fromkeys(changed)], check=True)
print('R4 source materialized; commit before testing. No production changes.')
