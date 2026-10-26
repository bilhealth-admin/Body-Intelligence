part of 'ai_coach_settings_page.dart';

typedef _Copy = String Function(String, String, String, String, String);

class _TokenHero extends StatelessWidget {
  const _TokenHero({
    required this.totalRemaining,
    required this.weeklyRemaining,
    required this.weeklyLimit,
    required this.paidRemaining,
    required this.spentFraction,
    required this.active,
    required this.weekStart,
    required this.resetAt,
    required this.t,
  });

  final int totalRemaining;
  final int weeklyRemaining;
  final int weeklyLimit;
  final int paidRemaining;
  final double spentFraction;
  final bool active;
  final String weekStart;
  final String resetAt;
  final _Copy t;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.onSurfaceVariant;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLow],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (active
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant)
                                  .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active ? scheme.primary : scheme.outline,
                          ),
                        ),
                        child: Text(
                          active
                              ? t(
                                  'COACH ACTIVE',
                                  'المدرب نشط',
                                  'COACH ACTIF',
                                  'COACH ACTIVO',
                                  'KOÇ AKTİF',
                                )
                              : t(
                                  'BOOST BALANCE',
                                  'رصيد BOOST',
                                  'SOLDE BOOST',
                                  'SALDO BOOST',
                                  'BOOST BAKİYESİ',
                                ),
                          style: TextStyle(
                            color: active
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      const ClipOval(
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: BilCoachPortrait(
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _number(totalRemaining),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    t(
                      'BIL AI Tokens',
                      'توكنز BIL AI',
                      'Jetons BIL AI',
                      'Tokens BIL AI',
                      'BIL AI Tokenleri',
                    ),
                    style: TextStyle(
                      color: light,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 225,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: BilStripedProgress(
                        tone: BilProgressTone.calories,
                        child: LinearProgressIndicator(
                          value: weeklyLimit <= 0 ? 0 : 1 - spentFraction,
                          minHeight: 7,
                          backgroundColor: scheme.outlineVariant,
                          valueColor: AlwaysStoppedAnimation(light),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    t(
                      '${_number(weeklyRemaining)} of ${_number(weeklyLimit)} left this week',
                      'تبقى ${_number(weeklyRemaining)} من ${_number(weeklyLimit)} هذا الأسبوع',
                      '${_number(weeklyRemaining)} sur ${_number(weeklyLimit)} cette semaine',
                      '${_number(weeklyRemaining)} de ${_number(weeklyLimit)} esta semana',
                      'Bu hafta ${_number(weeklyLimit)} tokenden ${_number(weeklyRemaining)} kaldı',
                    ),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (paidRemaining > 0)
                    Text(
                      '${_number(paidRemaining)} ${t('non-expiring Boost', 'Boost لا تنتهي صلاحيته', 'Boost sans expiration', 'Boost sin caducidad', 'süresiz Boost')}',
                      style: TextStyle(color: light, fontSize: 12),
                    ),
                  Text(
                    '${t('Current period', 'الفترة الحالية', 'Période actuelle', 'Periodo actual', 'Mevcut dönem')}: ${_periodDate(context, weekStart)} – ${_periodDate(context, resetAt)}',
                    key: const Key('ai-coach-current-period'),
                    style: TextStyle(color: light, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _periodDate(BuildContext context, String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return MaterialLocalizations.of(
    context,
  ).formatShortDate(DateTime(parsed.year, parsed.month, parsed.day));
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BilPearlFinish.panel(
        context,
        radius: BorderRadius.circular(22),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: const EdgeInsets.all(18), child: child),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        BilNavigationFeedback(
          child: Icon(icon, color: scheme.onSurfaceVariant, size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BilNavigationFeedback(
            child: Icon(icon, size: 17, color: scheme.primary),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    secondary: BilNavigationFeedback(
      child: Icon(
        icon,
        size: 22,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
    title: Text(title),
    subtitle: Text(
      subtitle,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
    ),
    value: value,
    onChanged: enabled ? onChanged : null,
  );
}
