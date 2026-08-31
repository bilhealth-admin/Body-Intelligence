import 'package:body_intelligence_log/features/settings/account_deletion_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({
  Map<String, dynamic> appMetadata = const {},
  List<UserIdentity>? identities,
}) => User(
  id: 'test-user',
  appMetadata: appMetadata,
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-08-30T00:00:00Z',
  identities: identities,
);

void main() {
  test('detects Apple from the authenticated identity list', () {
    final user = _user(
      identities: const [
        UserIdentity(
          id: 'identity',
          userId: 'test-user',
          identityData: null,
          identityId: 'apple-subject',
          provider: 'apple',
          createdAt: null,
          lastSignInAt: null,
        ),
      ],
    );

    expect(accountUsesAppleSignIn(user), isTrue);
  });

  test('falls back to Supabase provider metadata', () {
    expect(
      accountUsesAppleSignIn(
        _user(
          appMetadata: const {
            'providers': ['email', 'apple'],
          },
        ),
      ),
      isTrue,
    );
    expect(
      accountUsesAppleSignIn(_user(appMetadata: const {'provider': 'apple'})),
      isTrue,
    );
  });

  test('does not show Apple-specific guidance without Apple evidence', () {
    expect(accountUsesAppleSignIn(null), isFalse);
    expect(
      accountUsesAppleSignIn(
        _user(
          appMetadata: const {
            'provider': 'email',
            'providers': ['email'],
          },
        ),
      ),
      isFalse,
    );
  });
}
