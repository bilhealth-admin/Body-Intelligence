import 'dart:convert';
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;

// AST-based, scoped decoration migration. Never changes callbacks, keys,
// routes, numeric data, Icon properties or the original conditional expression.
class _Icons extends RecursiveAstVisitor<void> {
  _Icons(this.source);
  final String source;
  final nodes = <Expression>[];
  final arrowNames = <String>{};
  final typedSdkIcons = <Expression>[];
  final arrow = RegExp(
    r'(?:Icons|CupertinoIcons)\.(?:arrow\w*|chevron\w*|keyboard_arrow\w*|keyboard_return\w*|keyboard_tab\w*|navigate_\w*|expand_\w*|unfold_\w*|double_arrow\w*|first_page\w*|last_page\w*|reply\w*|refresh\w*|undo\w*|redo\w*|north\w*|south\w*|subdirectory_arrow\w*|send\w*|paperplane\w*|download\w*|upload\w*|file_download\w*|file_upload\w*|drive_file_move\w*|open_in_new\w*|swap_\w*|sync\w*|login\w*|logout\w*|exit_to_app\w*|trending_\w*|call_made\w*|call_received\w*|compare_arrows\w*|play_arrow\w*)',
  );
  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    super.visitPrefixedIdentifier(node);
    final value = node.toSource();
    if (arrow.firstMatch(value)?.group(0) == value) arrowNames.add(value);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    if (node.constructorName.type.name.lexeme == 'Icon') {
      _inspect(node, node.argumentList);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    if (node.target == null && node.methodName.name == 'Icon') {
      _inspect(node, node.argumentList);
    }
  }

  void _inspect(Expression node, ArgumentList arguments) {
    if (arguments.arguments.isEmpty) return;
    final argument = arguments.arguments.first.toSource();
    final found = arrow
        .allMatches(argument)
        .map((match) => match.group(0)!)
        .toSet();
    arrowNames.addAll(found);
    final dynamicIcon = !RegExp(
      r'\b(?:Icons|CupertinoIcons)\.',
    ).hasMatch(argument);
    if (found.isEmpty && !dynamicIcon) return;
    final slot = node.parent;
    if (slot is NamedExpression &&
        slot.name.label.name == 'backButtonIcon' &&
        slot.parent is ArgumentList) {
      final call = slot.parent!.parent;
      if (call is InstanceCreationExpression &&
              call.constructorName.type.name.lexeme == 'BarcodeAppBar' ||
          call is MethodInvocation && call.methodName.name == 'BarcodeAppBar') {
        typedSdkIcons.add(node);
        return;
      }
    }
    AstNode? cursor = node.parent;
    while (cursor != null &&
        cursor is! Statement &&
        cursor is! CompilationUnit) {
      if (cursor is InstanceCreationExpression &&
              cursor.constructorName.type.name.lexeme ==
                  'BilGlassPressFeedback' ||
          cursor is MethodInvocation &&
              cursor.methodName.name == 'BilGlassPressFeedback') {
        return;
      }
      cursor = cursor.parent;
    }
    nodes.add(node);
  }
}

void main(List<String> args) {
  final apply = args.contains('--apply');
  final updates = <String, String>{};
  final manifest = <Map<String, Object>>[];
  final arrows = <String>{};
  final typedSdkIcons = <Map<String, Object>>[];
  for (final file in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    final name = path.posix.normalize(file.path.replaceAll('\\', '/'));
    if (!name.endsWith('.dart') ||
        name.endsWith('.g.dart') ||
        name.endsWith('bil_glass_press_feedback.dart')) {
      continue;
    }
    final source = file.readAsStringSync();
    final unit = parseString(
      content: source,
      path: name,
      throwIfDiagnostics: true,
    ).unit;
    final visitor = _Icons(source);
    unit.accept(visitor);
    arrows.addAll(visitor.arrowNames);
    for (final node in visitor.typedSdkIcons) {
      typedSdkIcons.add({
        'file': name,
        'line': unit.lineInfo.getLocation(node.offset).lineNumber,
        'original': node.toSource(),
        'coverage':
            'typed BarcodeAppBar Icon slot; shared enabled SDK arrow feedback',
      });
    }
    if (visitor.nodes.isEmpty) continue;
    var value = source;
    for (final node
        in visitor.nodes..sort((a, b) => b.offset.compareTo(a.offset))) {
      final original = source.substring(node.offset, node.end);
      final explicitConst = original.startsWith('const ');
      final inner = explicitConst ? original.substring(6) : original;
      final replacement =
          '${explicitConst ? 'const ' : ''}BilGlassPressFeedback(child: $inner)';
      value = value.replaceRange(node.offset, node.end, replacement);
      manifest.add({
        'file': name,
        'line': unit.lineInfo.getLocation(node.offset).lineNumber,
        'original': original,
        'replacement': replacement,
      });
    }
    updates[name] = value;
    var library = name;
    var directives = unit.directives;
    final part = directives.whereType<PartOfDirective>().firstOrNull;
    if (part != null) {
      final uri = part.uri?.stringValue;
      if (uri == null) {
        throw StateError(
          'Named part requires manual owning-library review: $name',
        );
      }
      library = path.posix.normalize(
        path.posix.join(path.posix.dirname(name), uri),
      );
    }
    final parentSource = updates[library] ?? File(library).readAsStringSync();
    if (!parentSource.contains("import ") && part != null) {
      throw StateError('Unresolved owning library $library');
    }
    if (!parentSource.contains("import '") ||
        !parentSource.contains('bil_glass_press_feedback.dart')) {
      final uri = path.posix.relative(
        'lib/shared/widgets/bil_glass_press_feedback.dart',
        from: path.posix.dirname(library),
      );
      updates[library] = "import '$uri';\n$parentSource";
    }
  }
  if (apply) {
    for (final entry in updates.entries) {
      File(entry.key).writeAsStringSync(entry.value);
    }
  }
  final report = File(
    'build/stage1-closure/navigation-arrow-wrapper-audit.json',
  );
  report.parent.createSync(recursive: true);
  report.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'applied': apply,
      'changed_files': updates.keys.toList()..sort(),
      'arrow_names': arrows.toList()..sort(),
      'wrappers': manifest,
      'typed_sdk_icon_slots': typedSdkIcons,
    }),
  );
  stdout.writeln(
    jsonEncode({
      'applied': apply,
      'files': updates.length,
      'wrappers': manifest.length,
      'arrow_names': arrows.toList()..sort(),
    }),
  );
}
