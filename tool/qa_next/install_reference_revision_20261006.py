"""Materialize the isolated reference revision once; never connect to production.

Inputs are immutable committed code and readable, bounded transformations.
Every replacement aborts on source drift. All resulting Dart files are committed
by the branch-scoped review workflow, then tested as that exact source revision.
"""
from pathlib import Path
import os
import subprocess

BASE = 'cdd6f747611515ef8c116c2327d22649e07ab249'
BRANCH = 'refs/heads/qa/coach-community-next-20261005'
if os.environ.get('GITHUB_REF') != BRANCH:
    raise RuntimeError('Only the isolated QA branch is allowed')
subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, 'HEAD'], check=True)
r = Path('.')

def edit(path, old, new, count=1):
    p = r / path
    source = p.read_text()
    if source.count(old) != count:
        raise RuntimeError('Source drift in ' + path + ': ' + repr(old[:70]))
    p.write_text(source.replace(old, new))

# Replay the already-reviewed visual patch from its immutable source. The hub
# was subsequently updated independently, so its obsolete replacement is omitted.
original = subprocess.check_output(['git', 'show', BASE + ':tool/qa_next/apply_reference_visual_candidate.py'], text=True)
a = original.index("p='lib/features/community/presentation/community_hub_page.dart'")
b = original.index("p='lib/features/community/presentation/community_post_card.dart'", a)
original = original[:a] + original[b:]
if Path('docs/qa_next/REFERENCE_CANDIDATE_APPLIED.json').exists():
    raise RuntimeError('Revision already materialized; do not replay')
exec(compile(original, '<immutable-reference-patch>', 'exec'), {'__name__': '__main__'})

edit('lib/features/community/presentation/community_feed_reference_header.dart', 'height: 83,', 'height: 94 + (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 36),')
edit('lib/features/community/presentation/community_feed_reference_header.dart', 'height: 45,', 'height: 48 + (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, 36),')
p = 'lib/features/community/presentation/community_feed_tab.dart'
edit(p, '''                  slivers: [
                    SliverToBoxAdapter(''', '''                  slivers: [
                    SliverToBoxAdapter(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: PopupMenuButton<CommunityFeedMode>(
                          key: const Key('community-feed-mode-menu'),
                          tooltip: _feedModeLabel(_selectedFeedMode),
                          onSelected: _selectFeedMode,
                          itemBuilder: (_) => [
                            for (final mode in CommunityFeedMode.values)
                              PopupMenuItem<CommunityFeedMode>(
                                key: Key('community-feed-mode-${mode.wireValue}'),
                                value: mode,
                                child: Text(_feedModeLabel(mode)),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(_feedModeLabel(_selectedFeedMode), style: Theme.of(context).textTheme.labelSmall),
                              const Icon(Icons.expand_more_rounded, size: 18),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(''')
edit(p, '                    if (loading && snapshot.hasData)', '''                    if (!loading && posts.isEmpty && _selectedFeedMode == CommunityFeedMode.explore)
                      SliverToBoxAdapter(child: _CommunityFeedTopicSuggestions(topics: _suggestedTopics, onOpen: _openTopic)),
                    if (loading && snapshot.hasData)''')
p = 'lib/features/community/presentation/community_hub_page.dart'
edit(p, '        automaticallyImplyLeading: false,', '        leading: const CommunityReturnButton(),\n        leadingWidth: 48,')
edit(p, "          communityText(context, 'BIL Community', 'مجتمع BIL'),", "          communityText(context, 'BIL Community', 'مجتمع BIL'),\n          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),")
edit('tool/prebuild/run_code_tests.py', 'NOT_RUN = {', 'NOT_RUN = {\n    "test/qa_next/coach_reference_workspace_capture_test.dart": "dedicated native Coach capture job executes these cases; excluded only from code-only partition",')
p = 'test/qa_next/coach_reference_workspace_capture_test.dart'
for item in ['photo', 'voice', 'scan']:
    edit(p, f'await tester.ensureVisible({item});\n        await tester.tap({item});', f'await tester.ensureVisible({item});\n        await tester.pumpAndSettle();\n        expect({item}.hitTestable(), findsOneWidget);\n        await tester.tap({item});')
p = 'test/features/community/community_polish_visual_test.dart'
edit(p, "const PageStorageKey('community-feed-scroll-for_you')", "const PageStorageKey('community-feed-scroll-explore')")
edit(p, '''                await tester.tap(
                  find.byKey(const Key('community-create-post')),
                );''', '''                final composer = find.byKey(const Key('community-create-post'));
                await tester.scrollUntilVisible(
                  composer, -220,
                  scrollable: find.descendant(
                    of: find.byKey(const PageStorageKey('community-feed-scroll-explore')),
                    matching: find.byType(Scrollable),
                  ).first,
                );
                await tester.pumpAndSettle();
                expect(composer.hitTestable(), findsOneWidget);
                await tester.tap(composer);''')
Path('tool/qa_next/apply_reference_visual_candidate.py').write_text('''"""Verify tracked reference presentation; never transform source during tests."""
from pathlib import Path
required = {
    'lib/features/intelligence_center/presentation/intelligence_center_page.dart': '_buildReferenceChat',
    'lib/features/community/presentation/community_hub_page.dart': 'BilReferenceBottomBar',
    'lib/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart': 'CoachReferenceWorkspace',
}
for name, marker in required.items():
    if marker not in Path(name).read_text():
        raise RuntimeError('Reference presentation missing: ' + name)
print('Reference presentation is tracked source. No transformations performed.')
''')
p = Path('lib/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart')
s = p.read_text()
a = s.index('class _DarkCard extends StatelessWidget {')
components, s = s[a:], s[:a]
s = s.replace("import '../../domain/coach_context_snapshot.dart';", "import '../../domain/coach_context_snapshot.dart';\nimport '../../intelligence_locale_copy.dart';\n\npart 'coach_reference_workspace_components.dart';")
s = s.replace('String t(String en, String arabic) => ar ? arabic : en;', 'String t(String en, String arabic) => intelligenceText(context, en, arabic);')
s = s.replace('''          n <= 0)
        return 0;''', '''          n <= 0) {
        return 0;
      }''')
s = s.replace("'${today.meals.length} meal entries in your actual log',\n                          '${today.meals.length} وجبات في سجلك الفعلي',", "'{count} meal entries in your actual log',\n                          '{count} وجبات في سجلك الفعلي',")
s = s.replace("'{count} وجبات في سجلك الفعلي',\n                        ),", "'{count} وجبات في سجلك الفعلي',\n                        ).replaceAll('{count}', today.meals.length.toString()),")
s = s.replace('_water(snapshot!.waterHistory.last)', "_water(_latestMap(snapshot!.waterHistory, 'at'))")
s = s.replace('_steps(snapshot!.activityHistory.last, ar)', "_steps(_latestMap(snapshot!.activityHistory, 'day'), ar)")
s = s.replace('  String _water(Map<String, Object?> row) {', '''  Map<String, Object?> _latestMap(List<Map<String, Object?>> rows, String timeKey) {
    Map<String, Object?>? result;
    DateTime? latest;
    for (final row in rows) {
      final at = DateTime.tryParse(row[timeKey]?.toString() ?? '');
      if (at != null && (latest == null || at.isAfter(latest))) {
        latest = at;
        result = row;
      }
    }
    return result ?? const <String, Object?>{};
  }

  String _water(Map<String, Object?> row) {''')
p.write_text(s)
p.with_name('coach_reference_workspace_components.dart').write_text("part of 'coach_reference_workspace.dart';\n\n" + components)
p = Path('lib/features/intelligence_center/presentation/intelligence_center_page.dart')
s = p.read_text()
a = s.index('  Future<void> _navigateReference(int index) async {')
b = s.index('  Widget _buildReferenceChat(BuildContext context) {', a)
flow = s[a:b]
flow = flow.replace('''      if (question.text.trim().isEmpty && draft.isNotEmpty)
        question.text = draft;
      if (voiceMode == _CoachVoiceMode.liveCall)
        await _pauseLiveCall();
      else if (listening || voiceCaptureStarting)
        await _stopVoiceCapture(resetMode: true);''', '''      if (question.text.trim().isEmpty && draft.isNotEmpty) {
        question.text = draft;
      }
      if (voiceMode == _CoachVoiceMode.liveCall) {
        await _pauseLiveCall();
      } else if (listening || voiceCaptureStarting) {
        await _stopVoiceCapture(resetMode: true);
      }''')
flow = flow.replace('''      if (index == 0) {
        setState(() => _referenceOverview = true);
      } else if (index != 1) {''', '''      if (index != 1) {''')
flow = flow.replace('  @override\n  Widget build(BuildContext context) {', '  Widget _buildReferencePresentation(BuildContext context) {').replace('setState(', '_updateState(')
s = s[:a] + '  @override\n  Widget build(BuildContext context) => _buildReferencePresentation(context);\n\n' + s[b:]
s = s.replace("part 'intelligence_coach_menu.dart';", "part 'intelligence_coach_menu.dart';\npart 'intelligence_reference_workspace_flow.dart';\npart 'intelligence_coach_reference_header.dart';")
s = s.replace("    if (action == 'history') {", "    if (action == 'overview') {\n      setState(() => _referenceOverview = true);\n    } else if (action == 'history') {")
a = s.index('  Future<void> _showCoachMenuSheet() async {')
b = s.index('\n  @override\n  void dispose()', a)
menu = s[a:b].replace('setState(', '_updateState(')
s = s[:a] + s[b:]
p.write_text(s)
p.with_name('intelligence_reference_workspace_flow.dart').write_text("part of 'intelligence_center_page.dart';\n\nextension _ReferenceWorkspaceFlow on _IntelligenceCenterPageState {\n" + menu + '\n' + flow + '}\n')
p = 'lib/features/intelligence_center/presentation/intelligence_coach_menu.dart'
edit(p, '''            const SizedBox(height: 16),
            _CoachMenuTile(''', '''            const SizedBox(height: 16),
            _CoachMenuTile(
              icon: Icons.dashboard_outlined,
              title: intelligenceText(context, 'Overview', 'نظرة عامة'),
              subtitle: intelligenceText(context, 'Your Health Timeline', 'تسلسل يومك الصحي'),
              onTap: () => Navigator.of(context).pop('overview'),
            ),
            const SizedBox(height: 9),
            _CoachMenuTile(''')
p = Path('lib/features/intelligence_center/presentation/intelligence_center_widgets.dart')
s = p.read_text(); a = s.index('class _CoachHero extends StatelessWidget {'); b = s.index('class _CoachHeroPortrait extends StatelessWidget {', a); p.write_text(s[:a] + s[b:])
edit('test/qa_next/coach_reference_workspace_capture_test.dart', "await tester.tap(find.byKey(const Key('bil-reference-nav-0')));", "await tester.tap(find.byTooltip('Coach controls'));\n      await tester.pumpAndSettle();\n      await tester.tap(find.text('Overview'));")
p = Path('lib/shared/widgets/bil_reference_bottom_bar.dart'); s = p.read_text()
s = s.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../../app/localization/app_localizations.dart';")
a = s.index('    final ar = Directionality.of(context)'); b = s.index('    final icons =', a)
s = s[:a] + "    final labels = [for (final source in const ['Home', 'AI Coach', 'Quick Add', 'Community', 'More']) AppLocalizations.of(context).text(source)];\n" + s[b:]; p.write_text(s)
p = Path('lib/app/localization/runtime_copy.dart'); s = p.read_text(); s = "import 'runtime_copy_next_workspace.dart';\n" + s; s = s.replace('  static String? resolve(String english, String localeTag) {', '  static String? resolve(String english, String localeTag) {\n    final next = NextWorkspaceRuntimeCopy.resolve(english, localeTag);\n    if (next != null) return next;'); p.write_text(s)
p = Path('lib/features/community/presentation/community_copy.dart'); s = p.read_text(); s = "import '../../../app/localization/runtime_copy_next_workspace.dart';\n" + s; s = s.replace('  return CommunityReviewCopy.resolve(catalogEnglish, canonical) ??', '  return NextWorkspaceRuntimeCopy.resolve(catalogEnglish, canonical) ??\n      CommunityReviewCopy.resolve(catalogEnglish, canonical) ??'); p.write_text(s)
p = Path('tool/localization/locale_fallback_closure.dart'); s = p.read_text(); s = "import 'package:body_intelligence_log/app/localization/runtime_copy_next_workspace.dart';\n" + s; s = s.replace('    ...ReferenceDeltaRuntimeCopy.sources,', '    ...ReferenceDeltaRuntimeCopy.sources,\n    ...NextWorkspaceRuntimeCopy.sources,'); p.write_text(s)
# Format the exact next-version scope, not the inherited application wholesale.
paths = subprocess.check_output(['git', 'diff', '--name-only', '3f0085e6e6686f2e87e9cf14789e9e578ea64159', '--', '*.dart'], text=True).splitlines()
paths += subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '--', '*.dart'], text=True).splitlines()
paths = [p for p in dict.fromkeys(paths) if Path(p).is_file()]
subprocess.run(['dart', 'format', *paths], check=True)
print('Isolated revision materialized. Tests must evaluate the resulting tracked commit.')
