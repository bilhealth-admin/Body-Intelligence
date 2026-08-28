/// Projects the private, device-local profile identity into the Community
/// editor without publishing it as a side effect of reading the page.
///
/// An explicit Community alias always wins. This preserves the user's choice
/// to use a different public name from the one shown in My Profile. When no
/// Community identity exists yet, the user-selected My Profile display name is
/// used as the editor seed. `BIL` is the privacy-safe brand fallback; email and
/// authentication metadata are deliberately outside this contract.
abstract final class CommunityIdentityProjection {
  static const fallbackDisplayName = 'BIL';

  static String resolveDisplayName({
    String? communityDisplayName,
    String? myProfileDisplayName,
  }) {
    return _validDisplayName(communityDisplayName) ??
        _validDisplayName(myProfileDisplayName) ??
        fallbackDisplayName;
  }

  static String? _validDisplayName(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.length < 2 || normalized.length > 60) {
      return null;
    }
    return normalized;
  }
}
