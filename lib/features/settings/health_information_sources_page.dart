import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HealthInformationSourcesPage extends StatelessWidget {
  const HealthInformationSourcesPage({super.key});

  static const _sources =
      <({String title, String organization, String purpose, String url})>[
        (
          title: 'Steps for Losing Weight',
          organization: 'U.S. Centers for Disease Control and Prevention (CDC)',
          purpose: 'General healthy-weight and gradual weight-loss guidance.',
          url:
              'https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html',
        ),
        (
          title: 'Dietary Reference Intakes',
          organization:
              'U.S. Office of Disease Prevention and Health Promotion',
          purpose: 'Reference values used for nutrient and energy guidance.',
          url:
              'https://odphp.health.gov/our-work/nutrition-physical-activity/dietary-guidelines/dietary-reference-intakes',
        ),
        (
          title: 'Potassium Fact Sheet',
          organization: 'NIH Office of Dietary Supplements',
          purpose:
              'Potassium intake, food sources, safety, and clinical cautions.',
          url:
              'https://ods.od.nih.gov/factsheets/Potassium-HealthProfessional/',
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
          title: 'Body Mass Index (BMI) calculation',
          organization: 'U.S. Centers for Disease Control and Prevention (CDC)',
          purpose:
              'Published BMI calculation method used for BIL body-composition estimates.',
          url:
              'https://www.cdc.gov/growth-chart-training/hcp/using-bmi/calculating-bmi.html',
        ),
        (
          title: 'Waist-to-height ratio evidence',
          organization: 'Peer-reviewed research / PubMed',
          purpose:
              'Evidence supporting waist-to-height ratio as a non-diagnostic screening estimate.',
          url: 'https://pubmed.ncbi.nlm.nih.gov/25377944/',
        ),
        (
          title: 'Hodgdon–Beckett circumference body-composition method',
          organization: 'U.S. National Academies / NCBI Bookshelf',
          purpose:
              'Historical source context for the circumference equation used by BIL when the required measurements are available.',
          url: 'https://www.ncbi.nlm.nih.gov/books/NBK235939/',
        ),
        (
          title: 'Deurenberg BMI-age-sex body-fat prediction equation',
          organization: 'Peer-reviewed research / PubMed',
          purpose:
              'Published basis for BIL’s higher-uncertainty fallback estimate when circumference inputs are incomplete.',
          url: 'https://pubmed.ncbi.nlm.nih.gov/2043597/',
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
                ? 'يستخدم BIL هذه المراجع العامة والمنشورة لدعم تقديرات الطاقة والتغذية وتركيب الجسم والعافية. تشمل تقديرات تركيب الجسم مؤشر كتلة الجسم ونسبة الخصر إلى الطول وتقديرات الدهون بطريقة Hodgdon–Beckett، وعند نقص قياسات المحيط يستخدم BIL تقدير Deurenberg المعتمد على مؤشر كتلة الجسم والعمر والجنس مع درجة عدم يقين أعلى. هذه تقديرات تعليمية وليست قياسات سريرية أو تشخيصًا. BIL ليس جهازًا طبيًا ولا يشخّص الحالات الطبية أو يعالجها. استشر طبيبًا أو مختصًا صحيًا مؤهلًا قبل اتخاذ أي قرار طبي.'
                : 'BIL uses these published references to support energy, nutrition, body-composition, and general wellness estimates. Body-composition estimates include BMI, waist-to-height ratio, and the Hodgdon–Beckett circumference method; when the required circumference inputs are incomplete, BIL uses the Deurenberg BMI-age-sex equation as an explicitly higher-uncertainty fallback. These are educational estimates, not clinical measurements or diagnoses. BIL is not a medical device and does not diagnose or treat medical conditions. Consult a physician or other qualified healthcare professional before making medical decisions.',
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                arabic
                    ? 'ملاحظة منهجية: عوامل النشاط وتعديلات السعرات وتوزيع الماكروز وبعض أهداف التخطيط هي افتراضات منتج قابلة للتعديل وليست قياسات فسيولوجية مباشرة. يعرضها BIL كتقديرات للتخطيط ولا يضمن نتائج صحية أو نزولًا أو زيادةً محددة في الوزن.'
                    : 'Methodology note: activity factors, calorie adjustments, macro allocation, and some planning targets are adjustable product assumptions rather than directly measured physiology. BIL presents them as planning estimates and does not guarantee health outcomes or a specific amount of weight loss or gain.',
              ),
            ),
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
