import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/community/channels/presentation/community_channels_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../visual_closure/visual_evidence_font.dart';
import 'community_channels_widget_fixture.dart';

Future<void> _loadCaptureFonts() async {
  final directory = Platform.environment['BIL07_CAPTURE_FONT_DIR'];
  if (directory == null) return loadVisualEvidenceFont();
  // Same exact source faces as the BASE evidence helper. The override handles
  // a private runtime overlay whose executable resolves into a read-only SDK.
  // No fonts are downloaded, changed, or included in the channel handoff.
  Future<ByteData> bytes(String path) =>
      File(path).readAsBytes().then((data) => ByteData.sublistView(data));
  final latin = [
    '$directory/Roboto-Regular.ttf',
    '$directory/Roboto-Medium.ttf',
    '$directory/Roboto-Bold.ttf',
  ];
  final arabic = [
    'assets/fonts/NotoNaskhArabic-Regular.ttf',
    'assets/fonts/NotoNaskhArabic-Bold.ttf',
  ];
  final loaders = <FontLoader>[];
  for (final family in ['RobotoEvidence', 'Ahem']) {
    final loader = FontLoader(family);
    for (final source in [...latin, ...arabic]) {
      loader.addFont(bytes(source));
    }
    loaders.add(loader);
  }
  for (final family in ['NotoArabicEvidence', 'BILArabic']) {
    final loader = FontLoader(family);
    for (final source in arabic) {
      loader.addFont(bytes(source));
    }
    loaders.add(loader);
  }
  loaders.add(
    FontLoader('MaterialIcons')
      ..addFont(bytes('$directory/MaterialIcons-Regular.otf')),
  );
  loaders.add(
    FontLoader('BILDisplay')
      ..addFont(bytes('assets/fonts/Montserrat-Bold.ttf')),
  );
  loaders.add(
    FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
      rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
    ),
  );
  await Future.wait(loaders.map((loader) => loader.load()));
}

ChannelWidgetRepository _captureRepository(bool arabic) {
  final repository = ChannelWidgetRepository();
  repository.directory = [
    widgetChannel(
      title: arabic ? 'عام' : 'General',
      description: arabic
          ? 'المحادثات اليومية وتجارب المجتمع.'
          : 'Daily conversations and community experiences.',
      unread: 2,
      latest: 3,
    ),
    widgetChannel(
      id: channelWidgetNutrition,
      title: arabic ? 'التغذية' : 'Nutrition',
      description: arabic
          ? 'الأفكار والأسئلة المتعلقة بالطعام.'
          : 'Food ideas and questions.',
      unread: 1,
      latest: 1,
    ),
    widgetChannel(
      id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      title: arabic ? 'التمارين' : 'Workouts',
      description: arabic
          ? 'الحركة والتمارين اليومية.'
          : 'Movement and exercise.',
      unread: 0,
      latest: 0,
    ),
    widgetChannel(
      id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      title: arabic ? 'العادات والتوازن' : 'Mindset',
      description: arabic
          ? 'العادات الصغيرة والاستمرارية.'
          : 'Habits and consistency.',
      unread: null,
      latest: 0,
    ),
  ];
  repository.rows[channelWidgetGeneral] = [
    widgetMessage(
      1,
      authorName: arabic ? 'عضو تجريبي' : 'Sample member',
      text: arabic
          ? 'المشي لفترة قصيرة ساعدني على الاستمرار هذا الأسبوع.'
          : 'A short walk helped me stay consistent this week.',
    ),
    widgetMessage(
      2,
      authorId: channelWidgetOwner,
      authorName: arabic ? 'مُرسل تجريبي' : 'Sample sender',
      text: arabic
          ? 'سأبدأ بعشرين دقيقة اليوم. الخطوات الصغيرة مناسبة لي.'
          : 'I am starting with twenty minutes today. Small steps work for me.',
      isRead: true,
    ),
    widgetMessage(
      3,
      authorName: null,
      text: arabic
          ? 'هل جرّب أحد تمارين الحركة الخفيفة؟'
          : 'Has anyone tried a gentle mobility routine?',
    ),
  ];
  repository.rows[channelWidgetNutrition] = [
    widgetMessage(1, channelId: channelWidgetNutrition),
  ];
  return repository;
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey, {
  required String name,
  required String surface,
  required String locale,
  required double scale,
  required Size size,
}) async {
  final destination = Platform.environment['BIL07_CAPTURE_DIR'];
  if (destination == null) return;
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    await Directory(destination).create(recursive: true);
    final frame = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$destination/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      await File('$destination/$name.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'source': 'Flutter RenderRepaintBoundary.toImage',
          'fixture': 'ChannelWidgetRepository in-process synthetic data',
          'surface': surface,
          'locale': locale,
          'text_scale': scale,
          'logical_width': size.width,
          'logical_height': size.height,
          'capture_pixel_ratio': 2,
          'presence_source': 'unavailable; UI must show unknown',
          'unread_source': 'fixture authoritative directory/readback',
          'production_connection': false,
          'device_e2e': false,
          'approved_golden': false,
          'visual_reference_match_claimed': false,
        }),
      );
    } finally {
      frame.dispose();
    }
  });
}

void main() {
  setUpAll(_loadCaptureFonts);
  for (final language in ['en', 'ar']) {
    final arabic = language == 'ar';
    final scale = arabic ? 2.0 : 1.0;
    final size = arabic ? const Size(320, 568) : const Size(390, 844);
    for (final surface in ['directory', 'messages']) {
      testWidgets('genuine channel $surface $language ${scale}x capture', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _captureRepository(arabic);
        final boundary = GlobalKey();
        final family = arabic ? 'NotoArabicEvidence' : 'RobotoEvidence';
        try {
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: visualEvidenceTheme(
                BilFlagshipTheme.light(isArabic: arabic),
                fontFamily: family,
              ),
              home: surface == 'directory'
                  ? CommunityChannelsPage(repository: repository)
                  : CommunityChannelMessagesPage(
                      repository: repository,
                      channelId: channelWidgetGeneral,
                    ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                  key: boundary,
                  child: visualEvidenceTextSurface(child, fontFamily: family),
                ),
              ),
            ),
          );
          await pumpChannelActivityFrames(tester);
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
          if (surface == 'messages') {
            expect(
              find.text(
                arabic ? 'عدد المتصلين غير متاح' : 'Online count unavailable',
              ),
              findsOneWidget,
            );
          } else {
            expect(repository.reads, isEmpty);
          }
          await _capture(
            tester,
            boundary,
            name: 'bil07_${surface}_${language}_${scale.toInt()}x_fixture',
            surface: surface,
            locale: language,
            scale: scale,
            size: size,
          );
        } finally {
          await closeChannelWidget(tester, [repository]);
        }
      });
    }
  }
}
