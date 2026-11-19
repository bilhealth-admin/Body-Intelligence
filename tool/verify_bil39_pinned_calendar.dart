import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

// Normalize only the reviewed adaptive portrait header. Preserve every inner
// Material/Padding/Column/Row argument for the complete SDK AST comparison.
ArgumentList? _headerCallArguments(Expression? node, String name) {
  if (node is InstanceCreationExpression &&
      node.constructorName.toSource() == name) {
    return node.argumentList;
  }
  if (node is MethodInvocation &&
      node.target == null &&
      node.typeArguments == null &&
      node.methodName.name == name) {
    return node.argumentList;
  }
  return null;
}

Map<String, Expression>? _exactHeaderArguments(
  Expression? node,
  String name,
  Set<String> expected,
) {
  final arguments = _headerCallArguments(node, name);
  if (arguments == null) return null;
  final result = <String, Expression>{};
  for (final argument in arguments.arguments) {
    if (argument is! NamedExpression) return null;
    final key = argument.name.label.name;
    if (!expected.contains(key) || result.containsKey(key)) return null;
    result[key] = argument.expression;
  }
  return result.length == expected.length ? result : null;
}

Expression? _headerChild(Expression? node, String name) {
  final arguments = _headerCallArguments(node, name);
  if (arguments == null) return null;
  final children = arguments.arguments
      .whereType<NamedExpression>()
      .where((argument) => argument.name.label.name == 'child')
      .toList();
  return children.length == 1 ? children.single.expression : null;
}

T? _headerAncestor<T extends AstNode>(AstNode node) {
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    if (parent is T) return parent;
  }
  return null;
}

bool _isExactConstHeaderCall(Expression node, String name) =>
    node is InstanceCreationExpression &&
    node.keyword?.lexeme == 'const' &&
    node.constructorName.toSource() == name;

class _AdaptiveHeaderPresentation extends RecursiveAstVisitor<void> {
  _AdaptiveHeaderPresentation(this.source);

  final String source;
  final edits = <(int, int, String)>[];

  void inspect(Expression node) {
    if (_headerCallArguments(node, 'ConstrainedBox') == null) return;
    final owner = _headerAncestor<ClassDeclaration>(node);
    final method = _headerAncestor<MethodDeclaration>(node);
    final member = _headerAncestor<SwitchMember>(node);
    final returned = _headerAncestor<ReturnStatement>(node);
    if (owner?.namePart.typeName.lexeme != 'BilCrystalDatePickerHeader' ||
        method?.name.lexeme != 'build' ||
        member == null ||
        !member.toSource().startsWith('case Orientation.portrait:') ||
        !identical(_headerChild(returned?.expression, 'Semantics'), node)) {
      return;
    }
    final outer = _exactHeaderArguments(node, 'ConstrainedBox', {
      'constraints',
      'child',
    });
    if (outer == null) return;
    final constraints = _exactHeaderArguments(
      outer['constraints'],
      'BoxConstraints',
      {'minHeight'},
    );
    if (constraints == null) return;
    final height = constraints['minHeight']!;
    if (height.toSource() !=
        '_datePickerHeaderPortraitHeight * fontScaleAdjustedHeaderHeight') {
      return;
    }
    final intrinsic = _exactHeaderArguments(outer['child'], 'IntrinsicHeight', {
      'child',
    });
    if (intrinsic == null) return;
    final material = intrinsic['child']!;
    final padding = _headerChild(material, 'Material');
    final column = _headerChild(padding, 'Padding');
    final columnArguments = _headerCallArguments(column, 'Column');
    if (columnArguments == null) return;
    final childLists = columnArguments.arguments
        .whereType<NamedExpression>()
        .where((argument) => argument.name.label.name == 'children')
        .toList();
    if (childLists.length != 1) return;
    final children = childLists.single.expression;
    if (children is! ListLiteral || children.elements.length != 4) return;
    final first = children.elements[0];
    final help = children.elements[1];
    final spacer = children.elements[2];
    final row = children.elements[3];
    if (first is! Expression ||
        !_isExactConstHeaderCall(first, 'SizedBox') ||
        help is! SimpleIdentifier ||
        help.name != 'help' ||
        spacer is! Expression ||
        !_isExactConstHeaderCall(spacer, 'Spacer') ||
        _headerCallArguments(spacer, 'Spacer')!.arguments.isNotEmpty ||
        row is! Expression ||
        _headerCallArguments(row, 'Row') == null) {
      return;
    }
    final leading = _exactHeaderArguments(first, 'SizedBox', {'height'});
    if (leading == null || leading['height']!.toSource() != '16') return;
    if (edits.isNotEmpty) {
      throw StateError('More than one adaptive portrait header was found');
    }
    // Source offsets belong to the original parse. Preserve the whole inner
    // subtree except this one exact, positioned Spacer decoration.
    final inner = source
        .substring(material.offset, material.end)
        .replaceRange(
          spacer.offset - material.offset,
          spacer.end - material.offset,
          'const Flexible(child: SizedBox(height: 38))',
        );
    edits.add((
      node.offset,
      node.end,
      'SizedBox(height: ${height.toSource()}, child: $inner,)',
    ));
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    inspect(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    inspect(node);
    super.visitMethodInvocation(node);
  }
}

String normalizeAdaptiveDatePickerHeaderPresentation(String source) {
  final visitor = _AdaptiveHeaderPresentation(source);
  parseString(content: source).unit.accept(visitor);
  visitor.edits.sort((a, b) => b.$1.compareTo(a.$1));
  for (final edit in visitor.edits) {
    source = source.replaceRange(edit.$1, edit.$2, edit.$3);
  }
  return source;
}

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
      // Reparse after this scoped pass so crystal edit offsets cannot overlap.
      source = normalizeAdaptiveDatePickerHeaderPresentation(source);
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
      'PASS $group: ${actual.length} declarations syntax-identical after the documented names and documented presentation-only wrappers and adaptive portrait header.',
    );
  }
}
