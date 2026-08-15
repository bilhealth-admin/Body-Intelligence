import 'package:flutter/material.dart';

class DashboardIntelligenceCenterCard extends StatelessWidget {
  const DashboardIntelligenceCenterCard({
    required this.arabic,
    required this.onOpen,
    super.key,
  });

  final bool arabic;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final copy =
        _intelligenceCenterCopy[Localizations.localeOf(
          context,
        ).languageCode.toLowerCase()] ??
        _intelligenceCenterCopy['en']!;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.tertiary],
                  ),
                ),
                child: Icon(
                  Icons.psychology_alt_rounded,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy['title']!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(copy['body']!),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

const _intelligenceCenterCopy = <String, Map<String, String>>{
  'ar': {
    'title': 'مرشد BIL الشخصي',
    'body': 'إرشاد ذكي استباقي ومحادثة حرة، مدعومان بالأدلة وتحت موافقتك.',
  },
  'en': {
    'title': 'BIL Personal Guide',
    'body':
        'Proactive intelligent guidance and open chat, grounded in evidence and your approval.',
  },
  'fr': {
    'title': 'Guide personnel BIL',
    'body':
        'Des conseils intelligents proactifs et une discussion ouverte, fondés sur les preuves et soumis à votre approbation.',
  },
  'es': {
    'title': 'Guía personal de BIL',
    'body':
        'Orientación inteligente proactiva y chat abierto, basados en evidencia y sujetos a tu aprobación.',
  },
  'tr': {
    'title': 'BIL Kişisel Rehberi',
    'body':
        'Kanıtlara dayanan ve onayınıza bağlı proaktif akıllı rehberlik ve açık sohbet.',
  },
};
