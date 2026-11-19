import 'dart:convert';
import 'dart:io';

import 'verify_bil39_pinned_calendar.dart' as guard;

// Independent fixtures are parsed as Dart; no Flutter widget is built.
const _legacyPortrait = r'''
SizedBox(
  height: _datePickerHeaderPortraitHeight * fontScaleAdjustedHeaderHeight,
  child: Material(
    color: backgroundColor,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(start: 24, end: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 16), help,
          const Flexible(child: SizedBox(height: 38)),
          Row(children: <Widget>[
            Expanded(child: title),
            if (entryModeButton != null)
              Semantics(container: true, child: entryModeButton),
          ]),
        ],
      ),
    ),
  ),
)
''';

const _adaptivePortrait = r'''
ConstrainedBox(
  constraints: BoxConstraints(
    minHeight: _datePickerHeaderPortraitHeight * fontScaleAdjustedHeaderHeight,
  ),
  child: IntrinsicHeight(
    child: Material(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 24, end: 12, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 16), help,
            const Spacer(),
            Row(children: <Widget>[
              Expanded(child: title),
              if (entryModeButton != null)
                Semantics(container: true, child: entryModeButton),
            ]),
          ],
        ),
      ),
    ),
  ),
)
''';

String _fixture(String portrait) =>
    '''
class BilCrystalDatePickerHeader extends StatelessWidget {
  const BilCrystalDatePickerHeader({super.key, required this.firstDate,
    required this.lastDate, this.selectableDayPredicate});
  final DateTime firstDate;
  final DateTime lastDate;
  final bool Function(DateTime)? selectableDayPredicate;
  static const double _datePickerHeaderPortraitHeight = 120.0;
  static const double _datePickerHeaderLandscapeWidth = 152.0;
  bool allows(DateTime value) => !value.isBefore(firstDate) &&
    !value.isAfter(lastDate) && (selectableDayPredicate?.call(value) ?? true);
  Widget build(BuildContext context) {
    final double fontScaleAdjustedHeaderHeight = 1.0;
    final double scaledFontSize = 80.0;
    final title = Text(titleText,
      semanticsLabel: titleSemanticsLabel ?? titleText,
      maxLines: scaledFontSize > 70 ? 2 : 1);
    switch (orientation) {
      case Orientation.portrait:
        return Semantics(container: true, child: $portrait);
      case Orientation.landscape:
        return SizedBox(width: _datePickerHeaderLandscapeWidth, child: title);
    }
  }
}
class _RestorableDatePickerEntryMode extends RestorableValue<DatePickerEntryMode> {
  DatePickerEntryMode fromPrimitives(Object? data) =>
    DatePickerEntryMode.values[data! as int];
}
''';

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

String _changeOnce(String source, String from, String to) {
  final first = source.indexOf(from);
  _expect(
    first >= 0 && source.lastIndexOf(from) == first,
    'Mutation precondition must match exactly once: $from',
  );
  return source.replaceRange(first, first + from.length, to);
}

bool _equivalent(String first, String second) {
  final a = guard.declarations([first], adapted: true);
  final b = guard.declarations([second], adapted: true);
  return a.length == b.length &&
      a.entries.every((entry) => b[entry.key] == entry.value);
}

void main() {
  final legacy = _fixture(_legacyPortrait);
  final adaptive = _fixture(_adaptivePortrait);
  _expect(
    _equivalent(adaptive, legacy),
    'Reviewed adaptive portrait must canonicalize to independent legacy fixture',
  );
  _expect(
    guard.normalizeAdaptiveDatePickerHeaderPresentation(legacy) == legacy,
    'Legacy SDK-shaped header must require no presentation rewrite',
  );
  final normalized = guard.normalizeAdaptiveDatePickerHeaderPresentation(
    adaptive,
  );
  _expect(
    normalized != adaptive && normalized.contains('const Flexible('),
    'The positive case must actually exercise the adaptive rewrite',
  );

  final otherClass = adaptive.replaceAll(
    'BilCrystalDatePickerHeader',
    'OtherDatePickerHeader',
  );
  _expect(
    guard.normalizeAdaptiveDatePickerHeaderPresentation(otherClass) ==
        otherClass,
    'An unrelated class must never receive this normalization',
  );
  final landscapeOnly = _changeOnce(
    adaptive,
    'case Orientation.portrait:',
    'case Orientation.landscape:',
  );
  _expect(
    guard.normalizeAdaptiveDatePickerHeaderPresentation(landscapeOnly) ==
        landscapeOnly,
    'A non-portrait switch member must never receive this normalization',
  );

  final mutations = <(String, String)>[
    (
      'height-formula',
      _changeOnce(
        adaptive,
        '_datePickerHeaderPortraitHeight * fontScaleAdjustedHeaderHeight',
        '_datePickerHeaderPortraitHeight + fontScaleAdjustedHeaderHeight',
      ),
    ),
    ('constraint-kind', _changeOnce(adaptive, 'minHeight:', 'maxHeight:')),
    (
      'extra-constraint',
      _changeOnce(
        adaptive,
        'minHeight: _datePickerHeaderPortraitHeight * fontScaleAdjustedHeaderHeight,',
        'minHeight: _datePickerHeaderPortraitHeight * fontScaleAdjustedHeaderHeight, maxHeight: 200,',
      ),
    ),
    (
      'extra-outer-argument',
      _changeOnce(
        adaptive,
        'child: IntrinsicHeight(',
        'key: const ValueKey("changed"), child: IntrinsicHeight(',
      ),
    ),
    (
      'extra-intrinsic-argument',
      _changeOnce(
        adaptive,
        'child: Material(',
        'key: const ValueKey("changed"), child: Material(',
      ),
    ),
    (
      'spacer-flex',
      _changeOnce(adaptive, 'const Spacer()', 'const Spacer(flex: 2)'),
    ),
    ('nonconst-spacer', _changeOnce(adaptive, 'const Spacer()', 'Spacer()')),
    (
      'shifted-spacer-slot',
      _changeOnce(
        adaptive,
        'const Spacer(),',
        'const SizedBox(height: 1), const Spacer(),',
      ),
    ),
    (
      'material-color',
      _changeOnce(adaptive, 'color: backgroundColor', 'color: foregroundColor'),
    ),
    ('directional-padding', _changeOnce(adaptive, 'start: 24', 'start: 25')),
    (
      'title-semantics',
      _changeOnce(
        adaptive,
        'semanticsLabel: titleSemanticsLabel ?? titleText',
        'semanticsLabel: titleText',
      ),
    ),
    (
      'scale-threshold',
      _changeOnce(
        adaptive,
        'scaledFontSize > 70 ? 2 : 1',
        'scaledFontSize > 71 ? 2 : 1',
      ),
    ),
    (
      'landscape-width',
      _changeOnce(
        adaptive,
        '_datePickerHeaderLandscapeWidth = 152.0',
        '_datePickerHeaderLandscapeWidth = 153.0',
      ),
    ),
    (
      'restoration-index',
      _changeOnce(
        adaptive,
        'DatePickerEntryMode.values[data! as int]',
        'DatePickerEntryMode.values[(data! as int) + 1]',
      ),
    ),
    (
      'date-upper-bound',
      _changeOnce(
        adaptive,
        '!value.isAfter(lastDate)',
        '!value.isBefore(lastDate)',
      ),
    ),
    (
      'selectable-day-predicate',
      _changeOnce(
        adaptive,
        '(selectableDayPredicate?.call(value) ?? true)',
        'true',
      ),
    ),
  ];
  for (final (name, mutation) in mutations) {
    _expect(
      !_equivalent(mutation, legacy),
      'Forbidden mutation was accepted: $name',
    );
  }
  stdout.writeln(
    jsonEncode({
      'status': 'PASS',
      'positive_and_scope_controls': 5,
      'negative_mutations_rejected': mutations.map((item) => item.$1).toList(),
      'scope':
          'Pure Dart AST controls; installed pinned-SDK comparison remains separate',
    }),
  );
}
