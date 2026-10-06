import '../data/community_repository.dart';
import '../domain/community_models.dart';

/// Proof of a saved profile and a validated, server-provided BIL Code.
/// Not an entitlement, policy-acceptance receipt, or posting permission.
class CommunityEntryReceipt {
  const CommunityEntryReceipt({required this.profile, required this.code});
  final CommunityProfile profile;
  final CommunityPublicCode code;
}

class CommunityEntryOwnerChanged implements Exception {
  const CommunityEntryOwnerChanged();
}

/// Entry never edits an existing profile or rotates an existing public code.
/// Every asynchronous boundary is tied to the original authenticated owner.
class CommunityEntryCoordinator {
  CommunityEntryCoordinator(this.repository, {this.isCurrentOwner});
  final CommunityRepository repository;
  // A UI session epoch also invalidates A -> B -> A and disposal. The current
  // user ID alone cannot distinguish work from a previous visit by the owner.
  final bool Function()? isCurrentOwner;
  Future<CommunityEntryReceipt>? _saving;
  String? _savingOwner;

  void _requireOwner(String owner) {
    if (repository.currentUserId != owner || isCurrentOwner?.call() == false) {
      throw const CommunityEntryOwnerChanged();
    }
  }

  Future<CommunityEntryReceipt> _complete(
    String owner,
    CommunityProfile profile,
  ) async {
    _requireOwner(owner);
    if (profile.userId != owner || profile.displayName.trim().isEmpty) {
      throw const CommunityEntryOwnerChanged();
    }
    final result = await repository.loadPublicCode();
    _requireOwner(owner);
    // Validate the actual wire contract, including the full non-auth code URI.
    final code = CommunityPublicCode.fromJson({
      'code': result.code,
      'uri': result.uri.toString(),
      'handle': result.handle,
    });
    return CommunityEntryReceipt(profile: profile, code: code);
  }

  Future<CommunityEntryReceipt?> check() async {
    final owner = repository.currentUserId;
    _requireOwner(owner);
    final profile = await repository.loadMyProfile();
    _requireOwner(owner);
    return profile == null ? null : _complete(owner, profile);
  }

  Future<CommunityEntryReceipt> save({
    required String displayName,
    required String localeCode,
  }) {
    final owner = repository.currentUserId;
    _requireOwner(owner);
    if (_saving != null && _savingOwner == owner) return _saving!;
    _savingOwner = owner;
    late final Future<CommunityEntryReceipt> operation;
    operation = _save(owner, displayName, localeCode).then(
      (receipt) {
        if (identical(_saving, operation)) _saving = null;
        return receipt;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_saving, operation)) _saving = null;
        Error.throwWithStackTrace(error, stack);
      },
    );
    return _saving = operation;
  }

  Future<CommunityEntryReceipt> _save(
    String owner,
    String displayName,
    String localeCode,
  ) async {
    final name = displayName.trim();
    // Preserve the existing profile editor/repository contract. No new
    // username, photo, friendship, discoverability, or payment requirement.
    if (name.length < 2 || name.length > 60) {
      throw const FormatException('Invalid community display name');
    }
    final existing = await repository.loadMyProfile();
    _requireOwner(owner);
    if (existing != null) return _complete(owner, existing);

    await repository.createMyCommunityEntryProfile(
      displayName: name,
      localeCode: localeCode,
      expectedOwnerId: owner,
    );
    _requireOwner(owner);
    final saved = await repository.loadMyProfile();
    _requireOwner(owner);
    if (saved == null) {
      throw StateError('Community profile save not confirmed');
    }
    // Another device may have created the profile concurrently. The insert is
    // do-nothing-on-conflict: accept its authoritative name/privacy, not ours.
    return _complete(owner, saved);
  }
}
