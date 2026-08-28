import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../commerce/domain/subscription_state.dart';
import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/presentation/premium_collection_item_gate.dart';
import '../../commerce/presentation/premium_label_badge.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../domain/static_workout_artwork.dart';
import '../domain/wellness_content_pack.dart';
import '../domain/workout_routine_contract.dart';
import '../services/wellness_content_pack_manager.dart';
import '../services/wellness_media_cache.dart';
import 'workout_access_policy.dart';
import 'wellness_copy.dart';

part 'bil_workout_routines_list.dart';
part 'bil_workout_routine_details.dart';
part 'bil_workout_routine_media.dart';
part 'bil_workout_routine_presenters.dart';
part 'bil_workout_routine_visuals.dart';
part 'bil_custom_workout_routines.dart';
part 'bil_workout_routines_states.dart';

typedef WorkoutLibraryLoader =
    Future<List<WellnessContentItem>> Function(String locale);
typedef WorkoutLogHandler = Future<void> Function(WellnessContentItem workout);
typedef CustomRoutineWriter = Future<bool> Function(List<String> encodedRows);

SubscriptionState? _usableVerifiedSubscription(
  AsyncValue<SubscriptionState> snapshot,
) => snapshot.when(
  data: (value) => value,
  error: (_, _) => null,
  loading: () => null,
);

/// A verified, offline-first workout-routine browser.
///
/// The page only renders items that passed [WellnessContentPackManager]'s
/// trusted-item boundary. A video surface is shown as playable only when the
/// installed item carries integrity metadata for licensed media; an image or
/// an unverified URL is never presented as a workout video.
class BilWorkoutRoutinesPage extends ConsumerStatefulWidget {
  const BilWorkoutRoutinesPage({
    super.key,
    this.manager,
    this.loader,
    this.onLogWorkout,
    this.mediaCache,
    this.customRoutineWriter,
    this.offline = false,
    this.initialItemId,
  });

  final WellnessContentPackManager? manager;
  final WorkoutLibraryLoader? loader;
  final WorkoutLogHandler? onLogWorkout;
  final WellnessMediaCache? mediaCache;
  final CustomRoutineWriter? customRoutineWriter;
  final String? initialItemId;

  /// Set by the owning connectivity provider. Installed packs remain usable
  /// while this is true; no remote availability is inferred by this page.
  final bool offline;

  @override
  ConsumerState<BilWorkoutRoutinesPage> createState() =>
      _BilWorkoutRoutinesPageState();
}

class _BilWorkoutRoutinesPageState extends ConsumerState<BilWorkoutRoutinesPage>
    with SingleTickerProviderStateMixin {
  static const _routineIdsKey = 'bil.saved_workout_routine_ids.v1';
  static const _customRoutinesKey = 'bil.custom_workout_routines.v1';

  late final WellnessContentPackManager _manager =
      widget.manager ?? WellnessContentPackManager();
  late final WellnessMediaCache _mediaCache =
      widget.mediaCache ?? WellnessMediaCache();
  late final TabController _tabs;
  final _searchController = TextEditingController();
  Future<List<WellnessContentItem>>? _items;
  String? _loadedLocale;
  String _query = '';
  String? _category;
  _WorkoutPresenterFilter _presenterFilter = _WorkoutPresenterFilter.all;
  Set<String> _routineIds = const {};
  List<_CustomWorkoutRoutine> _customRoutines = const [];
  bool _customMutationBusy = false;
  bool _initialItemHandled = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);
    _loadRoutineIds();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_loadedLocale == locale) return;
    _loadedLocale = locale;
    _reload();
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    _searchController.dispose();
    if (widget.mediaCache == null) _mediaCache.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging && mounted) setState(() {});
  }

  Future<void> _loadRoutineIds() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final custom = <_CustomWorkoutRoutine>[];
    final customIds = <String>{};
    for (final encoded
        in preferences.getStringList(_customRoutinesKey) ?? const <String>[]) {
      try {
        final routine = _CustomWorkoutRoutine.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );
        if (customIds.add(routine.id)) custom.add(routine);
      } catch (_) {
        // Ignore only the malformed entry; keep every valid user routine.
      }
    }
    setState(() {
      _routineIds = (preferences.getStringList(_routineIdsKey) ?? const [])
          .toSet();
      _customRoutines = custom;
    });
  }

  Future<bool> _persistCustomRoutines(List<_CustomWorkoutRoutine> next) async {
    if (_customMutationBusy) return false;
    setState(() => _customMutationBusy = true);
    try {
      final encoded = next
          .map((routine) => jsonEncode(routine.toJson()))
          .toList(growable: false);
      final customWriter = widget.customRoutineWriter;
      final saved = customWriter != null
          ? await customWriter(encoded)
          : await (await SharedPreferences.getInstance()).setStringList(
              _customRoutinesKey,
              encoded,
            );
      if (!saved) throw StateError('Preference write was rejected.');
      if (mounted) setState(() => _customRoutines = next);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copy(
                context,
                'The routine could not be saved. Try again.',
                'تعذّر حفظ الروتين. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _customMutationBusy = false);
    }
  }

  void _reload() {
    final locale = _loadedLocale ?? 'en';
    setState(() {
      _items =
          widget.loader?.call(locale) ??
          _manager.loadTrustedInstalledItems(
            WellnessContentType.workouts,
            locale: locale,
          );
    });
  }

  Future<void> _toggleRoutine(WellnessContentItem item) async {
    final next = {..._routineIds};
    final saved = !next.remove(item.stableId);
    if (saved) next.add(item.stableId);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_routineIdsKey, next.toList()..sort());
      if (!mounted) return;
      setState(() => _routineIds = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? _copy(context, 'Saved to My Routines', 'حُفظ في روتيناتي')
                : _copy(
                    context,
                    'Removed from My Routines',
                    'أُزيل من روتيناتي',
                  ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'The routine could not be saved. Try again.',
              'تعذّر حفظ الروتين. حاول مجددًا.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _logTrustedRoutine(WellnessContentItem item) async {
    final subscription = _usableVerifiedSubscription(
      ref.read(verifiedSubscriptionStateProvider),
    );
    if (!workoutAccessGranted(item.minimumAccess, subscription)) {
      throw StateError(
        '${item.minimumAccess.name.toUpperCase()} access is required.',
      );
    }
    final customHandler = widget.onLogWorkout;
    if (customHandler != null) {
      await customHandler(item);
      return;
    }
    final now = DateTime.now();
    final repository = ref.read(dailyLogRepositoryProvider);
    final existing = await repository.getForDay(now);
    final entry = jsonEncode({
      'kind': 'trusted_workout_routine',
      'id': item.stableId,
      'title': item.title,
      'durationMinutes': item.durationMinutes,
      'source': item.sourceUrl.toString(),
      'recordedAt': now.toIso8601String(),
    });
    final previous = existing?.exerciseNotes?.trim();
    await repository.save(
      date: now,
      notes: existing?.notes,
      sleepHours: existing?.sleepHours,
      steps: existing?.steps,
      exerciseNotes: previous == null || previous.isEmpty
          ? entry
          : '$previous\n$entry',
    );
  }

  Future<void> _logCustomRoutine(
    _CustomWorkoutRoutine routine,
    List<WellnessContentItem> acceptedItems,
  ) async {
    if (acceptedItems.isEmpty) {
      throw StateError('No trusted movements are available.');
    }
    final now = DateTime.now();
    final repository = ref.read(dailyLogRepositoryProvider);
    final existing = await repository.getForDay(now);
    final entry = jsonEncode({
      'kind': 'custom_workout_routine',
      'id': routine.id,
      'title': routine.name,
      'movementIds': acceptedItems.map((item) => item.id).toList(),
      'movementCount': acceptedItems.length,
      'recordedAt': now.toIso8601String(),
    });
    final previous = existing?.exerciseNotes?.trim();
    await repository.save(
      date: now,
      notes: existing?.notes,
      sleepHours: existing?.sleepHours,
      steps: existing?.steps,
      exerciseNotes: previous == null || previous.isEmpty
          ? entry
          : '$previous\n$entry',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep paid rows fail-closed while entitlement is loading and rebuild the
    // library immediately if the verified server snapshot changes.
    ref.watch(verifiedSubscriptionStateProvider);
    final future = _items;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/wellness-library'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(_copy(context, 'Workout Routines', 'روتينات التمارين')),
        actions: [
          IconButton(
            key: const ValueKey('workout-programs-action'),
            tooltip: _copy(context, 'Add exercise', 'إضافة تمرين'),
            onPressed: () => context.push('/wellness/workouts/log'),
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
          ),
          IconButton(
            key: const ValueKey('workout-packs-action'),
            tooltip: _copy(
              context,
              'Manage verified packs',
              'إدارة الحزم الموثقة',
            ),
            onPressed: () => context.push('/wellness/content-packs'),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: _workoutHubCopy(context, 'Gym')),
            Tab(text: _workoutHubCopy(context, 'Home')),
            Tab(text: _workoutHubCopy(context, 'My plans')),
          ],
        ),
      ),
      body: future == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<WellnessContentItem>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _WorkoutLibraryLoading();
                }
                if (snapshot.hasError) {
                  return _WorkoutLibraryError(
                    offline: widget.offline,
                    onRetry: _reload,
                  );
                }
                final items = snapshot.data ?? const <WellnessContentItem>[];
                _scheduleInitialItem(items);
                return _buildLibrary(items);
              },
            ),
    );
  }

  Widget _buildLibrary(List<WellnessContentItem> items) {
    final subscription = _usableVerifiedSubscription(
      ref.watch(verifiedSubscriptionStateProvider),
    );
    final premiumUnlocked =
        subscription != null && subscription.plan != CommercePlan.free;
    final storefrontPlan = ref.watch(storefrontTargetPlanProvider).value;
    final premiumTier = storefrontPlan == CommercePlan.premiumAiCoach
        ? 'BIL PREMIUM AI COACH'
        : 'BIL PREMIUM';
    void openPremium() => context.push(
      storefrontPlan == CommercePlan.premiumAiCoach
          ? '/plans?focus=boost'
          : '/plans?focus=subscription',
    );
    final selectedItems = switch (_tabs.index) {
      0 => items.where((item) => item.releaseBundleId != 'home-training'),
      1 => items.where((item) => item.releaseBundleId == 'home-training'),
      _ => items.where((item) => _routineIds.contains(item.stableId)),
    };
    final categoryOrders = <String, int>{};
    for (final item in selectedItems) {
      final category = item.category?.trim();
      if (category == null || category.isEmpty) continue;
      final order = item.categoryOrder ?? 1 << 30;
      final current = categoryOrders[category];
      if (current == null || order < current) categoryOrders[category] = order;
    }
    final categories = categoryOrders.keys.toList()
      ..sort((left, right) {
        final order = categoryOrders[left]!.compareTo(categoryOrders[right]!);
        return order == 0 ? left.compareTo(right) : order;
      });
    if (_category != null && !categories.contains(_category)) {
      _category = null;
    }
    final query = _query.trim().toLowerCase();
    final visible = selectedItems
        .where((item) {
          if (_category != null && item.category != _category) return false;
          if (!_matchesWorkoutPresenter(item, _presenterFilter)) return false;
          if (query.isEmpty) return true;
          final searchable = <String>[
            item.title,
            item.description,
            item.category ?? '',
            item.difficulty ?? '',
            ...item.equipment,
            ...item.tags,
          ].join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: CustomScrollView(
        key: ValueKey('workout-library-tab-${_tabs.index}'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.offline) ...[
                    const _OfflineInstalledBanner(),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: _copy(
                        context,
                        'Search verified workouts',
                        'ابحث في التمارين الموثقة',
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: _copy(context, 'Clear', 'مسح'),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _WorkoutPresenterFilterPanel(
                    value: _presenterFilter,
                    onChanged: (value) =>
                        setState(() => _presenterFilter = value),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        key: const ValueKey('workout-category-list'),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryChip(
                            label: _copy(context, 'All', 'الكل'),
                            selected: _category == null,
                            onSelected: () => setState(() => _category = null),
                          ),
                          for (final category in categories)
                            _CategoryChip(
                              label: category,
                              selected: _category == category,
                              onSelected: () =>
                                  setState(() => _category = category),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (visible.isEmpty && _tabs.index != 2 && items.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverToBoxAdapter(
                child: _WorkoutMetadataPreviews(
                  offline: widget.offline,
                  onCardio: () =>
                      context.push('/wellness/workouts/log?category=Cardio'),
                  onStrength: () =>
                      context.push('/wellness/workouts/log?category=Strength'),
                  onManagePacks: () => context.push('/wellness/content-packs'),
                ),
              ),
            )
          else if (visible.isEmpty && _tabs.index != 2)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _WorkoutLibraryEmpty(
                myRoutines: false,
                offline: widget.offline,
                hasInstalledItems: true,
                onExplore: () => _tabs.animateTo(0),
                onManagePacks: () => context.push('/wellness/content-packs'),
              ),
            )
          else if (_tabs.index != 2)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 0, 40),
              sliver: SliverToBoxAdapter(
                child: _WorkoutExploreSections(
                  items: visible,
                  savedIds: _routineIds,
                  mediaCache: _mediaCache,
                  online: !widget.offline,
                  premiumUnlocked: premiumUnlocked,
                  premiumTier: premiumTier,
                  isLocked: _isLocked,
                  onUpgrade: openPremium,
                  onOpen: _openDetails,
                  onToggleSaved: _toggleRoutine,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverToBoxAdapter(
                child: _MyWorkoutRoutinesView(
                  items: items,
                  savedItems: visible,
                  routines: _customRoutines,
                  mediaCache: _mediaCache,
                  online: !widget.offline,
                  isLocked: _isLocked,
                  onOpen: _openDetails,
                  onToggleSaved: _toggleRoutine,
                  onCreate: () => _showCustomRoutineBuilder(items),
                  onDelete: _customMutationBusy ? null : _deleteCustomRoutine,
                  onComplete: _logCustomRoutine,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCustomRoutineBuilder(
    List<WellnessContentItem> items,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: !_customMutationBusy,
      enableDrag: !_customMutationBusy,
      builder: (_) => _CustomWorkoutRoutineBuilder(
        items: items,
        onSave: (routine) =>
            _persistCustomRoutines([..._customRoutines, routine]),
      ),
    );
  }

  Future<void> _deleteCustomRoutine(_CustomWorkoutRoutine routine) async {
    await _persistCustomRoutines(
      _customRoutines
          .where((item) => item.id != routine.id)
          .toList(growable: false),
    );
  }

  Future<void> _openDetails(WellnessContentItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BilWorkoutRoutineDetailsPage(
          item: item,
          initiallySaved: _routineIds.contains(item.stableId),
          onToggleSaved: () => _toggleRoutine(item),
          onLogWorkout: _logTrustedRoutine,
          mediaCache: _mediaCache,
          offline: widget.offline,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _scheduleInitialItem(List<WellnessContentItem> items) {
    if (_initialItemHandled) return;
    final requested = widget.initialItemId?.trim();
    if (requested == null || requested.isEmpty) {
      _initialItemHandled = true;
      return;
    }
    final matches = items.where((item) => item.stableId == requested);
    if (matches.isEmpty) {
      _initialItemHandled = true;
      return;
    }
    _initialItemHandled = true;
    final item = matches.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isLocked(item)) {
        final storefrontPlan = ref.read(storefrontTargetPlanProvider).value;
        context.push(
          storefrontPlan == CommercePlan.premiumAiCoach
              ? '/plans?focus=boost'
              : '/plans?focus=subscription',
        );
        return;
      }
      _openDetails(item);
    });
  }

  bool _isLocked(WellnessContentItem item) {
    final subscription = _usableVerifiedSubscription(
      ref.read(verifiedSubscriptionStateProvider),
    );
    return !workoutAccessGranted(item.minimumAccess, subscription);
  }
}
