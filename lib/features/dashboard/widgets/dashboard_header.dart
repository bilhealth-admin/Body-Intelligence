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

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 18 : 24,
            vertical: compact ? 18 : 22,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC8F3FF),
                  border: Border.all(color: Colors.white70),
                ),
                child: ClipOval(
                  child: const BilCoachPortrait(
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI COACH',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _dashboardHeaderText(locale, 'subtitle'),
                      style: const TextStyle(color: Color(0xFFBCD0DA)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 19,
                  color: Color(0xFF7CE8F5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('dashboard-ai-coach-entry'),
            readOnly: true,
            maxLines: 1,
            onTap: () => context.push('/intelligence-center'),
            decoration: InputDecoration(
              hintText: _dashboardHeaderText(locale, 'hint'),
              hintStyle: const TextStyle(color: Color(0xFF5E6A72)),
              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _dashboardHeaderText(locale, 'open'),
                onPressed: () => context.push('/intelligence-center'),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              filled: true,
              fillColor: const Color(0xFFF7F9FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _dashboardHeaderText(String locale, String key) =>
    _dashboardHeaderCopy[locale]?[key] ?? _dashboardHeaderCopy['en']![key]!;

const _dashboardHeaderCopy = <String, Map<String, String>>{
  'en': {
    'subtitle': 'Ask about your body, meals, or training',
    'hint': 'Message your BIL coach…',
    'open': 'Open conversation',
  },
  'ar': {
    'subtitle': 'اسأل عن جسمك أو وجباتك أو تمارينك',
    'hint': 'اكتب سؤالك إلى مدرب BIL…',
    'open': 'فتح المحادثة',
  },
  'fr': {
    'subtitle':
        'Posez vos questions sur votre corps, vos repas ou vos entraînements',
    'hint': 'Écrivez à votre coach BIL…',
    'open': 'Ouvrir la conversation',
  },
  'es': {
    'subtitle': 'Pregunta sobre tu cuerpo, comidas o entrenamiento',
    'hint': 'Escribe a tu coach de BIL…',
    'open': 'Abrir conversación',
  },
  'tr': {
    'subtitle': 'Bedeniniz, öğünleriniz veya antrenmanınız hakkında sorun',
    'hint': 'BIL koçunuza yazın…',
    'open': 'Sohbeti aç',
  },
};
