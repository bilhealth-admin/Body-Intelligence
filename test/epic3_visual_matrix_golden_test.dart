import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  const configurations = <_VisualConfiguration>[
    _VisualConfiguration('compact_en_light', Size(390, 844), false, false),
    _VisualConfiguration('compact_en_dark', Size(390, 844), false, true),
    _VisualConfiguration('compact_ar_light', Size(390, 844), true, false),
    _VisualConfiguration('compact_ar_dark', Size(390, 844), true, true),
    _VisualConfiguration('large_en_light', Size(430, 932), false, false),
    _VisualConfiguration('large_en_dark', Size(430, 932), false, true),
    _VisualConfiguration('large_ar_light', Size(430, 932), true, false),
    _VisualConfiguration('large_ar_dark', Size(430, 932), true, true),
  ];

  for (final configuration in configurations) {
    testWidgets('Epic 3 visual matrix ${configuration.name}', (tester) async {
      tester.view.physicalSize = configuration.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_VisualHarness(configuration: configuration));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(
          tester.element(find.byKey(const ValueKey('gallery'))),
        ),
        configuration.arabic ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('gallery'))),
        ).brightness,
        configuration.dark ? Brightness.dark : Brightness.light,
      );

      await expectLater(
        find.byKey(const ValueKey('gallery')),
        matchesGoldenFile('goldens/epic3_${configuration.name}.png'),
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('primary-action')),
        260,
        scrollable: _galleryScrollable,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('primary-action'))).height,
        greaterThanOrEqualTo(48),
      );
    });
  }

  testWidgets('compact phone remains usable at 200 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _VisualHarness(
        configuration: _VisualConfiguration(
          'accessibility_text_scale',
          Size(390, 844),
          false,
          false,
        ),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('primary-action')),
      260,
      scrollable: _galleryScrollable,
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('primary-action'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('compact phone survives keyboard and safe-area insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _VisualHarness(
        configuration: _VisualConfiguration(
          'keyboard_safe_area',
          Size(390, 844),
          false,
          false,
        ),
        safePadding: EdgeInsets.only(top: 44, bottom: 34),
        viewInsets: EdgeInsets.only(bottom: 300),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('primary-action')),
      260,
      scrollable: _galleryScrollable,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('primary-action')), findsOneWidget);
  });
}

final Finder _galleryScrollable = find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
  description: 'the vertical Epic 3 gallery scrollable',
);

class _VisualConfiguration {
  const _VisualConfiguration(this.name, this.size, this.arabic, this.dark);

  final String name;
  final Size size;
  final bool arabic;
  final bool dark;
}

class _VisualHarness extends StatelessWidget {
  const _VisualHarness({
    required this.configuration,
    this.textScale = 1,
    this.safePadding = EdgeInsets.zero,
    this.viewInsets = EdgeInsets.zero,
  });

  final _VisualConfiguration configuration;
  final double textScale;
  final EdgeInsets safePadding;
  final EdgeInsets viewInsets;

  @override
  Widget build(BuildContext context) {
    final theme = configuration.dark
        ? BilFlagshipTheme.dark(isArabic: configuration.arabic)
        : BilFlagshipTheme.light(isArabic: configuration.arabic);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: visualEvidenceTheme(
        theme,
        fontFamily: configuration.arabic
            ? 'NotoArabicEvidence'
            : 'RobotoEvidence',
      ),
      builder: (context, child) => visualEvidenceTextSurface(
        child,
        fontFamily: configuration.arabic
            ? 'NotoArabicEvidence'
            : 'RobotoEvidence',
      ),
      home: MediaQuery(
        data: MediaQueryData(
          size: configuration.size,
          padding: safePadding,
          viewInsets: viewInsets,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Directionality(
          textDirection: configuration.arabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: _Gallery(arabic: configuration.arabic),
        ),
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.arabic});

  final bool arabic;

  String text(String english, String arabicText) =>
      arabic ? arabicText : english;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('gallery'),
    appBar: AppBar(
      leading: const BackButton(),
      title: Text(text('Today', 'اليوم')),
      actions: const [IconButton(onPressed: null, icon: Icon(Icons.person))],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.grid_view_outlined),
          label: text('Today', 'اليوم'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.edit_note_outlined),
          label: text('Diary', 'اليوميات'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.insights_outlined),
          label: text('Progress', 'التقدم'),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        key: const ValueKey('gallery-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            text('Your health, clearly.', 'صحتك بوضوح.'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            text(
              'A calm, evidence-led view of your day.',
              'نظرة هادئة ليومك مبنية على الأدلة.',
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text('Daily summary', 'ملخص اليوم'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _MetricGroup(
                    metrics: [
                      _Metric(label: text('Energy', 'الطاقة'), value: '1,820'),
                      _Metric(
                        label: text('Protein', 'البروتين'),
                        value: '96 g',
                      ),
                      _Metric(label: text('Water', 'الماء'), value: '1.8 L'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: text('Search food', 'ابحث عن طعام'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(text('Evidence', 'الأدلة'))),
              Chip(label: Text(text('Private', 'خاص'))),
              Chip(label: Text(text('Offline ready', 'جاهز دون إنترنت'))),
            ],
          ),
          const SizedBox(height: 16),
          _StateRow(
            icon: Icons.hourglass_top_rounded,
            title: text('Loading', 'جارٍ التحميل'),
            body: text('Keeping your place…', 'نحفظ مكانك…'),
          ),
          _StateRow(
            icon: Icons.inbox_outlined,
            title: text('Nothing logged yet', 'لا توجد سجلات بعد'),
            body: text('Add your first entry.', 'أضف أول سجل.'),
          ),
          _StateRow(
            icon: Icons.wifi_off_rounded,
            title: text('Offline', 'غير متصل'),
            body: text(
              'Your local data remains available.',
              'بياناتك المحلية متاحة.',
            ),
          ),
          _StateRow(
            icon: Icons.error_outline_rounded,
            title: text('Could not refresh', 'تعذر التحديث'),
            body: text('Try again safely.', 'حاول مجددًا بأمان.'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('primary-action'),
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: Text(text('Add entry', 'إضافة سجل')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: null,
            child: Text(text('Unavailable action', 'إجراء غير متاح')),
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center),
    ],
  );
}

class _MetricGroup extends StatelessWidget {
  const _MetricGroup({required this.metrics});

  final List<Widget> metrics;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    if (largeText) {
      return Column(
        children: [
          for (final metric in metrics) ...[
            metric,
            if (metric != metrics.last) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return Row(
      children: [for (final metric in metrics) Expanded(child: metric)],
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) =>
      ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(body));
}
