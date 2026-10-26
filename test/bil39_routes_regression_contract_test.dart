import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BIL-05 Goals exposes Back with a safe cold-route destination', () {
    final source = File(
      'lib/features/settings/reference_goals_page.dart',
    ).readAsStringSync();
    expect(
      source,
      contains("BilSafeReturnButton(fallbackLocation: '/dashboard')"),
    );
    // Do not allow a route exit to bypass an in-progress Goals save.
    expect(source, contains('leading: saving'));
    // Check the actual disabled branch, independent of formatter whitespace
    // or the requested decoration around its existing BackButtonIcon.
    final visitor = _SavingGuardVisitor();
    parseString(content: source).unit.accept(visitor);
    final button = _constructor(visitor.savingBranches.single.thenExpression);
    expect(button.$1, 'IconButton');
    final arguments = {
      for (final value in button.$2.arguments.whereType<NamedExpression>())
        value.name.label.name: value.expression,
    };
    expect(arguments['onPressed'], isA<NullLiteral>());
    final icon = _constructor(arguments['icon']!);
    expect(icon.$1, 'BilCrystalArrow');
    final child = icon.$2.arguments.whereType<NamedExpression>().single;
    expect(child.name.label.name, 'child');
    expect(_constructor(child.expression).$1, 'BackButtonIcon');
  });

  test('BIL-14/BIL-18 Steps uses a push stack and safe root fallback', () {
    final settings = File(
      'lib/features/connected_health/steps_settings_page.dart',
    ).readAsStringSync();
    final history = File(
      'lib/features/connected_health/steps_history_page.dart',
    ).readAsStringSync();
    expect(
      settings,
      contains(
        RegExp(r"context\.push\(\s*'/connected-health/steps/history',?\s*\)"),
      ),
    );
    expect(
      settings,
      isNot(
        contains(RegExp(r"context\.go\(\s*'/connected-health/steps/history'")),
      ),
    );
    expect(history, contains('BilSafeReturnButton('));
    expect(history, contains("fallbackLocation: '/connected-health/steps'"));
  });

  test('BIL-20 direct health and language routes have fixed fallback paths', () {
    final routes = <String, String>{
      'lib/features/connected_health/connected_health_signal_detail_page.dart':
          '/connected-health',
      'lib/features/connected_health/partner_capabilities_page.dart':
          '/connected-health',
      'lib/features/settings/language_settings_page.dart': '/settings',
    };
    for (final entry in routes.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(source, contains('BilSafeReturnButton('), reason: entry.key);
      expect(
        source,
        contains("fallbackLocation: '${entry.value}'"),
        reason: entry.key,
      );
    }
  });

  test('BIL-10 only Smart Plan session media returns past the library', () {
    final actions = File(
      'lib/features/smart_plan/presentation/bil_smart_plan_actions.dart',
    ).readAsStringSync();
    final routes = File(
      'lib/app/router/app_wellness_routes.dart',
    ).readAsStringSync();
    final library = File(
      'lib/features/wellness/presentation/bil_workout_routines_page.dart',
    ).readAsStringSync();

    // The ordinary library entry remains unchanged; the live session opts in.
    expect(
      actions,
      contains(
        'openExercise: (id) => _openExercise(id, returnToSession: true)',
      ),
    );
    expect(
      actions,
      contains(r"returnToSession ? '$route&returnToSession=1' : route"),
    );
    expect(
      routes,
      contains("state.uri.queryParameters['returnToSession'] == '1'"),
    );
    // A URL query alone must not skip an unrelated warm deep-link caller.
    expect(actions, contains('extra: returnToSession'));
    expect(routes, contains('state.extra == true'));
    expect(library, contains('this.returnToCallerAfterInitialItem = false'));
    expect(library, contains('await _openDetails(item);'));
    expect(library, contains('!widget.returnToCallerAfterInitialItem'));
    expect(library, contains('ModalRoute.of(context)?.isCurrent == true'));
    expect(library, contains('context.pop();'));
  });
}

class _SavingGuardVisitor extends RecursiveAstVisitor<void> {
  final savingBranches = <ConditionalExpression>[];
  @override
  void visitConditionalExpression(ConditionalExpression node) {
    if (node.condition.toSource() == 'saving') savingBranches.add(node);
    super.visitConditionalExpression(node);
  }
}

(String, ArgumentList) _constructor(Expression expression) =>
    switch (expression) {
      InstanceCreationExpression node => (
        node.constructorName.type.name.lexeme,
        node.argumentList,
      ),
      MethodInvocation node when node.target == null => (
        node.methodName.name,
        node.argumentList,
      ),
      _ => throw StateError('Expected a direct widget constructor'),
    };
