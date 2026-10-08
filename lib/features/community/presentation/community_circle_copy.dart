part of 'community_hub_page.dart';

const _circleSlugByTitleKey = <String, String>{
  'community_circle_10k_steps': '10k-steps',
  'community_circle_healthy_eating': 'healthy-eating',
  'community_circle_beginner_fitness': 'beginner-fitness',
  'community_circle_strength': 'strength',
  'community_circle_running': 'running',
  'community_circle_sleep': 'sleep',
  'community_circle_ramadan_fasting': 'ramadan-fasting',
  'community_circle_weight_loss_journey': 'weight-loss-journey',
};

String _circleRecordTitle(BuildContext context, CommunityCircle circle) {
  if (circle is ManagedCommunityCircle &&
      circle.displayName?.trim().isNotEmpty == true) {
    return circle.displayName!;
  }
  final known = _circleSlugByTitleKey[circle.titleCopyKey];
  // A new unmapped server identity keeps its slug. A familiar slug must not
  // override a different title key returned by the current server record.
  return known == null ? circle.slug : _circleTitle(context, known);
}

String? _circleKnownDescription(BuildContext context, CommunityCircle circle) {
  if (circle is ManagedCommunityCircle &&
      circle.description?.trim().isNotEmpty == true) {
    return circle.description;
  }
  const suffix = '_body';
  final key = circle.descriptionCopyKey;
  if (!key.endsWith(suffix)) return null;
  final known =
      _circleSlugByTitleKey[key.substring(0, key.length - suffix.length)];
  return known == null ? null : _circleDescription(context, known);
}

String _circleRecordDescription(BuildContext context, CommunityCircle circle) =>
    _circleKnownDescription(context, circle) ??
    communityText(context, 'Description unavailable.', 'الوصف غير متاح.');

String _circleRecordRules(BuildContext context, CommunityCircle circle) =>
    circle is ManagedCommunityCircle && circle.rules?.trim().isNotEmpty == true
    ? circle.rules!
    : circle.rulesCopyKey == 'community_circle_standard_rules'
    ? communityText(
        context,
        'Be respectful, avoid private health details, and follow Community policy.',
        'كن محترمًا، وتجنب التفاصيل الصحية الخاصة، والتزم بسياسة المجتمع.',
      )
    : communityText(
        context,
        'Circle rules are unavailable.',
        'قواعد الدائرة غير متاحة.',
      );

String _circleMembershipLabel(BuildContext context, CommunityCircle circle) {
  if (circle.activeMember) return communityText(context, 'Joined', 'منضم');
  if (circle.pending) {
    return communityText(context, 'Requested', 'الطلب مُرسل');
  }
  if (circle.membershipStatus == CommunityCircleMembershipStatus.banned) {
    return communityText(
      context,
      'Membership unavailable',
      'العضوية غير متاحة',
    );
  }
  if (circle.joinPolicy == CommunityCircleJoinPolicy.invite) {
    return communityText(context, 'Invitation required', 'تحتاج إلى دعوة');
  }
  return communityText(context, 'Join', 'انضمام');
}

bool _circleCanChangeMembership(CommunityCircle circle) =>
    circle.membershipStatus != CommunityCircleMembershipStatus.banned &&
    (circle.activeMember ||
        circle.pending ||
        circle.joinPolicy != CommunityCircleJoinPolicy.invite);
