"""R4b: fix observed read-receipt regressions without changing assertions."""
from pathlib import Path
import os
import subprocess

BASE = 'a00898a88f5a98386fa918af10425f4bf15d8dc3'
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
edit(p, '  Object? _visibleReadOperation;', '''  Object? _visibleReadOperation;
  // A failed explicit action waits for the user's explicit retry. The automatic
  // dwell must not silently issue another write behind the error snackbar.
  final _manualReceiptIds = <String>{};''')
edit(p, '''    final generation = ++_loadGeneration;
    _loadingFirst = true;''', '''    final generation = ++_loadGeneration;
    _visibleReadOperation = null;
    _visibleReadBusy = false;
    _manualReceiptIds.clear();
    _loadingFirst = true;''')
edit(p, '''      _markingPageSeen = true;
      _markingSeen.addAll(ids);''', '''      _markingPageSeen = true;
      _manualReceiptIds.addAll(ids);
      _markingSeen.addAll(ids);''')
edit(p, '''    if (repository == null || !_markingSeen.add(notification.id)) return;
    try {''', '''    if (repository == null || !_markingSeen.add(notification.id)) return;
    setState(() => _manualReceiptIds.add(notification.id));
    try {''')
p = 'lib/features/community/presentation/community_notification_read_receipts.dart'
edit(p, '''        .where((row) => !row.seen && !_markingSeen.contains(row.id))''', '''        .where((row) => !row.seen &&
            !_markingSeen.contains(row.id) &&
            !_manualReceiptIds.contains(row.id))''')
edit(p, '''      _updateReceiptState(() => _updates = Future.value(readback));
      await CommunityAttentionScope.refresh(context);''', '''      _updateReceiptState(() => _updates = Future.value(readback));
      if (!mounted) return {};
      await CommunityAttentionScope.refresh(context);''')
p = 'lib/features/community/presentation/community_notifications_rendering.dart'
edit(p, '              if (!row.seen) row.id,', '              if (!row.seen && !_manualReceiptIds.contains(row.id)) row.id,')

# Bounded fixture-only milestones locate the previously opaque first-test hang.
# No existing expectations or production timing are weakened.
p = 'test/features/community/community_activity_auto_read_test.dart'
edit(p, '  addTearDown(repository.communitySocialClient.dispose);', '''  addTearDown(() async {
    debugPrint('R4 trace: client dispose begins');
    await repository.communitySocialClient.dispose();
    debugPrint('R4 trace: client dispose ends');
  });''')
edit(p, '  await tester.pumpWidget(\n    MaterialApp.router(', "  debugPrint('R4 trace: mount begins');\n  await tester.pumpWidget(\n    MaterialApp.router(")
edit(p, '''  await tester.pumpAndSettle();
  return selected;''', '''  debugPrint('R4 trace: first frame complete');
  await tester.pumpAndSettle();
  debugPrint('R4 trace: mount settled');
  return selected;''')
edit(p, '''Future<void> _dwell(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pumpAndSettle();
}''', '''Future<void> _dwell(WidgetTester tester) async {
  debugPrint('R4 trace: dwell begins');
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 20));
  debugPrint('R4 trace: dwell elapsed');
  await tester.pumpAndSettle();
  debugPrint('R4 trace: dwell settled');
}''')
edit(p, '''          repository.count - repository.seen.length,
        );
        expect(tester.takeException(), isNull);''', '''          repository.count - repository.seen.length,
        );
        expect(tester.takeException(), isNull);
        debugPrint('R4 trace: initial assertions complete');''')
subprocess.run(['dart', 'format', *dict.fromkeys(changed)], check=True)
print('R4b repairs applied. No source assertions deleted; trace is test-only.')
