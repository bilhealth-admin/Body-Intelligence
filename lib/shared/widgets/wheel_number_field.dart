import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WheelNumberField extends StatefulWidget {
  const WheelNumberField({
    super.key,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.step,
    required this.decimalPlaces,
    required this.unit,
    required this.label,
    required this.onChanged,
    this.errorText,
  });

  final double value;
  final double minimum;
  final double maximum;
  final double step;
  final int decimalPlaces;
  final String unit;
  final String label;
  final ValueChanged<double> onChanged;
  final String? errorText;

  @override
  State<WheelNumberField> createState() => _WheelNumberFieldState();
}

class _WheelNumberFieldState extends State<WheelNumberField> {
  late FixedExtentScrollController wheel;
  late TextEditingController text;
  late FocusNode focus;
  bool _editingText = false;

  int get itemCount =>
      ((widget.maximum - widget.minimum) / widget.step).round() + 1;
  int indexFor(double value) =>
      ((value - widget.minimum) / widget.step).round().clamp(0, itemCount - 1);
  double valueFor(int index) => widget.minimum + index * widget.step;

  @override
  void initState() {
    super.initState();
    wheel = FixedExtentScrollController(initialItem: indexFor(widget.value));
    text = TextEditingController(
      text: widget.value.toStringAsFixed(widget.decimalPlaces),
    );
    focus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant WheelNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editingText &&
        (oldWidget.value != widget.value || oldWidget.unit != widget.unit)) {
      text.value = TextEditingValue(
        text: widget.value.toStringAsFixed(widget.decimalPlaces),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (wheel.hasClients) wheel.jumpToItem(indexFor(widget.value));
      });
    }
  }

  @override
  void dispose() {
    wheel.dispose();
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  void updateFromText(String raw, {bool commit = false}) {
    final normalized = raw.replaceAll(',', '.').trim();
    if (normalized.isEmpty) {
      return;
    }
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed < widget.minimum || parsed > widget.maximum) {
      if (commit) {
        _syncTextFromValue();
      }
      return;
    }

    widget.onChanged(parsed);
    if (wheel.hasClients) {
      wheel.animateToItem(
        indexFor(parsed),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
    if (commit) {
      _syncTextFromValue(parsed);
    }
  }

  void _syncTextFromValue([double? value]) {
    final effective = value ?? widget.value;
    text.value = TextEditingValue(
      text: effective.toStringAsFixed(widget.decimalPlaces),
      selection: TextSelection.collapsed(
        offset: effective.toStringAsFixed(widget.decimalPlaces).length,
      ),
    );
  }

  void adjustBy(int direction) {
    final current = indexFor(widget.value);
    final next = (current + direction).clamp(0, itemCount - 1);
    if (next == current) return;
    final value = valueFor(next);
    _syncTextFromValue(value);
    widget.onChanged(value);
    if (wheel.hasClients) {
      wheel.animateToItem(
        next,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${widget.label}, ${widget.value.toStringAsFixed(widget.decimalPlaces)} ${widget.unit}',
      value: widget.value.toStringAsFixed(widget.decimalPlaces),
      increasedValue: valueFor(
        (indexFor(widget.value) + 1).clamp(0, itemCount - 1),
      ).toStringAsFixed(widget.decimalPlaces),
      decreasedValue: valueFor(
        (indexFor(widget.value) - 1).clamp(0, itemCount - 1),
      ).toStringAsFixed(widget.decimalPlaces),
      onIncrease: () => adjustBy(1),
      onDecrease: () => adjustBy(-1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer
                              .withValues(alpha: 0.55),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const SizedBox(
                          height: 48,
                          width: double.infinity,
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        controller: wheel,
                        itemExtent: 48,
                        physics: const FixedExtentScrollPhysics(),
                        diameterRatio: 1.35,
                        onSelectedItemChanged: (index) {
                          final value = valueFor(index);
                          text.text = value.toStringAsFixed(
                            widget.decimalPlaces,
                          );
                          HapticFeedback.selectionClick();
                          widget.onChanged(value);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: itemCount,
                          builder: (_, index) => Semantics(
                            button: true,
                            label:
                                '${valueFor(index).toStringAsFixed(widget.decimalPlaces)} ${widget.unit}',
                            child: InkWell(
                              onTap: () => wheel.animateToItem(
                                index,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                              ),
                              child: Center(
                                child: Text(
                                  valueFor(
                                    index,
                                  ).toStringAsFixed(widget.decimalPlaces),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 132,
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        if (event.scrollDelta.dy < 0) {
                          adjustBy(1);
                        } else if (event.scrollDelta.dy > 0) {
                          adjustBy(-1);
                        }
                      }
                    },
                    child: TextField(
                      controller: text,
                      focusNode: focus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onTap: () {
                        _editingText = true;
                      },
                      onChanged: (value) => updateFromText(value),
                      onSubmitted: (_) {
                        _editingText = false;
                        updateFromText(text.text, commit: true);
                      },
                      onEditingComplete: () {
                        _editingText = false;
                        updateFromText(text.text, commit: true);
                      },
                      onTapOutside: (_) {
                        _editingText = false;
                        updateFromText(text.text, commit: true);
                        focus.unfocus();
                      },
                      decoration: InputDecoration(
                        suffixText: widget.unit,
                        errorText: widget.errorText,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
