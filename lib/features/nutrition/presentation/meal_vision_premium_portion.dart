part of 'meal_vision_premium_review.dart';

extension _TrustedVisionPortionEditor on _PremiumTrustedMatchDialogState {
  Widget _portionEditor(BuildContext context) => Container(
    key: const Key('premium-vision-final-portion'),
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: _glassDecoration(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.imagePath != null && File(widget.imagePath!).existsSync())
          GestureDetector(
            key: const Key('premium-vision-final-photo'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (zoomContext) => Dialog(
                // A real FileImage has no dimensions until its first frame
                // decodes. Keep the modal and close button hittable even while
                // the original photo is pending or fails to load.
                insetPadding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(zoomContext).height * .65,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: const Color(0xFF061A22),
                        child: InteractiveViewer(
                          maxScale: 5,
                          child: Image.file(
                            File(widget.imagePath!),
                            fit: BoxFit.contain,
                            frameBuilder: (context, child, frame, synchronous) {
                              if (synchronous || frame != null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Text(
                                    _word(
                                      context,
                                      'Photo unavailable',
                                      'الصورة غير متوفرة',
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: Material(
                          color: const Color(0xCC061A22),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: _word(
                              zoomContext,
                              'Close photo',
                              'إغلاق الصورة',
                            ),
                            onPressed: () => Navigator.of(zoomContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.imagePath!),
                height: 88,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Text(
                  _word(context, 'Photo unavailable', 'الصورة غير متوفرة'),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          _word(context, 'Amount actually eaten', 'الكمية المأكولة فعلًا'),
          style: TextStyle(color: _foreground(context)),
        ),
        Row(
          children: [
            IconButton(
              key: const Key('premium-vision-final-minus'),
              tooltip: _word(context, 'Decrease amount', 'تقليل الكمية'),
              onPressed: () => _stepAmount(-5),
              icon: Icon(Icons.remove, color: _accent(context)),
            ),
            Expanded(
              child: TextField(
                key: const Key('premium-vision-final-amount'),
                controller: _amount,
                textDirection: TextDirection.ltr,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: _foreground(context)),
                onChanged: (_) => _portionUpdate(() {}),
              ),
            ),
            IconButton(
              key: const Key('premium-vision-final-plus'),
              tooltip: _word(context, 'Increase amount', 'زيادة الكمية'),
              onPressed: () => _stepAmount(5),
              icon: Icon(Icons.add, color: _accent(context)),
            ),
          ],
        ),
        TextField(
          key: const Key('premium-vision-final-unit'),
          controller: _unit,
          style: TextStyle(color: _foreground(context)),
          decoration: InputDecoration(
            labelText: _word(context, 'Unit', 'الوحدة'),
            suffixIcon: PopupMenuButton<String>(
              key: const Key('premium-vision-final-unit-menu'),
              onSelected: (unit) => _portionUpdate(() => _unit.text = unit),
              itemBuilder: (_) => [
                for (final unit in [
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
            ),
          ),
          onChanged: (_) => _portionUpdate(() {}),
        ),
        if (_selected != null && !_validPortion)
          Text(
            _word(
              context,
              'Enter a positive amount in a compatible unit.',
              'أدخل كمية موجبة بوحدة متوافقة مع سجل الطعام.',
            ),
            key: const Key('premium-vision-final-invalid'),
            style: TextStyle(color: _accent(context)),
          ),
      ],
    ),
  );
}
