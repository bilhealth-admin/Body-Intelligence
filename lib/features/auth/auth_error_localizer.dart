import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_five_locale_copy.dart';

String localizedAuthError(BuildContext context, AuthException error) {
  final message = error.message.toLowerCase();
  final code = error.code?.toLowerCase() ?? '';
  if (code == 'over_email_send_rate_limit' ||
      code == 'over_request_rate_limit' ||
      message.contains('rate limit') ||
      message.contains('too many')) {
    return authFiveLocaleText(
      'The temporary email limit has been reached. Wait up to one hour, then try once.',
      'تم بلوغ الحد المؤقت لإرسال الرسائل. انتظر حتى ساعة ثم حاول مرة واحدة.',
    );
  }
  if (code == 'provider_disabled' ||
      message.contains('provider is not enabled') ||
      message.contains('provider is disabled')) {
    return authFiveLocaleText(
      'This sign-in provider is unavailable or not configured.',
      'مزود تسجيل الدخول هذا غير متاح أو غير مهيأ.',
    );
  }
  if (code == 'invalid_credentials' ||
      message.contains('invalid login credentials')) {
    return authFiveLocaleText(
      'The email address or password is incorrect.',
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
    );
  }
  if (code == 'email_not_confirmed' ||
      message.contains('email not confirmed')) {
    return authFiveLocaleText(
      'Confirm your email address first, then try signing in.',
      'أكد بريدك الإلكتروني أولًا، ثم حاول تسجيل الدخول.',
    );
  }
  if (code == 'user_already_exists' ||
      message.contains('already registered') ||
      message.contains('already been registered') ||
      message.contains('user already exists')) {
    return authFiveLocaleText(
      'This email is already registered. Sign in instead.',
      'هذا البريد مسجل بالفعل. استخدم تسجيل الدخول بدل إنشاء حساب جديد.',
    );
  }
  if (code == 'weak_password' ||
      (message.contains('password') &&
          (message.contains('weak') ||
              message.contains('at least') ||
              message.contains('characters')))) {
    return authFiveLocaleText(
      'The password does not meet the Supabase security requirements.',
      'كلمة المرور لا تحقق متطلبات الأمان في Supabase.',
    );
  }
  if (code == 'otp_expired' ||
      message.contains('token has expired') ||
      message.contains('otp expired')) {
    return authFiveLocaleText(
      'The verification link or code has expired. Request a new one.',
      'انتهت صلاحية رابط أو رمز التحقق. اطلب واحدًا جديدًا.',
    );
  }
  if (code == 'signup_disabled' || message.contains('signup is disabled')) {
    return authFiveLocaleText(
      'Account creation is temporarily unavailable.',
      'إنشاء الحسابات غير متاح مؤقتًا.',
    );
  }
  if (code == 'same_password' || message.contains('same password')) {
    return authFiveLocaleText(
      'Choose a password different from the current password.',
      'اختر كلمة مرور مختلفة عن كلمة المرور الحالية.',
    );
  }
  if (message.contains('redirect')) {
    return authFiveLocaleText(
      'The password-recovery redirect is not allowed by Supabase.',
      'عنوان استعادة كلمة المرور غير مسموح في إعدادات Supabase.',
    );
  }
  return authFiveLocaleText(
    'Authentication could not be completed now. Try again later.',
    'تعذّر إكمال المصادقة الآن. حاول مرة أخرى لاحقًا.',
  );
}
