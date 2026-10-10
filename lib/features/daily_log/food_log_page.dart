import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/runtime_copy_food_log.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/theme/bil_semantic_icons.dart';
import '../../app/services/recoverable_image_picker.dart';
import '../../app/services/runtime_permission_policy.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../commerce/presentation/premium_barcode_access.dart';
import '../dashboard/widgets/first_use_context_coachmark.dart';
import '../dashboard/widgets/first_meal_celebration.dart';
import '../profile/providers/user_profile_provider.dart';
import '../commerce/providers/commerce_providers.dart';
import '../foods/providers/food_provider.dart';
import '../nutrition/presentation/food_barcode_scanner_page.dart';
import '../nutrition/presentation/meal_image_review_dialog.dart';
import '../nutrition/presentation/meal_vision_ui_copy.dart';
import '../nutrition/presentation/meal_vision_consent_gate.dart';
import '../nutrition/services/bil_speech_to_text.dart';
import '../nutrition/services/food_presentation_localizer.dart';
import '../nutrition/services/meal_image_analysis_service.dart';
import '../nutrition/services/meal_voice_input_service.dart';
import '../../shared/widgets/bil_camera_capture_page.dart';
import 'domain/food_log_meal_selector.dart';
import 'presentation/quick_macro_entry_dialog.dart';
import 'providers/daily_log_provider.dart';

part 'food_log_actions.dart';

/// Ranked foods shown by the standalone Food Log browse surface.
///
/// The authority already owns the local ranking contract (favorites, usage
/// count, and recency). Keeping this provider here means the new surface uses
/// that existing path without changing the Daily Log pages or their streams.
final foodLogPopularFoodsProvider = FutureProvider.autoDispose<List<Food>>((
  ref,
) async {
  // The standalone surface promotes a food only after more than three
  // confirmed selections. The ordinary Food Log search remains owned by the
  // runtime authority below and is not changed by this browse ranking.
  final repository = ref.read(foodRepositoryProvider);
  return repository.popularFoods(limit: 30);
});

/// Standalone Food Log entry surface based on the supplied reference flow.
///
/// This surface intentionally owns only the Food Log entry experience. The
/// existing Daily Log meal pages remain on their original route and continue
/// to use their original search and capture flows.
class FoodLogPage extends ConsumerStatefulWidget {
  const FoodLogPage({
    super.key,
    this.initialMealType,
    this.initialAction,
    this.directPhotoCapture = false,
    this.initialImage,
    this.returnPath,
    this.preferNavigatorPop = false,
  });

  final String? initialMealType;
  final String? initialAction;
  final bool directPhotoCapture;
  final XFile? initialImage;
  final String? returnPath;
  final bool preferNavigatorPop;

  @override
  ConsumerState<FoodLogPage> createState() => _FoodLogPageState();
}

class _FoodLogPageState extends ConsumerState<FoodLogPage> {
  final search = TextEditingController();
  String mealType = 'breakfast';
  Timer? _searchDebounce;
  List<Food>? searchResults;
  bool searchLoading = false;
  bool mealImageBusy = false;
  bool barcodeBusy = false;
  bool voiceBusy = false;
  bool quickAddBusy = false;
  final Set<int> addingFoodIds = <int>{};
  bool initialCaptureActionApplied = false;
  String? initialCaptureActionInFlight;
  int _searchGeneration = 0;
  bool _firstFoodTour = false;
  String? _tourOwner;

  @override
  void initState() {
    super.initState();
    mealType = normalizeFoodLogMealType(widget.initialMealType);
    _scheduleInitialCaptureAction();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFoodTour());
  }

  @override
  void didUpdateWidget(covariant FoodLogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAction != widget.initialAction ||
        oldWidget.directPhotoCapture != widget.directPhotoCapture) {
      initialCaptureActionApplied = false;
      if (initialCaptureActionInFlight == null) {
        _scheduleInitialCaptureAction();
      }
    }
  }

  String _tourKey(String? owner) =>
      'experience.dashboard_food_guide.v1.${owner ?? 'local'}';

  bool get _tourVisible =>
      _firstFoodTour &&
      _tourOwner == ref.read(preferencesRepositoryProvider).localOwnerId;

  Future<void> _restoreFoodTour() async {
    if (!mounted) return;
    final preferences = ref.read(preferencesRepositoryProvider);
    final owner = preferences.localOwnerId;
    String? state;
    try {
      state = await preferences.get(_tourKey(owner));
    } on Object {
      return;
    }
    if (!mounted ||
        ref.read(preferencesRepositoryProvider).localOwnerId != owner) {
      return;
    }
    setState(() {
      _tourOwner = owner;
      _firstFoodTour = state == 'started';
    });
  }

  Future<void> _dismissFoodTour({bool completed = false}) async {
    if (!_tourVisible) return;
    final preferences = ref.read(preferencesRepositoryProvider);
    final owner = preferences.localOwnerId;
    setState(() => _firstFoodTour = false);
    try {
      await preferences.set(
        _tourKey(owner),
        completed ? 'completed' : 'dismissed',
      );
    } on Object {
      // Skip works immediately, even when local preferences are unavailable.
    }
  }

  void _scheduleInitialCaptureAction() {
    final action = widget.initialAction;
    if (!const {'barcode', 'voice', 'photo'}.contains(action) ||
        initialCaptureActionApplied ||
        initialCaptureActionInFlight != null) {
      return;
    }
    initialCaptureActionApplied = true;
    initialCaptureActionInFlight = action;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.initialAction != action) {
        initialCaptureActionInFlight = null;
        if (mounted &&
            const {
              'barcode',
              'voice',
              'photo',
            }.contains(widget.initialAction) &&
            !initialCaptureActionApplied) {
          _scheduleInitialCaptureAction();
        }
        return;
      }
      try {
        final completed = switch (action) {
          'barcode' => await _scanBarcode(),
          'voice' => await _voiceSearch(),
          _ => await _runInitialPhotoCapture(),
        };
        // Quick Add is a one-shot task. Cancelling the native scanner, voice
        // sheet, or photo picker returns to the validated caller instead of
        // silently dropping the member on Today/Food Log.
        if (mounted && !completed) _close(context);
      } finally {
        if (initialCaptureActionInFlight == action) {
          initialCaptureActionInFlight = null;
          if (mounted &&
              const {
                'barcode',
                'voice',
                'photo',
              }.contains(widget.initialAction) &&
              !initialCaptureActionApplied) {
            _scheduleInitialCaptureAction();
          }
        }
      }
    });
  }

  Future<bool> _runInitialPhotoCapture() async {
    await _analyzeMealImage(
      directCamera: widget.directPhotoCapture,
      initialImage: widget.initialImage,
    );
    // Photo capture owns its existing review/consent flow. It may remain on
    // Food Log after a handled result; only barcode/voice expose a definitive
    // null cancellation result at this boundary.
    return true;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    search.dispose();
    super.dispose();
  }

  String _t(BuildContext context, String value) => context.strings.text(value);

  String _mealTitle(BuildContext context, String type) =>
      _t(context, foodLogMealTitle(type));

  void _updateState(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodsProvider);
    final popularFoods = ref.watch(foodLogPopularFoodsProvider);
    final date = ref.watch(selectedLogDateProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            IconButton(
              key: const Key('food-log-close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => _close(context),
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('food-log-select-meal'),
                  value: mealType,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                  onChanged: (value) {
                    if (value == null || value == mealType) return;
                    setState(() => mealType = value);
                  },
                  items: [
                    for (final type in foodLogMealTypes)
                      DropdownMenuItem(
                        value: type,
                        child: Text(_mealTitle(context, type)),
                      ),
                  ],
                ),
              ),
            ),
            Text(
              '${date.day}/${date.month}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: foods.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(foodsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_t(context, 'Retry')),
          ),
        ),
        data: (items) => mealImageBusy
            ? Center(
                key: const Key('food-log-meal-analysis-progress'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      '${_t(context, 'Analyze a meal photo')}…',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              )
            : _buildBody(context, items, rankedFoods: popularFoods.value),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<Food> foods, {
    List<Food>? rankedFoods,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final browseFoods = rankedFoods != null && rankedFoods.isNotEmpty
        ? rankedFoods
        : foods;
    final rawQuery = search.text.trim();
    final query = rawQuery.toLowerCase();
    final interfaceLocale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final resultLocale = FoodPresentationLocalizer.resultLocaleForQuery(
      query: rawQuery,
      interfaceLocaleTag: interfaceLocale,
    );
    final browseResults = browseFoods
        .where((food) {
          if (query.isEmpty) return true;
          return food.name.toLowerCase().contains(query) ||
              (food.arabicName?.toLowerCase().contains(query) ?? false);
        })
        .take(30)
        .toList(growable: false);
    final filtered = query.isEmpty
        ? browseResults
        : (searchResults ?? const <Food>[])
              .where(
                (food) => FoodPresentationLocalizer.hasSafeSearchDisplayName(
                  name: food.name,
                  arabicName: food.arabicName,
                  localeTag: resultLocale,
                  isCustom: food.isCustom,
                  source: food.source,
                ),
              )
              .toList(growable: false);
    return ListView(
      key: const Key('food-log-reference-page'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        if (_tourVisible && query.isEmpty) ...[
          FirstUseContextCoachmark(
            key: const Key('food-log-search-guide'),
            compact: true,
            title: _foodTourText(
              context,
              en: 'Find something delicious',
              ar: 'ابحث عن طعامك',
            ),
            message: _foodTourText(
              context,
              en: 'Type a food name here. You can always skip this tour.',
              ar: 'اكتب اسم الطعام في البحث. يمكنك تخطي الإرشادات في أي وقت.',
            ),
            icon: Icons.search_rounded,
            onSkip: _dismissFoodTour,
            skipKey: const Key('food-log-search-guide-skip'),
          ),
          const SizedBox(height: 8),
        ],
        SearchBar(
          key: const Key('food-log-search'),
          controller: search,
          hintText: _t(context, _searchHintKey()),
          leading: Icon(Icons.search_rounded, color: scheme.primary),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.primary.withValues(alpha: .18)),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
          ),
          trailing: [
            if (search.text.isNotEmpty)
              IconButton(
                tooltip: _t(context, 'Clear'),
                onPressed: () {
                  search.clear();
                  _searchDebounce?.cancel();
                  _searchGeneration++;
                  setState(() {
                    searchResults = null;
                    searchLoading = false;
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
          ],
          onChanged: _scheduleSearch,
        ),
        const SizedBox(height: 10),
        _buildActions(context),
        if (searchLoading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 14),
        if (_tourVisible && query.isNotEmpty && filtered.isNotEmpty) ...[
          FirstUseContextCoachmark(
            key: const Key('food-log-choose-guide'),
            compact: true,
            title: _foodTourText(
              context,
              en: 'Choose the right food',
              ar: 'اختر الطعام الصحيح',
            ),
            message: _foodTourText(
              context,
              en: 'Tap + next to a matching food. Review the serving before saving.',
              ar: 'اضغط + بجانب الطعام المناسب، ثم راجع الكمية قبل الحفظ.',
            ),
            icon: Icons.touch_app_rounded,
            accent: const Color(0xFF9BCBFF),
            onSkip: _dismissFoodTour,
            skipKey: const Key('food-log-choose-guide-skip'),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          _t(context, 'Most popular'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (filtered.isEmpty) _buildEmptyState(context),
        if (filtered.isNotEmpty)
          for (final food in filtered)
            _buildFoodTile(
              context,
              food,
              localeTag: query.isEmpty ? interfaceLocale : resultLocale,
            ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              _t(context, 'No foods found'),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  String _foodTourText(
    BuildContext context, {
    required String en,
    required String ar,
  }) => Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  String _searchHintKey() => FoodLogRuntimeCopy.searchHint;

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    _searchGeneration++;
    if (query.isEmpty) {
      setState(() {
        searchResults = null;
        searchLoading = false;
      });
      return;
    }
    setState(() {
      searchResults = null;
      searchLoading = true;
    });
    final generation = _searchGeneration;
    _searchDebounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final result = await ref
            .read(foodRuntimeSearchAuthorityProvider)
            .search(query, limit: 30);
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          searchResults = result.take(30).toList(growable: false);
          searchLoading = false;
        });
      } on Object {
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          searchResults = const <Food>[];
          searchLoading = false;
        });
      }
    });
  }

  Widget _buildActions(BuildContext context) {
    final actions =
        <({String keyId, IconData icon, String label, VoidCallback onTap})>[
          (
            keyId: 'Barcode scan',
            icon: Icons.qr_code_scanner_rounded,
            label: _t(context, 'Scan a barcode'),
            onTap: _scanBarcode,
          ),
          (
            keyId: 'Voice log',
            icon: Icons.mic_none_rounded,
            label: _t(context, 'Log with your voice'),
            onTap: _voiceSearch,
          ),
          (
            keyId: 'Analyze meal photo',
            icon: Icons.photo_camera_outlined,
            label: _t(context, 'Analyze a meal photo'),
            onTap: _analyzeMealImage,
          ),
          (
            keyId: 'Quick add',
            icon: Icons.add_circle_outline_rounded,
            label: _t(context, 'Quick Add'),
            onTap: _showQuickAdd,
          ),
        ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: actions.length,
      crossAxisSpacing: 8,
      childAspectRatio: 1.18,
      children: [
        for (final action in actions)
          _buildActionTile(
            key: Key('food-log-action-${action.keyId}'),
            icon: action.icon,
            label: action.label,
            onTap: action.onTap,
          ),
      ],
    );
  }

  Widget _buildActionTile({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      key: key,
      margin: EdgeInsets.zero,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: const Color(0xFF1677D2)),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodTile(
    BuildContext context,
    Food food, {
    required String localeTag,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final name = FoodPresentationLocalizer.foodName(
      name: food.name,
      arabicName: food.arabicName,
      localeTag: localeTag,
      isCustom: food.isCustom,
      source: food.source,
    );
    return Card(
      key: Key('food-log-food-${food.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: food.verified
              ? const Color(0xFFE2F8EC)
              : accent.withValues(alpha: .10),
          child: Icon(
            food.verified
                ? Icons.verified_rounded
                : food.isCustom
                ? Icons.person_rounded
                : Icons.shield_outlined,
            color: food.verified ? const Color(0xFF087A43) : accent,
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${food.calories.round()} kcal · ${food.servingSize} ${food.servingUnit}',
        ),
        trailing: IconButton(
          key: Key('food-log-add-${food.id}'),
          tooltip: _t(context, 'Add'),
          onPressed: () => _addFood(context, food),
          icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF1677D2)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 70),
    child: Column(
      children: [
        const BilSemanticIconBadge(
          kind: BilSemanticIconKind.foodSearch,
          size: 74,
        ),
        const SizedBox(height: 20),
        Text(
          _t(context, 'No foods found'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _t(context, 'Create and save your favorites for quick logging.'),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  void _close(BuildContext context) {
    if (widget.preferNavigatorPop && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go(widget.returnPath ?? '/dashboard');
  }
}
