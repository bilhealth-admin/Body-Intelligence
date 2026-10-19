part of 'community_repository.dart';

extension _CommunityCircleReportWrites on CommunityRepository {
  Future<void> _sendCircleReport({
    required String slug,
    required String reason,
  }) => _runCommunityOwnerOperation((operation) async {
    final text = reason.trim();
    if (!CommunityCircle.slugPattern.hasMatch(slug) ||
        slug.length > 48 ||
        text.runes.length < 3 ||
        text.runes.length > 500 ||
        CommunityRepository._unsafeText.hasMatch(text)) {
      throw ArgumentError('Invalid Community circle report');
    }
    final id = await _client.rpc(
      'bil_report_circle_v1',
      params: {'p_slug': slug, 'p_reason': text},
    );
    operation.check();
    if (id is! String || !CommunityRepository._uuid.hasMatch(id)) {
      throw const FormatException('Invalid Community circle report receipt');
    }
  });
}
