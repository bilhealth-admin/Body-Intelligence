part of 'community_hub_page.dart';

class _CommunityFoodTab extends StatefulWidget {
  const _CommunityFoodTab({required this.repository});
  final CommunityRepository repository;
  @override
  State<_CommunityFoodTab> createState() => _CommunityFoodTabState();
}

class _CommunityFoodTabState extends State<_CommunityFoodTab> {
  late Future<List<Map<String, dynamic>>> _submissions;
  bool _formOpen = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant _CommunityFoodTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) _reload();
  }

  void _reload() {
    _submissions = widget.repository.loadMyFoodSubmissions();
  }

  Future<void> _openForm() async {
    if (_formOpen) return;
    setState(() => _formOpen = true);
    try {
      final submitted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => CommunityFoodSubmissionSheet(
          onSubmit: widget.repository.submitFood,
        ),
      );
      if (!mounted) return;
      setState(() {
        if (submitted == true) _submitted = true;
        // Also refresh after cancellation: a timed-out request may have saved.
        _reload();
      });
    } finally {
      if (mounted) setState(() => _formOpen = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _submissions,
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
          onPressed: _formOpen ? null : _openForm,
          icon: const Icon(Icons.add_rounded),
          label: Text(communityText(context, 'Submit food', 'إضافة غذاء')),
        ),
        if (_submitted) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              communityText(
                context,
                'Food submitted for review. It will not appear as verified before validation.',
                'أُرسل الغذاء للمراجعة. لن يظهر كموثّق قبل التحقق.',
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData)
          const Center(child: CircularProgressIndicator()),
        if (snapshot.hasError) _InlineError(onRetry: () => setState(_reload)),
        for (final row in snapshot.data ?? const <Map<String, dynamic>>[])
          Card(
            child: ListTile(
              title: Text(row['canonical_name'] as String),
              subtitle: Text(row['status'] as String),
              trailing: Icon(
                row['status'] == 'approved'
                    ? Icons.verified_outlined
                    : Icons.hourglass_top_rounded,
              ),
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
