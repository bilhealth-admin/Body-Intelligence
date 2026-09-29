from pathlib import Path

def replace(path, old, new):
    p=Path(path); s=p.read_text()
    if old not in s: raise SystemExit('Expected reviewed source missing: '+path+' / '+old[:60])
    p.write_text(s.replace(old,new))

replace('lib/features/community/presentation/community_navigation_sheet.dart',
"              'الأصدقاء والطلبات',\n", "              'الأصدقاء والطلبات',\n              key: 'community-nav-friends',\n")
replace('lib/features/community/presentation/community_hub_page.dart',
"import 'community_copy.dart';", "import 'community_copy.dart';\nimport 'community_connections_page.dart';")
replace('lib/features/community/presentation/community_hub_page.dart',
"      switch (destination) {", """      switch (destination) {
        case '/community/connections':
          await pushCommunityPage<void>(context, CommunityConnectionsPage(repository: repository));""")
for path in ['test/features/community/community_review_regression_test.dart', 'test/features/community/community_social_v2_ui_test.dart']:
    replace(path, "hasLength(1)", "hasLength(3)")
replace('test/features/community/community_review_regression_test.dart',
"import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';", "import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';\nimport 'package:body_intelligence_log/features/community/presentation/community_connections_page.dart';")
replace('test/features/community/community_review_regression_test.dart',
"        'other_user_id': _other,", "        'id': '88888888-8888-4888-8888-888888888888',\n        'requester_id': _me,\n        'addressee_id': _other,\n        'other_user_id': _other,")
replace('test/features/community/community_review_regression_test.dart',
"find.byKey(const Key('community-friends-manage'))", "find.byType(CommunityConnectionsPage)")
for path in ['test/features/community/community_publish_validation_regression_test.dart', 'test/features/community/community_authenticated_interaction_test.dart']:
    replace(path, "    await tester.tap(find.byKey(const Key('community-nav-foods')));", """    await tester.scrollUntilVisible(
      find.byKey(const Key('community-nav-foods')), 160,
      scrollable: find.descendant(of: find.byKey(const Key('community-navigation-sheet')), matching: find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-nav-foods')));""")
replace('test/features/community/community_release_wiring_test.dart',
"final start = source.indexOf('flutter build ');", "final start = source.indexOf(path.contains('android') ? 'flutter build appbundle --release' : 'flutter build ipa --release');")

# Keep Dynamic Type intact. Labels yield width to badges rather than overflow.
# The complete label remains available to accessibility/tooltip consumers.
replace('lib/features/community/presentation/community_messages_page.dart',
"Text(copy.inbox)", "Flexible(child: Text(copy.inbox, maxLines: 1, overflow: TextOverflow.ellipsis))")
p=Path('lib/features/community/presentation/community_connections_page.dart')
s=p.read_text(); start=s.index('class _ConnectionTab'); end=s.index('class _ConnectionsEducation', start)
segment=s[start:end]
old="""          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: selected ? Theme.of(context).colorScheme.primary : null,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),"""
new="""          Flexible(
            child: Tooltip(
              message: label,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? Theme.of(context).colorScheme.primary : null,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),"""
if old not in segment: raise SystemExit('Reviewed connections tab label missing')
s=s[:start]+segment.replace(old,new)+s[end:]; p.write_text(s)

replace('test/features/auth/facebook_native_auth_flow_test.dart',
"import 'package:flutter/foundation.dart';", "import 'package:flutter/foundation.dart';\nimport 'package:flutter/services.dart';")
replace('test/features/auth/facebook_native_auth_flow_test.dart',
"'J/K Android Facebook dispatches native without browser callback'", "'J/K iOS Facebook preserves native dispatch without a browser callback'")
replace('test/features/auth/facebook_native_auth_flow_test.dart',
"debugDefaultTargetPlatformOverride = TargetPlatform.android;", "debugDefaultTargetPlatformOverride = TargetPlatform.iOS;")
p=Path('test/features/auth/facebook_native_auth_flow_test.dart'); s=p.read_text(); end=s.rfind('\n}')
s=s[:end]+'''
  for (final launched in [true, false]) {
    test('Android Facebook uses real Supabase PKCE browser boundary: $launched', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return launched;
      });
      final storage = _MemoryPkceStorage();
      final client = SupabaseClient('https://example.supabase.co', 'test-publishable-key',
        authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: storage));
      final login = _FakeFacebookLoginClient(LoginResult(status: LoginStatus.failed));
      final authority = _FakeFacebookSessionAuthority();
      final service = SupabaseAuthService(client,
        nativeFacebookSignIn: BilNativeFacebookSignIn(client: login), facebookSessionAuthority: authority);
      final previousPlatform = debugDefaultTargetPlatformOverride;
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(await service.signInWithOAuth(OAuthProvider.facebook), launched);
        expect(login.calls, 0);
        expect(authority.exchangeCalls, 0);
        final launch = calls.singleWhere((call) => call.method == 'launch');
        final arguments = Map<String, dynamic>.from(launch.arguments as Map);
        final url = Uri.parse(arguments['url'] as String);
        expect(url.host, 'example.supabase.co');
        expect(url.path, '/auth/v1/authorize');
        expect(url.queryParameters['provider'], 'facebook');
        expect(url.queryParameters['redirect_to'], SupabaseAuthService.oauthRedirectUri);
        expect(url.queryParameters['code_challenge'], isNotEmpty);
        expect(url.queryParameters['code_challenge_method']?.toLowerCase(), 's256');
        expect(arguments['useWebView'], isFalse);
        expect(storage.values, isNotEmpty);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        await client.dispose();
      }
    });
  }
'''+s[end:]
s+='''
class _MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async { values[key] = value; }
  @override
  Future<void> removeItem({required String key}) async { values.remove(key); }
}
'''
p.write_text(s)
print('Scoped compatibility, canonical navigation, accessible tabs and PKCE regression updates applied.')
