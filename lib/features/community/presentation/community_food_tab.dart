part of 'community_hub_page.dart';

class _CommunityFoodTab extends StatefulWidget {
  const _CommunityFoodTab({required this.repository});
  final CommunityRepository repository;

  @override
  State<_CommunityFoodTab> createState() => _CommunityFoodTabState();
}

class _CommunityFoodTabState extends State<_CommunityFoodTab> {
  final _name = TextEditingController();
  final _serving = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _name,
      _serving,
      _calories,
      _protein,
      _carbs,
      _fat,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final values = [_serving, _calories, _protein, _carbs, _fat]
        .map((controller) => double.tryParse(controller.text.trim()))
        .toList(growable: false);
    if (_name.text.trim().length < 2 || values.any((value) => value == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(
              context,
              'Complete all required values.',
              'أكمل القيم المطلوبة.',
            ),
          ),
        ),
      );
      return;
    }
    try {
      await widget.repository.submitFood(
        CommunityFoodDraft(
          name: _name.text,
          servingGrams: values[0]!,
          calories: values[1]!,
          protein: values[2]!,
          carbohydrate: values[3]!,
          fat: values[4]!,
        ),
      );
    } on CommunityTextPolicyException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.localizedMessage(
              Localizations.localeOf(context).toLanguageTag(),
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          communityText(
            context,
            'Food submitted for review. It will not appear as verified before validation.',
            'أُرسل الغذاء للمراجعة. لن يظهر كموثّق قبل التحقق.',
          ),
        ),
      ),
    );
  }

  void _openForm() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                communityText(
                  context,
                  'Submit community food',
                  'إضافة غذاء مجتمعي',
                ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: communityText(context, 'Name', 'الاسم'),
                ),
              ),
              TextField(
                controller: _serving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: communityText(
                    context,
                    'Serving grams',
                    'الحصة بالغرام',
                  ),
                ),
              ),
              TextField(
                controller: _calories,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: communityText(context, 'Calories', 'السعرات'),
                ),
              ),
              TextField(
                controller: _protein,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: communityText(context, 'Protein', 'البروتين'),
                ),
              ),
              TextField(
                controller: _carbs,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: communityText(
                    context,
                    'Carbohydrate',
                    'الكربوهيدرات',
                  ),
                ),
              ),
              TextField(
                controller: _fat,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: communityText(context, 'Fat', 'الدهون'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  communityText(context, 'Send for review', 'إرسال للمراجعة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: widget.repository.loadMyFoodSubmissions(),
    builder: (context, snapshot) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          communityText(
            context,
            'Arabic and Gulf foods are reviewed before approval, and your contribution remains attributed to you.',
            'الأغذية العربية والخليجية تمر بمراجعة قبل اعتمادها، وتظل مساهمتك منسوبة لك.',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _openForm,
          icon: const Icon(Icons.add_rounded),
          label: Text(communityText(context, 'Submit food', 'إضافة غذاء')),
        ),
        const SizedBox(height: 16),
        for (final row in snapshot.data ?? const <Map<String, dynamic>>[])
          Card(
            child: ListTile(
              title: Text(row['canonical_name'] as String),
              subtitle: Text(row['status'] as String),
              trailing: const Icon(Icons.verified_outlined),
            ),
          ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          communityText(
            context,
            'Community could not be loaded. No data was lost.',
            'تعذر تحميل المجتمع الآن. لم تُفقد أي بيانات.',
          ),
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(communityText(context, 'Retry', 'إعادة المحاولة')),
          ),
        ],
      ],
    ),
  );
}
