from pathlib import Path
import subprocess

BASE = 'eb281ccd09a782d0a8f1b51e21af0ea86224e659'

def replace(path, old, new, count=1):
    p = Path(path)
    text = p.read_text()
    if text.count(old) != count:
        raise RuntimeError('Source drift in ' + path + ': ' + repr(old[:75]))
    p.write_text(text.replace(old, new))

subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, 'HEAD'], check=True)
marker=Path('docs/qa_next/REFERENCE_CANDIDATE_APPLIED.json')
if marker.exists():
    print('Candidate is already materialized; do not replay transformations.')
    raise SystemExit(0)
p='lib/features/community/presentation/community_surface.dart'
replace(p,'fontSize: 24,','fontSize: 18,')
replace(p,'fontSize: 17,','fontSize: 15,')
replace(p,'fontSize: 16,\n        height: 1.55,','fontSize: 14,\n        height: 1.45,')
replace(p,'fontSize: 15,\n        height: 1.5,','fontSize: 13,\n        height: 1.45,')
replace(p,'fontSize: 13,\n        height: 1.45,','fontSize: 12,\n        height: 1.4,',count=2)
replace(p,'centerTitle: false,','centerTitle: true,')
replace(p,'titleSpacing: 8,','titleSpacing: 6,\n          toolbarHeight: 56,')
p='lib/features/community/presentation/community_hub_page.dart'
replace(p,"import 'community_return_button.dart';","import 'community_return_button.dart';\nimport '../../../shared/widgets/bil_reference_bottom_bar.dart';")
replace(p,'return Scaffold(\n      appBar: AppBar(','''return Scaffold(
      bottomNavigationBar: BilReferenceBottomBar(
        selected: 3,
        onSelected: (index) {
          if (index == 2) { _feedKey.currentState?._openComposer(); }
          else if (index != 3) { context.go(BilReferenceBottomBar.routes[index]); }
        },
      ),
      appBar: AppBar(''')
p='lib/features/community/presentation/community_post_card.dart'
replace(p,'borderRadius: BorderRadius.circular(22),','borderRadius: BorderRadius.circular(20),')
replace(p,'padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),','padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),')
replace(p,'radius: 24,','radius: 19,')
replace(p,"          if (widget.post.hasImage) ...[\n            const SizedBox(height: 10),\n            _CommunityFeedImage(post: widget.post),\n          ],\n          const SizedBox(height: 12),\n          _ExpandableCommunityPostBody(\n            postId: widget.post.id,\n            body: widget.post.body,\n          ),", "          const SizedBox(height: 8),\n          _ExpandableCommunityPostBody(\n            postId: widget.post.id,\n            body: widget.post.body,\n          ),\n          if (widget.post.hasImage) ...[\n            const SizedBox(height: 10),\n            _CommunityFeedImage(post: widget.post),\n          ],")
p='lib/features/community/presentation/community_notifications_page.dart'
replace(p,"import 'community_return_button.dart';","import 'community_return_button.dart';\nimport '../../../shared/widgets/bil_reference_bottom_bar.dart';")
p='lib/features/community/presentation/community_notifications_rendering.dart'
replace(p,'Widget buildCommunityNotifications(BuildContext context) => Scaffold(','''Widget buildCommunityNotifications(BuildContext context) => Scaffold(
    bottomNavigationBar: BilReferenceBottomBar(
      selected: 3,
      onSelected: (index) => context.go(BilReferenceBottomBar.routes[index]),
    ),''')
p='lib/features/intelligence_center/presentation/intelligence_center_page.dart'
replace(p,"import 'coach_message_text.dart';", "import 'coach_message_text.dart';\nimport '../../../shared/widgets/bil_reference_bottom_bar.dart';\nimport 'workspace/coach_reference_workspace.dart';")
replace(p,'  @override\n  Widget build(BuildContext context) {\n    if (entryWelcomeVisible)', '''  bool _referenceOverview = false;
  bool _referenceNavigating = false;

  Future<void> _navigateReference(int index) async {
    if (_referenceNavigating || sending || !conversationReady) return;
    _referenceNavigating = true;
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final draft = pendingVoiceTranscript.trim();
      if (question.text.trim().isEmpty && draft.isNotEmpty) question.text = draft;
      if (voiceMode == _CoachVoiceMode.liveCall) await _pauseLiveCall();
      else if (listening || voiceCaptureStarting) await _stopVoiceCapture(resetMode: true);
      if (!mounted) return;
      await _saveConversation();
      if (!mounted) return;
      if (index == 0) { setState(() => _referenceOverview = true); }
      else if (index != 1) { await context.push(BilReferenceBottomBar.routes[index]); }
    } finally { _referenceNavigating = false; }
  }

  @override
  Widget build(BuildContext context) {
    final inherited = Theme.of(context);
    if (_referenceOverview) {
      final snapshot = ref.watch(coachContextSnapshotProvider).asData?.value;
      return CoachReferenceWorkspace(
        snapshot: snapshot,
        now: ref.read(intelligenceConversationClockProvider)(),
        onChat: () => setState(() => _referenceOverview = false),
        onRoute: (route) => context.push(route),
        onPhoto: () { setState(() => _referenceOverview = false); unawaited(_analyzeFoodImageInChat()); },
        onVoice: () { setState(() => _referenceOverview = false); unawaited(_toggleLiveCall()); },
      );
    }
    return Theme(
      data: inherited.copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07111B),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF318BFF), brightness: Brightness.dark, surface: const Color(0xFF07111B), onSurface: const Color(0xFFF0F5FC)),
        textTheme: inherited.textTheme.apply(bodyColor: const Color(0xFFF0F5FC), displayColor: const Color(0xFFF0F5FC)),
      ),
      child: Builder(builder: _buildReferenceChat),
    );
  }

  Widget _buildReferenceChat(BuildContext context) {
    if (entryWelcomeVisible)''')
replace(p,'    return Scaffold(\n      backgroundColor: coachNavy,', '''    return Scaffold(
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0 ? null : BilReferenceBottomBar(
        selected: 1, dark: true,
        onSelected: (index) => unawaited(_navigateReference(index)),
      ),
      backgroundColor: coachNavy,''')
replace(p,'const coachNavy = Color(0xFF071923);','const coachNavy = Color(0xFF07111B);')
replace(p,'padding: const EdgeInsets.fromLTRB(6, 3, 6, 6),','padding: EdgeInsets.zero,')
replace(p,'borderRadius: BorderRadius.circular(28),','borderRadius: BorderRadius.zero,')
replace(p,"color: const Color(0xFF1D4A60),\n                    width: 1.2,", "color: Colors.transparent,\n                    width: 0,")
p='lib/features/intelligence_center/presentation/intelligence_center_message_widgets.dart'
replace(p,'color: scheme.primaryContainer.withValues(alpha: .62),','gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3F85DD), Color(0xFF285897)]),\n            border: Border.all(color: const Color(0xFF568CCB), width: .7),')
replace(p,'return Padding(\n      padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 28, 22),','''return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF21334A), Color(0xFF132236)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF344D68), width: .65),
      ),''')
replace(p,'          const _BilResponseMark(),\n          const SizedBox(width: 10),','')
p='lib/features/intelligence_center/presentation/intelligence_center_widgets.dart'
text=Path(p).read_text()
start=text.index('class _CoachHero extends StatelessWidget {')
end=text.index('class _CoachHeroPortrait extends StatelessWidget {', start)
new=Path('tool/qa_next/coach_header.fragment').read_text()
Path(p).write_text(text[:start]+new+'\n'+text[end:])
# Keep _BilResponseMark: the actual first-decision card still uses it.
paths=subprocess.check_output(['git','diff','--name-only','--','*.dart'],text=True).splitlines()
paths += ['lib/shared/widgets/bil_reference_bottom_bar.dart','lib/features/intelligence_center/presentation/workspace/coach_reference_workspace.dart','test/qa_next/coach_reference_workspace_capture_test.dart']
subprocess.run(['dart','format',*dict.fromkeys(paths)],check=True)
import json,hashlib
manifest=[]
for name in dict.fromkeys(paths):
    path=Path(name)
    manifest.append({'path':name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'lines':len(path.read_text().splitlines())})
marker.parent.mkdir(parents=True,exist_ok=True)
marker.write_text(json.dumps({'base':BASE,'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'source_manifest':manifest,'reference_parity_verified':False,'ready_for_store_build':False},indent=2)+'\n')
