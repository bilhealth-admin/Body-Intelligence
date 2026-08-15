part of '../bil_flagship_onboarding.dart';

class _CanvasNumberEditor extends StatefulWidget {
  const _CanvasNumberEditor({required this.config, required this.isArabic});

  final _EditorConfig config;
  final bool isArabic;

  @override
  State<_CanvasNumberEditor> createState() => _CanvasNumberEditorState();
}

class _CanvasNumberEditorState extends State<_CanvasNumberEditor> {
  late final List<int> wholeValues;
  late final FixedExtentScrollController wholeController;
  late final FixedExtentScrollController precisionController;
  late int selectedWhole;
  late int selectedPrecision;
  Timer? autoCloseTimer;

  bool get isWeight => widget.config.unit == 'kg' || widget.config.unit == 'lb';

  @override
  void initState() {
    super.initState();
    final minWhole = widget.config.min.floor();
    final maxWhole = widget.config.max.ceil();
    wholeValues = [
      for (var value = minWhole; value <= maxWhole; value++) value,
    ];

    final seed = (widget.config.value ?? _recommendedValue()).clamp(
      widget.config.min,
      widget.config.max,
    );
    selectedWhole = seed.floor();
    selectedPrecision = ((seed - selectedWhole) * 10).round().clamp(0, 9);

    wholeController = FixedExtentScrollController(
      initialItem: (selectedWhole - minWhole).clamp(0, wholeValues.length - 1),
    );
    precisionController = FixedExtentScrollController(
      initialItem: selectedPrecision,
    );
  }

  double _recommendedValue() {
    final title = widget.config.title.toLowerCase();
    if (isWeight) return widget.config.unit == 'kg' ? 90 : 198;
    if (title.contains('waist') || title.contains('خصر')) return 95;
    if (title.contains('height') || title.contains('طول')) return 175;
    return (widget.config.min + widget.config.max) / 2;
  }

  double get selectedValue => selectedWhole + selectedPrecision / 10;

  String get precisionUnit {
    if (widget.config.unit == 'kg') return 'g';
    if (widget.config.unit == 'cm') return 'mm';
    return widget.config.unit == 'lb' ? '0.1 lb' : '0.1 in';
  }

  String precisionLabel(int index) {
    if (widget.config.unit == 'kg') return '${index * 100}';
    if (widget.config.unit == 'cm') return '$index';
    return '.$index';
  }

  void _scheduleAutoSave() {
    autoCloseTimer?.cancel();
    autoCloseTimer = Timer(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      Navigator.pop(context, _EditorResult.value(selectedValue));
    });
  }

  @override
  void dispose() {
    autoCloseTimer?.cancel();
    wholeController.dispose();
    precisionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Material(
          color: Colors.transparent,
          child: _GlassPanel(
            radius: 32,
            glow: true,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 44),
                    Expanded(
                      child: Text(
                        widget.config.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.4,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _bodyCanvasText(context, 'Save', 'حفظ'),
                      onPressed: () => Navigator.pop(
                        context,
                        _EditorResult.value(selectedValue),
                      ),
                      icon: const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
                Text(
                  _bodyCanvasText(
                    context,
                    'Choose value and precision — saves automatically',
                    'اختر القيمة والدقة — تُحفظ تلقائيًا',
                  ),
                  style: const TextStyle(
                    color: _BilColors.textDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _BilColors.blue.withValues(alpha: .36),
                              _BilColors.cyan.withValues(alpha: .20),
                              _BilColors.emerald.withValues(alpha: .28),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _BilColors.cyan.withValues(alpha: .62),
                            width: 1.35,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _BilColors.cyan.withValues(alpha: .22),
                              blurRadius: 34,
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PrecisionWheel(
                            width: 175,
                            controller: wholeController,
                            count: wholeValues.length,
                            labelBuilder: (index) => '${wholeValues[index]}',
                            unit: widget.config.unit,
                            onChanged: (index) {
                              setState(() {
                                selectedWhole = wholeValues[index];
                              });
                              _scheduleAutoSave();
                            },
                          ),
                          const SizedBox(width: 18),
                          Container(
                            width: 1,
                            height: 132,
                            color: Colors.white.withValues(alpha: .12),
                          ),
                          const SizedBox(width: 18),
                          _PrecisionWheel(
                            width: 150,
                            controller: precisionController,
                            count: 10,
                            labelBuilder: precisionLabel,
                            unit: precisionUnit,
                            onChanged: (index) {
                              setState(() => selectedPrecision = index);
                              _scheduleAutoSave();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.config.optional) ...[
                  const SizedBox(height: 7),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, const _EditorResult.clear()),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    label: Text(
                      _bodyCanvasText(context, 'Not now', 'ليس الآن'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrecisionWheel extends StatelessWidget {
  const _PrecisionWheel({
    required this.width,
    required this.controller,
    required this.count,
    required this.labelBuilder,
    required this.unit,
    required this.onChanged,
  });

  final double width;
  final FixedExtentScrollController controller;
  final int count;
  final String Function(int index) labelBuilder;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Expanded(
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: 62,
              diameterRatio: 1.55,
              perspective: .003,
              physics: const FixedExtentScrollPhysics(),
              overAndUnderCenterOpacity: .28,
              onSelectedItemChanged: onChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: count,
                builder: (context, index) => Center(
                  child: Text(
                    labelBuilder(index),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              color: _BilColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthDateEditor extends StatefulWidget {
  const _BirthDateEditor({required this.initialDate, required this.isArabic});

  final DateTime? initialDate;
  final bool isArabic;

  @override
  State<_BirthDateEditor> createState() => _BirthDateEditorState();
}

class _BirthDateEditorState extends State<_BirthDateEditor> {
  late int day;
  late int month;
  late int year;
  late final List<int> years;
  late final FixedExtentScrollController dayController;
  late final FixedExtentScrollController monthController;
  late final FixedExtentScrollController yearController;
  Timer? autoCloseTimer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = widget.initialDate ?? DateTime(now.year - 30, 1, 1);
    day = initial.day;
    month = initial.month;
    year = initial.year;
    years = List<int>.generate(85, (index) => now.year - 16 - index);
    dayController = FixedExtentScrollController(initialItem: day - 1);
    monthController = FixedExtentScrollController(initialItem: month - 1);
    yearController = FixedExtentScrollController(
      initialItem: years.indexOf(year).clamp(0, years.length - 1),
    );
  }

  DateTime get selectedDate {
    final maxDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, maxDay));
  }

  void _scheduleAutoSave() {
    autoCloseTimer?.cancel();
    autoCloseTimer = Timer(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      Navigator.pop(context, selectedDate);
    });
  }

  @override
  void dispose() {
    autoCloseTimer?.cancel();
    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Material(
          color: Colors.transparent,
          child: _GlassPanel(
            radius: 32,
            glow: true,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 44),
                    Expanded(
                      child: Text(
                        _bodyCanvasText(
                          context,
                          'Date of birth',
                          'تاريخ الميلاد',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _bodyCanvasText(context, 'Save', 'حفظ'),
                      onPressed: () => Navigator.pop(context, selectedDate),
                      icon: const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
                Text(
                  _bodyCanvasText(
                    context,
                    'Choose day, month and year — saves automatically',
                    'اختر اليوم والشهر والسنة — تُحفظ تلقائيًا',
                  ),
                  style: const TextStyle(
                    color: _BilColors.textDim,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 252,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 66,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _BilColors.blue.withValues(alpha: .30),
                              _BilColors.cyan.withValues(alpha: .18),
                              _BilColors.emerald.withValues(alpha: .24),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _BilColors.cyan.withValues(alpha: .52),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _DateWheel(
                              controller: dayController,
                              count: 31,
                              labelBuilder: (index) => '${index + 1}',
                              onChanged: (index) {
                                setState(() => day = index + 1);
                                _scheduleAutoSave();
                              },
                            ),
                          ),
                          Expanded(
                            child: _DateWheel(
                              controller: monthController,
                              count: 12,
                              labelBuilder: (index) =>
                                  _bodyCanvasMonth(context, index),
                              onChanged: (index) {
                                setState(() => month = index + 1);
                                _scheduleAutoSave();
                              },
                            ),
                          ),
                          Expanded(
                            child: _DateWheel(
                              controller: yearController,
                              count: years.length,
                              labelBuilder: (index) => '${years[index]}',
                              onChanged: (index) {
                                setState(() => year = years[index]);
                                _scheduleAutoSave();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateWheel extends StatelessWidget {
  const _DateWheel({
    required this.controller,
    required this.count,
    required this.labelBuilder,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 58,
      diameterRatio: 1.6,
      perspective: .003,
      physics: const FixedExtentScrollPhysics(),
      overAndUnderCenterOpacity: .32,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) => Center(
          child: Text(
            labelBuilder(index),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetChoice<T> {
  const _SheetChoice(this.value, this.label, this.icon);

  final T value;
  final String label;
  final IconData icon;
}

class _CanvasChoiceSheet<T> extends StatelessWidget {
  const _CanvasChoiceSheet({
    required this.title,
    required this.current,
    required this.choices,
  });

  final String title;
  final T current;
  final List<_SheetChoice<T>> choices;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: media.size.height * .80,
        ),
        child: Material(
          color: Colors.transparent,
          child: _GlassPanel(
            radius: 30,
            glow: true,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .42),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 44),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final choice in choices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _ChoiceTile<T>(
                              data: _ChoiceData(
                                value: choice.value,
                                icon: choice.icon,
                                title: choice.label,
                              ),
                              selected: choice.value == current,
                              onTap: () =>
                                  Navigator.pop<T>(context, choice.value),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
