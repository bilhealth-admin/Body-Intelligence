part of 'dashboard_header.dart';

// Kept as a reversible visual fallback until the new conversation entry has
// completed device review.
// ignore: unused_element
class _BilGuideOrb extends StatelessWidget {
  const _BilGuideOrb({required this.arabic, required this.compact});

  final bool arabic;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final dimension = compact ? 190.0 : 220.0;
    final orb = Semantics(
      button: true,
      label: dashboardFiveLocaleText('Open BIL Guide', 'فتح مرشد BIL'),
      child: InkWell(
        onTap: () => context.push('/intelligence-center'),
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: dimension,
          child: CustomPaint(
            painter: const _PremiumSignalRingPainter(),
            child: Padding(
              padding: EdgeInsets.all(compact ? 28 : 38),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF173A50), Color(0xFF071421)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF20C9E8).withValues(alpha: .24),
                      blurRadius: 30,
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.psychology_alt_rounded,
                      color: Color(0xFF55DDF2),
                      size: 34,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dashboardFiveLocaleText('BIL GUIDE', 'مرشد BIL'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 14,
                      ),
                      child: Text(
                        arabic
                            ? 'ماذا تريد أن تعرف عن جسمك اليوم؟'
                            : 'What would you like to know about your body today?',
                        textAlign: TextAlign.center,
                        maxLines: compact ? 3 : 2,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          color: Color(0xFFB9CAD5),
                          fontSize: compact ? 10 : 11,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (reducedMotion) return orb;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .97, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Opacity(opacity: value, child: child),
      ),
      child: orb,
    );
  }
}

// Kept temporarily while the new BIL guide hero is visually validated.
// ignore: unused_element
class _MealStudioAction extends StatelessWidget {
  const _MealStudioAction({required this.arabic});

  final bool arabic;

  String tr(String en, String ar) => dashboardFiveLocaleText(en, ar);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tr('Open Meal Studio', 'فتح استوديو الوجبة'),
      child: InkWell(
        onTap: () => context.go(
          '/daily-log?meal=breakfast&focus=meal&from=%2Fdashboard',
        ),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                scheme.primary.withValues(alpha: .18),
                scheme.tertiary.withValues(alpha: .10),
                scheme.surface.withValues(alpha: .72),
              ],
            ),
            border: Border.all(color: scheme.primary.withValues(alpha: .38)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: .14),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .34),
                  ),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('MEAL STUDIO', 'استوديو الوجبة'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr(
                        'Log your meal and build your day precisely',
                        'سجّل وجبتك وابنِ يومك بدقة',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _SignalMeaning extends StatelessWidget {
  const _SignalMeaning({required this.arabic, required this.hasWeight});

  final bool arabic;
  final bool hasWeight;

  String tr(String en, String ar) => dashboardFiveLocaleText(en, ar);

  @override
  Widget build(BuildContext context) {
    return _InsightGlass(
      icon: hasWeight
          ? Icons.psychology_alt_outlined
          : Icons.monitor_weight_outlined,
      title: hasWeight
          ? tr('What this signal means', 'ماذا تعني هذه الإشارة؟')
          : tr('The best next step', 'أفضل خطوة تالية'),
      body: hasWeight
          ? tr(
              'BIL will not claim a trend until comparable measurements provide enough evidence.',
              'لن يدّعي BIL وجود اتجاه قبل توفر قياسات قابلة للمقارنة وأدلة كافية.',
            )
          : tr(
              'Record one trusted daily measurement to begin your private baseline.',
              'سجّل قياسًا يوميًا موثوقًا لبدء خط أساسك الخاص.',
            ),
    );
  }
}

// ignore: unused_element
