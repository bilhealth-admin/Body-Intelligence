import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/theme/bil_semantic_icons.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../commerce/presentation/premium_barcode_access.dart';
import '../foods/providers/food_provider.dart';
import '../nutrition/presentation/food_barcode_scanner_page.dart';
import '../nutrition/services/bil_speech_to_text.dart';
import '../nutrition/services/food_presentation_localizer.dart';
import '../nutrition/services/meal_voice_input_service.dart';
import 'domain/food_log_meal_selector.dart';
import 'presentation/quick_macro_entry_dialog.dart';
import 'providers/daily_log_provider.dart';

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
  const FoodLogPage({super.key, this.initialMealType, this.returnPath});

  final String? initialMealType;
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
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    mealType = normalizeFoodLogMealType(widget.initialMealType);
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
        data: (items) =>
            _buildBody(context, items, rankedFoods: popularFoods.value),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<Food> foods, {
    List<Food>? rankedFoods,
  }) {
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
          leading: const Icon(Icons.search_rounded),
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
    final locale = Localizations.localeOf(context).toLanguageTag();
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
        title: Row(
          children: [
            Flexible(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (food.verified) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.verified_rounded,
                size: 17,
                color: Color(0xFF18B875),
              ),
            ],
          ],
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

  Future<void> _addFood(BuildContext context, Food food) async {
    final messenger = ScaffoldMessenger.of(context);
    final addedCopy = _t(context, 'Added to diary');
    final errorCopy = _t(context, 'Could not add food');
    final controller = TextEditingController(text: food.servingSize.toString());
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t(dialogContext, 'Choose a serving')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '${food.servingUnit} ${_t(dialogContext, 'quantity')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t(dialogContext, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: Text(_t(dialogContext, 'Add')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || quantity == null || !quantity.isFinite || quantity <= 0) {
      return;
    }
    try {
      await ref
          .read(mealRepositoryProvider)
          .addReviewedMealItemsAtomically(
            date: ref.read(selectedLogDateProvider),
            mealType: mealType,
            items: [(foodId: food.id, quantity: quantity)],
          );
      try {
        await ref.read(foodRepositoryProvider).recordRecent(food.id);
      } on Object {
        // The diary commit already succeeded. Ranking metadata is best effort
        // and must never make a saved meal look unsuccessful.
      }
      ref.invalidate(foodLogPopularFoodsProvider);
      ref.invalidate(dailyMealsProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(addedCopy)));
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(errorCopy)));
    }
  }

  Future<void> _scanBarcode() async {
    if (!await requestPremiumBarcodeAccess(context, ref) || !mounted) return;
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const FoodBarcodeScannerPage()),
    );
    if (!mounted || barcode == null || barcode.trim().isEmpty) return;
    try {
      final outcome = await ref
          .read(foodRuntimeSearchAuthorityProvider)
          .lookupBarcodeJourney(barcode);
      if (!mounted) return;
      if (outcome.found) {
        search.text = outcome.normalizedBarcode;
        setState(() {
          searchResults = outcome.foods.take(30).toList(growable: false);
          searchLoading = false;
        });
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.invalid
                ? _t(context, 'Invalid barcode')
                : _t(context, 'No verified food matched this barcode'),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(context, 'Barcode lookup failed'))),
      );
    }
  }

  Future<void> _voiceSearch() async {
    final locale = Localizations.localeOf(context);
    final result = await MealVoiceInputService(SpeechToText()).capture(
      context: context,
      localeId: locale.languageCode,
      arabic: locale.languageCode.toLowerCase() == 'ar',
    );
    if (!mounted || result == null || result.foodQuery.trim().isEmpty) return;
    search.text = result.foodQuery.trim();
    _scheduleSearch(search.text);
  }

  Future<void> _showQuickAdd() async {
    final locale = Localizations.localeOf(context);
    String copy(String english, String arabic) =>
        locale.languageCode.toLowerCase() == 'ar' ? arabic : english;
    final saved = await showQuickMacroEntryDialog(
      context: context,
      copy: copy,
      mealLabel: _mealTitle(context, mealType),
      onSave: (draft) async {
        final date = ref.read(selectedLogDateProvider);
        await ref
            .read(mealRepositoryProvider)
            .addQuickMacroEntry(
              date: date,
              mealType: mealType,
              calories: draft.calories,
              protein: draft.protein,
              carbohydrates: draft.carbohydrates,
              fat: draft.fat,
              caloriesKnown: draft.caloriesKnown,
              proteinKnown: draft.proteinKnown,
              carbohydratesKnown: draft.carbohydratesKnown,
              fatKnown: draft.fatKnown,
              occurredAt: DateTime(
                date.year,
                date.month,
                date.day,
                draft.time.hour,
                draft.time.minute,
              ),
            );
      },
    );
    if (!mounted || saved != true) return;
    ref.invalidate(dailyMealsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t(context, 'Quick Add saved locally.'))),
    );
  }

  void _close(BuildContext context) {
    context.go('/dashboard');
  }
}
