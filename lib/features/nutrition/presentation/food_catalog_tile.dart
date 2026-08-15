part of '../food_page.dart';

class _FoodTile extends ConsumerStatefulWidget {
  const _FoodTile({required this.food, required this.onChanged});
  final Food food;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_FoodTile> createState() => _FoodTileState();
}

class _FoodTileState extends ConsumerState<_FoodTile> {
  bool favorite = false;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final rows = await ref
          .read(foodRepositoryProvider)
          .watchFavorites()
          .first;
      if (mounted) {
        setState(
          () => favorite = rows.any((food) => food.id == widget.food.id),
        );
      }
    });
  }

  Future<void> _edit() async {
    final draft = await showDialog<_FoodDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CustomFoodDialog(
        food: widget.food,
        onSave: (draft) => ref
            .read(foodRepositoryProvider)
            .updateCustomFood(
              id: widget.food.id,
              name: draft.name,
              arabicName: draft.arabicName,
              barcode: draft.barcode,
              category: 'custom',
              servingSize: draft.servingSize,
              servingUnit: draft.servingUnit,
              calories: draft.calories,
              protein: draft.protein,
              carbs: draft.carbs,
              fats: draft.fats,
              caloriesKnown: draft.caloriesKnown,
              proteinKnown: draft.proteinKnown,
              carbsKnown: draft.carbsKnown,
              fatsKnown: draft.fatsKnown,
              fiber: draft.fiber,
              sodium: draft.sodium,
              potassium: draft.potassium,
              calcium: draft.calcium,
              magnesium: draft.magnesium,
              sugar: draft.sugar,
            ),
      ),
    );
    if (draft == null) return;
    await widget.onChanged();
  }

  Future<void> _delete() async {
    var busy = false;
    String? error;
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return PopScope(
            canPop: !busy,
            child: AlertDialog(
              title: Text(context.strings.text('Delete custom food?')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.strings.text(
                      'Existing meal history keeps its nutrition snapshot. This food will no longer appear in search.',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: Text(context.strings.text('Cancel')),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setDialogState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await ref
                                .read(foodRepositoryProvider)
                                .deleteCustomFood(widget.food.id);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (_) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                busy = false;
                                error = context.strings.text(
                                  'Could not delete this food. Try again.',
                                );
                              });
                            }
                          }
                        },
                  child: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.strings.text('Delete')),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (deleted == true) {
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    final food = widget.food;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          constraints: const BoxConstraints(maxWidth: 720),
          builder: (context) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height - 96,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      food.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (food.arabicName != null) Text(food.arabicName!),
                    const SizedBox(height: 12),
                    // Provenance labels are authoritative identifiers, not UI
                    // copy. Translating them can alter the cited dataset and
                    // also routes arbitrary catalog data through RuntimeCopy.
                    Text('${t('Source')}: ${food.source}'),
                    Text(
                      food.verified
                          ? t('Verified catalog record')
                          : t('Not independently verified'),
                    ),
                    Text(
                      '${t('Normalized serving')}: ${food.servingSize.toStringAsFixed(0)} ${food.servingUnit}',
                    ),
                    Text(
                      '${t('Updated locally')}: ${food.updatedAt.toLocal()}',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${food.calories.toStringAsFixed(0)} kcal · ${food.protein.toStringAsFixed(1)} g protein · '
                      '${food.carbs.toStringAsFixed(1)} g carbs · ${food.fats.toStringAsFixed(1)} g fat',
                      textDirection: TextDirection.ltr,
                    ),
                    if (food.isCustom) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _edit();
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(t('Edit custom food')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _delete();
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: Text(t('Delete')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        title: Text(
          arabic && food.arabicName?.trim().isNotEmpty == true
              ? food.arabicName!.trim()
              : food.name,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (arabic && food.arabicName?.trim().isNotEmpty == true)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(food.name),
              ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${food.calories.toStringAsFixed(0)} kcal · '
                '${food.protein.toStringAsFixed(1)} g ${nutritionText(context, 'protein', 'بروتين')} · '
                '${food.carbs.toStringAsFixed(1)} g ${nutritionText(context, 'carbs', 'كربوهيدرات')} · '
                '${food.fats.toStringAsFixed(1)} g ${nutritionText(context, 'fat', 'دهون')}',
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${food.fiber.toStringAsFixed(1)} g ${nutritionText(context, 'fiber', 'ألياف')} · '
                '${food.sodium.toStringAsFixed(0)} mg ${nutritionText(context, 'sodium', 'صوديوم')} · '
                '${food.potassium.toStringAsFixed(0)} mg ${nutritionText(context, 'potassium', 'بوتاسيوم')}',
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${food.servingSize.toStringAsFixed(0)} ${food.servingUnit} · '
                '${food.source} · '
                '${t(food.verified ? 'verified' : 'unverified')}',
              ),
            ),
          ],
        ),
        isThreeLine: false,
        trailing: IconButton(
          tooltip: t(favorite ? 'Remove favorite' : 'Add favorite'),
          icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
          onPressed: () async {
            final next = !favorite;
            await ref.read(foodRepositoryProvider).setFavorite(food.id, next);
            if (mounted) setState(() => favorite = next);
          },
        ),
      ),
    );
  }
}
