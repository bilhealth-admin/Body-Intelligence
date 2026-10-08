import '../domain/community_models.dart';

/// A browser-friendly public invitation. The opaque, rotatable BIL Code is
/// intentionally used instead of any private account identifier.
abstract final class CommunityMemberShare {
  static const downloadHost = 'www.bilhealth.com';

  static Uri linkFor(CommunityPublicCode code) {
    if (!CommunityPublicCode.codePattern.hasMatch(code.code)) {
      throw const FormatException('Invalid public member code');
    }
    return Uri.https(downloadHost, '/download', {'member': code.code});
  }

  static String messageFor(CommunityPublicCode code, {required String locale}) {
    final url = linkFor(code).toString();
    final handle = code.handle;
    if (locale.toLowerCase().startsWith('ar')) {
      return '✨ تواصل معي على BIL 💙\n\n'
          'الصحة رحلة أجمل عندما نشارك التقدّم والعادات الملهمة. '
          'اكتشف ملفي في مجتمع BIL وخلّينا نشجّع بعض!\n\n'
          '👤 @$handle\n'
          '🔗 $url\n\n'
          'BIL • Body Intelligence Log';
    }
    return '✨ Let’s connect on BIL 💙\n\n'
        'Health is a better journey together. Let’s share progress, '
        'celebrate small wins, and inspire each other in the BIL community.\n\n'
        '👤 @$handle\n'
        '🔗 $url\n\n'
        'BIL • Body Intelligence Log';
  }
}
