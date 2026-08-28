import 'package:body_intelligence_log/data/database/database_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDatabaseScope', () {
    test(
      'guest and authenticated accounts use different stable namespaces',
      () {
        expect(LocalDatabaseScope.keyForOwner(null), 'guest');
        final ownerA = LocalDatabaseScope.keyForOwner('owner-a');
        final ownerARepeat = LocalDatabaseScope.keyForOwner('owner-a');
        final ownerB = LocalDatabaseScope.keyForOwner('owner-b');

        expect(ownerA, startsWith('account_'));
        expect(ownerA, ownerARepeat);
        expect(ownerA, isNot(ownerB));
        expect(ownerA, isNot(contains('owner-a')));
      },
    );

    test(
      'legacy data is never adopted by a different authenticated account',
      () {
        expect(
          LocalDatabaseScope.canAdoptLegacyDatabase(
            activeOwnerId: 'owner-b',
            legacyOwnerId: 'owner-a',
          ),
          isFalse,
        );
        expect(
          LocalDatabaseScope.canAdoptLegacyDatabase(
            activeOwnerId: 'owner-a',
            legacyOwnerId: 'owner-a',
          ),
          isTrue,
        );
        expect(
          LocalDatabaseScope.canAdoptLegacyDatabase(
            activeOwnerId: 'owner-a',
            legacyOwnerId: null,
          ),
          isTrue,
        );
        expect(
          LocalDatabaseScope.canAdoptLegacyDatabase(
            activeOwnerId: null,
            legacyOwnerId: 'owner-a',
          ),
          isFalse,
        );
      },
    );

    test('database filenames are isolated by account', () {
      final a = LocalDatabaseScope.databaseFileName('owner-a');
      final b = LocalDatabaseScope.databaseFileName('owner-b');
      final guest = LocalDatabaseScope.databaseFileName(null);

      expect(a, isNot(b));
      expect(a, isNot(guest));
      expect(b, isNot(guest));
      expect(a, endsWith('.sqlite'));
    });
  });
}
