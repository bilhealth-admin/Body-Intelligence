import '../../../../app/theme/bil_pearl_finish.dart';
import '../../../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../../../../shared/widgets/bil_navigation_feedback.dart';
import 'package:flutter/material.dart';

import '../../domain/food_v2/coach_food_v2.dart';
import 'coach_food_card_copy.dart';
import 'coach_food_card_models.dart';

abstract final class CoachFoodCardPalette {
  static const white = Color(0xFFF7F9FF);
  static Color muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  static const blue = Color(0xFF3298FF);
  static const green = Color(0xFF34C792);
  static const border = Color(0xFF334150);
  static Color inset(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? BilPearlFinish.darkInset
      : BilPearlFinish.lightInset;
}

class CoachFoodCardSurface extends StatelessWidget {
  const CoachFoodCardSurface({
    required this.child,
    this.maxWidth = 366,
    this.fillAvailableWidth = false,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });
  final Widget child;
  final double maxWidth;
  final bool fillAvailableWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surface = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BilPearlFinish.panel(
          context,
          radius: BorderRadius.circular(17),
        ),
        child: Material(
          color: Colors.transparent,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              height: 1.4,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
    return fillAvailableWidth
        ? SizedBox(width: double.infinity, child: surface)
        : surface;
  }
}

class CoachFoodThumbnail extends StatelessWidget {
  const CoachFoodThumbnail({
    required this.food,
    this.resolver,
    this.width,
    this.height = 60,
    this.compact = false,
    super.key,
  });
  final CoachFoodSnapshot? food;
  final CoachFoodThumbnailResolver? resolver;
  final double? width;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    ImageProvider<Object>? image;
    try {
      image = food == null ? null : resolver?.call(food!);
    } on Object {
      // A failed optional image lookup never invalidates a saved food receipt.
      image = null;
    }
    final fallback = Semantics(
      label: CoachFoodCardCopy(context).photoUnavailable,
      image: true,
      child: ColoredBox(
        color: const Color(0xFF223344),
        child: Center(
          child: ExcludeSemantics(
            child: Icon(
              Icons.restaurant_outlined,
              size: compact ? 18 : 26,
              color: CoachFoodCardPalette.muted(context),
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 5 : 7),
        child: image == null
            ? fallback
            : Image(
                image: image,
                fit: BoxFit.cover,
                semanticLabel: food!.name,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class CoachFoodEvidenceDetails extends StatelessWidget {
  const CoachFoodEvidenceDetails({required this.portion, super.key});
  final CoachFoodPortion? portion;

  @override
  Widget build(BuildContext context) {
    final copy = CoachFoodCardCopy(context);
    final source = portion?.food.source;
    final values = <(String, String)>[
      (
        copy.source,
        source == null
            ? copy.unknown
            : '${copy.sourceKind(source.kind)} · ${source.ref}',
      ),
      (copy.sourceConfidence, copy.confidence(source?.confidence)),
      (copy.identityConfidence, copy.confidence(portion?.identityConfidence)),
      (
        copy.quantity,
        portion == null
            ? copy.unknown
            : '${copy.amount(portion!, includeGrams: true)} · ${portion!.quantity.evidence.description}',
      ),
      (
        copy.quantityConfidence,
        copy.confidence(portion?.quantity.evidence.confidence),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CoachFoodCardPalette.inset(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in values)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: TextStyle(
                        color: CoachFoodCardPalette.muted(context),
                      ),
                    ),
                    TextSpan(text: value),
                  ],
                ),
                style: TextStyle(fontSize: 11, height: 1.45),
              ),
            ),
        ],
      ),
    );
  }
}

class CoachFoodNutrientStrip extends StatelessWidget {
  const CoachFoodNutrientStrip({required this.value, super.key});
  final double? Function(FoodNutrient nutrient) value;

  static const _nutrients = [
    (
      FoodNutrient.calories,
      Icons.local_fire_department_rounded,
      Color(0xFFF5AE56),
    ),
    (FoodNutrient.protein, Icons.water_drop_rounded, Color(0xFF4CAEFF)),
    (FoodNutrient.carbohydrates, Icons.eco_rounded, Color(0xFF79D070)),
    (FoodNutrient.fat, Icons.water_drop_rounded, Color(0xFFB871F5)),
  ];

  @override
  Widget build(BuildContext context) {
    final copy = CoachFoodCardCopy(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            MediaQuery.textScalerOf(context).scale(13) > 18 ||
                constraints.maxWidth < 285
            ? 2
            : 4;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            for (final (nutrient, icon, color) in _nutrients)
              SizedBox(
                width: width,
                child: _metric(copy, nutrient, icon, color),
              ),
          ],
        );
      },
    );
  }

  Widget _metric(
    CoachFoodCardCopy copy,
    FoodNutrient nutrient,
    IconData icon,
    Color color,
  ) {
    final number = value(nutrient);
    final text = number == null
        ? copy.unknown
        : nutrient == FoodNutrient.calories
        ? copy.number(number)
        : '${copy.number(number)} ${CoachFoodNutrients.units[nutrient]}';
    final largeText = MediaQuery.textScalerOf(copy.context).scale(13) > 18;
    final symbol = Container(
      width: 22,
      height: 25,
      margin: const EdgeInsetsDirectional.only(end: 5, top: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        shape: BoxShape.circle,
      ),
      child: BilNavigationFeedback(child: Icon(icon, color: color, size: 20)),
    );
    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: TextStyle(fontSize: 11.5)),
        Text(
          copy.nutrient(nutrient),
          style: TextStyle(
            color: CoachFoodCardPalette.muted(copy.context),
            fontSize: 10.5,
          ),
        ),
      ],
    );
    return Semantics(
      label: '${copy.nutrient(nutrient)}: $text',
      child: ExcludeSemantics(
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [symbol, const SizedBox(height: 4), labels],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  symbol,
                  Expanded(child: labels),
                ],
              ),
      ),
    );
  }
}

class CoachFoodStatusLine extends StatelessWidget {
  const CoachFoodStatusLine({
    required this.text,
    this.running = false,
    super.key,
  });
  final String text;
  final bool running;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (running)
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 8, top: 3),
            child: SizedBox.square(
              dimension: 15,
              child: BilFeatureWelcomeStatus(color: CoachFoodCardPalette.blue),
            ),
          ),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
