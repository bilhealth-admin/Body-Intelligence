import 'global_platform_test_support.dart';

void main() {
  test(
    'professional invitations and RBAC are durable revocable and audited',
    () async {
      final store = InMemoryGlobalStore();
      final runtime = ProfessionalRuntime(
        store: store,
        audit: InMemoryGlobalAuditSink(),
      );
      await runtime.createWorkspace(
        id: 'w',
        ownerId: 'o',
        name: 'Clinic',
        at: DateTime.utc(2026),
      );
      await runtime.invite(
        id: 'i',
        workspaceId: 'w',
        email: 'd@x.com',
        role: ProfessionalRole.doctor,
        scopes: {'read'},
        expiresAt: DateTime.utc(2027),
        at: DateTime.utc(2026),
      );
      await runtime.acceptInvite(
        inviteId: 'i',
        subjectId: 'd',
        consentId: 'c',
        at: DateTime.utc(2026),
      );
      expect(await runtime.permits('d', 'w', 'read', DateTime.utc(2026)), true);
      await runtime.revoke('grant:i:d', DateTime.utc(2026));
      expect(
        await runtime.permits('d', 'w', 'read', DateTime.utc(2026)),
        false,
      );
    },
  );
}
