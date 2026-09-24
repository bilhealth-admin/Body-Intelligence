import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

bool isAppleSignInCancellation(Object error) =>
    error is SignInWithAppleAuthorizationException &&
    error.code == AuthorizationErrorCode.canceled;

String appleSignInCanceledText(Locale locale) =>
    switch (locale.toLanguageTag().toLowerCase()) {
      'ar' => 'تم إلغاء تسجيل الدخول.',
      'fr' => 'La connexion a été annulée.',
      'es' => 'Se canceló el inicio de sesión.',
      'tr' => 'Oturum açma iptal edildi.',
      'de' => 'Die Anmeldung wurde abgebrochen.',
      'it' => "L'accesso è stato annullato.",
      'pt-br' || 'pt-pt' => 'O início de sessão foi cancelado.',
      'ur' => 'سائن اِن منسوخ کر دیا گیا۔',
      'fa' => 'ورود لغو شد.',
      'hi' => 'साइन-इन रद्द कर दिया गया।',
      'id' => 'Proses masuk dibatalkan.',
      'ms' => 'Log masuk telah dibatalkan.',
      'ja' => 'サインインはキャンセルされました。',
      'ko' => '로그인이 취소되었습니다.',
      'zh-hans' => '登录已取消。',
      'zh-hant' => '登入已取消。',
      'ru' => 'Вход отменен.',
      'bn' => 'সাইন-ইন বাতিল করা হয়েছে।',
      'vi' => 'Đã hủy đăng nhập.',
      'th' => 'ยกเลิกการลงชื่อเข้าใช้แล้ว',
      'pl' => 'Logowanie zostało anulowane.',
      'nl' => 'Aanmelden is geannuleerd.',
      'uk' => 'Вхід скасовано.',
      _ => 'Sign-in was canceled.',
    };

class AppleSignInCanceledBanner extends StatelessWidget {
  const AppleSignInCanceledBanner({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('apple-sign-in-canceled-banner'),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsetsDirectional.only(start: 14, top: 8, bottom: 8),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                appleSignInCanceledText(Localizations.localeOf(context)),
              ),
            ),
            IconButton(
              key: const Key('apple-sign-in-canceled-dismiss'),
              onPressed: onDismiss,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
