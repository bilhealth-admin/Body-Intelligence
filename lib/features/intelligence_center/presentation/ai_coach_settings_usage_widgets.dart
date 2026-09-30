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
    const light = Color(0xFFC8F3FF);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12394E), Color(0xFF071923)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26071923),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -18,
            bottom: -6,
            child: Opacity(
              opacity: 0.42,
              child: const BilCoachPortrait(height: 210, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (active ? const Color(0xFF65D59A) : Colors.white)
                                  .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active
                                ? const Color(0xFF65D59A)
                                : Colors.white54,
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
                                ? const Color(0xFF8BE6B5)
                                : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _number(totalRemaining),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'BIL AI Tokens',
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
                      child: LinearProgressIndicator(
                        value: 1 - spentFraction,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.13),
                        valueColor: const AlwaysStoppedAnimation(light),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (paidRemaining > 0)
                    Text(
                      '${_number(paidRemaining)} ${t('non-expiring Boost', 'Boost لا تنتهي صلاحيته', 'Boost sans expiration', 'Boost sin caducidad', 'süresiz Boost')}',
                      style: const TextStyle(
                        color: Color(0xBFFFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    '${t('Current period', 'الفترة الحالية', 'Période actuelle', 'Periodo actual', 'Mevcut dönem')}: ${_periodDate(context, weekStart)} – ${_periodDate(context, resetAt)}',
                    key: const Key('ai-coach-current-period'),
                    style: const TextStyle(
                      color: Color(0xBFFFFFFF),
                      fontSize: 12,
                    ),
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
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF0B0D10) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(18), child: child),
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scheme.primary),
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
          Icon(icon, size: 17, color: scheme.primary),
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
  Widget build(BuildContext context) => BilPremiumConsentToggle(
    icon: icon,
    title: title,
    subtitle: subtitle,
    value: value,
    onChanged: enabled ? onChanged : null,
    loading: !enabled,
  );
}
