import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/theme/bil_semantic_icons.dart';
import '../../app/services/recoverable_image_picker.dart';
import '../../app/services/runtime_permission_policy.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../commerce/presentation/premium_barcode_access.dart';
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
  });

  final String? initialMealType;
  final String? initialAction;
  final bool directPhotoCapture;
  final XFile? initialImage;
  final String? returnPath;

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
  bool initialPhotoActionApplied = false;
  String? initialPhotoActionInFlight;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    mealType = normalizeFoodLogMealType(widget.initialMealType);
    _scheduleInitialPhotoAction();
  }

  @override
  void didUpdateWidget(covariant FoodLogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAction != widget.initialAction ||
        oldWidget.directPhotoCapture != widget.directPhotoCapture) {
      initialPhotoActionApplied = false;
      if (initialPhotoActionInFlight == null) {
        _scheduleInitialPhotoAction();
      }
    }
  }

  void _scheduleInitialPhotoAction() {
    final action = widget.initialAction;
    if (action != 'photo' ||
        initialPhotoActionApplied ||
        initialPhotoActionInFlight != null) {
      return;
    }
    initialPhotoActionApplied = true;
    initialPhotoActionInFlight = action;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.initialAction != action) {
        initialPhotoActionInFlight = null;
        if (mounted &&
            widget.initialAction == 'photo' &&
            !initialPhotoActionApplied) {
          _scheduleInitialPhotoAction();
        }
        return;
      }
      try {
        await _analyzeMealImage(
          directCamera: widget.directPhotoCapture,
          initialImage: widget.initialImage,
        );
      } finally {
        if (initialPhotoActionInFlight == action) {
          initialPhotoActionInFlight = null;
          if (mounted &&
              widget.initialAction == 'photo' &&
              !initialPhotoActionApplied) {
            _scheduleInitialPhotoAction();
          }
        }
      }
    });
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
                      '${_t(context, 'Analyze meal photo')}…',
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
    final query = search.text.trim().toLowerCase();
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
        : (searchResults ?? const <Food>[]);
    return ListView(
      key: const Key('food-log-reference-page'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
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
        Text(
          _t(context, 'Most popular'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (filtered.isEmpty) _buildEmptyState(context),
        if (filtered.isNotEmpty)
          for (final food in filtered) _buildFoodTile(context, food),
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

  String _searchHintKey() => 'Search foods, brands, flavors…';

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
    final actions = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.qr_code_scanner_rounded,
        label: _t(context, 'Barcode scan'),
        onTap: _scanBarcode,
      ),
      (
        icon: Icons.mic_none_rounded,
        label: _t(context, 'Voice log'),
        onTap: _voiceSearch,
      ),
      (
        icon: Icons.photo_camera_outlined,
        label: _t(context, 'Analyze meal photo'),
        onTap: _analyzeMealImage,
      ),
      (
        icon: Icons.add_circle_outline_rounded,
        label: _t(context, 'Quick add'),
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
            key: Key('food-log-action-${action.label}'),
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

  Widget _buildFoodTile(BuildContext context, Food food) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final name = FoodPresentationLocalizer.foodName(
      name: food.name,
      arabicName: food.arabicName,
      localeTag: locale,
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
    context.go(widget.returnPath ?? '/dashboard');
  }
}
