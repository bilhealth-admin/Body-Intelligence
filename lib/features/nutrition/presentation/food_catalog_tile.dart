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
    // Resolve the dependency while this ConsumerState is mounted. The async
    // lookup may finish after a route transition; consulting `ref` from that
    // deferred callback would then access an already-unmounted State.
    final repository = ref.read(foodRepositoryProvider);
    Future<void>(() async {
      final rows = await repository.watchFavorites().first;
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
        onSave: (draft) async {
          final localeCode = Localizations.localeOf(context).toLanguageTag();
          await ref
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
              );
          await ref
              .read(communityFoodSyncServiceProvider)
              .publishFood(widget.food.id, localeCode: localeCode);
        },
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
                            final localFoodUuid = widget.food.uuid;
                            await ref
                                .read(foodRepositoryProvider)
                                .deleteCustomFood(widget.food.id);
                            await ref
                                .read(communityFoodSyncServiceProvider)
                                .withdrawFood(localFoodUuid);
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    _FoodNutrientSummary(food: food, expanded: true),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (arabic && food.arabicName?.trim().isNotEmpty == true)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(food.name),
              ),
            const SizedBox(height: 8),
            _FoodNutrientSummary(food: food),
            const SizedBox(height: 6),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${food.servingSize.toStringAsFixed(0)} ${food.servingUnit} · '
                '${food.source} · '
                '${t(food.verified ? 'verified' : 'unverified')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        isThreeLine: false,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 4, 8, 4),
        minVerticalPadding: 6,
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
