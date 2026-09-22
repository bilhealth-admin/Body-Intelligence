import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/app_localizations.dart';
import '../../core/health_evidence/health_evidence_catalog.dart';

class HealthInformationSourcesPage extends StatelessWidget {
  const HealthInformationSourcesPage({
    super.key,
    this.initialTopic,
    this.sourceIds = const <String>[],
  });

  final String? initialTopic;
  final List<String> sourceIds;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String copy(String english, String arabicText) =>
        arabic ? arabicText : context.strings.text(english);
    final requested = HealthEvidenceCatalog.validateIds([
      ...sourceIds,
      ...HealthEvidenceCatalog.forTopic(initialTopic),
    ]);
    final featured = HealthEvidenceCatalog.resolve(requested);
    final featuredIds = requested.toSet();
    final visibleSources = <HealthEvidenceSource>[
      ...featured,
      ...HealthEvidenceCatalog.all.where(
        (source) => !featuredIds.contains(source.id),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          copy('Health sources & methodology', 'مصادر ومنهجية الصحة'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            copy('Sources & methodology', 'المصادر والمنهجية'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            copy(
              'BIL distinguishes your recorded or measured data from calculated estimates and general population references. BIL does not diagnose medical conditions, and estimates are not a treatment prescription. Check with a doctor or qualified health professional before decisions involving pregnancy, supplements, medicines, or medical conditions.',
              'يميز BIL بين بياناتك المسجلة أو المقاسة، والتقديرات المحسوبة، والمراجع السكانية العامة. لا يشخّص BIL الحالات الطبية، وليست التقديرات وصفة علاجية. استشر طبيبًا أو مختصًا صحيًا مؤهلًا قبل قرارات الحمل أو المكملات أو الأدوية أو الحالات الطبية.',
            ),
          ),
          const SizedBox(height: 18),
          if (featured.isNotEmpty) ...[
            Text(
              copy(
                'References for this information',
                'المراجع المرتبطة بهذه المعلومة',
              ),
              key: const Key('health-sources-featured-heading'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
          ],
          for (final source in visibleSources) ...[
            _SourceCard(source: source, arabic: arabic),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.arabic});

  final HealthEvidenceSource source;
  final bool arabic;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Semantics(
      key: ValueKey('health-source-${source.id}'),
      button: true,
      label: arabic
          ? 'فتح المصدر الأصلي: ${source.title}'
          : Localizations.localeOf(context).languageCode == 'en'
          ? 'Open original source: ${source.title}'
          : '${context.strings.text('Source')}: ${source.title}',
      child: InkWell(
        onTap: () => _openSource(context, source.url, arabic: arabic),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.organization,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(context.strings.text(source.shortDescription)),
                    const SizedBox(height: 6),
                    Text(
                      context.strings.text(source.methodologyNote),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.open_in_new_rounded),
            ],
          ),
        ),
      ),
    ),
  );

  static Future<void> _openSource(
    BuildContext context,
    Uri uri, {
    required bool arabic,
  }) async {
    if (uri.scheme != 'https' || uri.host.isEmpty) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !context.mounted) return;
    } on Object {
      // The visible fallback below keeps a failed external launch non-fatal.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          arabic
              ? 'تعذر فتح المصدر الآن.'
              : context.strings.text(
                  'This link cannot be opened safely. Return to the dashboard and try again.',
                ),
        ),
      ),
    );
  }
}
