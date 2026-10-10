part of 'meal_vision_premium_review.dart';

extension _PremiumVisionVisuals on _PremiumVisionReviewDialogState {
  Widget _photo(BuildContext context) {
    final path = _sourceImagePath;
    if (path == null || path.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: _glassDecoration(context),
        child: Row(
          children: [
            Icon(
              Icons.no_photography_outlined,
              color: _secondary(context),
              size: 23,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _word(
                  context,
                  'Photo unavailable. No substitute image is shown.',
                  'الصورة غير متاحة، ولن نعرض صورة بديلة على أنها صورتك.',
                ),
                style: TextStyle(color: _secondary(context), fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    final photoHeight = MediaQuery.sizeOf(context).height >= 760
        ? 238.0
        : 168.0;
    return Semantics(
      label: _word(
        context,
        'Your original meal photo. Tap to zoom.',
        'صورتك الأصلية للوجبة. اضغط لتكبيرها.',
      ),
      button: true,
      child: InkWell(
        key: const Key('premium-vision-photo'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (zoomContext) => Dialog(
            child: Stack(
              children: [
                InteractiveViewer(
                  child: Image.file(
                    File(path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: IconButton(
                    tooltip: _word(context, 'Close photo', 'إغلاق الصورة'),
                    onPressed: () => Navigator.pop(zoomContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              SizedBox(
                height: photoHeight,
                width: double.infinity,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      _word(
                        context,
                        'Photo cannot be loaded',
                        'تعذر عرض الصورة',
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                end: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xDE081B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _outline),
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _mealLabel(BuildContext context, String? type) => switch (type) {
    'breakfast' => _word(context, 'Breakfast', 'إفطار'),
    'lunch' => _word(context, 'Lunch', 'غداء'),
    'dinner' => _word(context, 'Dinner', 'عشاء'),
    'snack' => _word(context, 'Snack', 'سناك'),
    _ => type ?? _word(context, 'Not set', 'غير محددة'),
  };

  Widget _stageChooser(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _word(
            context,
            'When was this photo taken?',
            'متى التُقطت هذه الصورة؟',
          ),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _foreground(context),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final stage in const ['before', 'during', 'after'])
              ChoiceChip(
                key: Key('premium-vision-stage-$stage'),
                label: Text(switch (stage) {
                  'before' => _word(context, 'Before eating', 'قبل الأكل'),
                  'during' => _word(context, 'Partly eaten', 'أثناء الأكل'),
                  _ => _word(context, 'Leftovers', 'بقايا الطعام'),
                }),
                selected: _photoStage == stage,
                onSelected: (_) => _visualUpdate(() => _photoStage = stage),
              ),
          ],
        ),
        if (_photoStage == 'during' || _photoStage == 'after')
          Text(
            _word(
              context,
              'A photo of leftovers does not tell us how much you ate. Confirm the amount actually eaten below.',
              'الصورة لا تثبت الكمية التي أكلتها. أكّد الكمية المأكولة فعليًا أدناه.',
            ),
            style: const TextStyle(color: Color(0xFFFFD18B), fontSize: 12),
          ),
      ],
    );
  }

  Widget _candidateCard(int index) {
    final context = _visualContext;
    final item = _foods[index];
    final selected = _selected.contains(index);
    final low = item.confidence < 0.55;
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final portionUnit = mealImageUnitLabel(_units[index].text, locale);
    return Container(
      key: Key('premium-vision-food-$index'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _glassDecoration(context, active: selected),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _candidateHeading(index),
          if (item.evidence.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 6),
              child: Text(
                item.evidence,
                style: TextStyle(
                  color: _secondary(context),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          if (low || item.uncertainty != null || item.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 17,
                    color: Color(0xFFFFC66E),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      [
                        if (low)
                          _word(
                            context,
                            'Recognition needs review',
                            'التعرّف يحتاج مراجعة',
                          ),
                        if (item.uncertainty != null) item.uncertainty!,
                        ...item.warnings,
                      ].join(' · '),
                      style: const TextStyle(
                        color: Color(0xFFFFDF9A),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (selected) ...[
            const SizedBox(height: 7),
            Text(
              _word(
                context,
                'Does the suggested amount mean eaten or remaining?',
                'هل الكمية المقترحة هي ما أكلته أم ما تبقّى؟',
              ),
              style: const TextStyle(color: Color(0xFFFFD18B), fontSize: 12),
            ),
            Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  key: Key('premium-vision-eaten-$index'),
                  label: Text(
                    _word(context, 'I ate this amount', 'أكلت هذه الكمية'),
                  ),
                  selected: _amountMeaning[index] == true,
                  onSelected: (_) =>
                      _visualUpdate(() => _amountMeaning[index] = true),
                ),
                ChoiceChip(
                  key: Key('premium-vision-remaining-$index'),
                  label: Text(
                    _word(
                      context,
                      'This amount remains',
                      'هذه الكمية المتبقية',
                    ),
                  ),
                  selected: _amountMeaning[index] == false,
                  onSelected: (_) => _visualUpdate(() {
                    _amountMeaning[index] = false;
                    _amounts[index]
                        .clear(); // Never log visible leftovers as eaten.
                  }),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 48,
                  child: IconButton(
                    key: Key('premium-vision-minus-$index'),
                    tooltip: _word(context, 'Decrease amount', 'تقليل الكمية'),
                    padding: EdgeInsets.zero,
                    onPressed: () => _adjust(index, -5),
                    icon: Icon(Icons.remove_rounded, color: _accent(context)),
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: Key('premium-vision-amount-$index'),
                    controller: _amounts[index],
                    onChanged: (_) => _visualUpdate(() {}),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _foreground(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: _word(context, 'Eaten', 'المأكول'),
                      hintText: _word(context, 'Amount', 'الكمية'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  width: 38,
                  child: IconButton(
                    key: Key('premium-vision-plus-$index'),
                    tooltip: _word(context, 'Increase amount', 'زيادة الكمية'),
                    padding: EdgeInsets.zero,
                    onPressed: () => _adjust(index, 5),
                    icon: Icon(Icons.add_rounded, color: _accent(context)),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 103,
                  child: TextField(
                    key: Key('premium-vision-unit-$index'),
                    controller: _units[index],
                    onChanged: (_) => _visualUpdate(() {}),
                    style: TextStyle(color: _foreground(context), fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: _word(context, 'Unit', 'الوحدة'),
                      hintText: portionUnit.isEmpty ? 'g' : portionUnit,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 32,
                      ),
                      suffixIcon: PopupMenuButton<String>(
                        tooltip: _word(context, 'Choose unit', 'اختيار الوحدة'),
                        onSelected: (unit) =>
                            _visualUpdate(() => _units[index].text = unit),
                        itemBuilder: (_) => [
                          for (final unit in const [
                            'g',
                            'kg',
                            'oz',
                            'lb',
                            'piece',
                            'ml',
                            'serving',
                          ])
                            PopupMenuItem(value: unit, child: Text(unit)),
                        ],
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (item.alternatives.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (var alt = 0; alt < item.alternatives.length; alt++)
                      ChoiceChip(
                        label: Text(item.alternatives[alt].name),
                        selected: _alternatives[index] == alt,
                        onSelected: (v) => _visualUpdate(
                          () => _alternatives[index] = v ? alt : null,
                        ),
                      ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: Key('premium-vision-exclude-$index'),
                icon: const Icon(Icons.remove_circle_outline, size: 17),
                onPressed: () => _visualUpdate(() {
                  _excluded.add(index);
                  _selected.remove(index);
                }),
                label: Text(_word(context, 'Exclude', 'استبعاد')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
