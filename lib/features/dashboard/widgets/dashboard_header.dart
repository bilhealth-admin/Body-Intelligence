import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../../../shared/widgets/bil_navigation_feedback.dart';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/bil_wordmark.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../dashboard_five_locale_copy.dart';

part 'dashboard_guide_orb.dart';
part 'dashboard_signal_orb.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        if (compact) {
          return _CoachConversationEntry(locale: locale, compact: true);
        }

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 24,
            vertical: compact ? 0 : 22,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: .08)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: _CoachConversationEntry(locale: locale, compact: compact),
        );
      },
    );
  }
}

class _CoachConversationEntry extends StatelessWidget {
  const _CoachConversationEntry({required this.locale, required this.compact});

  final String locale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void openCoach() => context.push('/intelligence-center');
    return Semantics(
      key: const Key('dashboard-ai-coach-entry'),
      button: true,
      onTap: openCoach,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: openCoach,
          borderRadius: BorderRadius.circular(compact ? 18 : 26),
          child: Container(
            key: const Key('dashboard-coach-card-surface'),
            // Retain the measured approved compact footprint. Larger text
            // still grows naturally instead of clipping the new description.
            constraints: BoxConstraints(minHeight: compact ? 143.6 : 154),
            padding: EdgeInsets.all(compact ? 14 : 26),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 18 : 26),
              // Keep the existing large approved coach portrait unchanged.
              image: const DecorationImage(
                image: AssetImage(bilApprovedAiCoachAsset),
                fit: BoxFit.contain,
                alignment: AlignmentDirectional.centerEnd,
                opacity: .66,
              ),
              border: Border.all(color: const Color(0x5487DBEF), width: .8),
              gradient: const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFF0D2738), Color(0xFF071721)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26071822),
                  blurRadius: 30,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                // The approved portrait must never make title or subtitle unreadable.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: AlignmentDirectional.centerStart,
                          end: AlignmentDirectional.centerEnd,
                          colors: [
                            Color(0xF20B2332),
                            Color(0xD80B2332),
                            Color(0x000B2332),
                          ],
                          stops: [0, .53, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: compact ? 76 : 132,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dashboardHeaderText(locale, 'title'),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: compact ? 16 : 18,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 17,
                            color: Color(0xFF7CE8F5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: compact ? 76 : 132,
                      ),
                      child: Text(
                        _dashboardHeaderText(locale, 'body'),
                        key: const Key('dashboard-coach-description'),
                        style: TextStyle(
                          color: const Color(0xFFBCD0DA),
                          fontSize: compact ? 12 : 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _dashboardHeaderText(String locale, String key) =>
    _dashboardHeaderCopy[locale]?[key] ?? _dashboardHeaderCopy['en']![key]!;

const _dashboardHeaderCopy = <String, Map<String, String>>{
  'en': {
    'title': 'BIL AI Coach',
    'body':
        'Discuss your goals, prepare training and nutrition plans, and review your progress.',
  },
  'ar': {
    'title': 'مدرب BIL الذكي',
    'body': 'ناقش أهدافك، جهّز خطط التدريب والتغذية، وراجع تقدّمك.',
  },
  'fr': {
    'title': 'Coach IA BIL',
    'body':
        'Discutez de vos objectifs, préparez vos plans d’entraînement et de nutrition, et suivez vos progrès.',
  },
  'es': {
    'title': 'Coach de IA BIL',
    'body':
        'Habla de tus objetivos, prepara planes de entrenamiento y nutrición y revisa tu progreso.',
  },
  'tr': {
    'title': 'BIL Yapay Zekâ Koçu',
    'body':
        'Hedeflerinizi konuşun, antrenman ve beslenme planları hazırlayın ve ilerlemenizi gözden geçirin.',
  },
};
