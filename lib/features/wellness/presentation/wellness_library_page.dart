import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/bil_flagship_tokens.dart';
import '../../ads/domain/ad_policy.dart';
import '../../ads/presentation/safe_contextual_banner_slot.dart';
import 'wellness_copy.dart';

class WellnessLibraryPage extends StatefulWidget {
  const WellnessLibraryPage({super.key});

  @override
  State<WellnessLibraryPage> createState() => _WellnessLibraryPageState();
}

class _WellnessLibraryPageState extends State<WellnessLibraryPage> {
  final PageController controller = PageController(viewportFraction: .9);
  int current = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          wellnessCopy(context, 'BIL wellness library', 'مكتبة BIL الصحية'),
        ),
        actions: [
          IconButton(
            tooltip: wellnessCopy(
              context,
              'Manage content packs',
              'إدارة حزم المحتوى',
            ),
            onPressed: () => context.push('/wellness/content-packs'),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                wellnessCopy(
                  context,
                  'Practical tools grounded in your real logs and connections—never invented measurements.',
                  'أدوات عملية مبنية على سجلك واتصالاتك الحقيقية—من دون افتراض قياسات غير موجودة.',
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: controller,
                itemCount: items.length,
                onPageChanged: (value) => setState(() => current = value),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _WellnessExperienceCard(item: items[index]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const SafeContextualBannerSlot(
              placement: AdPlacement.wellnessLibrary,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                items.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == current ? 24 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == current
                        ? BilFlagshipTokens.cyan500
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  List<_WellnessItem> _items(BuildContext context) => [
    _WellnessItem(
      asset: 'assets/images/flagship/bil_meal_discovery_v1.png',
      icon: Icons.menu_book_rounded,
      title: wellnessCopy(context, 'BIL recipes', 'وصفات BIL'),
      subtitle: wellnessCopy(
        context,
        'Searchable, saveable recipes without invented nutrition values.',
        'وصفات قابلة للبحث والحفظ دون اختراع قيم غذائية.',
      ),
      status: wellnessCopy(
        context,
        'Nutrition appears only when ingredients resolve to trusted sources.',
        'تظهر القيم الغذائية فقط عند ربط المكونات بمصادر موثقة.',
      ),
      action: wellnessCopy(context, 'Explore recipes', 'افتح الوصفات'),
      route: '/wellness/recipes',
    ),
    _WellnessItem(
      asset: 'assets/images/flagship/bil_sleep_insights_v1.png',
      icon: Icons.bedtime_outlined,
      title: wellnessCopy(context, 'Sleep intelligence', 'ذكاء النوم'),
      subtitle: wellnessCopy(
        context,
        'Understand how sleep relates to energy, meals, and recovery.',
        'افهم علاقة نومك بالطاقة والوجبات والتعافي.',
      ),
      status: wellnessCopy(
        context,
        'Trends appear after a sleep log or a supported health connection.',
        'تظهر الاتجاهات بعد تسجيل النوم أو ربط مصدر صحي مدعوم.',
      ),
      action: wellnessCopy(context, 'Log your sleep', 'سجّل نومك'),
      route: '/wellness/sleep',
    ),
    _WellnessItem(
      asset: 'assets/images/flagship/bil_movement_v1.png',
      icon: Icons.fitness_center_rounded,
      title: wellnessCopy(context, 'Movement & recovery', 'الحركة والتعافي'),
      subtitle: wellnessCopy(
        context,
        'Plan movement around your current capacity, not a generic template.',
        'نظّم الحركة حول قدرتك الحالية بدل خطة عامة.',
      ),
      status: wellnessCopy(
        context,
        'BIL does not count workouts or burn without a log or trusted source.',
        'لا يحسب BIL تمرينًا أو حرقًا دون سجل أو مصدر موثوق.',
      ),
      action: wellnessCopy(context, 'Add today’s workout', 'أضف تمرين اليوم'),
      route: '/wellness/workouts',
    ),
    _WellnessItem(
      asset:
          'assets/images/brand/generated/intermittent_fasting_meal_window_v3.png',
      icon: Icons.timelapse_rounded,
      title: wellnessCopy(context, 'Intermittent fasting', 'الصيام المتقطع'),
      subtitle: wellnessCopy(
        context,
        'Track your window and its context with clear health guardrails.',
        'سجّل نافذتك وسياقها مع حماية واضحة للصحة.',
      ),
      status: wellnessCopy(
        context,
        'Fasting is optional, not medical advice. Consult a clinician when relevant.',
        'الصيام اختياري وليس توصية طبية. راجع مختصًا عند وجود حالة صحية.',
      ),
      action: wellnessCopy(
        context,
        'Open intermittent fasting timer',
        'افتح مؤقت الصيام المتقطع',
      ),
      route: '/wellness/fasting',
    ),
    _WellnessItem(
      asset: 'assets/images/flagship/bil_body_intelligence_journey_v1.png',
      icon: Icons.insights_rounded,
      title: wellnessCopy(context, 'Your weekly review', 'مراجعتك الأسبوعية'),
      subtitle: wellnessCopy(
        context,
        'Bring weight, nutrition, water, and context into one explainable review.',
        'اجمع الوزن والتغذية والماء والسياق في مراجعة واحدة قابلة للتفسير.',
      ),
      status: wellnessCopy(
        context,
        'BIL shows record sufficiency and confidence limits; weight alone never proves fat or muscle change.',
        'يعرض BIL كفاية السجلات وحدود الثقة، ولا يستنتج تغير الدهون أو العضلات من الوزن وحده.',
      ),
      action: wellnessCopy(context, 'Open weekly review', 'افتح المراجعة'),
      route: '/weekly-report',
    ),
  ];
}

class _WellnessExperienceCard extends StatelessWidget {
  const _WellnessExperienceCard({required this.item});

  final _WellnessItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusXl),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: BilFlagshipTokens.shadowCard,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(item.asset, fit: BoxFit.cover, cacheWidth: 720),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xD9071120)],
                        stops: [.45, 1],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 20,
                    end: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.icon, color: BilFlagshipTokens.cyan400),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.subtitle,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: const Color(0xFFE5EEF8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 20,
                        color: BilFlagshipTokens.emerald500,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.status)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push(item.route),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(item.action),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WellnessItem {
  const _WellnessItem({
    required this.asset,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.action,
    required this.route,
  });

  final String asset;
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final String action;
  final String route;
}
