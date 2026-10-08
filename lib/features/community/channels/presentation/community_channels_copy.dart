import 'package:flutter/widgets.dart';

/// Arabic and English are authored here. Other app locales intentionally use
/// English fallback; they are not claimed as completed translations.
enum CommunityChannelsCopyKey {
  channels,
  publicChannels,
  publicScope,
  directoryEmpty,
  directoryUnavailable,
  signIn,
  ownerChanged,
  retry,
  refresh,
  openChannel,
  unreadCount,
  unreadUnknown,
  onlineCount,
  onlineUnknown,
  readOnly,
  channelDisabled,
  accessRestricted,
  policyRequired,
  reviewPolicy,
  noMessages,
  historyUnavailable,
  loadOlder,
  loadNewer,
  loadMoreChannels,
  retryRead,
  readUnconfirmed,
  message,
  send,
  retrySend,
  sending,
  sendFailed,
  retryOriginal,
  originalAttempt,
  textLimit,
  blocked,
  permissionsUnknown,
  refreshPermission,
  connectionOffline,
  reconnect,
  channelUnavailable,
  membershipRequired,
  sent,
  unread,
  loading,
  member,
}

abstract final class CommunityChannelsCopy {
  static String text(
    BuildContext context,
    CommunityChannelsCopyKey key, [
    Map<String, Object> values = const {},
  ]) => forLocale(Localizations.localeOf(context), key, values);

  static String forLocale(
    Locale locale,
    CommunityChannelsCopyKey key, [
    Map<String, Object> values = const {},
  ]) {
    var result = locale.languageCode == 'ar' ? arabic[key]! : english[key]!;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return result;
  }

  static const english = <CommunityChannelsCopyKey, String>{
    CommunityChannelsCopyKey.channels: 'Channels',
    CommunityChannelsCopyKey.publicChannels: 'Community channels',
    CommunityChannelsCopyKey.publicScope:
        'Messages are shared with people who can access this channel.',
    CommunityChannelsCopyKey.directoryEmpty:
        'No channels are available for your account yet.',
    CommunityChannelsCopyKey.directoryUnavailable:
        'Channels could not be loaded. Check your connection and retry.',
    CommunityChannelsCopyKey.signIn: 'Sign in to open Community channels.',
    CommunityChannelsCopyKey.ownerChanged:
        'Your account changed. Return to Community to continue.',
    CommunityChannelsCopyKey.retry: 'Retry',
    CommunityChannelsCopyKey.refresh: 'Refresh',
    CommunityChannelsCopyKey.openChannel: 'Open {channel}',
    CommunityChannelsCopyKey.unreadCount: 'Unread: {count}',
    CommunityChannelsCopyKey.unreadUnknown: 'Unread count unavailable',
    CommunityChannelsCopyKey.onlineCount: 'Online: {count}',
    CommunityChannelsCopyKey.onlineUnknown: 'Online count unavailable',
    CommunityChannelsCopyKey.readOnly: 'Read-only channel',
    CommunityChannelsCopyKey.channelDisabled:
        'This channel is disabled. Messages cannot be sent.',
    CommunityChannelsCopyKey.accessRestricted:
        'Your account cannot access this channel.',
    CommunityChannelsCopyKey.policyRequired:
        'Review the active Community policy before sending a message.',
    CommunityChannelsCopyKey.reviewPolicy: 'Review policy',
    CommunityChannelsCopyKey.noMessages: 'No messages in this channel yet.',
    CommunityChannelsCopyKey.historyUnavailable:
        'Messages could not be updated. Check your connection and retry.',
    CommunityChannelsCopyKey.loadOlder: 'Load older messages',
    CommunityChannelsCopyKey.loadNewer: 'Load newer messages',
    CommunityChannelsCopyKey.loadMoreChannels: 'Load more channels',
    CommunityChannelsCopyKey.retryRead: 'Retry read confirmation',
    CommunityChannelsCopyKey.readUnconfirmed:
        'Some visible messages could not be confirmed as read.',
    CommunityChannelsCopyKey.message: 'Message',
    CommunityChannelsCopyKey.send: 'Send message',
    CommunityChannelsCopyKey.retrySend: 'Retry original message',
    CommunityChannelsCopyKey.sending: 'Sending…',
    CommunityChannelsCopyKey.sendFailed:
        'The message could not be confirmed. Your text is kept.',
    CommunityChannelsCopyKey.retryOriginal:
        'Retry sends the original message. Any newer draft stays separate.',
    CommunityChannelsCopyKey.originalAttempt: 'Original message',
    CommunityChannelsCopyKey.textLimit:
        'Channel messages can contain up to {limit} Unicode characters. Your text has not been shortened.',
    CommunityChannelsCopyKey.blocked:
        'Your Community access is restricted. You cannot send here.',
    CommunityChannelsCopyKey.permissionsUnknown:
        'Channel permissions could not be verified. Sending stays locked.',
    CommunityChannelsCopyKey.refreshPermission: 'Check access again',
    CommunityChannelsCopyKey.connectionOffline:
        'Live updates are disconnected. Refresh to check for messages.',
    CommunityChannelsCopyKey.reconnect: 'Reconnect',
    CommunityChannelsCopyKey.channelUnavailable:
        'This channel is currently unavailable.',
    CommunityChannelsCopyKey.membershipRequired:
        'Channel membership is required to send messages.',
    CommunityChannelsCopyKey.sent: 'Sent',
    CommunityChannelsCopyKey.unread: 'Unread',
    CommunityChannelsCopyKey.loading: 'Loading channels…',
    CommunityChannelsCopyKey.member: 'Community member',
  };

  static const arabic = <CommunityChannelsCopyKey, String>{
    CommunityChannelsCopyKey.channels: 'القنوات',
    CommunityChannelsCopyKey.publicChannels: 'قنوات المجتمع',
    CommunityChannelsCopyKey.publicScope:
        'تظهر الرسائل للأشخاص الذين يملكون صلاحية دخول هذه القناة.',
    CommunityChannelsCopyKey.directoryEmpty:
        'لا توجد قنوات متاحة لحسابك حاليًا.',
    CommunityChannelsCopyKey.directoryUnavailable:
        'تعذر تحميل القنوات. تحقق من الاتصال وأعد المحاولة.',
    CommunityChannelsCopyKey.signIn: 'سجّل الدخول لفتح قنوات المجتمع.',
    CommunityChannelsCopyKey.ownerChanged:
        'تغير الحساب. ارجع إلى المجتمع للمتابعة.',
    CommunityChannelsCopyKey.retry: 'إعادة المحاولة',
    CommunityChannelsCopyKey.refresh: 'تحديث',
    CommunityChannelsCopyKey.openChannel: 'فتح {channel}',
    CommunityChannelsCopyKey.unreadCount: 'غير المقروء: {count}',
    CommunityChannelsCopyKey.unreadUnknown: 'عدد غير المقروء غير متاح',
    CommunityChannelsCopyKey.onlineCount: 'المتصلون الآن: {count}',
    CommunityChannelsCopyKey.onlineUnknown: 'عدد المتصلين غير متاح',
    CommunityChannelsCopyKey.readOnly: 'قناة للقراءة فقط',
    CommunityChannelsCopyKey.channelDisabled:
        'هذه القناة معطّلة. لا يمكن إرسال رسائل إليها.',
    CommunityChannelsCopyKey.accessRestricted:
        'لا يملك حسابك صلاحية دخول هذه القناة.',
    CommunityChannelsCopyKey.policyRequired:
        'راجع سياسة المجتمع الفعالة قبل إرسال رسالة.',
    CommunityChannelsCopyKey.reviewPolicy: 'مراجعة السياسة',
    CommunityChannelsCopyKey.noMessages: 'لا توجد رسائل في هذه القناة بعد.',
    CommunityChannelsCopyKey.historyUnavailable:
        'تعذر تحديث الرسائل. تحقق من الاتصال وأعد المحاولة.',
    CommunityChannelsCopyKey.loadOlder: 'تحميل الرسائل الأقدم',
    CommunityChannelsCopyKey.loadNewer: 'تحميل الرسائل الأحدث',
    CommunityChannelsCopyKey.loadMoreChannels: 'تحميل المزيد من القنوات',
    CommunityChannelsCopyKey.retryRead: 'إعادة تأكيد القراءة',
    CommunityChannelsCopyKey.readUnconfirmed:
        'تعذر تأكيد قراءة بعض الرسائل الظاهرة.',
    CommunityChannelsCopyKey.message: 'رسالة',
    CommunityChannelsCopyKey.send: 'إرسال الرسالة',
    CommunityChannelsCopyKey.retrySend: 'إعادة محاولة الرسالة الأصلية',
    CommunityChannelsCopyKey.sending: 'جارٍ الإرسال…',
    CommunityChannelsCopyKey.sendFailed:
        'تعذر تأكيد إرسال الرسالة. احتفظنا بالنص.',
    CommunityChannelsCopyKey.retryOriginal:
        'تعيد المحاولة إرسال الرسالة الأصلية. تبقى مسودتك الأحدث منفصلة.',
    CommunityChannelsCopyKey.originalAttempt: 'الرسالة الأصلية',
    CommunityChannelsCopyKey.textLimit:
        'حد رسالة القناة {limit} محرف Unicode. لم يُقصّ نصك.',
    CommunityChannelsCopyKey.blocked:
        'الوصول إلى المجتمع مقيّد لحسابك. لا يمكنك الإرسال هنا.',
    CommunityChannelsCopyKey.permissionsUnknown:
        'تعذر التحقق من صلاحيات القناة. يبقى الإرسال مقفلًا.',
    CommunityChannelsCopyKey.refreshPermission: 'التحقق من الصلاحية مجددًا',
    CommunityChannelsCopyKey.connectionOffline:
        'انقطع التحديث المباشر. حدّث للتحقق من الرسائل.',
    CommunityChannelsCopyKey.reconnect: 'إعادة الاتصال',
    CommunityChannelsCopyKey.channelUnavailable: 'هذه القناة غير متاحة حاليًا.',
    CommunityChannelsCopyKey.membershipRequired:
        'تحتاج إلى عضوية في القناة لإرسال الرسائل.',
    CommunityChannelsCopyKey.sent: 'مُرسلة',
    CommunityChannelsCopyKey.unread: 'غير مقروءة',
    CommunityChannelsCopyKey.loading: 'جارٍ تحميل القنوات…',
    CommunityChannelsCopyKey.member: 'عضو في المجتمع',
  };
}
