import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy_release_polish.dart';
import '../../commerce/domain/subscription_state.dart';
import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/presentation/premium_collection_item_gate.dart';
import '../../commerce/presentation/premium_label_badge.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../domain/static_workout_artwork.dart';
import '../domain/gym_six_month_plan.dart';
import '../domain/wellness_content_pack.dart';
import '../domain/workout_routine_contract.dart';
import '../domain/workout_free_preview_policy.dart';
import '../repositories/gym_six_month_plan_repository.dart';
import '../services/wellness_content_pack_manager.dart';
import '../services/wellness_media_cache.dart';
import 'workout_access_policy.dart';
import 'wellness_copy.dart';
import 'workout_video_group_copy.dart';

part 'bil_workout_routines_list.dart';
part 'bil_workout_routine_details.dart';
part 'bil_workout_routine_media.dart';
part 'bil_workout_routine_presenters.dart';
part 'bil_workout_routine_visuals.dart';
part 'bil_custom_workout_routines.dart';
part 'bil_workout_routines_states.dart';
part 'bil_workout_routines_library.dart';
part 'bil_workout_videos_wall.dart';

typedef WorkoutLibraryLoader =
    Future<List<WellnessContentItem>> Function(String locale);
typedef WorkoutLogHandler = Future<void> Function(WellnessContentItem workout);
typedef CustomRoutineWriter = Future<bool> Function(List<String> encodedRows);
typedef GymPlanLoader = Future<GymSixMonthPlan> Function();

SubscriptionState? _usableVerifiedSubscription(
  AsyncValue<SubscriptionState> snapshot,
) => snapshot.when(
  data: (value) => value,
  error: (_, _) => null,
  loading: () => null,
);

/// A verified, offline-first workout-routine browser.
///
/// The page only renders release-approved discovery items or installed items
/// that passed [WellnessContentPackManager]'s trusted-item boundary. Discovery
/// rows contain no executable routine steps or playable downloaded media. A
/// video surface is shown as playable only when an installed item carries
/// integrity metadata for licensed media; an image or an unverified URL is
/// never presented as a workout video.
class BilWorkoutRoutinesPage extends ConsumerStatefulWidget {
  const BilWorkoutRoutinesPage({
    super.key,
    this.manager,
    this.loader,
    this.onLogWorkout,
    this.mediaCache,
    this.customRoutineWriter,
    this.gymPlanLoader,
    this.offline = false,
    this.initialItemId,
  });

  final WellnessContentPackManager? manager;
  final WorkoutLibraryLoader? loader;
  final WorkoutLogHandler? onLogWorkout;
  final WellnessMediaCache? mediaCache;
  final CustomRoutineWriter? customRoutineWriter;
  final GymPlanLoader? gymPlanLoader;
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
  static const _emptyInjectedGymPlan = GymSixMonthPlan(
    sourcePath: 'injected-catalog',
    sourceContractId: 'injected-catalog',
    sourceSha256: '',
    releaseManifestPath: 'injected-catalog',
    releaseManifestSha256: '',
    months: [],
    sessions: [],
    warmups: GymPlanWarmups(exerciseIds: [], groups: []),
    libraryPages: [],
    exerciseIds: [],
  );

  late final WellnessContentPackManager _manager =
      widget.manager ?? WellnessContentPackManager();
  late final WellnessMediaCache _mediaCache =
      widget.mediaCache ?? WellnessMediaCache();
  late final TabController _tabs;
  final _searchController = TextEditingController();
  Future<List<WellnessContentItem>>? _items;
  late final Future<GymSixMonthPlan> _gymPlan;
  String? _loadedLocale;
  String _query = '';
  String? _category;
  _WorkoutPresenterFilter _presenterFilter = _WorkoutPresenterFilter.all;
  Set<String> _routineIds = const {};
  List<_CustomWorkoutRoutine> _customRoutines = const [];
  bool _customMutationBusy = false;
  bool _initialItemHandled = false;

  /// Owns UI mutations initiated by the split library-surface extension.
  void _mutateWorkoutLibrary(VoidCallback mutation) {
    if (mounted) setState(mutation);
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this)..addListener(_onTabChanged);
    _gymPlan =
        widget.gymPlanLoader?.call() ??
        (widget.loader == null
            ? _loadBundledGymPlan()
            : Future.value(_emptyInjectedGymPlan));
    _loadRoutineIds();
  }

  Future<GymSixMonthPlan> _loadBundledGymPlan() async {
    const repository = GymSixMonthPlanRepository();
    final sources = await Future.wait([
      rootBundle.loadString(GymSixMonthPlanRepository.artifactPath),
      rootBundle.loadString(GymSixMonthPlanRepository.releaseManifestPath),
    ]);
    return repository.parse(
      sources[0],
      releaseManifestBytes: utf8.encode(sources[1]),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
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
          _manager.loadWorkoutLibraryItems(locale: locale);
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
    if (!workoutItemAccessGranted(item, subscription)) {
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
    final compactHeader = MediaQuery.sizeOf(context).width < 520;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: compactHeader ? 72 : null,
        titleSpacing: compactHeader ? 0 : null,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/wellness-library'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          wellnessWorkoutVideosAndRoutinesTitle(context),
          key: const ValueKey('workout-videos-routines-title'),
          maxLines: compactHeader ? 2 : 1,
          overflow: compactHeader
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: compactHeader
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.08,
                )
              : null,
        ),
        actions: [
          IconButton(
            key: const ValueKey('workout-programs-action'),
            tooltip: _copy(context, '10 training categories', '10 فئات تدريب'),
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
            Tab(text: _workoutHubCopy(context, 'Videos')),
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
                return FutureBuilder<GymSixMonthPlan>(
                  future: _gymPlan,
                  builder: (context, planSnapshot) {
                    if (planSnapshot.connectionState != ConnectionState.done) {
                      return const _WorkoutLibraryLoading();
                    }
                    if (planSnapshot.hasError || planSnapshot.data == null) {
                      return _WorkoutLibraryError(
                        offline: widget.offline,
                        onRetry: _reload,
                      );
                    }
                    return _buildLibrary(items, planSnapshot.data!);
                  },
                );
              },
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
    return !workoutItemAccessGranted(item, subscription);
  }
}
