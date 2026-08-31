import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated email always wins over a cached owner email', () {
    const identity = ProfileAuthIdentity(
      ownerId: 'signed-in-user',
      email: 'member@example.test',
    );

    expect(
      resolveAuthoritativeProfileEmail(
        authIdentity: identity,
        cachedEmail: 'kademcom@yahoo.com',
      ),
      'member@example.test',
    );
  });

  test('missing auth email fails closed instead of leaking cached email', () {
    const identity = ProfileAuthIdentity(
      ownerId: 'signed-in-user',
      email: null,
    );

    expect(
      resolveAuthoritativeProfileEmail(
        authIdentity: identity,
        cachedEmail: 'owner@example.test',
      ),
      isEmpty,
    );
  });

  test('sign-out and sign-in identities have distinct hydration scopes', () {
    const guest = ProfileAuthIdentity.local();
    const first = ProfileAuthIdentity(ownerId: 'user-a', email: 'a@test.dev');
    const second = ProfileAuthIdentity(ownerId: 'user-b', email: 'b@test.dev');

    expect(
      guest.hydrationKey('profile-1'),
      isNot(first.hydrationKey('profile-1')),
    );
    expect(
      first.hydrationKey('profile-1'),
      isNot(second.hydrationKey('profile-1')),
    );
  });
}
