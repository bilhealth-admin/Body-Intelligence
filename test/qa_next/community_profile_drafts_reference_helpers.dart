part of 'community_profile_drafts_reference_capture_test.dart';

const _avatarAsset =
    'assets/images/onboarding_2026/bil_onboarding_welcome_photo_v1.webp';

const _assets = [
  'assets/images/onboarding_2026/bil_onboarding_meal_quick_add_photo_v1.webp',
  'assets/images/workouts/workout_strength_cover_v1.png',
  'assets/images/nutrition_plans/low_carb_outdoor_lifestyle_v1.webp',
  'assets/images/quick_add/quick_add_wellness_lifestyle_v1.png',
];

class _PhotoClient implements HttpClient {
  _PhotoClient(this.images);
  final Map<String, List<int>> images;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final bytes = images[url.toString()];
    if (bytes == null) throw StateError('Unlisted visual asset: $url');
    return _PhotoRequest(bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoRequest implements HttpClientRequest {
  _PhotoRequest(this.bytes);
  final List<int> bytes;
  @override
  Future<HttpClientResponse> close() async => _PhotoResponse(bytes);
  @override
  HttpHeaders get headers => _PhotoHeaders();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoResponse extends Stream<List<int>> implements HttpClientResponse {
  _PhotoResponse(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<({GlobalKey boundary, ValueNotifier<_ReferenceRepository> selection})>
_mountReference(
  WidgetTester tester,
  _ReferenceRepository repository, {
  bool drafts = false,
  String language = 'en',
  bool dark = false,
  double scale = 1,
  double width = 414,
}) async {
  repository.arabic = language == 'ar';
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 896);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  final boundary = GlobalKey();
  final selection = ValueNotifier(repository);
  final router = GoRouter(
    initialLocation: drafts ? '/community/drafts' : '/community/member/$_owner',
    routes: [
      GoRoute(
        path: '/community/drafts',
        builder: (_, _) => ValueListenableBuilder<_ReferenceRepository>(
          valueListenable: selection,
          builder: (_, value, _) =>
              CommunitySurface(child: CommunityDraftsPage(repository: value)),
        ),
      ),
      GoRoute(
        path: '/community/member/:id',
        builder: (_, state) => ValueListenableBuilder<_ReferenceRepository>(
          valueListenable: selection,
          builder: (_, value, _) => CommunitySurface(
            child: CommunityMemberProfilePage(
              userId: state.pathParameters['id']!,
              repository: value,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/community/profile',
        builder: (_, _) =>
            const Scaffold(body: Text('Profile editor route boundary')),
      ),
      for (final path in [
        '/dashboard',
        '/intelligence-center',
        '/community',
        '/settings',
      ])
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text(path)),
        ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(selection.dispose);
  debugNetworkImageHttpClientProvider = () => _PhotoClient({
    'https://reference.invalid/avatar': repository.avatarBytes,
    'https://reference.invalid/cover': repository.photos[2].bytes,
    for (var index = 0; index < 4; index++)
      'https://reference.invalid/photo/$index': repository.photos[index].bytes,
  });
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
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
          fontFamily: language == 'ar'
              ? 'NotoArabicEvidence'
              : 'RobotoEvidence',
        ),
        builder: (context, child) => RepaintBoundary(
          key: boundary,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: visualEvidenceTextSurface(
              child,
              fontFamily: language == 'ar'
                  ? 'NotoArabicEvidence'
                  : 'RobotoEvidence',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (boundary: boundary, selection: selection);
}

Future<void> _tapReference(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _settleReferenceImages(WidgetTester tester) async {
  final providers = <({ImageProvider<Object> image, Element element})>[
    for (final element in find.byType(Image).evaluate())
      (image: (element.widget as Image).image, element: element),
    for (final element in find.byType(CircleAvatar).evaluate())
      if ((element.widget as CircleAvatar).backgroundImage case final image?)
        (image: image, element: element),
  ];
  for (final value in providers) {
    final stream = value.image.resolve(
      createLocalImageConfiguration(value.element),
    );
    var completed = false;
    Object? failure;
    final listener = ImageStreamListener(
      (_, _) => completed = true,
      onError: (Object error, StackTrace? _) {
        failure = error;
        completed = true;
      },
    );
    stream.addListener(listener);
    try {
      for (var tick = 0; tick < 200 && !completed; tick++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
    } finally {
      stream.removeListener(listener);
    }
    expect(
      failure,
      isNull,
      reason: 'Visual proof must contain decoded repository photos.',
    );
    expect(completed, isTrue);
  }
  await tester.pump();
}

Future<void> _captureReference(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  await _settleReferenceImages(tester);
  expect(tester.takeException(), isNull);
  final output = Platform.environment['BIL_PROFILE_DRAFTS_CAPTURE_DIR'];
  if (output == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void _referenceTest(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugNetworkImageHttpClientProvider = null;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  });
}

Finder get _draftScrollable => find
    .descendant(
      of: find.byKey(const Key('community-drafts-list')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _findMore(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('community-drafts-load-more')),
    450,
    scrollable: _draftScrollable,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}
