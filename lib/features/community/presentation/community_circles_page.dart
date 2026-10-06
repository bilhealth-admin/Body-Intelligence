part of 'community_hub_page.dart';

class CommunityCirclesPage extends StatefulWidget {
  const CommunityCirclesPage({
    required this.repository,
    this.onComposeCircle,
    this.embedded = false,
    super.key,
  });

  final CommunityRepository repository;
  final Future<void> Function(String slug)? onComposeCircle;
  final bool embedded;

  @override
  State<CommunityCirclesPage> createState() => _CommunityCirclesPageState();
}

class _CommunityCirclesPageState extends State<CommunityCirclesPage> {
  late _CommunityCircleOwnerScope _owner;
  late Future<List<CommunityCircle>> _circles;
  final Set<String> _busy = <String>{};
  final TextEditingController _search = TextEditingController();
  bool _myCircles = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bindOwner();
    _circles = _loadCircles();
  }

  @override
  void didUpdateWidget(covariant CommunityCirclesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _owner.dispose();
      _busy.clear();
      _search.clear();
      _myCircles = false;
      _loadGeneration++;
      _bindOwner();
      _circles = _loadCircles();
    }
  }

  @override
  void dispose() {
    _owner.dispose();
    _search.dispose();
    super.dispose();
  }

  void _bindOwner() {
    late final _CommunityCircleOwnerScope owner;
    owner = _CommunityCircleOwnerScope(
      repository: widget.repository,
      target: 'circles',
      currentVisit: () => mounted && identical(_owner, owner),
      onInvalidated: () {
        _loadGeneration++;
        _busy.clear();
        setState(() {});
      },
    );
    _owner = owner;
  }

  Future<List<CommunityCircle>> _loadCircles() async {
    final visit = _owner.capture();
    final generation = ++_loadGeneration;
    if (visit == null) return const [];
    try {
      return await visit.run(() async {
        final rows = await visit.repository.loadCommunityCircles();
        visit.check();
        if (generation != _loadGeneration) {
          throw const CommunityOwnerOperationCancelled();
        }
        return rows;
      });
    } on CommunityOwnerOperationCancelled {
      return const [];
    }
  }

  Future<void> _refresh() async {
    if (!_owner.isCurrent) return;
    final future = _loadCircles();
    setState(() {
      _circles = future;
    });
    try {
      await future;
    } on Object {
      // FutureBuilder renders the retry state.
    }
  }

  Future<void> _toggleMembership(
    CommunityCircle circle,
    _CommunityProfileVisit visit,
  ) async {
    if (!visit.isCurrent() ||
        !_circleCanChangeMembership(circle) ||
        !_busy.add(circle.slug)) {
      return;
    }
    setState(() {});
    try {
      await visit.run(() async {
        if (circle.activeMember || circle.pending) {
          await visit.repository.leaveCommunityCircle(circle.slug);
        } else {
          await visit.repository.joinCommunityCircle(circle.slug);
        }
        visit.check();
        await _refresh();
        visit.check();
      });
    } on CommunityOwnerOperationCancelled {
      // An in-flight request may finish, but no old-owner read follows it.
    } catch (_) {
      if (mounted && visit.isCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not update this circle safely. Try again.',
                'تعذر تحديث هذه الدائرة بأمان. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (visit.isCurrent()) {
        setState(() => _busy.remove(circle.slug));
      }
    }
  }

  Future<void> _membershipAction(
    CommunityCircle circle,
    _CommunityProfileVisit visit,
  ) async {
    if (!visit.isCurrent() || _busy.contains(circle.slug)) return;
    if (!circle.activeMember && !circle.pending) {
      await _toggleMembership(circle, visit);
      return;
    }
    try {
      await visit.run(() async {
        visit.check();
        final leave = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => visit.guard(
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _circleRecordTitle(sheetContext, circle),
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      key: Key('community-circle-leave-${circle.slug}'),
                      leading: const Icon(Icons.logout_rounded),
                      title: Text(
                        circle.pending
                            ? communityText(
                                sheetContext,
                                'Cancel request',
                                'إلغاء الطلب',
                              )
                            : communityText(sheetContext, 'Leave', 'مغادرة'),
                      ),
                      onTap: () {
                        if (visit.isCurrent()) {
                          Navigator.of(sheetContext).pop(true);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        visit.check();
        if (leave == true) await _toggleMembership(circle, visit);
      });
    } on CommunityOwnerOperationCancelled {
      // A menu opened for one membership cannot act on a later account.
    }
  }

  Future<void> _openCircle(
    CommunityCircle circle,
    _CommunityProfileVisit visit,
    Future<void> Function(String)? compose,
  ) async {
    try {
      await visit.run(() async {
        visit.check();
        await pushCommunityPage<void>(
          context,
          CommunityCirclePage(
            repository: visit.repository,
            circle: circle,
            onComposeCircle: compose,
            ownerIsCurrent: visit.isCurrent,
            ownerChanges: visit.changes,
          ),
        );
        visit.check();
      });
    } on CommunityOwnerOperationCancelled {
      // Nested routes retain the exact list visit that opened them.
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = _owner.capture();
    final compose = widget.onComposeCircle;
    final body = visit == null
        ? const _CommunityProfileOwnerChangedBody()
        : _CommunityCircleReferenceBody(
            circles: _circles,
            search: _search,
            myCircles: _myCircles,
            busy: Set<String>.unmodifiable(_busy),
            onSearch: (value) {
              if (!visit.isCurrent()) return;
              if (value.isEmpty && _search.text.isNotEmpty) _search.clear();
              setState(() {});
            },
            onSelect: (mine) {
              if (visit.isCurrent()) setState(() => _myCircles = mine);
            },
            onRefresh: () async {
              if (visit.isCurrent()) await _refresh();
            },
            onMembership: (circle) => _membershipAction(circle, visit),
            onOpen: (circle) => _openCircle(circle, visit, compose),
            onCompose: compose == null
                ? null
                : (circle) =>
                      _composeFromCircle(context, visit, circle.slug, compose),
          );
    return widget.embedded
        ? body
        : Scaffold(
            backgroundColor: CommunitySapphire.paper(context),
            appBar: AppBar(
              leading: const CommunityReturnButton(),
              centerTitle: true,
              backgroundColor: CommunitySapphire.paper(context),
              title: Text(communityText(context, 'Circles', 'الدوائر')),
            ),
            body: body,
          );
  }
}

class _CommunityCircleCover extends StatelessWidget {
  const _CommunityCircleCover({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: Key('community-circle-cover-$slug'),
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Icon(
        _circleIcon(slug),
        size: 26,
        color: scheme.onPrimaryContainer,
      ),
    );
  }
}

class _CircleMetric extends StatelessWidget {
  const _CircleMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 16), label: Text('$value $label'));
}

String _circleTitle(BuildContext context, String slug) => switch (slug) {
  '10k-steps' => communityText(context, '10K Steps', '10 آلاف خطوة'),
  'healthy-eating' => communityText(context, 'Healthy Eating', 'الأكل الصحي'),
  'beginner-fitness' => communityText(
    context,
    'Beginner Fitness',
    'لياقة للمبتدئين',
  ),
  'strength' => communityText(context, 'Strength', 'القوة'),
  'running' => communityText(context, 'Running', 'الجري'),
  'sleep' => communityText(context, 'Better Sleep', 'نوم أفضل'),
  'ramadan-fasting' => communityText(
    context,
    'Ramadan & Fasting',
    'رمضان والصيام',
  ),
  'weight-loss-journey' => communityText(
    context,
    'Weight-Loss Journey',
    'رحلة خفض الوزن',
  ),
  _ => slug,
};

String _circleDescription(BuildContext context, String slug) => switch (slug) {
  '10k-steps' => communityText(
    context,
    'Build a consistent walking habit and encourage one another.',
    'ابنِ عادة مشي مستمرة وشجّع الآخرين.',
  ),
  'healthy-eating' => communityText(
    context,
    'Share practical meal ideas and sustainable eating habits.',
    'شارك أفكار وجبات عملية وعادات غذائية مستدامة.',
  ),
  'beginner-fitness' => communityText(
    context,
    'A welcoming place for safe, gradual fitness progress.',
    'مساحة مرحبة للتقدم التدريجي والآمن في اللياقة.',
  ),
  'strength' => communityText(
    context,
    'Discuss strength training, consistency, and recovery.',
    'ناقش تمارين القوة والاستمرارية والتعافي.',
  ),
  'running' => communityText(
    context,
    'Share running progress, routines, and encouragement.',
    'شارك تقدمك في الجري وروتينك والتشجيع.',
  ),
  'sleep' => communityText(
    context,
    'Support better sleep routines without medical claims.',
    'ادعم عادات نوم أفضل دون ادعاءات طبية.',
  ),
  'ramadan-fasting' => communityText(
    context,
    'Share culturally respectful fasting routines and experiences.',
    'شارك تجارب وروتين الصيام باحترام ثقافي.',
  ),
  'weight-loss-journey' => communityText(
    context,
    'Share sustainable progress and support without comparison pressure.',
    'شارك تقدمًا مستدامًا ودعمًا دون ضغط المقارنة.',
  ),
  _ => '',
};

IconData _circleIcon(String slug) => switch (slug) {
  '10k-steps' => Icons.directions_walk_rounded,
  'healthy-eating' => Icons.restaurant_outlined,
  'beginner-fitness' => Icons.fitness_center_outlined,
  'strength' => Icons.sports_gymnastics_outlined,
  'running' => Icons.directions_run_rounded,
  'sleep' => Icons.bedtime_outlined,
  'ramadan-fasting' => Icons.nightlight_round,
  'weight-loss-journey' => Icons.trending_down_rounded,
  _ => Icons.groups_2_outlined,
};
