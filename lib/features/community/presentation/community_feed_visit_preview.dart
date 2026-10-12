part of 'community_hub_page.dart';

/// Bounded presentation reads for one owner visit and language. This is not
/// publishing authority: write entry points always request fresh policy state.
class _CommunityFeedVisitPreview {
  _CommunityFeedVisitPreview(
    this.visit,
    this.locale,
    Future<CommunityProfileOverview?>? initialProfile,
  ) {
    profile = initialProfile;
    topics = visit.run(visit.repository.loadCommunityTopics).then((value) {
      if (visit.isCurrent()) knownTopics = value;
      return value;
    }, onError: (Object _, StackTrace _) => const <CommunityTopic>[]);
    refreshPolicy();
  }

  final _CommunityHomeVisit visit;
  final String locale;
  Future<CommunityProfileOverview?>? _profile;
  CommunityProfileOverview? knownProfile;
  Future<CommunityProfileOverview?>? get profile => _profile;
  set profile(Future<CommunityProfileOverview?>? value) {
    _profile = value;
    value?.then<void>((result) {
      if (visit.isCurrent() && identical(value, _profile)) {
        knownProfile = result;
      }
    }, onError: (Object _, StackTrace _) {});
  }

  late final Future<List<CommunityTopic>> topics;
  List<CommunityTopic>? knownTopics;
  final scrollOffsets = <CommunityFeedMode, double>{};
  late Future<CommunityPolicyState> policy;
  CommunityPolicyState? knownPolicy;
  final Stopwatch _age = Stopwatch();
  int _policyRead = 0;

  void refreshIfExpired() {
    if (_age.elapsed >= const Duration(seconds: 30)) refreshPolicy();
  }

  Future<CommunityPolicyState> refreshPolicy() {
    final read = ++_policyRead;
    knownPolicy = null;
    _age.reset();
    _age.start();
    policy = visit
        .run(
          () => visit.repository.loadCommunityPolicyState(localeCode: locale),
        )
        .then(
          (value) {
            if (visit.isCurrent() && read == _policyRead) knownPolicy = value;
            return value;
          },
          onError: (Object _, StackTrace _) {
            const value = CommunityPolicyState.unavailable();
            if (visit.isCurrent() && read == _policyRead) knownPolicy = value;
            return value;
          },
        );
    return policy;
  }
}
