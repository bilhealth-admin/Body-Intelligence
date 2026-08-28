import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/domain/community_identity_projection.dart';
import 'package:body_intelligence_log/features/community/domain/community_models.dart';
import 'package:body_intelligence_log/features/community/presentation/community_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _MissingCommunityProfileRepository extends CommunityRepository {
  _MissingCommunityProfileRepository()
    : super(
        SupabaseClient(
          'https://community-identity.invalid',
          'community-identity-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  int loads = 0;
  int saves = 0;

  @override
  Future<CommunityProfile?> loadMyProfile() async {
    loads++;
    return null;
  }

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
    saves++;
  }
}

void main() {
  test('Community identity projection preserves privacy-safe precedence', () {
    expect(
      CommunityIdentityProjection.resolveDisplayName(
        communityDisplayName: ' Community alias ',
        myProfileDisplayName: 'My Profile name',
      ),
      'Community alias',
    );
    expect(
      CommunityIdentityProjection.resolveDisplayName(
        communityDisplayName: ' ',
        myProfileDisplayName: ' BIL Owner ',
      ),
      'BIL Owner',
    );
    expect(CommunityIdentityProjection.resolveDisplayName(), 'BIL');
  });

  testWidgets(
    'Community read seeds BIL without filling bio or writing cloud state',
    (tester) async {
      final repository = _MissingCommunityProfileRepository();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: CommunityProfilePage(repository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(greaterThanOrEqualTo(2)));
      expect(fields[0].controller?.text, 'BIL');
      expect(fields[1].controller?.text, isEmpty);
      expect(repository.loads, 1);
      expect(repository.saves, 0);
    },
  );
}
