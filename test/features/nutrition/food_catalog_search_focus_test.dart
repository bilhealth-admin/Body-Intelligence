import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// No remote/catalog dependency, delay, or pending result is needed to reproduce
// editing-state retirement. The production FoodPage owns every layout rebuild.
final class _ImmediateSearchAuthority extends FoodRuntimeSearchAuthority {
  _ImmediateSearchAuthority(super.repository)
    : super(catalogResolver: () async => null);

  final queries = <String>[];

  @override
  Stream<FoodRuntimeSearchResult> searchResultsProgressively(
    String query, {
    int limit = 50,
    Duration remoteDebounce = const Duration(milliseconds: 180),
  }) {
    queries.add(query);
    return Stream.value(
      const FoodRuntimeSearchResult(
        foods: <Food>[],
        source: FoodRuntimeSearchSource.localOnly,
      ),
    );
  }
}

final _search = find.byKey(const Key('food-primary-search'));
final _editable = find.descendant(
  of: _search,
  matching: find.byType(EditableText),
);

Future<_ImmediateSearchAuthority> _mountCatalog(
  WidgetTester tester, {
  bool embedded = false,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  // The production controller is retired in a post-frame callback.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  final repository = FoodRepository(database);
  final authority = _ImmediateSearchAuthority(repository);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        foodRepositoryProvider.overrideWithValue(repository),
        foodRuntimeSearchAuthorityProvider.overrideWithValue(authority),
        foodsProvider.overrideWith((ref) => Stream.value(const <Food>[])),
        favoriteFoodsProvider.overrideWith(
          (ref) => Stream.value(const <Food>[]),
        ),
        recentFoodsProvider.overrideWith((ref) => Stream.value(const <Food>[])),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: FoodPage(embedded: embedded),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return authority;
}

EditableTextState _editor(WidgetTester tester) =>
    tester.state<EditableTextState>(_editable);

void _expectStillEditing(WidgetTester tester, EditableTextState original) {
  // State identity catches subtree replacement even if a callback were to
  // reopen a keyboard. A whole-prefix enterText() can hide that replacement.
  expect(identical(_editor(tester), original), isTrue);
  expect(original.mounted, isTrue);
  expect(original.widget.focusNode.hasPrimaryFocus, isTrue);
  expect(tester.testTextInput.hasAnyClients, isTrue);
}

Future<EditableTextState> _focusOnce(WidgetTester tester) async {
  await tester.ensureVisible(_search);
  await tester.tap(_search);
  await tester.pump();
  final editor = _editor(tester);
  _expectStillEditing(tester, editor);
  return editor;
}

Future<void> _typeOneCharacterAtATime(
  WidgetTester tester,
  EditableTextState original,
  String suffix,
) async {
  var expected = original.widget.controller.text;
  for (final rune in suffix.runes) {
    _expectStillEditing(tester, original);
    expected += String.fromCharCode(rune);
    // Use the existing input connection. Do not tap, call showKeyboard(), or
    // WidgetTester.enterText() between characters: those would refocus it.
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: expected,
        selection: TextSelection.collapsed(offset: expected.length),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    _expectStillEditing(tester, original);
    expect(original.widget.controller.text, expected);
    expect(tester.takeException(), isNull);
  }
}

void main() {
  testWidgets('standalone hero collapses without retiring the active editor', (
    tester,
  ) async {
    final authority = await _mountCatalog(tester);
    expect(find.text('Log smarter. Understand your food.'), findsOneWidget);
    final editor = await _focusOnce(tester);
    await _typeOneCharacterAtATime(tester, editor, 'BILcatalog');
    expect(find.text('Log smarter. Understand your food.'), findsNothing);
    expect(authority.queries.last, 'BILcatalog');
  });

  testWidgets(
    'clear expands hero and next characters use the same connection',
    (tester) async {
      final authority = await _mountCatalog(tester);
      final editor = await _focusOnce(tester);
      await _typeOneCharacterAtATime(tester, editor, 'BIL');
      await tester.tap(find.byKey(const Key('food-search-clear')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      _expectStillEditing(tester, editor);
      expect(editor.widget.controller.text, isEmpty);
      expect(find.text('Log smarter. Understand your food.'), findsOneWidget);
      expect(find.byKey(const Key('food-browse-filters')), findsOneWidget);
      await _typeOneCharacterAtATime(tester, editor, 'food');
      expect(authority.queries.last, 'food');
    },
  );

  testWidgets('keyboard header wrapper changes preserve editor and input', (
    tester,
  ) async {
    await _mountCatalog(tester);
    final editor = await _focusOnce(tester);
    await _typeOneCharacterAtATime(tester, editor, 'B');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    _expectStillEditing(tester, editor);
    await _typeOneCharacterAtATime(tester, editor, 'IL');
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    _expectStillEditing(tester, editor);
    await _typeOneCharacterAtATime(tester, editor, 'food');
  });

  testWidgets('compact taskbar changes preserve the same active editor', (
    tester,
  ) async {
    await _mountCatalog(tester);
    final editor = await _focusOnce(tester);
    await _typeOneCharacterAtATime(tester, editor, 'B');
    // Inner width crosses _NutritionTaskBar's 340-pixel Row/Column boundary.
    tester.view.physicalSize = const Size(320, 844);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    _expectStillEditing(tester, editor);
    await _typeOneCharacterAtATime(tester, editor, 'IL');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    _expectStillEditing(tester, editor);
    await _typeOneCharacterAtATime(tester, editor, 'catalog');
  });

  testWidgets('embedded catalog keeps incremental typing as a control', (
    tester,
  ) async {
    final authority = await _mountCatalog(tester, embedded: true);
    final editor = await _focusOnce(tester);
    await _typeOneCharacterAtATime(tester, editor, 'BILcatalog');
    expect(authority.queries.last, 'BILcatalog');
  });

  testWidgets('Arabic standalone search survives collapse and clear', (
    tester,
  ) async {
    await _mountCatalog(tester, locale: const Locale('ar'));
    final editor = await _focusOnce(tester);
    await _typeOneCharacterAtATime(tester, editor, '\u0628\u064a\u0644');
    await tester.tap(find.byKey(const Key('food-search-clear')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    _expectStillEditing(tester, editor);
    await _typeOneCharacterAtATime(tester, editor, '\u063a\u0630\u0627\u0621');
  });

  testWidgets('small large-text catalog keeps editing through hero changes', (
    tester,
  ) async {
    await _mountCatalog(tester, size: const Size(320, 640), textScale: 1.6);
    final editor = await _focusOnce(tester);
    await _typeOneCharacterAtATime(tester, editor, 'BIL');
    await tester.tap(find.byKey(const Key('food-search-clear')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    _expectStillEditing(tester, editor);
    await _typeOneCharacterAtATime(tester, editor, 'food');
  });
}
