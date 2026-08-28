import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A fast horizontal scale for measurements with a wide range.
///
/// Unlike the precise vertical wheel, this control lets a high-weight user
/// jump across the full range in one drag while retaining one-step arrow and
/// screen-reader adjustments. The selected value stays visible above the
/// moving indicator like a digital scale readout.
class SmartWeightScaleField extends StatelessWidget {
  const SmartWeightScaleField({
    super.key,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.step,
    required this.decimalPlaces,
    required this.unit,
    required this.label,
    required this.onChanged,
  });

  final double value;
  final double minimum;
  final double maximum;
  final double step;
  final int decimalPlaces;
  final String unit;
  final String label;
  final ValueChanged<double> onChanged;

  int get _divisions => ((maximum - minimum) / step).round();

  double _stepped(double next) {
    final index = ((next - minimum) / step).round().clamp(0, _divisions);
    return minimum + index * step;
  }

  void _adjust(int direction) => onChanged(_stepped(value + step * direction));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatted = value.toStringAsFixed(decimalPlaces);
    return Semantics(
      key: const Key('smart-weight-scale-field'),
      label: '$label, $formatted $unit',
      value: formatted,
      increasedValue: _stepped(value + step).toStringAsFixed(decimalPlaces),
      decreasedValue: _stepped(value - step).toStringAsFixed(decimalPlaces),
      onIncrease: () => _adjust(1),
      onDecrease: () => _adjust(-1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            key: const Key('smart-weight-scale-readout'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: .58),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.primary.withValues(alpha: .38)),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: formatted,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: '  $unit',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.outlined(
                key: const Key('smart-weight-scale-decrease'),
                tooltip: '-${step.toStringAsFixed(decimalPlaces)} $unit',
                onPressed: value <= minimum ? null : () => _adjust(-1),
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    activeTrackColor: scheme.primary,
                    inactiveTrackColor: scheme.surfaceContainerHighest,
                    thumbColor: scheme.primary,
                    overlayColor: scheme.primary.withValues(alpha: .14),
                    valueIndicatorColor: scheme.primary,
                    showValueIndicator: ShowValueIndicator.onlyForDiscrete,
                  ),
                  child: Slider(
                    key: const Key('smart-weight-scale-slider'),
                    value: value.clamp(minimum, maximum),
                    min: minimum,
                    max: maximum,
                    divisions: _divisions,
                    label: '$formatted $unit',
                    onChanged: (next) => onChanged(_stepped(next)),
                  ),
                ),
              ),
              IconButton.outlined(
                key: const Key('smart-weight-scale-increase'),
                tooltip: '+${step.toStringAsFixed(decimalPlaces)} $unit',
                onPressed: value >= maximum ? null : () => _adjust(1),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${minimum.toStringAsFixed(0)} $unit',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${maximum.toStringAsFixed(0)} $unit',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
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
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<WheelNumberField> createState() => _WheelNumberFieldState();
}

class _WheelNumberFieldState extends State<WheelNumberField> {
  late FixedExtentScrollController wheel;
  late TextEditingController text;
  late FocusNode focus;
  late bool _ownsFocusNode;
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
    _ownsFocusNode = widget.focusNode == null;
    focus = widget.focusNode ?? FocusNode();
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
        if (wheel.hasClients) {
          wheel.jumpToItem(indexFor(widget.value));
        }
      });
    }
  }

  @override
  void dispose() {
    wheel.dispose();
    text.dispose();
    if (_ownsFocusNode) {
      focus.dispose();
    }
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

    // تأمين هندسي: تقريب الرقم المدخل يدوياً إلى أقرب خطوة (Step) مدعومة في الـ Wheel
    final targetIndex = indexFor(parsed);
    final steppedValue = valueFor(targetIndex);

    widget.onChanged(steppedValue);

    if (wheel.hasClients) {
      wheel.animateToItem(
        targetIndex,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }

    if (commit) {
      _syncTextFromValue(steppedValue);
    }
  }

  void _syncTextFromValue([double? value]) {
    final effective = value ?? widget.value;
    final formattedText = effective.toStringAsFixed(widget.decimalPlaces);
    text.value = TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
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
                          if (_editingText) {
                            return; // منع تداخل الأحداث أثناء الكتابة باليد
                          }
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
                              onTap: () {
                                if (wheel.hasClients) {
                                  wheel.animateToItem(
                                    index,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                  );
                                }
                              },
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
                  child: Focus(
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      // تعديل الاتجاه هندسياً ليتوافق مع حركة الأسهم الطبيعية للمستخدم
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        adjustBy(1);
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        adjustBy(-1);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          // تصحيح اتجاه سكرول الماوس ليكون طبيعياً (Up يزيد، Down ينقص)
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
                        textInputAction: widget.textInputAction,
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
                          widget.onSubmitted?.call();
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
