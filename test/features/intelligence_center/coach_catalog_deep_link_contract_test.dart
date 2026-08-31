import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog chips resolve to gated local recipe and workout details', () {
    final bubble = File(
      'lib/features/intelligence_center/presentation/'
      'intelligence_center_message_widgets.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final linkDomain = File(
      'lib/features/intelligence_center/domain/intelligence_message.dart',
    ).readAsStringSync();
    final recipes = File(
      'lib/features/wellness/presentation/recipe_library_page.dart',
    ).readAsStringSync();
    final workouts = File(
      'lib/features/wellness/presentation/bil_workout_routines_page.dart',
    ).readAsStringSync();

    expect(bubble, contains('link.isTrustedLocalRoute'));
    expect(bubble, contains('onPressed: () => context.push(link.route)'));
    expect(bubble, contains('IntelligenceMessageLinkKind.recipe'));
    expect(linkDomain, contains('IntelligenceMessageLinkKind.workout'));
    expect(linkDomain, contains("'/wellness/workouts/routines'"));
    expect(bubble, contains('TextDirection.rtl'));
    expect(router, contains("queryParameters['recipe']"));
    expect(router, contains("queryParameters['item']"));
    expect(recipes, contains('recipe.id == requested'));
    expect(recipes, contains('subscription.plan == CommercePlan.free'));
    expect(recipes, contains('_open(recipe);'));
    expect(workouts, contains('item.stableId == requested'));
    expect(workouts, contains('if (_isLocked(item))'));
    expect(workouts, contains('_openDetails(item);'));
  });
}
