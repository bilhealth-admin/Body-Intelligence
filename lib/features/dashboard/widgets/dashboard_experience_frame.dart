import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';

class DashboardExperienceFrame extends StatelessWidget {
  const DashboardExperienceFrame({
    super.key,
    required this.arabic,
    required this.child,
  });

  final bool arabic;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final copy =
        _experienceFrameCopy[Localizations.localeOf(
          context,
        ).languageCode.toLowerCase()] ??
        _experienceFrameCopy['en']!;
    final scheme = Theme.of(context).colorScheme;
    final compactVerticalRhythm = MediaQuery.sizeOf(context).width >= 900;
    final contentGap = compactVerticalRhythm
        ? 12.0
        : PremiumDesignTokens.spaceMd;
    return Semantics(
      container: true,
      label: copy['semantic']!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              copy['title']!,
              key: const Key('dashboard-priority-heading'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: -.3,
              ),
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            copy['body']!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          SizedBox(height: contentGap),
          child,
        ],
      ),
    );
  }
}

const _experienceFrameCopy = <String, Map<String, String>>{
  'ar': {
    'semantic': 'أولويات اليوم ثم التفاصيل الداعمة',
    'title': 'يومك حسب الأولوية',
    'body': 'ابدأ بالإجراء الأهم، ثم راجع الأرقام والتفسير عندما تحتاجهما.',
  },
  'en': {
    'semantic': 'Today priorities followed by supporting detail',
    'title': 'Your day, in priority order',
    'body':
        'Start with the most useful action, then review numbers and evidence when needed.',
  },
  'fr': {
    'semantic': 'Priorités du jour suivies des détails utiles',
    'title': 'Votre journée, par ordre de priorité',
    'body':
        'Commencez par l’action la plus utile, puis consultez les chiffres et les preuves au besoin.',
  },
  'es': {
    'semantic': 'Prioridades de hoy seguidas de detalles de apoyo',
    'title': 'Tu día, por orden de prioridad',
    'body':
        'Empieza con la acción más útil y consulta después las cifras y la evidencia cuando lo necesites.',
  },
  'tr': {
    'semantic': 'Bugünün öncelikleri ve ardından destekleyici ayrıntılar',
    'title': 'Gününüz, öncelik sırasına göre',
    'body':
        'En yararlı adımla başlayın; gerektiğinde sayıları ve kanıtları inceleyin.',
  },
};
