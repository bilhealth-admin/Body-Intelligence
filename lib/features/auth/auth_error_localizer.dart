import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_entry_locale_copy.dart';
import 'auth_five_locale_copy.dart';

String localizedAuthError(BuildContext context, AuthException error) {
  final message = error.message.toLowerCase();
  final code = error.code?.toLowerCase() ?? '';
  if (code == 'over_email_send_rate_limit' ||
      code == 'over_request_rate_limit' ||
      message.contains('rate limit') ||
      message.contains('too many') ||
      message.contains('only request this after')) {
    return authEntryText(context, AuthEntryCopyKey.rateLimit60);
  }
  if (code == 'provider_disabled' ||
      message.contains('provider is not enabled') ||
      message.contains('provider is disabled')) {
    return authEntryText(context, AuthEntryCopyKey.providerUnavailable);
  }
  if (code == 'otp_expired' ||
      message.contains('token has expired') ||
      message.contains('otp expired') ||
      message.contains('expired or is invalid')) {
    return authEntryText(context, AuthEntryCopyKey.verificationExpired);
  }
  if (message.contains('invalid otp') ||
      message.contains('invalid token') ||
      message.contains('token is invalid')) {
    return authEntryText(context, AuthEntryCopyKey.codeVerificationFailed);
  }
  if (code == 'signup_disabled' || message.contains('signup is disabled')) {
    return authEntryText(context, AuthEntryCopyKey.signupUnavailable);
  }
  if (code == 'invalid_credentials' ||
      message.contains('invalid login credentials')) {
    return authFiveLocaleTextOf(
      context,
      'The email address or password is incorrect.',
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
    );
  }
  if (code == 'email_not_confirmed' ||
      message.contains('email not confirmed')) {
    return authFiveLocaleTextOf(
      context,
      'Confirm your email address first, then try signing in.',
      'أكد بريدك الإلكتروني أولًا، ثم حاول تسجيل الدخول.',
    );
  }
  if (code == 'user_already_exists' ||
      message.contains('already registered') ||
      message.contains('already been registered') ||
      message.contains('user already exists')) {
    return authFiveLocaleTextOf(
      context,
      'This email is already registered. Sign in instead.',
      'هذا البريد مسجل بالفعل. استخدم تسجيل الدخول بدل إنشاء حساب جديد.',
    );
  }
  if (code == 'weak_password' ||
      (message.contains('password') &&
          (message.contains('weak') ||
              message.contains('at least') ||
              message.contains('characters')))) {
    return authFiveLocaleTextOf(
      context,
      'The password does not meet the Supabase security requirements.',
      'كلمة المرور لا تحقق متطلبات الأمان في Supabase.',
    );
  }
  if (code == 'same_password' || message.contains('same password')) {
    return authFiveLocaleTextOf(
      context,
      'Choose a password different from the current password.',
      'اختر كلمة مرور مختلفة عن كلمة المرور الحالية.',
    );
  }
  if (message.contains('redirect')) {
    return authFiveLocaleTextOf(
      context,
      'The password-recovery redirect is not allowed by Supabase.',
      'عنوان استعادة كلمة المرور غير مسموح في إعدادات Supabase.',
    );
  }
  return authEntryText(context, AuthEntryCopyKey.authenticationFailed);
}
