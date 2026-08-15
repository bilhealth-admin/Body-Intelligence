import 'package:flutter/material.dart';

import '../../../app/theme/bil_premium_responsive_layout.dart';
import 'dashboard_twin_deck_shell.dart';

class DashboardPrimaryCarousel extends StatelessWidget {
  const DashboardPrimaryCarousel({
    required this.arabic,
    required this.bestAction,
    required this.summary,
    required this.insights,
    super.key,
  });

  final bool arabic;
  final Widget bestAction;
  final Widget summary;
  final Widget insights;

  @override
  Widget build(BuildContext context) {
    final copy =
        _primaryCarouselCopy[Localizations.localeOf(
          context,
        ).languageCode.toLowerCase()] ??
        _primaryCarouselCopy['en']!;
    final width = MediaQuery.sizeOf(context).width;
    final height = BilPremiumResponsiveLayout.twinBaseHeight(width);

    return SizedBox(
      key: const Key('dashboard-primary-carousel'),
      height: height,
      child: DashboardTwinDeckShell(
        title: copy['signal']!,
        subtitle: copy['action']!,
        pageTitles: List.filled(3, copy['signal']!),
        pageSubtitles: [copy['action']!, copy['summary']!, copy['insights']!],
        semanticLabel: copy['semantic']!,
        compact: true,
        pages: [
          DashboardPrimaryEmbeddedScope(child: bestAction),
          DashboardPrimaryEmbeddedScope(child: summary),
          DashboardPrimaryEmbeddedScope(child: insights),
        ],
      ),
    );
  }
}

const _primaryCarouselCopy = <String, Map<String, String>>{
  'ar': {
    'signal': 'إشارة اليوم',
    'action': 'أفضل خطوة الآن',
    'summary': 'ملخص اليوم',
    'insights': 'رؤى اليوم',
    'semantic': 'أفضل خطوة وملخص اليوم ورؤى اليوم',
  },
  'en': {
    'signal': "Today's signal",
    'action': 'Best action now',
    'summary': 'Today summary',
    'insights': "Today's insights",
    'semantic': 'Best action, today summary, and insights',
  },
  'fr': {
    'signal': 'Signal du jour',
    'action': 'Meilleure action maintenant',
    'summary': 'Résumé du jour',
    'insights': 'Analyses du jour',
    'semantic': 'Meilleure action, résumé et analyses du jour',
  },
  'es': {
    'signal': 'Señal de hoy',
    'action': 'Mejor acción ahora',
    'summary': 'Resumen de hoy',
    'insights': 'Perspectivas de hoy',
    'semantic': 'Mejor acción, resumen y perspectivas de hoy',
  },
  'tr': {
    'signal': 'Bugünün sinyali',
    'action': 'Şimdi en iyi adım',
    'summary': 'Bugünün özeti',
    'insights': 'Bugünün içgörüleri',
    'semantic': 'En iyi adım, bugünün özeti ve içgörüleri',
  },
};

class DashboardPrimaryEmbeddedScope extends InheritedWidget {
  const DashboardPrimaryEmbeddedScope({required super.child, super.key});

  static bool active(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<
              DashboardPrimaryEmbeddedScope
            >() !=
        null;
  }

  @override
  bool updateShouldNotify(DashboardPrimaryEmbeddedScope oldWidget) => false;
}
