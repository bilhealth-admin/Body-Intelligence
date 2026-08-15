import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/community_repository.dart';
import 'community_copy.dart';

class CommunityFoodReviewPage extends StatefulWidget {
  const CommunityFoodReviewPage({super.key});

  @override
  State<CommunityFoodReviewPage> createState() =>
      _CommunityFoodReviewPageState();
}

class _CommunityFoodReviewPageState extends State<CommunityFoodReviewPage> {
  late final CommunityRepository _repository;
  late Future<List<Map<String, dynamic>>> _items;

  bool get _arabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _repository = CommunityRepository(Supabase.instance.client);
    _items = _repository.loadReviewableFoods();
  }

  void _reload() => setState(() {
    _items = _repository.loadReviewableFoods();
  });

  Future<void> _review(Map<String, dynamic> item, String verdict) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(communityText(context, 'Confirm review', 'تأكيد المراجعة')),
        content: Text(
          _arabic
              ? 'سيُسجل هذا القرار النهائي باسم المشرف. لا تعتمد المنتج قبل التحقق من هويته ومصدره.'
              : 'This records a final moderator decision. Verify the product identity and evidence before approving it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(communityText(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(communityText(context, 'Submit', 'إرسال')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.finalizeFoodSubmission(
      submissionId: item['id'] as String,
      decision: verdict,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          communityText(
            context,
            'Moderator decision saved.',
            'تم حفظ قرار المراجعة.',
          ),
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(communityText(context, 'Product review', 'مراجعة المنتجات')),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              _arabic
                  ? 'تعذر تحميل المراجعات. تحقق من تسجيل الدخول.'
                  : 'Could not load reviews. Check your sign-in.',
            ),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Text(
              _arabic
                  ? 'لا توجد مساهمات بانتظار المراجعة.'
                  : 'No submissions are awaiting review.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final localized = item['localized_names'];
            final arabicName = localized is Map ? localized['ar'] : null;
            final name = _arabic && arabicName is String
                ? arabicName
                : item['canonical_name'] as String;
            final nutrients = <String>[
              if (item['serving_grams'] != null) '${item['serving_grams']} g',
              if (item['calories_kcal'] != null)
                '${item['calories_kcal']} kcal',
              if (item['protein_g'] != null) 'P ${item['protein_g']} g',
              if (item['carbohydrate_g'] != null)
                'C ${item['carbohydrate_g']} g',
              if (item['fat_g'] != null) 'F ${item['fat_g']} g',
            ];
            final identity = <String>[
              if (item['product_kind'] case final String value) value,
              if (item['brand'] case final String value) value,
              if (item['barcode'] case final String value) value,
              if (item['observed_source'] case final String value) value,
              if (item['observed_confidence'] case final String value)
                '${communityText(context, 'confidence', 'ثقة')}: $value',
            ];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (identity.isNotEmpty) Text(identity.join(' · ')),
                    const SizedBox(height: 6),
                    Text(
                      nutrients.isEmpty
                          ? (_arabic
                                ? 'مراجعة هوية فقط — لا توجد قيم غذائية موثقة.'
                                : 'Identity-only review — no verified nutrition values.')
                          : nutrients.join(' · '),
                    ),
                    if (item['evidence_url'] case final String evidence)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(evidence),
                      ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _review(item, 'approved'),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: Text(
                            communityText(context, 'Approve', 'اعتماد'),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _review(item, 'needs_changes'),
                          child: Text(
                            communityText(
                              context,
                              'Needs changes',
                              'يحتاج تعديلًا',
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _review(item, 'rejected'),
                          child: Text(communityText(context, 'Reject', 'رفض')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
