import '../core/global_platform_core.dart';

enum ProfessionalRole { owner, doctor, coach, viewer }

final class AccessGrant {
  AccessGrant({
    required this.id,
    required this.workspaceId,
    required this.subjectId,
    required this.role,
    required this.scopes,
    required DateTime expiresAt,
    required this.consentId,
  }) : expiresAt = expiresAt.toUtc();
  final String id, workspaceId, subjectId, consentId;
  final ProfessionalRole role;
  final Set<String> scopes;
  final DateTime expiresAt;
}

final class ProfessionalRuntime {
  ProfessionalRuntime({required this.store, required this.audit});
  final GlobalDurableStore store;
  final GlobalAuditSink audit;

  Future<void> createWorkspace({
    required String id,
    required String ownerId,
    required String name,
    required DateTime at,
  }) async {
    await store.put('professional_workspaces', id, <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'createdAt': at.toUtc().toIso8601String(),
    });
    await audit.record(
      GlobalAuditEvent(
        action: 'professional.workspace.created',
        subjectId: ownerId,
        at: at,
        metadata: <String, Object?>{'workspace': id},
      ),
    );
  }

  Future<void> invite({
    required String id,
    required String workspaceId,
    required String email,
    required ProfessionalRole role,
    required Set<String> scopes,
    required DateTime expiresAt,
    required DateTime at,
  }) async {
    if (await store.get('professional_workspaces', workspaceId) == null) {
      throw StateError('Unknown workspace.');
    }
    await store.put('professional_invites', id, <String, Object?>{
      'id': id,
      'workspace': workspaceId,
      'email': email,
      'role': role.name,
      'scopes': scopes.toList()..sort(),
      'expires': expiresAt.toUtc().toIso8601String(),
      'state': 'pending',
    });
    await audit.record(
      GlobalAuditEvent(
        action: 'professional.invite.created',
        subjectId: email,
        at: at,
        metadata: <String, Object?>{'workspace': workspaceId},
      ),
    );
  }

  Future<void> acceptInvite({
    required String inviteId,
    required String subjectId,
    required String consentId,
    required DateTime at,
  }) async {
    final invite = await store.get('professional_invites', inviteId);
    if (invite == null || invite['state'] != 'pending') {
      throw StateError('Invalid invitation.');
    }
    if (!DateTime.parse(invite['expires']! as String).isAfter(at.toUtc())) {
      throw StateError('Invitation expired.');
    }
    final grant = AccessGrant(
      id: 'grant:$inviteId:$subjectId',
      workspaceId: invite['workspace']! as String,
      subjectId: subjectId,
      role: ProfessionalRole.values.byName(invite['role']! as String),
      scopes: Set<String>.from(invite['scopes']! as List<Object?>),
      expiresAt: DateTime.parse(invite['expires']! as String),
      consentId: consentId,
    );
    await grantAccess(grant, at);
    await store.put('professional_invites', inviteId, <String, Object?>{
      ...invite,
      'state': 'accepted',
    });
  }

  Future<void> grantAccess(AccessGrant grant, DateTime at) async {
    await store.put('professional_grants', grant.id, <String, Object?>{
      'id': grant.id,
      'workspace': grant.workspaceId,
      'subject': grant.subjectId,
      'role': grant.role.name,
      'scopes': grant.scopes.toList()..sort(),
      'expires': grant.expiresAt.toIso8601String(),
      'consentId': grant.consentId,
    });
    await audit.record(
      GlobalAuditEvent(
        action: 'professional.grant',
        subjectId: grant.subjectId,
        at: at,
        metadata: <String, Object?>{
          'workspace': grant.workspaceId,
          'scopes': grant.scopes.toList(),
        },
      ),
    );
  }

  Future<bool> permits(
    String subject,
    String workspace,
    String scope,
    DateTime at,
  ) async => (await store.list('professional_grants')).any(
    (grant) =>
        grant['subject'] == subject &&
        grant['workspace'] == workspace &&
        (grant['scopes']! as List<Object?>).contains(scope) &&
        DateTime.parse(grant['expires']! as String).isAfter(at.toUtc()),
  );

  Future<void> revoke(String id, DateTime at) async {
    final grant = await store.get('professional_grants', id);
    await store.remove('professional_grants', id);
    await audit.record(
      GlobalAuditEvent(
        action: 'professional.revoke',
        subjectId: grant?['subject'] as String? ?? id,
        at: at,
      ),
    );
  }
}
