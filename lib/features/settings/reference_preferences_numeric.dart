part of 'reference_preferences_pages.dart';

class _StoredNumber extends ConsumerStatefulWidget {
  const _StoredNumber(this.keyName, this.label, this.defaultValue, this.suffix);
  final String keyName;
  final String label;
  final String? defaultValue;
  final String suffix;
  @override
  ConsumerState<_StoredNumber> createState() => _StoredNumberState();
}

@visibleForTesting
bool validStoredNutritionGoal(String key, String suffix, String input) {
  final number = double.tryParse(input);
  if (number == null || !number.isFinite || number < 0) return false;
  if (key == 'goal.calories') return number >= 1 && number <= 10000;
  if (key.endsWith('Percent') || suffix == '%') return number <= 100;
  if (suffix == 'mg') return number <= 1000000;
  return number <= 10000;
}

class _StoredNumberState extends ConsumerState<_StoredNumber> {
  String? value;
  String? retainedDraft;
  bool loading = true;
  bool saving = false;
  Object? error;
  bool editorOpen = false;

  bool _valid(String input) {
    return validStoredNutritionGoal(widget.keyName, widget.suffix, input);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final saved = await ref
          .read(preferencesRepositoryProvider)
          .get(widget.keyName);
      if (!mounted) return;
      final candidate = saved ?? widget.defaultValue;
      setState(() {
        value = candidate != null && _valid(candidate) ? candidate : null;
        loading = false;
      });
    } catch (caught) {
      if (mounted) {
        setState(() {
          loading = false;
          error = caught;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(_nutritionGoalText(context, widget.label)),
    trailing: loading || saving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : error != null
        ? TextButton(
            onPressed: _load,
            child: Text(context.strings.text('Retry')),
          )
        : Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value == null
                  ? '—'
                  : widget.suffix == '%'
                  ? '$value%'
                  : '$value${widget.suffix.isEmpty ? '' : ' ${widget.suffix}'}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF0A6FF5),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
    onTap: loading || saving || error != null
        ? null
        : () async {
            if (editorOpen) return;
            editorOpen = true;
            final controller = TextEditingController(
              text: retainedDraft ?? value ?? '',
            );
            String? next;
            try {
              next = await showDialog<String>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) {
                  var dialogSaving = false;
                  String? dialogError;
                  return StatefulBuilder(
                    builder: (dialogContext, setDialogState) => PopScope(
                      canPop: !dialogSaving,
                      child: AlertDialog(
                        title: Text(_nutritionGoalText(context, widget.label)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: controller,
                              autofocus: true,
                              enabled: !dialogSaving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                            if (dialogError != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                dialogError!,
                                style: TextStyle(
                                  color: Theme.of(
                                    dialogContext,
                                  ).colorScheme.error,
                                ),
                              ),
                            ],
                            if (dialogSaving) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: dialogSaving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            child: Text(context.strings.text('Cancel')),
                          ),
                          FilledButton(
                            onPressed: dialogSaving
                                ? null
                                : () async {
                                    final draft = controller.text.trim();
                                    if (draft.isNotEmpty && !_valid(draft)) {
                                      setDialogState(
                                        () => dialogError = context.strings
                                            .text('Review values and retry.'),
                                      );
                                      return;
                                    }
                                    setDialogState(() {
                                      dialogSaving = true;
                                      dialogError = null;
                                    });
                                    if (mounted) {
                                      setState(() => saving = true);
                                    }
                                    try {
                                      final repository = ref.read(
                                        preferencesRepositoryProvider,
                                      );
                                      if (draft.isEmpty) {
                                        await repository.remove(widget.keyName);
                                      } else {
                                        await repository.set(
                                          widget.keyName,
                                          draft,
                                        );
                                      }
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext, draft);
                                      }
                                    } catch (_) {
                                      if (dialogContext.mounted) {
                                        setDialogState(() {
                                          dialogSaving = false;
                                          dialogError = context.strings.text(
                                            'Could not save changes.',
                                          );
                                        });
                                      }
                                      if (mounted) {
                                        setState(() => saving = false);
                                      }
                                    }
                                  },
                            child: Text(context.strings.text('Save')),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            } finally {
              await WidgetsBinding.instance.endOfFrame;
              await Future<void>.delayed(const Duration(milliseconds: 250));
              controller.dispose();
              editorOpen = false;
            }
            final saved = next;
            if (saved == null || !mounted || !context.mounted) {
              return;
            }
            setState(() {
              value = saved.isEmpty ? null : saved;
              retainedDraft = null;
              saving = false;
            });
          },
  );
}
