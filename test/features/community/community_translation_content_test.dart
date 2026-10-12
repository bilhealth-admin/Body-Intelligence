import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import '../../visual_closure/visual_evidence_font.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/community/services/community_translation_service.dart';
import 'package:body_intelligence_log/features/community/presentation/community_translation_content.dart';
import '../../visual_closure/closure_surface_capture.dart';

class _Port implements CommunityTranslationPort {
  final calls = <({String id, Map<String, String> texts, String target})>[];
  final cancelled = <String>[];
  final pending = <Completer<CommunityTranslationResult>>[];
  @override
  Future<CommunityTranslationResult> translate({
    required String requestId,
    required Map<String, String> texts,
    required String targetTag,
    String? statusLabel,
    String? cancelLabel,
  }) {
    calls.add((id: requestId, texts: texts, target: targetTag));
    final completer = Completer<CommunityTranslationResult>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> cancel(String requestId) async {
    cancelled.add(requestId);
  }

  void complete(int index, {bool same = false}) => pending[index].complete(
    CommunityTranslationResult(
      {'body': 'Bugün yürüdüm', 'title': 'İlerlemem'},
      'apple',
      sameLanguage: same,
    ),
  );
}

class _Fixture extends StatefulWidget {
  const _Fixture(
    this.port, {
    this.scale = 1,
    this.width = 390,
    this.locale = const Locale('tr'),
    this.dark = false,
  });
  final _Port port;
  final double scale, width;
  final Locale locale;
  final bool dark;
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  String owner = 'A', body = 'I walked today', id = 'post-1';
  bool current = true;
  late Locale locale = widget.locale;
  final ownerChanges = ChangeNotifier();
  void update(VoidCallback change) => setState(change);
  void switchOwner(String next) {
    update(() => owner = next);
    ownerChanges.notifyListeners();
  }

  @override
  void dispose() {
    ownerChanges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [communityTranslationProvider.overrideWithValue(widget.port)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: BilLocalePolicy.productionTags.map(
        BilLocalePolicy.localeFromTag,
      ),
      theme: visualEvidenceTheme(
        widget.dark ? BilFlagshipTheme.dark() : BilFlagshipTheme.light(),
        fontFamily: BilLocalePolicy.rtlLanguages.contains(locale.languageCode)
            ? 'NotoArabicEvidence'
            : 'RobotoEvidence',
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(widget.width, 840),
          textScaler: TextScaler.linear(widget.scale),
        ),
        child: Directionality(
          textDirection:
              BilLocalePolicy.rtlLanguages.contains(locale.languageCode)
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: const Key('translation-capture'),
                  child: CommunityTranslationContent(
                    contentId: id,
                    ownerId: owner,
                    ownerChanges: ownerChanges,
                    ownerIsCurrent: () => current,
                    texts: {'body': body, 'title': 'My progress'},
                    builder: (texts) => Column(
                      children: [
                        Text(texts['title']!),
                        SelectableText(texts['body']!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<_FixtureState> _mount(WidgetTester tester, _Port port) async {
  await tester.pumpWidget(_Fixture(port));
  await tester.pump();
  return tester.state<_FixtureState>(find.byType(_Fixture));
}

Future<void> tap(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('community-translate-post-1')));
  await tester.pump();
}

void main() {
  setUpAll(loadVisualEvidenceFont);
  testWidgets(
    'original first, Turkish app target, title/body toggle and local cache',
    (tester) async {
      final port = _Port();
      await _mount(tester, port);
      expect(port.calls, isEmpty);
      expect(find.text('I walked today'), findsOneWidget);
      await captureClosureSurface(
        tester,
        find.byKey(const Key('translation-capture')),
        'community-translation-original-tr',
      );
      await tap(tester);
      expect(port.calls.single.target, 'tr');
      expect(port.calls.single.texts, {
        'body': 'I walked today',
        'title': 'My progress',
      });
      await tap(tester); // Cancel is a real action, not another request.
      expect(port.calls.length, 1);
      expect(port.cancelled.length, 1);
      port.complete(0);
      await tester.pump();
      expect(find.text('I walked today'), findsOneWidget);
      await tap(tester);
      port.complete(1);
      await tester.pump();
      expect(find.text('Bugün yürüdüm'), findsOneWidget);
      expect(find.text('İlerlemem'), findsOneWidget);
      await captureClosureSurface(
        tester,
        find.byKey(const Key('translation-capture')),
        'community-translation-translated-tr',
      );
      await tap(tester);
      expect(find.text('I walked today'), findsOneWidget);
      await tap(tester);
      expect(port.calls.length, 2);
      expect(find.text('Bugün yürüdüm'), findsOneWidget);
    },
  );
  for (final boundary in [
    'account ABA',
    'locale',
    'edited body',
    'deleted/replaced',
    'background',
    'dispose',
  ]) {
    testWidgets('late translation rejected after $boundary', (tester) async {
      final port = _Port();
      final state = await _mount(tester, port);
      await tap(tester);
      switch (boundary) {
        case 'account ABA':
          state.switchOwner('B');
          state.switchOwner('A');
        case 'locale':
          state.update(() => state.locale = const Locale('ar'));
        case 'edited body':
          state.update(() => state.body = 'Edited original');
        case 'deleted/replaced':
          state.update(() => state.id = 'reply-2');
        case 'background':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        case 'dispose':
          await tester.pumpWidget(const SizedBox());
      }
      await tester.pump();
      port.complete(0);
      await tester.pump();
      expect(find.text('Bugün yürüdüm'), findsNothing);
      expect(port.cancelled.length, 1);
      if (boundary == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  testWidgets('failed model/engine leaves original and retry is explicit', (
    tester,
  ) async {
    final port = _Port();
    await _mount(tester, port);
    await tap(tester);
    port.pending[0].completeError(PlatformException(code: 'model_unavailable'));
    await tester.pump();
    expect(find.text('I walked today'), findsOneWidget);
    expect(find.textContaining('Orijinal metin korundu'), findsOneWidget);
    await tap(tester);
    expect(port.calls.length, 2);
    port.complete(1);
    await tester.pump();
    expect(find.text('Bugün yürüdüm'), findsOneWidget);
  });
  testWidgets('same language never labels original as a machine translation', (
    tester,
  ) async {
    final port = _Port();
    await _mount(tester, port);
    await tap(tester);
    port.complete(0, same: true);
    await tester.pump();
    expect(find.text('I walked today'), findsOneWidget);
    expect(find.textContaining('Makine çevirisi'), findsNothing);
  });
  for (final tag in BilLocalePolicy.productionTags) {
    for (final dark in [false, true]) {
      testWidgets('translation actions reachable at 320 2x $tag dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 840);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final port = _Port();
        await tester.pumpWidget(
          _Fixture(
            port,
            width: 320,
            scale: 2,
            locale: BilLocalePolicy.localeFromTag(tag),
            dark: dark,
          ),
        );
        await tester.pump();
        final action = find.byKey(const Key('community-translate-post-1'));
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        await tap(tester);
        expect(port.calls.single.target, tag);
        await tap(tester);
        port.complete(0);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
  test(
    'native port validates contract; missing SDK cannot fabricate a translation',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(DeviceCommunityTranslation.channel, (
        call,
      ) async {
        if (call.method == 'cancel') return null;
        return {
          'texts': {'body': ''},
          'engine': 'google',
        };
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          DeviceCommunityTranslation.channel,
          null,
        ),
      );
      await expectLater(
        const DeviceCommunityTranslation().translate(
          requestId: 'test',
          texts: {'body': 'Source'},
          targetTag: 'tr',
        ),
        throwsFormatException,
      );
    },
  );
}
