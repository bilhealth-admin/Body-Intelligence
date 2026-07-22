import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/secondary_page_app_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:drift/drift.dart' show OrderingTerm;

import '../../data/database/database_provider.dart';
import '../../data/repositories/meal_repository.dart';
import '../../engine/share_metrics_engine.dart';

class _ShareStudioData {
  const _ShareStudioData({required this.metrics, required this.goal});
  final ShareMetrics metrics;
  final String goal;
}

final shareStudioDataProvider = FutureProvider<_ShareStudioData>((ref) async {
  final database = ref.watch(databaseProvider);
  final plan = await database.select(database.planSettings).getSingleOrNull();
  final goal =
      await (database.select(database.goals)
            ..where((row) => row.deletedAt.isNull())
            ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
            ..limit(1))
          .getSingleOrNull();
  final now = DateTime.now();
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 6));
  final meals = await MealRepository(database).watchAll().first;
  final weights = await (database.select(
    database.weightEntries,
  )..where((row) => row.deletedAt.isNull())).get();
  final water = await database.select(database.waterEntries).get();
  String key(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  final evidence = <ShareDayEvidence>[];
  for (var offset = 0; offset < 7; offset++) {
    final day = start.add(Duration(days: offset));
    final dayMeals = meals.where((meal) => key(meal.meal.date) == key(day));
    evidence.add(
      ShareDayEvidence(
        hasMeal: dayMeals.any((meal) => meal.items.isNotEmpty),
        hasWeight: weights.any((entry) => key(entry.date) == key(day)),
        protein: dayMeals
            .expand((meal) => meal.items)
            .fold(0, (sum, item) => sum + item.protein),
        waterMl: water
            .where((entry) => key(entry.occurredAt) == key(day))
            .fold(0, (sum, entry) => sum + entry.amountMl),
      ),
    );
  }
  return _ShareStudioData(
    metrics: ShareMetricsEngine.calculate(
      evidence,
      proteinTarget: plan?.overrideProtein ?? plan?.recommendedProtein ?? 100,
      waterTarget: plan?.overrideWater ?? plan?.recommendedWater ?? 2500,
    ),
    goal: goal?.type ?? 'maintain',
  );
});

class ShareStudioPage extends ConsumerStatefulWidget {
  const ShareStudioPage({super.key});

  @override
  ConsumerState<ShareStudioPage> createState() => _ShareStudioPageState();
}

class _ShareStudioPageState extends ConsumerState<ShareStudioPage> {
  final boundaryKey = GlobalKey();
  bool consistency = true;
  bool protein = true;
  bool hydration = true;
  bool score = false;
  bool goal = false;
  bool branding = true;
  bool sharing = false;

  Future<void> _share() async {
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;
    setState(() => sharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'bil-progress.png',
            ),
          ],
          text: 'BIL progress card',
          subject: 'My BIL progress',
          sharePositionOrigin:
              boundary.localToGlobal(Offset.zero) & boundary.size,
        ),
      );
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(shareStudioDataProvider);
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: SecondaryPageAppBar(
        title: Text(ar ? 'استوديو المشاركة' : 'Share Studio'),
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              ar
                  ? 'اختر ما تريد إظهاره. الوزن الفعلي والبيانات الصحية الحساسة مخفية دائمًا.'
                  : 'Choose what appears. Actual weight and sensitive health details always stay hidden.',
            ),
            const SizedBox(height: 12),
            RepaintBoundary(
              key: boundaryKey,
              child: _ShareCard(
                data: value,
                consistency: consistency,
                protein: protein,
                hydration: hydration,
                score: score,
                goal: goal,
                branding: branding,
                arabic: ar,
              ),
            ),
            const SizedBox(height: 16),
            _option(
              ar ? 'الاستمرارية' : 'Consistency',
              consistency,
              (v) => setState(() => consistency = v),
            ),
            _option(
              ar ? 'البروتين' : 'Protein progress',
              protein,
              (v) => setState(() => protein = v),
            ),
            _option(
              ar ? 'الترطيب' : 'Hydration',
              hydration,
              (v) => setState(() => hydration = v),
            ),
            _option(
              ar ? 'درجة BIL' : 'BIL Score',
              score,
              (v) => setState(() => score = v),
            ),
            _option(
              ar ? 'اتجاه الهدف' : 'Goal direction',
              goal,
              (v) => setState(() => goal = v),
            ),
            _option(
              ar ? 'علامة BIL' : 'BIL branding',
              branding,
              (v) => setState(() => branding = v),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: sharing ? null : _share,
              icon: const Icon(Icons.ios_share),
              label: Text(
                sharing
                    ? (ar ? 'جارٍ التجهيز…' : 'Preparing…')
                    : (ar ? 'مشاركة كصورة' : 'Share image'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ar
                  ? 'تفتح المشاركة قائمة النظام لتختار واتساب أو إنستغرام أو X أو حفظ الصورة حسب التطبيقات المتاحة.'
                  : 'The system share sheet lets you choose WhatsApp, Instagram, X, or image saving when those apps are available.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(String label, bool value, ValueChanged<bool> changed) =>
      SwitchListTile(value: value, onChanged: changed, title: Text(label));
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.data,
    required this.consistency,
    required this.protein,
    required this.hydration,
    required this.score,
    required this.goal,
    required this.branding,
    required this.arabic,
  });
  final _ShareStudioData data;
  final bool consistency;
  final bool protein;
  final bool hydration;
  final bool score;
  final bool goal;
  final bool branding;
  final bool arabic;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xff10253f), Color(0xff167d8d)]),
      borderRadius: BorderRadius.all(Radius.circular(28)),
    ),
    child: DefaultTextStyle(
      style: const TextStyle(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            arabic ? 'تقدمي هذا الأسبوع' : 'My week in progress',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (consistency)
            _line(
              Icons.calendar_month,
              arabic
                  ? '${data.metrics.consistentDays} من 7 أيام متابعة'
                  : '${data.metrics.consistentDays} of 7 days tracked',
            ),
          if (protein)
            _line(
              Icons.egg_alt_outlined,
              arabic
                  ? '${data.metrics.proteinDays} أيام بروتين داعمة'
                  : '${data.metrics.proteinDays} protein-supporting days',
            ),
          if (hydration)
            _line(
              Icons.water_drop_outlined,
              arabic
                  ? '${data.metrics.hydrationDays} أيام ترطيب داعمة'
                  : '${data.metrics.hydrationDays} hydration-supporting days',
            ),
          if (score)
            _line(
              Icons.insights,
              arabic
                  ? 'درجة BIL: ${data.metrics.score}'
                  : 'BIL Score: ${data.metrics.score}',
            ),
          if (goal)
            _line(
              Icons.flag_outlined,
              arabic
                  ? 'اتجاه الهدف: ${data.goal}'
                  : 'Goal direction: ${data.goal}',
            ),
          if (!consistency && !protein && !hydration && !score && !goal)
            Text(arabic ? 'اختر مقياسًا لعرضه' : 'Select a metric to show'),
          if (branding) ...[
            const SizedBox(height: 18),
            const Text(
              'BIL · Body Intelligence Log',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    ),
  );
}
