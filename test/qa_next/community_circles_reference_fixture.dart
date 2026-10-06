part of 'community_circles_reference_capture_test.dart';

const _viewer = '11111111-1111-4111-8111-111111111111';
const _circleChanged = 'Your account changed. Return to Community to continue.';

CommunityCircle _circleRecord(
  String slug, {
  int members = 17,
  int posts = 4,
  CommunityCircleMembershipStatus? membership,
  CommunityCircleJoinPolicy policy = CommunityCircleJoinPolicy.open,
  String? titleKey,
  String? descriptionKey,
  String rulesKey = 'community_circle_standard_rules',
}) => CommunityCircle(
  slug: slug,
  titleCopyKey: titleKey ?? 'community_circle_${slug.replaceAll('-', '_')}',
  descriptionCopyKey:
      descriptionKey ?? 'community_circle_${slug.replaceAll('-', '_')}_body',
  rulesCopyKey: rulesKey,
  access: CommunityCircleAccess.public,
  joinPolicy: policy,
  featured: false,
  memberCount: members,
  postCount: posts,
  membershipStatus: membership,
  membershipRole: membership == null
      ? null
      : CommunityCircleMembershipRole.member,
);

class _CircleVisualRepository extends CommunityRepository {
  _CircleVisualRepository(super.client);

  @override
  String get currentUserId => _viewer;
  @override
  bool get useServerCommunityReferenceParity => true;

  List<CommunityCircle> rows = [
    _circleRecord('10k-steps', members: 4200, posts: 27),
    _circleRecord(
      'healthy-eating',
      members: 8300,
      posts: 61,
      membership: CommunityCircleMembershipStatus.active,
    ),
    _circleRecord('beginner-fitness', members: 1800, posts: 21),
    _circleRecord(
      'strength',
      members: 2600,
      posts: 15,
      membership: CommunityCircleMembershipStatus.active,
    ),
    _circleRecord('sleep', members: 1100, posts: 9),
    _circleRecord(
      'running',
      members: 1900,
      posts: 14,
      membership: CommunityCircleMembershipStatus.pending,
    ),
    _circleRecord('ramadan-fasting', members: 900, posts: 7),
    _circleRecord('weight-loss-journey', members: 1300, posts: 12),
  ];
  List<CommunityCircle>? membershipReadback;
  Completer<void>? membershipWait;
  bool failList = false;
  int lists = 0;
  int joins = 0;
  int leaves = 0;
  int feeds = 0;
  int metrics = 0;
  final composed = <String>[];

  @override
  Future<List<CommunityCircle>> loadCommunityCircles() async {
    lists++;
    if (failList) throw StateError('Synthetic circle transport details');
    return List.of(rows);
  }

  @override
  Future<CommunityCircleMembershipStatus> joinCommunityCircle(
    String slug,
  ) async {
    joins++;
    await membershipWait?.future;
    if (membershipReadback != null) rows = membershipReadback!;
    // A mutation acknowledgment is deliberately different from one test's
    // pending readback. Only the subsequent authoritative list may drive UI.
    return CommunityCircleMembershipStatus.active;
  }

  @override
  Future<bool> leaveCommunityCircle(String slug) async {
    leaves++;
    await membershipWait?.future;
    if (membershipReadback != null) rows = membershipReadback!;
    return true;
  }

  @override
  Future<CommunityCirclePostBatch> loadCommunityCirclePosts({
    required String slug,
    DateTime? before,
    String? beforeId,
    int limit = 30,
  }) async {
    feeds++;
    return CommunityCirclePostBatch(
      posts: [
        for (var index = 0; index < 4; index++)
          CommunityPost(
            id: '33333333-3333-4333-8333-33333333333$index',
            authorId: '22222222-2222-4222-8222-222222222222',
            authorName: 'Community member',
            body: 'Approved $slug post ${index + 1}',
            createdAt: DateTime.utc(2026, 10, 6 - index),
            moderationStatus: CommunityPostModerationStatus.approved,
            likeCount: index + 2,
          ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<Map<String, int>> loadCommunityPostViewCounts(
    List<String> postIds,
  ) async {
    metrics++;
    return {
      for (var index = 0; index < postIds.length; index++)
        postIds[index]: 37 + index,
    };
  }

  Future<void> compose(String slug) async => composed.add(slug);
}

class _CircleCaptureHost {
  _CircleCaptureHost(this.boundary, this.repository, this.router);
  final GlobalKey boundary;
  final ValueNotifier<_CircleVisualRepository> repository;
  final GoRouter router;
}

Future<_CircleCaptureHost> _mountCircles(
  WidgetTester tester,
  _CircleVisualRepository repository, {
  String language = 'en',
  bool dark = false,
  double scale = 1,
  double width = 414,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 896);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  final boundary = GlobalKey();
  final selection = ValueNotifier(repository);
  final router = GoRouter(
    initialLocation: '/circles',
    routes: [
      GoRoute(
        path: '/circles',
        builder: (_, _) => ValueListenableBuilder<_CircleVisualRepository>(
          valueListenable: selection,
          builder: (_, value, _) => CommunitySurface(
            child: CommunityCirclesPage(
              key: const Key('stable-circles-reference'),
              repository: value,
              onComposeCircle: value.compose,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, _) =>
            const Scaffold(body: Text('Dashboard route boundary')),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(selection.dispose);
  final family = language == 'ar' ? 'NotoArabicEvidence' : 'RobotoEvidence';
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: visualEvidenceTheme(
        dark
            ? BilFlagshipTheme.dark(isArabic: language == 'ar')
            : BilFlagshipTheme.light(isArabic: language == 'ar'),
        fontFamily: family,
      ),
      builder: (context, child) => RepaintBoundary(
        key: boundary,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: visualEvidenceTextSurface(child, fontFamily: family),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _CircleCaptureHost(boundary, selection, router);
}

Future<void> _circleCapture(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final directory = Platform.environment['BIL_CIRCLES_CAPTURE_DIR'];
  if (directory == null || directory.isEmpty) return;
  final geometry = <String, List<double>>{};
  for (final name in [
    'community-circles-search',
    'community-circles-search-scope',
    'community-circles-discover',
    'community-circles-mine',
    'community-circle-row-10k-steps',
    'community-circle-cover-10k-steps',
    'community-circle-membership-10k-steps',
    'community-circle-row-healthy-eating',
    'community-circle-cover-healthy-eating',
    'community-circle-membership-healthy-eating',
  ]) {
    final target = find.byKey(Key(name));
    if (target.evaluate().length != 1) continue;
    final bounds = tester.getRect(target);
    geometry[name] = [bounds.left, bounds.top, bounds.width, bounds.height];
  }
  final pageContext = tester.element(find.byType(Scaffold).last);
  final record = <String, Object>{
    'scenario': name,
    'locale': Localizations.localeOf(pageContext).toLanguageTag(),
    'brightness': Theme.of(pageContext).brightness.name,
    'textScale': MediaQuery.textScalerOf(pageContext).scale(1),
    'fontFamily': Theme.of(pageContext).textTheme.bodyMedium!.fontFamily!,
    'pixelRatio': 1.5,
    'debugDisableShadows': debugDisableShadows,
    'geometryDp': geometry,
  };
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Flutter did not return a PNG');
    final file = File('$directory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List());
    await File(
      '$directory/$name.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(record));
  });
}

Future<void> _tapCircle(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _circlesTest(String name, WidgetTesterCallback body) =>
    testWidgets(name, (tester) async {
      final previousShadows = debugDisableShadows;
      // Flutter's debug substitute draws thick outlines around elevated
      // Material widgets. Capture the production shadow renderer instead.
      debugDisableShadows = false;
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        debugDisableShadows = previousShadows;
      }
    });
