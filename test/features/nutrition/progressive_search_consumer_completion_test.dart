// Actual progressive-search consumers. Synthetic held query responses, no network.
import 'dart:async';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/daily_log/food_log_page.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/nutrition/food_page.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/nutrition_food_picker.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/shared/widgets/bil_compact_activity_indicator.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HeldAuthority extends FoodRuntimeSearchAuthority {
  // Super positional parameter is private to another library.
  // ignore: use_super_parameters
  _HeldAuthority(FoodRepository repository)
    : super(repository, catalogResolver: () async => null);
  final streams = <String, StreamController<FoodRuntimeSearchResult>>{};
  final retired = <String>{};
  @override
  Stream<FoodRuntimeSearchResult> searchResultsProgressively(
    String query, {
    int limit = 50,
    Duration remoteDebounce = const Duration(milliseconds: 180),
  }) {
    final stream = StreamController<FoodRuntimeSearchResult>.broadcast(
      sync: true,
      onCancel: () => retired.add(query),
    );
    streams[query] = stream;
    return stream.stream;
  }

  void emit(String query, List<Food> rows) => streams[query]!.add(
    FoodRuntimeSearchResult(
      foods: rows,
      source: FoodRuntimeSearchSource.localOnly,
    ),
  );
  Future<void> finish(String query) => streams[query]!.close();
}

enum _Surface { foodLog, catalog, picker }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late FoodRepository repository;
  late _HeldAuthority authority;
  late Food egg;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = FoodRepository(database);
    await repository.addFood(
      name: 'Egg pending fixture',
      category: 'protein',
      calories: 72,
      protein: 6,
      carbs: 1,
      fats: 5,
      servingSize: 1,
      servingUnit: 'egg',
    );
    egg = (await repository.getFoods()).single;
    authority = _HeldAuthority(repository);
  });
  tearDown(() async {
    for (final stream in authority.streams.values) {
      if (!stream.isClosed) await stream.close();
    }
    await database.close();
  });

  Future<void> mount(WidgetTester tester, _Surface surface) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          preferencesRepositoryProvider.overrideWithValue(
            PreferencesRepository(database),
          ),
          foodRepositoryProvider.overrideWithValue(repository),
          foodRuntimeSearchAuthorityProvider.overrideWithValue(authority),
          foodsProvider.overrideWith((ref) => Stream.value(const [])),
          favoriteFoodsProvider.overrideWith((ref) => Stream.value(const [])),
          recentFoodsProvider.overrideWith((ref) => Stream.value(const [])),
          foodLogPopularFoodsProvider.overrideWithValue(const AsyncData([])),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: switch (surface) {
            _Surface.foodLog => const FoodLogPage(),
            _Surface.catalog => const FoodPage(embedded: true),
            _Surface.picker => const Scaffold(body: NutritionFoodPicker()),
          },
        ),
      ),
    );
    if (surface == _Surface.picker) {
      // Picker intentionally starts its initial stream before a query is typed.
      await tester.pump(const Duration(milliseconds: 200));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> query(WidgetTester tester, _Surface surface, String text) async {
    final field = switch (surface) {
      _Surface.foodLog => find.byKey(const Key('food-log-search')),
      _Surface.catalog => find.byType(SearchBar),
      _Surface.picker => find.byType(TextField),
    };
    await tester.enterText(field, text);
    await tester.pump(const Duration(milliseconds: 200));
    expect(authority.streams[text]?.hasListener, isTrue);
  }

  Finder empty(_Surface surface) => switch (surface) {
    _Surface.foodLog => find.text('No foods found'),
    _Surface.catalog => find.byKey(const Key('food-search-empty-state')),
    _Surface.picker => find.textContaining('No local match yet.'),
  };
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  for (final surface in _Surface.values) {
    testWidgets(
      '${surface.name}: initial empty stays pending until delayed remote result',
      (tester) async {
        await mount(tester, surface);
        await query(tester, surface, 'egg');
        authority.emit('egg', const []);
        await tester.pump();
        expect(empty(surface), findsNothing);
        expect(find.byType(BilCompactActivityIndicator), findsWidgets);
        await tester.pump(const Duration(seconds: 4));
        expect(
          empty(surface),
          findsNothing,
          reason: 'A held remote phase is not a completed empty search',
        );
        authority.emit('egg', [egg]);
        await tester.pump();
        expect(
          find.text('Egg pending fixture'),
          findsOneWidget,
          reason: 'Usable local/cached rows must remain immediately visible',
        );
        expect(find.byType(BilCompactActivityIndicator), findsWidgets);
        await authority.finish('egg');
        await tester.pumpAndSettle();
        expect(empty(surface), findsNothing);
        expect(find.text('Egg pending fixture'), findsOneWidget);
        expect(find.byType(BilCompactActivityIndicator), findsNothing);
        await unmount(tester);
      },
    );

    testWidgets(
      '${surface.name}: no result is shown only after all sources complete',
      (tester) async {
        await mount(tester, surface);
        await query(tester, surface, 'unknown');
        authority.emit('unknown', const []);
        await tester.pump();
        expect(empty(surface), findsNothing);
        await authority.finish('unknown');
        await tester.pumpAndSettle();
        expect(empty(surface), findsOneWidget);
        expect(find.byType(BilCompactActivityIndicator), findsNothing);
        await unmount(tester);
      },
    );

    testWidgets(
      '${surface.name}: retired query cannot clear the new query pending state',
      (tester) async {
        await mount(tester, surface);
        await query(tester, surface, 'old');
        authority.emit('old', const []);
        await tester.pump();
        await query(tester, surface, 'egg');
        expect(authority.retired, contains('old'));
        authority.emit('old', [egg]);
        await authority.finish('old');
        await tester.pump();
        expect(find.text('Egg pending fixture'), findsNothing);
        expect(empty(surface), findsNothing);
        expect(find.byType(BilCompactActivityIndicator), findsWidgets);
        authority.emit('egg', [egg]);
        await authority.finish('egg');
        await tester.pumpAndSettle();
        expect(find.text('Egg pending fixture'), findsOneWidget);
        await unmount(tester);
      },
    );

    testWidgets(
      '${surface.name}: later search error does not erase received rows',
      (tester) async {
        await mount(tester, surface);
        await query(tester, surface, 'egg');
        authority.emit('egg', [egg]);
        await tester.pump();
        authority.streams['egg']!.addError(
          StateError('controlled enrichment failure'),
        );
        await authority.finish('egg');
        await tester.pumpAndSettle();
        expect(find.text('Egg pending fixture'), findsOneWidget);
        expect(empty(surface), findsNothing);
        if (surface == _Surface.picker) {
          expect(
            find.text('Search unavailable. Edit the phrase and retry.'),
            findsOneWidget,
          );
        }
        expect(find.byType(BilCompactActivityIndicator), findsNothing);
        await unmount(tester);
      },
    );
  }
}
