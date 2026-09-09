part of 'community_models.dart';

class CommunityPostAuthorSocial {
  const CommunityPostAuthorSocial({
    required this.userId,
    required this.handle,
    required this.relationship,
    required this.canRequest,
  });

  final String userId;
  final String handle;
  final CommunityRelationshipStatus relationship;
  final bool canRequest;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  factory CommunityPostAuthorSocial.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    final handle = json['handle'];
    final relationship = json['relationship'];
    final canRequest = json['can_request'];
    if (userId is! String ||
        !_uuidPattern.hasMatch(userId) ||
        handle is! String ||
        !CommunitySocialIdentity.handlePattern.hasMatch(handle) ||
        relationship is! String ||
        !CommunityRelationshipStatus.values.any(
          (value) => value.name == relationship,
        ) ||
        canRequest is! bool ||
        (canRequest && relationship != 'none')) {
      throw const FormatException('Invalid Community post author');
    }
    return CommunityPostAuthorSocial(
      userId: userId,
      handle: handle,
      relationship: CommunityRelationshipStatus.values.byName(relationship),
      canRequest: canRequest,
    );
  }
}
