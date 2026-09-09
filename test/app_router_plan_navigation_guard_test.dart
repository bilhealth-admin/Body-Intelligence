import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a visible Plans route cannot be pushed onto itself', () {
    expect(
      AppRouter.blocksDuplicatePlansNavigation(
        Uri.parse('/plans?focus=subscription'),
        Uri.parse('/plans?focus=subscription'),
      ),
      isTrue,
    );
    expect(
      AppRouter.blocksDuplicatePlansNavigation(
        Uri.parse('/plans?focus=subscription'),
        Uri.parse('/plans?focus=boost'),
      ),
      isTrue,
    );
    expect(
      AppRouter.blocksDuplicatePlansNavigation(
        Uri.parse('/dashboard'),
        Uri.parse('/plans?focus=subscription'),
      ),
      isFalse,
    );
  });
}
