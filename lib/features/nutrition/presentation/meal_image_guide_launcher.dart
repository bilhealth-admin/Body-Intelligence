import 'package:flutter/material.dart';

import 'meal_image_guide_page.dart';

Future<bool?> openMealImageGuide(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => const MealImageGuidePage(),
      fullscreenDialog: true,
    ),
  );
}
