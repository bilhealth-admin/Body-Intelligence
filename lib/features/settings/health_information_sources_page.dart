import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HealthInformationSourcesPage extends StatelessWidget {
  const HealthInformationSourcesPage({super.key});

  static const _sources = <({String title, String organization, String purpose, String url})>[
    (
      title: 'Steps for Losing Weight',
      organization: 'U.S. Centers for Disease Control and Prevention (CDC)',
      purpose: 'General healthy-weight and gradual weight-loss guidance.',
      url: 'https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html',
    ),
    (
      title: 'Dietary Reference Intakes',
      organization: 'U.S. Office of Disease Prevention and Health Promotion',
      purpose:
          'Reference values used for nutrient, energy, and water-intake guidance.',
      url:
          'https://odphp.health.gov/our-work/nutrition-physical-activity/dietary-guidelines/dietary-reference-intakes',
    ),
    (
      title: 'Potassium Fact Sheet',
      organization: 'NIH Office of Dietary Supplements',
      purpose: 'Potassium intake, food sources, safety, and clinical cautions.',
      url: 'https://ods.od.nih.gov/factsheets/Potassium-HealthProfessional/',
    ),
    (
      title: 'Nutrition and Healthy Eating — Evidence-Based Resources',
      organization: 'Healthy People 2030 / U.S. HHS',
      purpose: 'Evidence-based nutrition and healthy-eating resources.',
      url:
          'https://odphp.health.gov/healthypeople/objectives-and-data/browse-objectives/nutrition-and-healthy-eating/evidence-based-resources',
    ),
    (
      title: 'Mifflin–St Jeor resting energy equation',
      organization: 'American Journal of Clinical Nutrition / PubMed',
      purpose: 'Published basis for BIL resting-energy estimates.',
      url: 'https://pubmed.ncbi.nlm.nih.gov/2305711/',
    ),
    (
      title: 'Recommended sleep duration for adults',
      organization: 'National Sleep Foundation expert panel / PubMed',
      purpose:
          'Consensus reference for the general 7–9 hour adult sleep range; individual needs and age may differ.',
      url: 'https://pubmed.ncbi.nlm.nih.gov/29073398/',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          arabic ? 'مصادر المعلومات الصحية' : 'Health information sources',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            arabic ? 'المصادر والمنهجية' : 'Sources & methodology',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            arabic
                ? 'يستخدم BIL هذه المراجع العامة لدعم تقديرات الطاقة وإرشادات التغذية والعافية غير التشخيصية. لا يشخّص BIL الحالات الطبية ولا يصف علاجًا، وقد تحتاج احتياجاتك الفردية إلى مختص صحي مؤهل.'
                : 'BIL uses these public references to support energy estimates and general, non-diagnostic nutrition and wellness guidance. BIL does not diagnose medical conditions or prescribe treatment; individual needs may require a qualified health professional.',
          ),
          const SizedBox(height: 18),
          for (final source in _sources) ...[
            Card(
              child: ListTile(
                title: Text(source.title),
                subtitle: Text('${source.organization}\n${source.purpose}'),
                isThreeLine: true,
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => _openSource(context, source.url),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _openSource(BuildContext context, String value) async {
    try {
      final opened = await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } on Object {
      // The visible fallback below keeps a failed external launch non-fatal.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'تعذر فتح المصدر الآن.'
              : 'The source could not be opened right now.',
        ),
      ),
    );
  }
}
