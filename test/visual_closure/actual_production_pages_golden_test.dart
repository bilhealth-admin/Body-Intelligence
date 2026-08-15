import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/auth/premium_account_gateway_page.dart';
import 'package:body_intelligence_log/features/ads/advertising_privacy_page.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/community/presentation/community_hub_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_connections_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_people_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_profile_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_messages_page.dart';
import 'package:body_intelligence_log/features/community/presentation/community_notifications_page.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/steps_settings_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_preferences_page.dart';
import 'package:body_intelligence_log/features/settings/trust_support_page.dart';
import 'package:body_intelligence_log/features/settings/help_center_page.dart';
import 'package:body_intelligence_log/features/settings/legal_document_page.dart';
import 'package:body_intelligence_log/features/notifications/presentation/notification_settings_page.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meal_image_guide_page.dart';
import 'package:body_intelligence_log/features/daily_log/presentation/quick_macro_entry_dialog.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/meals_recipes_foods_page.dart';
import 'package:body_intelligence_log/features/foods/providers/food_provider.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:body_intelligence_log/features/wellness/presentation/professional_content_library_page.dart';
import 'package:body_intelligence_log/features/wellness/presentation/recipe_library_page.dart';
import 'package:body_intelligence_log/features/wellness/repositories/recipe_release_repository.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_library_page.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_learn_page.dart';
import 'package:body_intelligence_log/features/wellness/presentation/wellness_tools_pages.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_content_pack_manager.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'visual_evidence_font.dart';

final class _VisualHealthGateway implements ConnectedHealthGateway {
  const _VisualHealthGateway(this.snapshot);

  final ConnectedHealthSnapshot snapshot;

  @override
  Future<ConnectedHealthSnapshot> load() async => snapshot;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => snapshot;

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      snapshot;

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => snapshot;

  @override
  Future<ConnectedHealthSnapshot> synchronize() async => snapshot;
}

final class _VisualRouteStack extends StatelessWidget {
  const _VisualRouteStack({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Navigator(
    onGenerateInitialRoutes: (_, _) => [
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      MaterialPageRoute<void>(builder: (_) => child),
    ],
  );
}

final class _EmptyWellnessManager extends WellnessContentPackManager {
  @override
  Future<List<WellnessContentItem>> loadTrustedInstalledItems(
    WellnessContentType type, {
    String? locale,
  }) async => const [];
}

final class _VisualCommunityRepository extends CommunityRepository {
  _VisualCommunityRepository({
    this.friendshipStatus = 'accepted',
    this.emptyUpdates = false,
  }) : super(
         SupabaseClient(
           'https://visual.invalid',
           'visual-anon-key',
           authOptions: const AuthClientOptions(autoRefreshToken: false),
         ),
       );

  static const currentId = '11111111-1111-4111-8111-111111111111';
  static const otherId = '22222222-2222-4222-8222-222222222222';
  static const friendshipId = '33333333-3333-4333-8333-333333333333';
  static const inboxId = '44444444-4444-4444-8444-444444444444';
  static const sentId = '55555555-5555-4555-8555-555555555555';

  String friendshipStatus;
  final bool emptyUpdates;
  CommunityProfile profile = const CommunityProfile(
    userId: currentId,
    displayName: 'BIL QA Member',
    localeCode: 'en',
    discoverable: true,
    bio: 'Testing community controls without personal health data.',
    visibility: CommunityProfileVisibility.friends,
    allowFriendRequests: true,
    allowMessagesFrom: CommunityMessagePermission.friends,
  );

  @override
  String get currentUserId => currentId;

  @override
  Future<CommunityProfile?> loadMyProfile() async => profile;

  @override
  Future<void> saveMyProfile({
    required String displayName,
    required String localeCode,
    required bool discoverable,
    String? bio,
    CommunityProfileVisibility visibility = CommunityProfileVisibility.friends,
    bool allowFriendRequests = true,
    bool allowFollows = false,
    CommunityMessagePermission allowMessagesFrom =
        CommunityMessagePermission.friends,
  }) async {
    profile = CommunityProfile(
      userId: currentId,
      displayName: displayName.trim(),
      localeCode: localeCode,
      discoverable: discoverable,
      bio: bio?.trim(),
      visibility: visibility,
      allowFriendRequests: allowFriendRequests,
      allowFollows: allowFollows,
      allowMessagesFrom: allowMessagesFrom,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> loadFriendshipsWithProfiles() async =>
      emptyUpdates
      ? const []
      : [
          {
            'id': friendshipId,
            'requester_id': otherId,
            'addressee_id': currentId,
            'other_user_id': otherId,
            'status': friendshipStatus,
            'profile': {'display_name': 'BIL QA Partner', 'avatar_url': null},
          },
        ];

  @override
  Future<void> respondToFriendship(String id, {required bool accept}) async {
    if (id != friendshipId) throw StateError('Unknown visual friendship');
    friendshipStatus = accept ? 'accepted' : 'declined';
  }

  @override
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async => [
    {
      'user_id': otherId,
      'display_name': 'BIL QA Partner',
      'bio': 'Non-personal community search fixture',
      'avatar_url': null,
    },
  ];

  @override
  Future<void> requestFriend(String addresseeId) async {
    if (addresseeId != otherId) throw StateError('Unknown visual profile');
  }

  @override
  Future<List<CommunityPost>> loadFeed({int limit = 40}) async => [
    CommunityPost(
      id: '66666666-6666-4666-8666-666666666666',
      authorId: otherId,
      authorName: 'BIL QA Partner',
      body:
          'A non-personal QA post about building a consistent movement habit.',
      createdAt: DateTime.utc(2026, 8, 15, 8),
    ),
  ];

  Map<String, dynamic> _message({required bool incoming}) => {
    'id': incoming ? inboxId : sentId,
    'sender_id': incoming ? otherId : currentId,
    'recipient_id': incoming ? currentId : otherId,
    'body': incoming
        ? '[BIL-SUBJECT]Weekly check-in\nHow did your movement plan feel?'
        : '[BIL-SUBJECT]Plan update\nI completed today’s session.',
    'created_at': DateTime.utc(2026, 8, 15, 8).toIso8601String(),
    'read_at': incoming ? null : DateTime.utc(2026, 8, 15, 9).toIso8601String(),
    'profile': {'display_name': 'BIL QA Partner', 'avatar_url': null},
  };

  @override
  Future<List<Map<String, dynamic>>> loadInboxMessages() async =>
      emptyUpdates ? const [] : [_message(incoming: true)];

  @override
  Future<List<Map<String, dynamic>>> loadSentMessages() async => [
    _message(incoming: false),
  ];
}

final _visualWorkoutRoutine = WellnessContentItem(
  id: 'visual-foundation-mobility',
  type: WellnessContentType.workouts,
  locale: 'en',
  title: 'Foundation mobility',
  description: 'A controlled mobility sequence for a comfortable range.',
  publisher: 'BIL Health',
  sourceUrl: Uri.parse(
    'https://bilhealth.com/workouts/visual-foundation-mobility',
  ),
  licenseName: 'BIL licensed original',
  verified: true,
  durationMinutes: 18,
  difficulty: 'Beginner',
  category: 'Recovery',
  equipment: const ['Mat'],
  steps: const [
    'Move through a comfortable range.',
    'Stop if movement causes pain.',
  ],
  author: 'BIL exercise review team',
  attribution: 'Reviewed original routine',
  reviewedAt: DateTime.utc(2026, 8, 1),
  safetyReviewed: true,
);

final _visualWorkoutRoutineTwo = WellnessContentItem(
  id: 'visual-foundation-strength',
  type: WellnessContentType.workouts,
  locale: 'en',
  title: 'Foundation strength',
  description: 'A controlled strength sequence with deliberate repetitions.',
  publisher: 'BIL Health',
  sourceUrl: Uri.parse(
    'https://bilhealth.com/workouts/visual-foundation-strength',
  ),
  licenseName: 'BIL licensed original',
  verified: true,
  durationMinutes: 22,
  difficulty: 'Beginner',
  category: 'Strength',
  equipment: const ['Dumbbells'],
  steps: const [
    'Brace your core before each repetition.',
    'Stop when form begins to change.',
  ],
  author: 'BIL exercise review team',
  attribution: 'Reviewed original routine',
  reviewedAt: DateTime.utc(2026, 8, 1),
  safetyReviewed: true,
);

final class _VisualStoreCatalog implements BilStoreCatalogGateway {
  int purchaseCalls = 0;
  int restoreCalls = 0;
  int manageCalls = 0;

  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(
    Set<String> productIds,
  ) async => const [
    BilStoreOfferMetadata(
      productId: 'bil.visual.monthly',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'BIL Premium monthly',
      localizedPrice: r'$4.79',
      currencyCode: 'USD',
      priceMicros: 4790000,
      billingPeriodIso8601: 'P1M',
    ),
    BilStoreOfferMetadata(
      productId: 'bil.visual.annual',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'BIL Premium annual',
      localizedPrice: r'$45.49',
      currencyCode: 'USD',
      priceMicros: 45490000,
      billingPeriodIso8601: 'P1Y',
    ),
  ];

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
    purchaseCalls++;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
  }

  @override
  Future<void> openManageSubscriptions() async {
    manageCalls++;
  }
}

void main() {
  setUpAll(loadVisualEvidenceFont);

  Future<void> capture(
    WidgetTester tester, {
    required Widget page,
    required String name,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    Widget Function(Widget child)? wrapper,
    Future<void> Function(WidgetTester tester)? interact,
    Future<void> Function(AppDatabase database)? seed,
    bool captureOverlay = false,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    if (seed != null) await seed(db);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final arabic = locale.languageCode == 'ar';
    final theme = brightness == Brightness.dark
        ? BilFlagshipTheme.dark(isArabic: arabic)
        : BilFlagshipTheme.light(isArabic: arabic);
    var renderedPage = page;
    if (page is RecipeLibraryPage) {
      final repository = RecipeReleaseRepository();
      final catalog = await tester.runAsync(repository.loadIndex);
      renderedPage = RecipeLibraryPage(
        initialCatalog: catalog,
        repository: repository,
      );
    }
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: visualEvidenceTheme(
        theme,
        fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
      ),
      builder: (context, child) => RepaintBoundary(
        key: const Key('visual-capture-root'),
        child: visualEvidenceTextSurface(
          child,
          fontFamily: arabic ? 'NotoArabicEvidence' : 'RobotoEvidence',
        ),
      ),
      home: renderedPage,
    );
    final databaseScope = ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: wrapper?.call(app) ?? app,
    );
    await tester.pumpWidget(databaseScope);
    await tester.pumpAndSettle();
    await settleVisualAssetImages(tester);
    await tester.pumpAndSettle();
    if (interact != null) {
      await interact(tester);
      await settleVisualAssetImages(tester);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      captureOverlay
          ? find.byKey(const Key('visual-capture-root'))
          : find.byType(Scaffold).first,
      matchesGoldenFile('goldens/visual_closure_$name.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
  }

  testWidgets('store plans production page phone capture', (tester) async {
    await capture(
      tester,
      page: const BilStorePlansPage(connectToDeviceStore: false),
      name: 'store_plans_phone',
    );
  });

  testWidgets('store plans production page lower actions capture', (
    tester,
  ) async {
    final catalog = _VisualStoreCatalog();
    await capture(
      tester,
      page: BilStorePlansPage(
        catalog: catalog,
        productIds: const {'bil.visual.monthly', 'bil.visual.annual'},
      ),
      name: 'store_plans_phone_2',
      interact: (tester) async {
        await tester.tap(find.textContaining(r'$4.79').first);
        await tester.pumpAndSettle();
        expect(catalog.purchaseCalls, 1);
        await tester.drag(find.byType(ListView).first, const Offset(0, -520));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Restore purchases'));
        await tester.tap(find.text('Manage subscription'));
        await tester.pumpAndSettle();
        expect(catalog.restoreCalls, 1);
        expect(catalog.manageCalls, 1);
      },
    );
  });

  for (var step = 0; step < 4; step++) {
    testWidgets('meal image guide production step ${step + 1} capture', (
      tester,
    ) async {
      await capture(
        tester,
        page: MealImageGuidePage(initialPage: step),
        name: 'meal_image_guide_${step + 1}_phone',
      );
    });
  }

  for (final tab in const <String>['meals', 'recipes', 'my_foods']) {
    testWidgets('saved nutrition $tab production empty-state capture', (
      tester,
    ) async {
      await capture(
        tester,
        page: const MealsRecipesFoodsPage(),
        name: 'saved_nutrition_${tab}_phone',
        seed: (database) =>
            PreferencesRepository(database).set('diary.defaultSearchTab', tab),
        wrapper: (child) => ProviderScope(
          overrides: [
            seedCatalogProvider.overrideWith((ref) async {}),
            foodsProvider.overrideWithValue(const AsyncData(<Food>[])),
          ],
          child: child,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('quick nutrition production dialog capture', (tester) async {
    await capture(
      tester,
      page: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showQuickMacroEntryDialog(
                context: context,
                copy: (english, _) => english,
                mealLabel: 'Breakfast',
                onSave: (_) async {},
              ),
              child: const Text('Open quick nutrition'),
            ),
          ),
        ),
      ),
      name: 'quick_nutrition_form_phone',
      captureOverlay: true,
      interact: (tester) async {
        await tester.tap(find.text('Open quick nutrition'));
        await tester.pumpAndSettle();
        expect(find.text('Quick Add macros'), findsOneWidget);
        expect(find.text('Breakfast'), findsOneWidget);
      },
    );
  });

  testWidgets('account gateway production Arabic phone capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const AccountGatewayPage(),
      name: 'account_gateway_ar_phone',
      locale: const Locale('ar'),
    );
  });

  testWidgets('community signed-out production state phone capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const CommunityHubPage(),
      name: 'community_signed_out_phone',
    );
  });

  testWidgets('community profile production unavailable state capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const CommunityProfilePage(),
      name: 'community_profile_phone',
    );
  });

  testWidgets('community connections production unavailable state capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const CommunityConnectionsPage(),
      name: 'community_connections_phone',
    );
  });

  testWidgets('community messages production unavailable state capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const CommunityChatPage(
        userId: 'visual-reference-user',
        displayName: 'BIL member',
      ),
      name: 'community_messages_phone',
    );
  });

  testWidgets('community authenticated profile production state capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: _VisualRouteStack(
        child: CommunityProfilePage(repository: _VisualCommunityRepository()),
      ),
      name: 'community_profile_authenticated_phone',
    );
  });

  testWidgets('community authenticated hub feed capture', (tester) async {
    await capture(
      tester,
      page: CommunityHubPage(repository: _VisualCommunityRepository()),
      name: 'community_hub_authenticated_phone',
      interact: (tester) async {
        expect(find.text('BIL QA Partner'), findsOneWidget);
        expect(
          find.textContaining('consistent movement habit'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('community authenticated navigation menu capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: CommunityHubPage(repository: _VisualCommunityRepository()),
      name: 'community_navigation_menu_authenticated_phone',
      captureOverlay: true,
      interact: (tester) async {
        await tester.tap(find.byTooltip('Community actions'));
        await tester.pumpAndSettle();
        expect(find.text('Community profile'), findsOneWidget);
        expect(find.text('Friends and requests'), findsOneWidget);
        expect(find.text('Find people'), findsOneWidget);
      },
    );
  });

  testWidgets('community authenticated incoming request state capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: CommunityConnectionsPage(
        repository: _VisualCommunityRepository(friendshipStatus: 'pending'),
      ),
      name: 'community_request_authenticated_phone',
      interact: (tester) async {
        await tester.tap(find.text('Requests'));
        await tester.pumpAndSettle();
        expect(find.text('Incoming friend request'), findsOneWidget);
      },
    );
  });

  testWidgets('community authenticated friend state capture', (tester) async {
    await capture(
      tester,
      page: CommunityConnectionsPage(repository: _VisualCommunityRepository()),
      name: 'community_friend_authenticated_phone',
      interact: (tester) async {
        expect(find.text('Friend'), findsOneWidget);
      },
    );
  });

  testWidgets('community add friends chooser authenticated capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: _VisualRouteStack(
        child: CommunityPeoplePage(repository: _VisualCommunityRepository()),
      ),
      name: 'community_add_friends_authenticated_phone',
      captureOverlay: true,
      interact: (tester) async {
        expect(
          find.byKey(const Key('community-add-from-contacts')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('community-add-by-bil-name')),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('community people search authenticated capture', (tester) async {
    await capture(
      tester,
      page: _VisualRouteStack(
        child: CommunityPeoplePage(repository: _VisualCommunityRepository()),
      ),
      name: 'community_people_search_authenticated_phone',
      captureOverlay: true,
      interact: (tester) async {
        await tester.enterText(
          find.byKey(const Key('community-people-search')),
          'BIL QA',
        );
        await tester.pumpAndSettle();
        expect(find.text('BIL QA Partner'), findsOneWidget);
        expect(find.byTooltip('Send request'), findsOneWidget);
      },
    );
  });

  testWidgets('community authenticated inbox state capture', (tester) async {
    await capture(
      tester,
      page: CommunityMessagesPage(repository: _VisualCommunityRepository()),
      name: 'community_inbox_authenticated_phone',
      interact: (tester) async {
        expect(find.text('Weekly check-in'), findsOneWidget);
      },
    );
  });

  testWidgets('community authenticated sent state capture', (tester) async {
    await capture(
      tester,
      page: CommunityMessagesPage(repository: _VisualCommunityRepository()),
      name: 'community_sent_authenticated_phone',
      interact: (tester) async {
        await tester.tap(find.text('Sent'));
        await tester.pumpAndSettle();
        expect(find.text('Plan update'), findsOneWidget);
      },
    );
  });

  testWidgets('community notifications empty authenticated capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: _VisualRouteStack(
        child: CommunityNotificationsPage(
          repository: _VisualCommunityRepository(emptyUpdates: true),
        ),
      ),
      name: 'community_notifications_empty_authenticated_phone',
      captureOverlay: true,
      interact: (tester) async {
        expect(find.text('No community updates'), findsOneWidget);
        expect(find.text('Find people'), findsOneWidget);
      },
    );
  });

  testWidgets('trust and support production page RTL dark capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const TrustSupportPage(),
      name: 'trust_support_rtl_dark_phone',
      locale: const Locale('ar'),
      brightness: Brightness.dark,
    );
  });

  testWidgets('privacy policy production capture', (tester) async {
    await capture(
      tester,
      page: const LegalDocumentPage(document: BilLegalDocument.privacy),
      name: 'privacy_policy_phone',
    );
  });

  testWidgets('terms of service production capture', (tester) async {
    await capture(
      tester,
      page: const LegalDocumentPage(document: BilLegalDocument.terms),
      name: 'terms_phone',
    );
  });

  testWidgets('advertising consent production capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const AdvertisingPrivacyPage(),
      name: 'advertising_privacy_phone',
    );
  });

  testWidgets('connected health permission state production capture', (
    tester,
  ) async {
    const snapshot = ConnectedHealthSnapshot(
      status: ConnectedHealthStatus.permissionDenied,
      platformSource: 'Health Connect',
      availableSources: ['Health Connect'],
      signals: [],
      importedCount: 0,
      lastSyncAt: null,
      failureCode: 'permission_denied',
    );
    await capture(
      tester,
      page: const ConnectedHealthPage(),
      name: 'connected_health_permission_phone',
      wrapper: (child) => ProviderScope(
        overrides: [
          connectedHealthGatewayProvider.overrideWithValue(
            const _VisualHealthGateway(snapshot),
          ),
        ],
        child: child,
      ),
    );
  });

  testWidgets('connected health compatibility production capture', (
    tester,
  ) async {
    const snapshot = ConnectedHealthSnapshot(
      status: ConnectedHealthStatus.permissionDenied,
      platformSource: 'Health Connect',
      availableSources: ['Health Connect'],
      signals: [],
      importedCount: 0,
      lastSyncAt: null,
      failureCode: 'permission_denied',
    );
    await capture(
      tester,
      page: const ConnectedHealthPage(),
      name: 'connected_health_compatibility_phone',
      wrapper: (child) => ProviderScope(
        overrides: [
          connectedHealthGatewayProvider.overrideWithValue(
            const _VisualHealthGateway(snapshot),
          ),
        ],
        child: child,
      ),
      interact: (tester) async {
        await tester.drag(find.byType(ListView), const Offset(0, -1010));
        await tester.pumpAndSettle();
      },
    );
  });

  const connectedHealthStates = <(String, ConnectedHealthSnapshot)>[
    ('unavailable', ConnectedHealthSnapshot.unavailable()),
    (
      'update_required',
      ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.updateRequired,
        platformSource: 'Health Connect',
        availableSources: ['Health Connect'],
        signals: [],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: 'update_required',
      ),
    ),
    (
      'offline',
      ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.degraded,
        platformSource: 'Health Connect',
        availableSources: ['Health Connect'],
        signals: [],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: 'offline',
      ),
    ),
  ];
  for (final state in connectedHealthStates) {
    testWidgets('connected health ${state.$1} production capture', (
      tester,
    ) async {
      await capture(
        tester,
        page: const ConnectedHealthPage(),
        name: 'connected_health_${state.$1}_phone',
        wrapper: (child) => ProviderScope(
          overrides: [
            connectedHealthGatewayProvider.overrideWithValue(
              _VisualHealthGateway(state.$2),
            ),
          ],
          child: child,
        ),
      );
    });
  }

  testWidgets('verified recipe library production capture', (tester) async {
    await capture(
      tester,
      page: ProfessionalContentLibraryPage(
        type: WellnessContentType.recipes,
        manager: _EmptyWellnessManager(),
      ),
      name: 'recipe_library_phone',
    );
  });

  testWidgets('local recipe discovery production capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const RecipeLibraryPage(),
      name: 'recipe_discovery_phone',
    );
  });

  for (var page = 2; page <= 8; page++) {
    testWidgets('local recipe discovery production capture page $page', (
      tester,
    ) async {
      await capture(
        tester,
        page: const RecipeLibraryPage(),
        name: 'recipe_discovery_phone_$page',
        interact: (tester) async {
          final verticalScrollable = find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          );
          final state = tester.state<ScrollableState>(verticalScrollable.first);
          final fraction = (page - 1) / 7;
          state.position.jumpTo(state.position.maxScrollExtent * fraction);
          await tester.pumpAndSettle();
        },
      );
    });
  }

  const additionalRecipeScrollFractions = <double>[.08, .22, .36, .64, .93];
  for (var index = 0; index < additionalRecipeScrollFractions.length; index++) {
    final page = index + 9;
    testWidgets('local recipe discovery production capture page $page', (
      tester,
    ) async {
      await capture(
        tester,
        page: const RecipeLibraryPage(),
        name: 'recipe_discovery_phone_$page',
        interact: (tester) async {
          final verticalScrollable = find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          );
          final state = tester.state<ScrollableState>(verticalScrollable.first);
          state.position.jumpTo(
            state.position.maxScrollExtent *
                additionalRecipeScrollFractions[index],
          );
          await tester.pumpAndSettle();
        },
      );
    });
  }

  testWidgets('local recipe detail production capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const RecipeLibraryPage(),
      name: 'recipe_detail_phone',
      captureOverlay: true,
      interact: (tester) async {
        await tester.tap(find.text('Bean & corn salad'));
        for (
          var attempt = 0;
          attempt < 30 && find.text('Ingredients').evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Ingredients'), findsOneWidget);
      },
    );
  });

  const recipeFilters = <(String, String)>[
    ('regional', 'Regional'),
    ('quick', 'Quick'),
    ('plant', 'Plant-forward'),
    ('saved', 'Saved'),
  ];
  for (final filter in recipeFilters) {
    testWidgets('local recipe ${filter.$1} collection capture', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await capture(
        tester,
        page: const RecipeLibraryPage(),
        name: 'recipe_collection_${filter.$1}_phone',
        interact: (tester) async {
          if (filter.$1 == 'saved') {
            final save = find.byTooltip('Save recipe').first;
            await tester.tap(save);
            await tester.pumpAndSettle();
          }
          final target = find.widgetWithText(ChoiceChip, filter.$2);
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
          final chip = tester.widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, filter.$2),
          );
          expect(chip.selected, isTrue);
          if (filter.$1 == 'saved') {
            expect(find.text('Bean & corn salad'), findsOneWidget);
          }
        },
      );
    });
  }

  testWidgets('local recipe search filters the authoritative catalog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const RecipeLibraryPage(),
      name: 'recipe_search_phone',
      interact: (tester) async {
        await tester.enterText(
          find.byType(TextField).first,
          'Bean & corn salad',
        );
        await tester.pumpAndSettle();
        expect(find.text('Bean & corn salad'), findsNWidgets(2));
        expect(find.text('1 of 1500 recipes'), findsOneWidget);
      },
    );
  });

  const recipeDetails = <(String, String)>[
    ('yogurt', 'Yogurt oat bowl'),
    ('chickpea', 'Chickpea herb salad'),
    ('shakshuka', 'Herbed shakshuka'),
  ];
  for (final detail in recipeDetails) {
    testWidgets('local recipe ${detail.$1} detail capture', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await capture(
        tester,
        page: const RecipeLibraryPage(),
        name: 'recipe_detail_${detail.$1}_phone',
        captureOverlay: true,
        interact: (tester) async {
          final target = find.text(detail.$2);
          await tester.scrollUntilVisible(
            target,
            420,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
        },
      );
    });
  }

  testWidgets('professional workout library production capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: ProfessionalContentLibraryPage(
        type: WellnessContentType.workouts,
        manager: _EmptyWellnessManager(),
      ),
      name: 'workout_library_phone',
    );
  });

  testWidgets('workout logging production page capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const WorkoutLibraryPage(),
      name: 'workout_log_phone',
    );
  });

  const workoutCategoryCaptures = <(String, String)>[
    ('2', 'Cardio'),
    ('3', 'Strength'),
    ('4', 'Recovery'),
  ];
  for (final captureState in workoutCategoryCaptures) {
    testWidgets('workout logging ${captureState.$2} category capture', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await capture(
        tester,
        page: const WorkoutLibraryPage(),
        name: 'workout_log_phone_${captureState.$1}',
        interact: (tester) async {
          await tester.tap(find.widgetWithText(ChoiceChip, captureState.$2));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ChoiceChip>(
                  find.widgetWithText(ChoiceChip, captureState.$2),
                )
                .selected,
            isTrue,
          );
        },
      );
    });
  }

  for (var page = 0; page < 10; page += 1) {
    testWidgets('strength all-exercises scroll evidence ${page + 1}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await capture(
        tester,
        page: const WorkoutLibraryPage(initialCategory: 'Strength'),
        name: 'workout_strength_all_scroll_${page + 1}_phone',
        interact: (tester) async {
          final list = find.byType(ListView).first;
          if (page > 0) {
            await tester.drag(list, Offset(0, -35.0 * page));
            await tester.pumpAndSettle();
          }
          final scrollable = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          if (page == 0) {
            expect(scrollable.position.pixels, 0);
          } else {
            expect(scrollable.position.pixels, greaterThan(0));
          }
          expect(find.text('All Exercises'), findsOneWidget);
        },
      );
    });
  }

  testWidgets('workout custom exercises empty state capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const WorkoutLibraryPage(),
      name: 'workout_my_exercises_phone',
      interact: (tester) async {
        await tester.tap(find.text('My Exercises'));
        await tester.pumpAndSettle();
        expect(find.text('No custom exercises yet'), findsOneWidget);
      },
    );
  });

  testWidgets('strength custom exercises empty state capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const WorkoutLibraryPage(initialCategory: 'Strength'),
      name: 'workout_strength_my_exercises_phone',
      interact: (tester) async {
        await tester.tap(find.text('My Exercises'));
        await tester.pumpAndSettle();
        expect(find.text('No custom exercises yet'), findsOneWidget);
      },
    );
  });

  testWidgets('custom exercise editor production capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const WorkoutLibraryPage(initialCategory: 'Strength'),
      name: 'workout_custom_exercise_editor_phone',
      captureOverlay: true,
      interact: (tester) async {
        await tester.tap(find.text('New exercise'));
        await tester.pumpAndSettle();
        expect(find.text('Create exercise'), findsOneWidget);
        expect(find.byKey(const Key('custom-exercise-name')), findsOneWidget);
      },
    );
  });

  testWidgets('workout display options production capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const WorkoutLibraryPage(initialCategory: 'Strength'),
      name: 'workout_display_options_phone',
      captureOverlay: true,
      interact: (tester) async {
        await tester.tap(find.byTooltip('Display options'));
        await tester.pumpAndSettle();
        expect(find.text('A to Z'), findsOneWidget);
        expect(find.text('Z to A'), findsOneWidget);
      },
    );
  });

  testWidgets('workout multi-add selected state capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const WorkoutLibraryPage(initialCategory: 'Strength'),
      name: 'workout_multi_add_phone',
      interact: (tester) async {
        await tester.tap(find.text('Multi-add'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Core strength'));
        await tester.pumpAndSettle();
        expect(find.text('Log 1'), findsOneWidget);
      },
    );
  });

  testWidgets('strength workout history empty state capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const WorkoutLibraryPage(),
      name: 'workout_strength_history_phone',
      interact: (tester) async {
        await tester.tap(find.widgetWithText(ChoiceChip, 'Strength'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        expect(find.text('No exercise history yet'), findsOneWidget);
      },
    );
  });

  testWidgets('saved custom workout routine production capture', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: BilWorkoutRoutinesPage(
        loader: (_) async => [_visualWorkoutRoutine, _visualWorkoutRoutineTwo],
      ),
      name: 'workout_routines_saved_phone',
      interact: (tester) async {
        await tester.tap(find.text('My Routines'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('build-custom-routine')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Routine name'),
          'Balanced mobility',
        );
        await tester.tap(
          find.widgetWithText(CheckboxListTile, 'Foundation mobility'),
        );
        await tester.tap(
          find.widgetWithText(CheckboxListTile, 'Foundation strength'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Save').last);
        await tester.pumpAndSettle();
        expect(find.text('Balanced mobility'), findsOneWidget);
        final preferences = await SharedPreferences.getInstance();
        final stored = preferences.getStringList(
          'bil.custom_workout_routines.v1',
        );
        expect(stored, hasLength(1));
        final record = jsonDecode(stored!.single) as Map<String, dynamic>;
        expect(record['name'], 'Balanced mobility');
        expect(
          record['itemIds'],
          containsAll(<String>[
            'visual-foundation-mobility',
            'visual-foundation-strength',
          ]),
        );
      },
    );
  });

  testWidgets('custom workout routine builder production capture', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: BilWorkoutRoutinesPage(
        loader: (_) async => [_visualWorkoutRoutine, _visualWorkoutRoutineTwo],
      ),
      name: 'workout_routine_builder_phone',
      captureOverlay: true,
      interact: (tester) async {
        await tester.tap(find.text('My Routines'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('build-custom-routine')));
        await tester.pumpAndSettle();
        expect(find.text('Build routine'), findsWidgets);
        expect(find.text('Foundation mobility'), findsOneWidget);
      },
    );
  });

  const workoutSelections = <(String, String)>[
    ('walk', 'Brisk walk'),
    ('run', 'Easy run'),
    ('cycle', 'Cycling'),
    ('strength', 'Full-body strength'),
    ('upper', 'Upper-body strength'),
    ('lower', 'Lower-body strength'),
    ('mobility', 'Mobility flow'),
    ('stretch', 'Gentle stretching'),
    ('swim', 'Swimming'),
    ('hike', 'Hiking'),
    ('stairs', 'Stair climbing'),
    ('row', 'Rowing'),
    ('dance', 'Dance fitness'),
    ('core', 'Core strength'),
    ('circuit', 'Strength circuit'),
    ('yoga', 'Yoga'),
    ('pilates', 'Pilates'),
    ('breathing', 'Breathing recovery'),
  ];
  for (final workout in workoutSelections) {
    testWidgets('workout ${workout.$1} selection form production capture', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await capture(
        tester,
        page: const WorkoutLibraryPage(),
        name: 'workout_entry_${workout.$1}_phone',
        captureOverlay: true,
        interact: (tester) async {
          // Featured cards intentionally repeat only these two promoted
          // exercise names. Off-screen lazy rows must keep the ordinary
          // finder so scrollUntilVisible can build them before selection.
          final matchesFeatured =
              workout.$1 == 'strength' || workout.$1 == 'mobility';
          final target = matchesFeatured
              ? find.text(workout.$2).last
              : find.text(workout.$2);
          await tester.scrollUntilVisible(
            target,
            520,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(find.text('Log workout'), findsOneWidget);
        },
      );
    });
  }

  testWidgets('dashboard customization production capture', (tester) async {
    await capture(
      tester,
      page: const DashboardPreferencesPage(),
      name: 'dashboard_preferences_phone',
    );
  });

  testWidgets('dashboard customization lower modules production capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const DashboardPreferencesPage(),
      name: 'dashboard_preferences_phone_2',
      interact: (tester) async {
        await tester.drag(find.byType(ListView).first, const Offset(0, -700));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('dashboard goal editing destinations capture', (tester) async {
    await capture(
      tester,
      page: const DashboardPreferencesPage(),
      name: 'dashboard_preferences_goal_edit_phone',
      seed: (database) async {
        await PreferencesRepository(database).setMany({
          'steps.dailyGoal': '7200',
          'dashboard.nutrientGoalCards': 'protein',
          'goal.proteinGrams': '132',
        });
      },
      interact: (tester) async {
        final target = find.byKey(
          const Key('dashboard-edit-exercise-settings'),
        );
        await tester.scrollUntilVisible(
          target,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('dashboard-edit-step-goal')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('dashboard-edit-nutrition-goals')),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('dashboard customization Arabic RTL production capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const DashboardPreferencesPage(),
      name: 'dashboard_preferences_ar_phone',
      locale: const Locale('ar'),
      wrapper: (child) => ProviderScope(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
        ],
        child: child,
      ),
    );
  });

  testWidgets('dashboard free nutrient cards locked preview capture', (
    tester,
  ) async {
    await capture(
      tester,
      page: const DashboardPreferencesPage(),
      name: 'dashboard_preferences_nutrient_locked_phone',
      captureOverlay: true,
      wrapper: (child) => ProviderScope(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(FreePlan.createState()),
          ),
        ],
        child: child,
      ),
      interact: (tester) async {
        final trigger = find.byKey(
          const Key('dashboard-add-nutrient-goal-cards'),
        );
        await tester.scrollUntilVisible(
          trigger,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(find.text('View Premium plans'), findsOneWidget);
      },
    );
  });

  testWidgets('dashboard Premium nutrient cards chooser capture', (
    tester,
  ) async {
    final premium = SubscriptionState(
      plan: CommercePlan.pro,
      entitlements: const {CommerceEntitlement.advancedIntelligence},
      authority: EntitlementAuthority.verifiedServer,
      isPurchasable: true,
      canRestorePurchases: true,
    );
    await capture(
      tester,
      page: const DashboardPreferencesPage(),
      name: 'dashboard_preferences_nutrient_premium_phone',
      captureOverlay: true,
      wrapper: (child) => ProviderScope(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWithValue(
            AsyncData(premium),
          ),
        ],
        child: child,
      ),
      interact: (tester) async {
        final trigger = find.byKey(
          const Key('dashboard-add-nutrient-goal-cards'),
        );
        await tester.scrollUntilVisible(
          trigger,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('dashboard-nutrient-goal-protein')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Save cards'), findsOneWidget);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('dashboard-nutrient-goal-protein')),
              )
              .value,
          isTrue,
        );
      },
    );
  });

  testWidgets('steps settings persisted honest state capture', (tester) async {
    await capture(
      tester,
      page: const StepsSettingsPage(),
      name: 'steps_settings_phone',
      seed: (database) async {
        await PreferencesRepository(
          database,
        ).setMany({'steps.source': 'none', 'steps.dailyGoal': '7200'});
      },
      wrapper: (child) => ProviderScope(
        overrides: [
          connectedHealthGatewayProvider.overrideWithValue(
            const _VisualHealthGateway(ConnectedHealthSnapshot.unavailable()),
          ),
        ],
        child: child,
      ),
      interact: (tester) async {
        expect(find.text('7200'), findsOneWidget);
        expect(find.text('10000'), findsNothing);
      },
    );
  });

  const preferenceSections = <(String, String)>[
    ('calories', 'Calories'),
    ('macros', 'Macros'),
    ('activity', 'Activity'),
    ('quick_log', 'Quick log'),
    ('discover', 'Discover'),
    ('best_action', 'Personal intelligence'),
    ('daily_intelligence', 'Daily intelligence'),
    ('progress', 'Progress'),
    ('connected_health', 'Connected health'),
    ('body_twin', 'Body Twin'),
  ];
  for (final section in preferenceSections) {
    testWidgets('dashboard customization ${section.$1} disabled capture', (
      tester,
    ) async {
      await capture(
        tester,
        page: const DashboardPreferencesPage(),
        name: 'dashboard_preferences_${section.$1}_phone',
        interact: (tester) async {
          // Quick log and Personal intelligence are both hidden by default.
          // Turn the peer on so each golden proves one distinct disabled state.
          final peerLabel = switch (section.$1) {
            'quick_log' => 'Personal intelligence',
            'best_action' => 'Quick log',
            _ => null,
          };
          if (peerLabel != null) {
            final peer = find.text(peerLabel);
            await tester.scrollUntilVisible(
              peer,
              180,
              scrollable: find.byType(Scrollable).first,
            );
            final peerTile = find.ancestor(
              of: peer,
              matching: find.byType(SwitchListTile),
            );
            if (!tester.widget<SwitchListTile>(peerTile).value) {
              await tester.tap(peerTile);
              await tester.pumpAndSettle();
            }
          }
          final target = find.text(section.$2);
          await tester.scrollUntilVisible(
            target,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            tester.element(target),
            alignment: .35,
            duration: Duration.zero,
          );
          await tester.pumpAndSettle();
          final tile = find.ancestor(
            of: target,
            matching: find.byType(SwitchListTile),
          );
          if (tester.widget<SwitchListTile>(tile).value) {
            await tester.tap(tile);
            await tester.pumpAndSettle();
          }
          expect(tester.widget<SwitchListTile>(tile).value, isFalse);
          if (section.$1 == 'quick_log') {
            final restore = find.text('Restore default view');
            await Scrollable.ensureVisible(
              tester.element(restore),
              alignment: .72,
              duration: Duration.zero,
            );
            await tester.pumpAndSettle();
          }
        },
      );
    });
  }

  testWidgets('help center production capture', (tester) async {
    await capture(
      tester,
      page: const HelpCenterPage(),
      name: 'help_center_phone',
    );
  });

  const helpQuestions = <(String, String, String)>[
    (
      'targets',
      'How does BIL calculate my targets?',
      'BIL uses the profile and goals you saved and shows missing evidence instead of inventing values.',
    ),
    (
      'offline',
      'Can I use BIL offline?',
      'Core logging and saved content work offline. Connected services clearly show when a connection is required.',
    ),
    (
      'medical',
      'Is BIL medical advice?',
      'No. BIL supports wellness tracking and does not diagnose, prescribe, or replace a qualified clinician.',
    ),
  ];
  for (final question in helpQuestions) {
    testWidgets('help ${question.$1} answer production capture', (
      tester,
    ) async {
      await capture(
        tester,
        page: const HelpFaqPage(),
        name: 'help_faq_${question.$1}_phone',
        interact: (tester) async {
          final target = find.text(question.$2);
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(find.text(question.$3), findsOneWidget);
        },
      );
    });
  }

  for (final dialog in <(String, String, String)>[
    (
      'about',
      'About BIL',
      'Private body intelligence for nutrition, movement, recovery and progress. BIL keeps evidence and user control visible.',
    ),
    (
      'troubleshooting',
      'Troubleshooting',
      'Check connectivity and permissions, restart BIL, then try again. Your saved local data is not removed.',
    ),
    (
      'service_status',
      'Service Status',
      'Core local logging is available. Connected integrations show their current state and permissions on Apps & Devices.',
    ),
  ]) {
    testWidgets('help ${dialog.$1} production dialog capture', (tester) async {
      await capture(
        tester,
        page: const HelpCenterPage(),
        name: 'help_${dialog.$1}_phone',
        captureOverlay: true,
        interact: (tester) async {
          await tester.tap(find.text(dialog.$2));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text(dialog.$3), findsOneWidget);
        },
      );
    });
  }

  testWidgets('sleep production page capture', (tester) async {
    await capture(tester, page: const SleepTrackerPage(), name: 'sleep_phone');
  });

  testWidgets('sleep production saved record capture', (tester) async {
    await capture(
      tester,
      page: const SleepTrackerPage(),
      name: 'sleep_phone_2',
      seed: (database) async {
        await DailyLogRepository(
          database,
        ).save(date: DateTime.now(), sleepHours: 7.5);
      },
      interact: (tester) async {
        expect(find.textContaining('Recorded today: 7.5 h'), findsOneWidget);
      },
    );
  });

  testWidgets('sleep measured trend production capture', (tester) async {
    await capture(
      tester,
      page: const SleepTrackerPage(),
      name: 'sleep_trend_phone',
      seed: (database) async {
        final repository = DailyLogRepository(database);
        for (var day = 0; day < 5; day++) {
          await repository.save(
            date: DateTime.now().subtract(Duration(days: day)),
            sleepHours: 6.5 + (day * .35),
          );
        }
      },
      interact: (tester) async {
        await tester.tap(find.text('Insights'));
        await tester.pumpAndSettle();
      },
    );
  });

  for (final state in const [
    (page: 1, swipes: 0, title: 'How does food affect your sleep?'),
    (page: 2, swipes: 1, title: "Find out what's keeping you awake"),
    (page: 3, swipes: 2, title: 'Time your meals for the best rest'),
  ]) {
    testWidgets('sleep education production page ${state.page} capture', (
      tester,
    ) async {
      await capture(
        tester,
        page: const SleepTrackerPage(),
        name: state.page == 1
            ? 'sleep_learn_phone'
            : 'sleep_learn_phone_${state.page}',
        interact: (tester) async {
          await tester.tap(find.text('Learn'));
          await tester.pumpAndSettle();
          final carousel = find.byKey(const Key('sleep-education-carousel'));
          for (var swipe = 0; swipe < state.swipes; swipe++) {
            await tester.drag(carousel, const Offset(-320, 0));
            await tester.pumpAndSettle();
          }
          expect(
            find
                .descendant(of: carousel, matching: find.text(state.title))
                .hitTestable(),
            findsOneWidget,
          );
        },
      );
    });
  }

  testWidgets('fasting production page capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const FastingTimerPage(),
      name: 'fasting_phone',
    );
  });

  testWidgets('wellness directory production page capture', (tester) async {
    await capture(
      tester,
      page: const WellnessLibraryPage(),
      name: 'wellness_library_phone',
    );
  });

  testWidgets('wellness learn production page capture', (tester) async {
    await capture(
      tester,
      page: const WellnessLearnPage(),
      name: 'wellness_learn_phone',
    );
  });

  testWidgets('wellness learn filtered search capture', (tester) async {
    await capture(
      tester,
      page: const WellnessLearnPage(),
      name: 'wellness_learn_search_phone',
      interact: (tester) async {
        final search = find.byType(SearchBar);
        expect(search, findsOneWidget);
        await tester.tap(search);
        await tester.enterText(search, 'sleep');
        await tester.pumpAndSettle();
        expect(
          find.text('Why one night cannot explain your sleep'),
          findsOneWidget,
        );
        expect(find.text('Educational highlights'), findsNothing);
      },
    );
  });

  for (final topic in const ['Nutrition', 'Movement', 'Sleep', 'Privacy']) {
    testWidgets('wellness learn $topic topic capture', (tester) async {
      await capture(
        tester,
        page: const WellnessLearnPage(),
        name: 'wellness_learn_${topic.toLowerCase()}_phone',
        interact: (tester) async {
          final target = find.text(topic);
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
          final chip = tester.widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, topic),
          );
          expect(chip.selected, isTrue);
        },
      );
    });
  }

  const learnArticles = <(String, String)>[
    ('nutrition', 'How to read your food log without judgment'),
    ('movement', 'Consistency matters more than a perfect day'),
    ('sleep', 'Why one night cannot explain your sleep'),
    ('privacy', 'Your health data stays under your control'),
  ];
  for (final article in learnArticles) {
    testWidgets('wellness learn ${article.$1} article capture', (tester) async {
      await capture(
        tester,
        page: const WellnessLearnPage(),
        name: 'wellness_learn_article_${article.$1}_phone',
        captureOverlay: true,
        interact: (tester) async {
          final target = find.text(article.$2);
          await tester.scrollUntilVisible(
            target,
            400,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(target.first);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
        },
      );
    });
  }

  for (var page = 2; page <= 4; page++) {
    testWidgets('wellness learn production page $page capture', (tester) async {
      await capture(
        tester,
        page: const WellnessLearnPage(),
        name: 'wellness_learn_phone_$page',
        interact: (tester) async {
          for (var step = 1; step < page; step++) {
            await tester.drag(find.byType(ListView), const Offset(0, -420));
            await tester.pumpAndSettle();
          }
        },
      );
    });
  }

  testWidgets('notification settings production page capture', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await capture(
      tester,
      page: const NotificationSettingsPage(),
      name: 'notification_settings_phone',
    );
  });
}
