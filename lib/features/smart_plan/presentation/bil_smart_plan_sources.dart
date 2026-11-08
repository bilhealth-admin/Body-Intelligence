import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/bil_flat_icon.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../core/health_evidence/health_evidence_catalog.dart';
import '../../../shared/widgets/bil_modal_bottom_sheet.dart';
import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../../wellness/domain/wellness_content_pack.dart';
import '../services/bil_smart_plan_prescriptions.dart';
import 'bil_smart_plan_panel.dart';

String _copy(BuildContext context, String english, String arabic) =>
    Localizations.localeOf(context).languageCode == 'ar'
    ? arabic
    : context.strings.text(english);

/// A compact source entry using BIL's existing native book vocabulary.
class BilSmartPlanBookButton extends StatelessWidget {
  const BilSmartPlanBookButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    icon: const BilFlatIcon(
      kind: BilSemanticIconKind.learn,
      materialIcon: BilSemanticIcons.diary,
      size: 24,
      iconSize: 22,
    ),
  );
}

/// References are public, read-only information. Close the sheet completely
/// before pushing the existing methodology route, avoiding stacked barriers.
Future<void> showBilSmartPlanSources(
  BuildContext context, {
  required bool home,
  bool training = true,
  bool nutrition = true,
  WellnessContentItem? exercise,
}) async {
  final sources = <String>[
    if (training) HealthEvidenceIds.activityGuidelines,
    if (nutrition) ...[
      HealthEvidenceIds.dietaryReferenceIntakes,
      HealthEvidenceIds.fdaDailyValues,
      HealthEvidenceIds.healthyEating,
    ],
  ];
  final openMethodology = await showBilModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) => BilSmartPlanSourcesPanel(
      home: home,
      training: training,
      nutrition: nutrition,
      exercise: exercise,
      onMethodology: () => Navigator.of(sheet).pop(true),
    ),
  );
  if (openMethodology == true && context.mounted) {
    await context.push(
      Uri(
        path: '/health-information-sources',
        queryParameters: {'sources': sources.join(',')},
      ).toString(),
    );
  }
}

class BilSmartPlanSourcesPanel extends StatefulWidget {
  const BilSmartPlanSourcesPanel({
    super.key,
    required this.home,
    required this.training,
    required this.nutrition,
    required this.onMethodology,
    this.exercise,
  });
  final bool home, training, nutrition;
  final VoidCallback onMethodology;
  final WellnessContentItem? exercise;

  @override
  State<BilSmartPlanSourcesPanel> createState() =>
      _BilSmartPlanSourcesPanelState();
}

class _BilSmartPlanSourcesPanelState extends State<BilSmartPlanSourcesPanel> {
  late Future<List<({String publisher, String title, Uri url})>> _homeSources;

  @override
  void initState() {
    super.initState();
    _homeSources = widget.home && widget.training
        ? const BilSmartPlanPrescriptions().homeSources()
        : Future.value(const []);
  }

  Widget _reference(String title, Uri url) => TextButton.icon(
    onPressed: () async {
      var opened = false;
      try {
        opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      } on Object {
        opened = false;
      }
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copy(
                context,
                'The reference could not be opened. Try again.',
                'تعذّر فتح المرجع. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    },
    icon: const Icon(Icons.open_in_new_rounded),
    label: Text(title),
  );

  @override
  Widget build(BuildContext context) {
    String t(String en, String ar) => _copy(context, en, ar);
    final exercise = widget.exercise;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        key: const ValueKey('bil-smart-plan-sources-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('Plan sources', 'مصادر الخطة'),
                    key: const ValueKey('bil-smart-plan-sources-title'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (widget.training) ...[
              const SizedBox(height: 12),
              BilSmartPlanPanel(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t('Training references', 'مراجع التدريب'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.home
                            ? t(
                                'BIL adapts published strength guidance for this general adult program. It is not injury rehabilitation. Sets and resistance never increase automatically; review and approve any change.',
                                'يطبّق BIL إرشادات القوة المنشورة في برنامج عام للبالغين وليس لتأهيل الإصابات. لا تزيد المجموعات أو المقاومة تلقائيًا؛ راجع أي تعديل ووافق عليه.',
                              )
                            : t(
                                'Reference: BIL source-verified Gym plan. Adjust only through a reviewed plan change.',
                                'المرجع: خطة النادي الموثقة من مصدر BIL. لا تُعدّل إلا بعد مراجعة تغيير الخطة.',
                              ),
                      ),
                      if (exercise != null && exercise.verified)
                        _reference(
                          '${exercise.title} · ${exercise.publisher}',
                          exercise.sourceUrl,
                        ),
                      if (widget.home) ...[
                        FutureBuilder<
                          List<({String publisher, String title, Uri url})>
                        >(
                          future: _homeSources,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final source in snapshot.data!)
                                    _reference(
                                      '${source.publisher} · ${source.title}',
                                      source.url,
                                    ),
                                ],
                              );
                            }
                            if (snapshot.hasError) {
                              return TextButton(
                                onPressed: () => setState(() {
                                  _homeSources =
                                      const BilSmartPlanPrescriptions()
                                          .homeSources();
                                }),
                                child: Text(
                                  t(
                                    'References unavailable. Tap to retry.',
                                    'المراجع غير متاحة. اضغط لإعادة المحاولة.',
                                  ),
                                ),
                              );
                            }
                            return const SizedBox(
                              height: 24,
                              child: BilFeatureWelcomeStatus(),
                            );
                          },
                        ),
                        _reference(
                          t('NHS warm-up reference', 'مرجع الإحماء من NHS'),
                          Uri.parse(
                            'https://www.nhs.uk/live-well/exercise/how-to-warm-up-before-exercising/',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (widget.nutrition) ...[
              const SizedBox(height: 12),
              BilSmartPlanPanel(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t(
                      'Meal values come from the verified recipe and its source serving. Open the book beside a meal title for its ingredients, portions and original sources. Saved daily goals are separate from food consumed.',
                      'تأتي قيم الوجبة من الوصفة الموثقة وحصتها من المصدر. افتح الكتاب بجانب عنوان الوجبة للاطلاع على المكونات والحصص والمصادر الأصلية. الأهداف اليومية المحفوظة منفصلة عن الطعام المستهلك.',
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextButton.icon(
              key: const ValueKey('bil-smart-plan-health-methodology'),
              onPressed: widget.onMethodology,
              icon: const BilFlatIcon(
                kind: BilSemanticIconKind.learn,
                materialIcon: BilSemanticIcons.diary,
                size: 24,
                iconSize: 22,
              ),
              label: Text(
                t('Health sources & methodology', 'مصادر ومنهجية الصحة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
