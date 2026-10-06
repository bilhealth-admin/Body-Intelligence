part of 'community_composer_reference_capture_test.dart';

const _photoAssets = [
  'assets/images/onboarding_2026/bil_onboarding_meal_quick_add_photo_v1.webp',
  'assets/images/workouts/workout_strength_cover_v1.png',
  'assets/images/nutrition_plans/low_carb_outdoor_lifestyle_v1.webp',
  'assets/images/quick_add/quick_add_wellness_lifestyle_v1.png',
];
const _bodyEn =
    'A little progress, every day. Fresh food, a good walk, and time to recharge. What small habit helped you today?';
const _bodyAr =
    'خطوات صغيرة كل يوم. وجبة متوازنة ومشي في الهواء الطلق ووقت للراحة. ما العادة البسيطة التي ساعدتك اليوم؟';
const _pollEn = 'What helps you feel your best?';

CommunityDraftSaveInput _savedInput(String language) => CommunityDraftSaveInput(
  draftId: _restoredId,
  title: language == 'ar' ? 'خطوة صغيرة نحو يوم أفضل' : 'A small win for today',
  body: language == 'ar' ? _bodyAr : _bodyEn,
  topicSlugs: const ['success-stories'],
  circleSlug: 'healthy-eating',
  locationLabel: language == 'ar' ? 'ملبورن' : 'Melbourne',
  hashtags: const ['healthyhabits', 'progress'],
  pollQuestion: language == 'ar'
      ? 'ما الذي يساعدك على الشعور بالراحة؟'
      : _pollEn,
  pollOptions: language == 'ar'
      ? const ['المشي في الهواء الطلق', 'وجبة متوازنة']
      : const ['A walk outdoors', 'A balanced meal'],
);

Future<GlobalKey> _mountComposer(
  WidgetTester tester,
  _ComposerReferenceRepository repository, {
  _FixturePicker? picker,
  String language = 'en',
  bool dark = false,
  double scale = 1,
  bool drafts = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(414, 896);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
        home: drafts
            ? CommunityDraftsPage(repository: repository)
            : CommunityHubPage(
                repository: repository,
                postImagePicker: picker,
                entryWelcomeHandled: true,
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await settleVisualAssetImages(tester);
  await tester.pumpAndSettle();
  return boundary;
}

Future<void> _tapComposer(WidgetTester tester, String key) async {
  var target = find.byKey(Key(key));
  expect(target, findsOneWidget, reason: key);
  if (tester.widget(target) is ExpansionTile) {
    target = find.descendant(of: target, matching: find.byType(ListTile)).first;
  }
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason: '$key must be an actual reachable control.',
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enterComposer(
  WidgetTester tester,
  String key,
  String text,
) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

String _composerBody(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('community-post-composer')))
    .controller!
    .text;

Future<void> _scrollComposerTop(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('community-composer-title')));
  await tester.pumpAndSettle();
}

Future<void> _captureComposer(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  await _settleComposerPhotos(tester);
  expect(tester.takeException(), isNull);
  final output = Platform.environment['BIL_COMPOSER_CAPTURE_DIR'];
  if (output == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _unmountComposer(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

// Image.memory decoding uses an engine worker. Interleave real wall time and
// frames until the actual selected photos are decoded, never capture fallbacks.
Future<void> _settleComposerPhotos(WidgetTester tester) async {
  for (final element in find.byType(Image).evaluate().toList()) {
    final image = element.widget as Image;
    if (image.image is! MemoryImage) continue;
    final stream = image.image.resolve(createLocalImageConfiguration(element));
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
      for (var frame = 0; frame < 200 && !completed; frame++) {
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
      reason: 'Selected photos must decode for visual evidence.',
    );
    expect(completed, isTrue, reason: 'Selected-photo decoder did not finish.');
  }
  await tester.pump();
}
