import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/bil_coach_identity.dart';
import '../../../commerce/domain/commerce_entitlement.dart';
import '../../../commerce/domain/commerce_plan.dart';
import '../../../commerce/domain/subscription_state.dart';
import '../../../commerce/providers/commerce_providers.dart';
import '../../domain/coach_context_snapshot.dart';
import '../../intelligence_locale_copy.dart';

part 'coach_reference_workspace_components.dart';

/// Live-context workspace. Illustrations are decorative; every displayed health
/// value comes from the caller's repository snapshot and verified entitlement.
class CoachReferenceWorkspace extends ConsumerWidget {
  const CoachReferenceWorkspace({
    required this.snapshot,
    required this.now,
    required this.onChat,
    required this.onRoute,
    required this.onPhoto,
    required this.onVoice,
    super.key,
  });
  final CoachContextSnapshot? snapshot;
  final DateTime now;
  final VoidCallback onChat;
  final ValueChanged<String> onRoute;
  final VoidCallback onPhoto;
  final VoidCallback onVoice;
  static const _ink = Color(0xFF101D2D);
  static const _blue = Color(0xFF1677FF);
  static const _muted = Color(0xFF738196);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    String t(String en, String arabic) => intelligenceText(context, en, arabic);
    final access = ref.watch(verifiedSubscriptionAccessProvider).asData?.value;
    final unlocked =
        access != null &&
        access.authority == EntitlementAuthority.verifiedServer &&
        access.plan != CommercePlan.free &&
        access.grants(CommerceEntitlement.advancedIntelligence);
    final name = snapshot?.minimalIdentity['displayName']?.toString();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    CoachNutritionDay? today;
    for (final day in snapshot?.nutritionDays ?? const <CoachNutritionDay>[]) {
      if (day.day == date) {
        today = day;
        break;
      }
    }
    final rawTargets = snapshot?.computedHealth['dailyTargets'];
    final targets = rawTargets is Map ? rawTargets : const <String, Object?>{};
    String value(double? v, String key) => !unlocked
        ? '—'
        : today == null ||
              !today.knownTotals.contains(key) ||
              v == null ||
              !v.isFinite
        ? '—'
        : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
    String target(String key) {
      final n = targets[key];
      return unlocked && n is num && n.isFinite && n > 0
          ? n.toStringAsFixed(0)
          : '—';
    }

    double progress(double? amount, String key) {
      final n = targets[key];
      if (!unlocked ||
          today == null ||
          !today.knownTotals.contains(key) ||
          amount == null ||
          !amount.isFinite ||
          n is! num ||
          !n.isFinite ||
          n <= 0) {
        return 0;
      }
      return (amount / n).clamp(0.0, 1.0);
    }

    final nutrientRows = <(String, String, String, Color, double)>[
      (
        t('Calories', 'السعرات'),
        value(today?.calories, 'caloriesKcal'),
        target('caloriesKcal'),
        const Color(0xFF2DCEBB),
        progress(today?.calories, 'caloriesKcal'),
      ),
      (
        t('Protein', 'البروتين'),
        value(today?.protein, 'proteinG'),
        '${target('proteinG')} g',
        const Color(0xFF59A5FF),
        progress(today?.protein, 'proteinG'),
      ),
      (
        t('Carbs', 'الكربوهيدرات'),
        value(today?.carbs, 'carbsG'),
        '${target('carbsG')} g',
        const Color(0xFFEFBB60),
        progress(today?.carbs, 'carbsG'),
      ),
      (
        t('Fat', 'الدهون'),
        value(today?.fat, 'fatG'),
        '${target('fatG')} g',
        const Color(0xFFAE9AF2),
        progress(today?.fat, 'fatG'),
      ),
    ];
    final inherited = Theme.of(context);
    return Theme(
      data: inherited.copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F7FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: _blue,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        textTheme: inherited.textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
        ),
      ),
      child: Scaffold(
        key: const Key('coach-reference-workspace'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${now.hour < 12 ? t('Good morning', 'صباح الخير') : t('Welcome back', 'أهلًا بعودتك')}${name == null || name.isEmpty ? '' : ', $name'}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t("Let's make today count.", 'لنصنع فرقًا اليوم.'),
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  if (unlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pro',
                        style: TextStyle(
                          color: _blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 9),
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF84BFF3),
                        width: 1.5,
                      ),
                    ),
                    child: const ClipOval(
                      child: BilCoachPortrait(width: 38, height: 38),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in <(String, String)>[
                      (t('Chat', 'المحادثة'), 'chat'),
                      (t('Insights', 'تحليلات'), '/analytics'),
                      (t('Plan', 'الخطة'), '/plan'),
                      (t('Progress', 'التقدم'), '/history'),
                      (t('Tools', 'الأدوات'), '/daily-log'),
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 5),
                        child: TextButton(
                          key: Key('coach-workspace-tab-${item.$2}'),
                          style: TextButton.styleFrom(
                            foregroundColor: item.$2 == 'chat'
                                ? Colors.white
                                : _muted,
                            backgroundColor: item.$2 == 'chat'
                                ? _blue
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 10,
                            ),
                            minimumSize: const Size(48, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          onPressed: item.$2 == 'chat'
                              ? onChat
                              : () => onRoute(item.$2),
                          child: Text(
                            item.$1,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                          constraints.maxWidth < 340
                      ? 2
                      : 4;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 7) / columns;
                  return Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final row in nutrientRows)
                        SizedBox(
                          width: width,
                          child: _NutrientTile(
                            label: row.$1,
                            amount: row.$2,
                            target: row.$3,
                            accent: row.$4,
                            progress: row.$5,
                            locked: !unlocked,
                            onTap: () => onRoute(
                              unlocked ? '/analytics/nutrition' : '/plans',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 13),
              _DarkCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.track_changes_rounded,
                        color: Color(0xFFFFBC6B),
                        size: 31,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t("Today's Focus", 'تركيز اليوم'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              t(
                                'One small action at a time. Your coach is here to help you log, reflect, and plan.',
                                'خطوة صغيرة في كل مرة. مدربك هنا ليساعدك على التسجيل والمراجعة والتخطيط.',
                              ),
                              style: const TextStyle(
                                color: Color(0xFFCBD5E5),
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 17),
              Text(
                t('Plan Tools', 'أدوات خطتك'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    for (final tool
                        in <(IconData, String, String, Color, VoidCallback)>[
                          (
                            Icons.photo_camera_outlined,
                            t('Log a Meal', 'سجّل وجبة'),
                            t('Take a photo', 'التقط صورة'),
                            const Color(0xFF3CA7FF),
                            onPhoto,
                          ),
                          (
                            Icons.graphic_eq_rounded,
                            t('Voice Log', 'تسجيل صوتي'),
                            t('Just talk', 'تحدث فقط'),
                            const Color(0xFF2CAAD6),
                            onVoice,
                          ),
                          (
                            Icons.add_rounded,
                            t('Quick Add', 'إضافة سريعة'),
                            t('In seconds', 'خلال ثوانٍ'),
                            const Color(0xFF448BFF),
                            () => onRoute('/daily-log'),
                          ),
                          (
                            Icons.qr_code_scanner_rounded,
                            t('Scan Product', 'مسح منتج'),
                            t('Barcode / Label', 'باركود / ملصق'),
                            const Color(0xFF9475DA),
                            () =>
                                onRoute('/daily-log?foodLog=1&action=barcode'),
                          ),
                        ])
                      SizedBox(
                        width: (constraints.maxWidth - 9) / 2,
                        child: _DarkCard(
                          child: InkWell(
                            onTap: tool.$5,
                            borderRadius: BorderRadius.circular(13),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          tool.$4,
                                          tool.$4.withValues(alpha: .35),
                                        ],
                                      ),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Icon(
                                      tool.$1,
                                      color: Colors.white,
                                      size: 21,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tool.$2,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          tool.$3,
                                          style: const TextStyle(
                                            color: Color(0xFFB2C1D6),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              _DarkCard(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/professional/mediterranean_protein_bowl.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: const [
                              Color(0xF2112031),
                              Color(0xC5112031),
                              Color(0x20112031),
                            ],
                            stops: const [0, .6, 1],
                            begin: ar
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            end: ar
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FractionallySizedBox(
                        widthFactor: .77,
                        alignment: AlignmentDirectional.centerStart,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(
                                'Turn any meal into insights',
                                'حوّل وجبتك إلى معلومات',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t(
                                "Snap a photo to review food and portions before adding it to your log.",
                                'التقط صورة لمراجعة الطعام والكميات قبل إضافتها إلى سجلك.',
                              ),
                              style: const TextStyle(
                                color: Color(0xFFD5DFEC),
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 11),
                            FilledButton(
                              onPressed: onPhoto,
                              style: FilledButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(48, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                t(
                                  'Try Photo Logging  ›',
                                  'جرّب تسجيل الصورة  ‹',
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Text(
                t('Your Health Timeline', 'تسلسل يومك الصحي'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFE3EAF5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      if (today != null && today.meals.isNotEmpty)
                        _TimelineRow(
                          icon: Icons.restaurant_rounded,
                          label: t('Meals logged', 'وجبات مسجلة'),
                          detail: t(
                            '${today.meals.length} meal entries in your actual log',
                            '${today.meals.length} وجبات في سجلك الفعلي',
                          ),
                          onTap: () => onRoute('/daily-log'),
                        ),
                      if (snapshot?.weights.isNotEmpty == true)
                        _TimelineRow(
                          icon: Icons.monitor_weight_outlined,
                          label: t('Weight logged', 'وزن مسجل'),
                          detail:
                              '${snapshot!.weights.reduce((a, b) => a.at.isAfter(b.at) ? a : b).kg} kg',
                          onTap: () => onRoute('/weight-history'),
                        ),
                      if (snapshot?.waterHistory.isNotEmpty == true)
                        _TimelineRow(
                          icon: Icons.water_drop_outlined,
                          label: t('Water logged', 'ماء مسجل'),
                          detail: _water(
                            _latestMap(snapshot!.waterHistory, 'at'),
                          ),
                          onTap: () => onRoute('/daily-log/water'),
                        ),
                      if (snapshot?.activityHistory.isNotEmpty == true)
                        _TimelineRow(
                          icon: Icons.directions_walk_rounded,
                          label: t('Activity synced', 'نشاط متزامن'),
                          detail: _steps(
                            _latestMap(snapshot!.activityHistory, 'day'),
                            ar,
                          ),
                          onTap: () => onRoute('/connected-health/steps'),
                        ),
                      if (today?.meals.isNotEmpty != true &&
                          snapshot?.weights.isNotEmpty != true &&
                          snapshot?.waterHistory.isNotEmpty != true &&
                          snapshot?.activityHistory.isNotEmpty != true)
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            t(
                              'Your verified entries will appear here.',
                              'ستظهر تسجيلاتك الفعلية هنا.',
                            ),
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFE3EAF5)),
                ),
                child: Text(
                  t(
                    'Small consistent actions create meaningful progress.\n— BIL AI Coach',
                    'خطوات صغيرة مستمرة تصنع تقدمًا حقيقيًا.\n— مدرب BIL الذكي',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.7,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, Object?> _latestMap(
    List<Map<String, Object?>> rows,
    String timeKey,
  ) {
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

  String _water(Map<String, Object?> row) {
    final amount = row['amountMl'];
    return amount is num && amount.isFinite && amount >= 0 ? '$amount ml' : '—';
  }

  String _steps(Map<String, Object?> row, bool ar) {
    final amount = row['steps'];
    return amount is num && amount.isFinite && amount >= 0
        ? '$amount ${ar ? 'خطوة' : 'steps'}'
        : '—';
  }
}
