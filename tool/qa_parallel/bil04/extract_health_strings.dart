// This offline QA tool uses analyzer from the existing pinned pubspec.lock via
// an explicit --packages argument. It does not add a product dependency.
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:crypto/crypto.dart';

/// Reads only the explicitly listed local files. It never invokes Git, resolves
/// packages or changes source. Templates use numbered placeholders; bindings
/// retain exact Dart expressions and source offsets instead of evaluating them.
void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: extract_health_strings.dart manifest.json output.json',
    );
    exitCode = 64;
    return;
  }
  final manifest = jsonDecode(File(arguments[0]).readAsStringSync()) as Map;
  final catalog = _Catalog();
  for (final raw in manifest['files'] as List) {
    final spec = (raw as Map).cast<String, Object?>();
    final source = File(spec['sourcePath']! as String).readAsStringSync();
    final parsed = parseString(
      content: source,
      path: spec['path']! as String,
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) {
      throw StateError('Dart parse diagnostics: ${parsed.errors.join('\n')}');
    }
    final visitor = _StringsVisitor(spec, source, parsed.lineInfo, catalog);
    parsed.unit.accept(visitor);
    visitor.finish();
  }
  catalog.finish();
  File(arguments[1]).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(catalog.toJson())}\n',
  );
  stdout.writeln('Extracted ${catalog.pairs.length} bilingual templates.');
}

final class _Template {
  const _Template(this.text, this.bindings);
  final String text;
  final Map<String, String> bindings;

  static _Template? from(Expression expression) {
    if (expression is! StringLiteral) return null;
    final buffer = StringBuffer();
    final bindings = <String, String>{};
    void append(StringLiteral literal) {
      if (literal is SimpleStringLiteral) {
        buffer.write(literal.value);
      } else if (literal is AdjacentStrings) {
        for (final child in literal.strings) {
          append(child);
        }
      } else if (literal is StringInterpolation) {
        for (final part in literal.elements) {
          if (part is InterpolationString) {
            buffer.write(part.value);
          } else if (part is InterpolationExpression) {
            final key = 'p${bindings.length + 1}';
            bindings[key] = part.expression.toSource();
            buffer.write('{$key}');
          }
        }
      } else {
        throw StateError(
          'Unsupported Dart string node: ${literal.runtimeType}',
        );
      }
    }

    append(expression);
    return _Template(buffer.toString(), bindings);
  }
}

final class _Catalog {
  final pairs = <String, Map<String, Object?>>{};
  final audit = <Map<String, Object?>>[];
  final diagnostics = <Map<String, Object?>>[];

  void add({
    required _Template en,
    required _Template ar,
    required Map<String, Object?> enSource,
    required Map<String, Object?> arSource,
    required String kind,
  }) {
    final digest = sha256
        .convert(utf8.encode('${en.text}\n${ar.text}'))
        .toString();
    final id = 'bil04.${digest.substring(0, 16)}';
    final pair = pairs.putIfAbsent(
      id,
      () => {
        'id': id,
        'en': en.text,
        'ar': ar.text,
        'kinds': <String>[],
        'sources': <Map<String, Object?>>[],
        'placeholderParity': en.bindings.length == ar.bindings.length,
      },
    );
    if (!(pair['kinds'] as List).contains(kind)) {
      (pair['kinds'] as List).add(kind);
    }
    (pair['sources'] as List).add({
      'en': {...enSource, 'bindings': en.bindings},
      'ar': {...arSource, 'bindings': ar.bindings},
    });
    if (en.bindings.length != ar.bindings.length) {
      diagnostics.add({
        'id': id,
        'reason': 'placeholder_count_mismatch',
        'en': en.bindings,
        'ar': ar.bindings,
      });
    }
  }

  void finish() {
    for (final pair in pairs.values) {
      final sources = pair['sources'] as List;
      final distinct = <String, Object?>{};
      for (final source in sources) {
        distinct[jsonEncode(source)] = source;
      }
      pair['sources'] = distinct.values.toList();
    }
    audit.sort((a, b) {
      final paths = (a['path'] as String).compareTo(b['path'] as String);
      return paths == 0
          ? (a['offset'] as int).compareTo(b['offset'] as int)
          : paths;
    });
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'method': 'Dart analyzer AST; no regex extraction of Dart string contents',
    'pairs': pairs.values.toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String)),
    'unpairedLiteralAudit': audit,
    'diagnostics': diagnostics,
  };
}

final class _StringsVisitor extends RecursiveAstVisitor<void> {
  _StringsVisitor(this.spec, this.source, this.lines, this.catalog);

  final Map<String, Object?> spec;
  final String source;
  final LineInfo lines;
  final _Catalog catalog;
  final literals = <StringLiteral>[];
  final covered = <(int, int)>[];
  final weekdayLists = <String, ListLiteral>{};

  bool allowed(AstNode node) {
    if (spec['mode'] == 'owned') return true;
    for (final raw in spec['addedRanges'] as List) {
      final range = raw as List;
      if (node.offset < (range[1] as int) && node.end > (range[0] as int)) {
        return true;
      }
    }
    return false;
  }

  Map<String, Object?> location(AstNode node) {
    final start = lines.getLocation(node.offset);
    final end = lines.getLocation(node.end);
    return {
      'path': spec['path'],
      'scope': spec['mode'],
      'line': start.lineNumber,
      'column': start.columnNumber,
      'endLine': end.lineNumber,
      'offset': node.offset,
      'length': node.length,
      'dartLiteral': node.toSource(),
      'newOrChangedSpan': allowed(node),
    };
  }

  void pair(Expression en, Expression ar, String kind) {
    if (en is ConditionalExpression && ar is ConditionalExpression) {
      pair(en.thenExpression, ar.thenExpression, '$kind:true_branch');
      pair(en.elseExpression, ar.elseExpression, '$kind:false_branch');
      return;
    }
    final enTemplate = _Template.from(en);
    final arTemplate = _Template.from(ar);
    if (enTemplate == null || arTemplate == null) return;
    if (!allowed(en) && !allowed(ar)) return;
    catalog.add(
      en: enTemplate,
      ar: arTemplate,
      enSource: location(en),
      arSource: location(ar),
      kind: kind,
    );
    covered.add((en.offset, en.end));
    covered.add((ar.offset, ar.end));
    final enExpressions = _interpolations(en);
    final arExpressions = _interpolations(ar);
    if (enExpressions.length == arExpressions.length) {
      for (var index = 0; index < enExpressions.length; index++) {
        nested(enExpressions[index], arExpressions[index]);
      }
    }
  }

  List<Expression> _interpolations(Expression expression) {
    if (expression is StringInterpolation) {
      return [
        for (final element in expression.elements)
          if (element is InterpolationExpression) element.expression,
      ];
    }
    if (expression is AdjacentStrings) {
      return [
        for (final literal in expression.strings) ..._interpolations(literal),
      ];
    }
    return const [];
  }

  void nested(Expression en, Expression ar) {
    if (en is ConditionalExpression && ar is ConditionalExpression) {
      pair(en.thenExpression, ar.thenExpression, 'interpolation_choice');
      pair(en.elseExpression, ar.elseExpression, 'interpolation_choice');
    }
    if (en is MethodInvocation &&
        ar is MethodInvocation &&
        en.methodName.name == ar.methodName.name) {
      final enArgs = en.argumentList.arguments;
      final arArgs = ar.argumentList.arguments;
      if (enArgs.length != arArgs.length) return;
      for (var index = 0; index < enArgs.length; index++) {
        final a = enArgs[index];
        final b = arArgs[index];
        if (a is NamedExpression &&
            b is NamedExpression &&
            a.name.label.name == 'suffix' &&
            b.name.label.name == 'suffix') {
          pair(a.expression, b.expression, 'unit_suffix');
        }
        nested(
          a is NamedExpression ? a.expression : a,
          b is NamedExpression ? b.expression : b,
        );
      }
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final args = node.argumentList.arguments;
    if ((name == 'tr' || name == 'copy') && args.length == 2) {
      pair(args[0], args[1], 'translation_call');
    } else if ((name == 'intelligenceTextFor' || name == 'intelligenceText') &&
        args.length == 3) {
      pair(args[1], args[2], 'translation_call');
    } else if (name == 'action' &&
        args.length == 4 &&
        (spec['path'] as String).endsWith('coach_health_parser.dart')) {
      pair(args[2], args[3], 'parser_action_label');
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitRecordLiteral(RecordLiteral node) {
    final fields = node.fields;
    if (fields.length == 2 &&
        fields[0] is StringLiteral &&
        fields[1] is StringLiteral &&
        RegExp(r'[\u0600-\u06ff]').hasMatch(fields[1].toSource())) {
      pair(fields[0], fields[1], 'bilingual_record');
    } else {
      final named = <String, Expression>{
        for (final field in fields)
          if (field is NamedExpression) field.name.label.name: field.expression,
      };
      if (named['name'] != null && named['nameAr'] != null) {
        pair(named['name']!, named['nameAr']!, 'catalog_display_name');
      }
    }
    super.visitRecordLiteral(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if ((node.name.lexeme == 'en' || node.name.lexeme == 'ar') &&
        node.initializer is ListLiteral) {
      weekdayLists[node.name.lexeme] = node.initializer! as ListLiteral;
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.parent is! AdjacentStrings) literals.add(node);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    if (node.parent is! AdjacentStrings) literals.add(node);
    super.visitStringInterpolation(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    literals.add(node);
    super.visitAdjacentStrings(node);
  }

  void finish() {
    final en = weekdayLists['en'];
    final ar = weekdayLists['ar'];
    if (en != null && ar != null && en.elements.length == ar.elements.length) {
      for (var index = 0; index < en.elements.length; index++) {
        final a = en.elements[index];
        final b = ar.elements[index];
        if (a is Expression && b is Expression) pair(a, b, 'weekday_name');
      }
    }
    for (final literal in literals) {
      if (!allowed(literal) ||
          covered.any(
            (span) => literal.offset >= span.$1 && literal.end <= span.$2,
          )) {
        continue;
      }
      final template = _Template.from(literal)!;
      catalog.audit.add({
        ...location(literal),
        'template': template.text,
        'bindings': template.bindings,
        'classification': _classify(literal, template),
      });
    }
  }

  String _classify(StringLiteral node, _Template value) {
    if (node.parent is Directive) return 'source_directive';
    if (node.parent is IndexExpression) return 'data_key';
    final path = spec['path']! as String;
    var cursor = node.parent;
    final ancestors = <AstNode>[];
    while (cursor != null) {
      ancestors.add(cursor);
      cursor = cursor.parent;
    }
    if (ancestors.any((a) => a is ThrowExpression)) {
      return 'internal_diagnostic';
    }
    if (ancestors.any(
      (a) =>
          a is MethodInvocation &&
          (a.methodName.name == 'RegExp' ||
              a.methodName.name == 'replaceAll' ||
              a.methodName.name == 'replaceFirst'),
    )) {
      return 'grammar_or_formatting';
    }
    if (path.endsWith('coach_health_parser.dart')) return 'grammar_or_argument';
    if (path.endsWith('coach_health_tools.dart')) {
      return 'tool_protocol_or_argument';
    }
    if (path.endsWith('coach_activity_catalog.dart')) {
      return 'catalog_id_or_category';
    }
    if (spec['mode'] == 'shared_added' && spec['userCopyExpected'] == false) {
      return 'shared_internal_protocol_or_schema';
    }
    final visible = value.text.replaceAll(RegExp(r'\{p\d+\}'), '');
    if (!RegExp(r'[A-Za-z\u0600-\u06ff]').hasMatch(visible)) {
      return 'locale_neutral_format';
    }
    if (RegExp(r'^[a-zA-Z_][a-zA-Z0-9_.:-]*$').hasMatch(visible)) {
      return 'identifier_or_enum';
    }
    if (ancestors.any((a) => a is SwitchExpressionCase) &&
        node.parent is ConstantPattern) {
      return 'switch_identifier';
    }
    return 'REVIEW_UNPAIRED';
  }
}
