import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

// Verify the shipped date logic against the installed, pinned SDK rather than
// trusting a copied filename or screenshots. AST serialization preserves string contents.
class _UnwrapCrystals extends RecursiveAstVisitor<void> {
  final edits = <(int, int, String)>[];
  void inspect(AstNode node, String name, ArgumentList args) {
    if (name != 'BilCrystalArrow' && name != 'FittedBox') return;
    final child = args.arguments.whereType<NamedExpression>().singleWhere(
      (argument) => argument.name.label.name == 'child',
    );
    if (child.name.label.name != 'child') {
      throw StateError('Unexpected crystal argument');
    }
    edits.add((node.offset, node.end, child.expression.toSource()));
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    inspect(node, node.constructorName.type.name.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    inspect(node, node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }
}

const _names = {
  'BilPearlMaterialDialog': 'Dialog',
  'BilCrystalCalendarDatePicker': 'CalendarDatePicker',
  'BilCrystalYearPicker': 'YearPicker',
  'BilCrystalDatePickerHeader': '_DatePickerHeader',
  'WidgetStatesController': 'MaterialStatesController',
  'BilCrystalDatePickerDialog': 'DatePickerDialog',
  'showBilCrystalDatePicker': 'showDatePicker',
};

Map<String, String> declarations(
  Iterable<String> sources, {
  bool adapted = false,
}) {
  final result = <String, String>{};
  for (var source in sources) {
    if (adapted) {
      final visitor = _UnwrapCrystals();
      parseString(content: source).unit.accept(visitor);
      visitor.edits.sort((a, b) => b.$1.compareTo(a.$1));
      for (final edit in visitor.edits) {
        source = source.replaceRange(edit.$1, edit.$2, edit.$3);
      }
    }
    for (final declaration in parseString(content: source).unit.declarations) {
      final name = switch (declaration) {
        ClassDeclaration n => n.namePart.typeName.lexeme,
        FunctionDeclaration n => n.name.lexeme,
        TopLevelVariableDeclaration n =>
          n.variables.variables.single.name.lexeme,
        _ => null,
      };
      if (name == null) continue;
      final canonicalName = _names[name] ?? name;
      var serialized = declaration.toSource().replaceAll(
        'todayBorder!.color.a',
        'todayBorder!.color.opacity',
      );
      // The copied header is public for Dart's unused-parameter analysis.
      // Its only added constructor parameter is the standard optional key.
      if (adapted && name == 'BilCrystalDatePickerHeader') {
        serialized = serialized.replaceFirst(
          'BilCrystalDatePickerHeader({super.key, ',
          'BilCrystalDatePickerHeader({',
        );
      }
      for (final entry in _names.entries) {
        serialized = serialized.replaceAll(
          RegExp('\\b${entry.key}\\b'),
          entry.value,
        );
      }
      if (result.containsKey(canonicalName)) {
        throw StateError('Duplicate $canonicalName');
      }
      result[canonicalName] = serialized;
    }
  }
  return result;
}

void main() {
  final executable = File(Platform.resolvedExecutable).absolute;
  var sdk = executable.parent;
  for (var i = 0; i < 4; i++) {
    sdk = sdk.parent;
  }
  final configured = Platform.environment['FLUTTER_ROOT'];
  if (configured != null && configured.isNotEmpty) sdk = Directory(configured);
  final material = Directory('${sdk.path}/packages/flutter/lib/src/material');
  if (!material.existsSync()) {
    throw StateError('Pinned Flutter SDK not found: ${sdk.path}');
  }
  final dir = Directory('lib/shared/widgets/calendar');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  for (final group in ['calendar', 'date_picker']) {
    final originalFile = group == 'calendar'
        ? 'calendar_date_picker.dart'
        : 'date_picker.dart';
    final expected = declarations([
      File('${material.path}/$originalFile').readAsStringSync(),
    ]);
    final selected = files.where(
      (f) => group == 'calendar'
          ? f.uri.pathSegments.last.startsWith('bil_crystal_calendar_')
          : f.uri.pathSegments.last.startsWith('bil_crystal_date_picker'),
    );
    final actual = declarations(
      selected.map((f) => f.readAsStringSync()),
      adapted: true,
    );
    if (group == 'calendar' && actual.length != expected.length) {
      throw StateError(
        'Calendar declarations omitted or added: ${actual.length}/${expected.length}',
      );
    }
    if (group == 'date_picker' && actual.length < 20) {
      throw StateError(
        'Single-date dialog proof unexpectedly incomplete: ${actual.length}',
      );
    }
    for (final entry in actual.entries) {
      final baseline = expected[entry.key];
      if (baseline == null || baseline != entry.value) {
        final original = baseline ?? '';
        var offset = 0;
        while (offset < entry.value.length &&
            offset < original.length &&
            entry.value[offset] == original[offset]) {
          offset++;
        }
        stderr.writeln(
          'First AST difference at $offset: '
          'actual ${entry.value.substring(offset, (offset + 100).clamp(0, entry.value.length))}; '
          'SDK ${original.substring(offset, (offset + 100).clamp(0, original.length))}',
        );
        throw StateError(
          'Date logic differs from pinned Flutter SDK: ${entry.key}',
        );
      }
    }
    stdout.writeln(
      'PASS $group: ${actual.length} declarations syntax-identical after the documented names and documented presentation-only wrappers.',
    );
  }
}
