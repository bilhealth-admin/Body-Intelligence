import 'dart:convert';
import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';

String authFiveLocaleText(String english, String arabic) {
  final locale = AppLocalizations.activeLocale;
  return _authLocaleTextFor(locale, english, arabic);
}

String authFiveLocaleTextOf(
  BuildContext context,
  String english,
  String arabic,
) => _authLocaleTextFor(Localizations.localeOf(context), english, arabic);

String arabicLocaleCode(BuildContext context, bool arabic) {
  if (arabic) return 'ar';
  return Localizations.localeOf(context).languageCode;
}

String authFiveLocaleTextFor(String localeTag, String english, String arabic) =>
    _authLocaleTextFor(
      BilLocalePolicy.localeFromTag(localeTag),
      english,
      arabic,
    );

String _authLocaleTextFor(Locale locale, String english, String arabic) {
  if (locale.languageCode == 'ar') return _repairLegacyUtf8(arabic);
  final authored = _authAuthoredCopy[english]?[locale.languageCode];
  if (authored != null) return authored;
  final exact = RuntimeCopy.resolve(
    english,
    BilLocalePolicy.canonicalTag(locale),
  );
  if (exact != null) return exact;
  final localized = AppLocalizations(locale).text(english);
  return localized;
}

String _repairLegacyUtf8(String value) {
  if (!value.codeUnits.any((unit) => unit == 0xD8 || unit == 0xD9)) {
    return value;
  }
  try {
    return utf8.decode(latin1.encode(value));
  } on FormatException {
    return value;
  }
}

const _authAuthoredCopy = <String, Map<String, String>>{
  'Cloud account is not enabled on this build.': {
    'fr': 'Le compte cloud n’est pas activé dans cette version.',
    'es': 'La cuenta en la nube no está habilitada en esta versión.',
    'tr': 'Bulut hesabı bu sürümde etkin değil.',
  },
  'OR': {'fr': 'OU', 'es': 'O', 'tr': 'VEYA'},
  'Continue with Google': {
    'fr': 'Continuer avec Google',
    'es': 'Continuar con Google',
    'tr': 'Google ile devam et',
  },
  'Continue with Apple': {
    'fr': 'Continuer avec Apple',
    'es': 'Continuar con Apple',
    'tr': 'Apple ile devam et',
  },
  'Continue with Facebook': {
    'fr': 'Continuer avec Facebook',
    'es': 'Continuar con Facebook',
    'tr': 'Facebook ile devam et',
  },
  'We will never post anything without your permission.': {
    'fr': 'Nous ne publierons jamais rien sans votre autorisation.',
    'es': 'Nunca publicaremos nada sin tu permiso.',
    'tr': 'İzniniz olmadan hiçbir şey paylaşmayacağız.',
  },
  'Read the Privacy Policy': {
    'fr': 'Lire la politique de confidentialité',
    'es': 'Leer la Política de privacidad',
    'tr': 'Gizlilik Politikasını okuyun',
  },
  'This sign-in provider is unavailable or not configured.': {
    'fr': 'Ce fournisseur de connexion est indisponible ou non configuré.',
    'es':
        'Este proveedor de inicio de sesión no está disponible o no está configurado.',
    'tr': 'Bu oturum açma sağlayıcısı kullanılamıyor veya yapılandırılmamış.',
  },
  'Could not open secure sign-in. Try again.': {
    'fr': 'Impossible d’ouvrir la connexion sécurisée. Réessayez.',
    'es': 'No se pudo abrir el inicio de sesión seguro. Inténtalo de nuevo.',
    'tr': 'Güvenli oturum açılamadı. Tekrar deneyin.',
  },
  'Weak': {'fr': 'Faible', 'es': 'Débil', 'tr': 'Zayıf'},
  'Good': {'fr': 'Bonne', 'es': 'Buena', 'tr': 'İyi'},
  'Strong': {'fr': 'Forte', 'es': 'Fuerte', 'tr': 'Güçlü'},
  'Cancel': {'fr': 'Annuler', 'es': 'Cancelar', 'tr': 'İptal'},
  'Restore': {'fr': 'Restaurer', 'es': 'Restaurar', 'tr': 'Geri yükle'},
  'Restore previous data?': {
    'fr': 'Restaurer les données précédentes ?',
    'es': '¿Restaurar los datos anteriores?',
    'tr': 'Önceki veriler geri yüklensin mi?',
  },
  'Continue locally': {
    'fr': 'Continuer en local',
    'es': 'Continuar localmente',
    'tr': 'Yerel olarak devam et',
  },
  'Choose language': {
    'fr': 'Choisir la langue',
    'es': 'Elegir idioma',
    'tr': 'Dil seç',
  },
  'Try again': {
    'fr': 'Réessayer',
    'es': 'Intentar de nuevo',
    'tr': 'Tekrar dene',
  },
  'Your local data could not be opened': {
    'fr': 'Impossible d’ouvrir vos données locales',
    'es': 'No se pudieron abrir tus datos locales',
    'tr': 'Yerel verileriniz açılamadı',
  },
  'Nothing was deleted or uploaded. You can retry safely.': {
    'fr':
        'Rien n’a été supprimé ni envoyé. Vous pouvez réessayer en toute sécurité.',
    'es':
        'No se eliminó ni subió nada. Puedes volver a intentarlo con seguridad.',
    'tr':
        'Hiçbir şey silinmedi veya yüklenmedi. Güvenle tekrar deneyebilirsiniz.',
  },
  'The password could not be updated. Request a new link.': {
    'fr':
        'Impossible de mettre à jour le mot de passe. Demandez un nouveau lien.',
    'es': 'No se pudo actualizar la contraseña. Solicita un enlace nuevo.',
    'tr': 'Parola güncellenemedi. Yeni bir bağlantı isteyin.',
  },
  'BIL will replace the current local data with the validated previous snapshot.': {
    'fr':
        'BIL remplacera les données locales actuelles par l’instantané précédent validé.',
    'es':
        'BIL sustituirá los datos locales actuales por la instantánea anterior validada.',
    'tr':
        'BIL mevcut yerel verileri doğrulanmış önceki anlık görüntüyle değiştirecek.',
  },
  'The local snapshot could not be restored safely. No partial restore was applied.': {
    'fr':
        'Impossible de restaurer l’instantané local en toute sécurité. Aucune restauration partielle n’a été appliquée.',
    'es':
        'No se pudo restaurar la instantánea local de forma segura. No se aplicó una restauración parcial.',
    'tr':
        'Yerel anlık görüntü güvenle geri yüklenemedi. Kısmi geri yükleme uygulanmadı.',
  },
  'Start privately. Build your body intelligence locally.': {
    'fr':
        'Commencez en privé. Développez votre intelligence corporelle localement.',
    'es': 'Empieza en privado. Crea tu inteligencia corporal localmente.',
    'tr': 'Özel başlayın. Beden zekânızı yerel olarak oluşturun.',
  },
  'Your health data stays on this device. No account is created and no email is uploaded.': {
    'fr':
        'Vos données de santé restent sur cet appareil. Aucun compte n’est créé et aucune adresse e-mail n’est envoyée.',
    'es':
        'Tus datos de salud permanecen en este dispositivo. No se crea ninguna cuenta ni se sube ningún correo.',
    'tr':
        'Sağlık verileriniz bu cihazda kalır. Hesap oluşturulmaz ve e-posta yüklenmez.',
  },
  'Display name (optional)': {
    'fr': 'Nom affiché (facultatif)',
    'es': 'Nombre visible (opcional)',
    'tr': 'Görünen ad (isteğe bağlı)',
  },
  'Sign in or create account': {
    'fr': 'Se connecter ou créer un compte',
    'es': 'Iniciar sesión o crear una cuenta',
    'tr': 'Giriş yap veya hesap oluştur',
  },
  'Email sign-in — Coming with Cloud': {
    'fr': 'Connexion par e-mail — bientôt avec le cloud',
    'es': 'Inicio por correo — próximamente con la nube',
    'tr': 'E-postayla giriş — Bulut ile yakında',
  },
  'Restore previous data': {
    'fr': 'Restaurer les données précédentes',
    'es': 'Restaurar datos anteriores',
    'tr': 'Önceki verileri geri yükle',
  },
  'Your body. Your intelligence.': {
    'fr': 'Votre corps. Votre intelligence.',
    'es': 'Tu cuerpo. Tu inteligencia.',
    'tr': 'Bedeniniz. Zekânız.',
  },
  'A private health experience built around you. Your data stays yours, and cloud sync is always your choice.': {
    'fr':
        'Une expérience santé privée conçue autour de vous. Vos données vous appartiennent et la synchronisation cloud reste votre choix.',
    'es':
        'Una experiencia de salud privada diseñada para ti. Tus datos siguen siendo tuyos y la sincronización en la nube siempre es opcional.',
    'tr':
        'Size göre tasarlanmış özel bir sağlık deneyimi. Verileriniz size aittir ve bulut eşitlemesi daima sizin seçiminizdir.',
  },
  'Continue with BIL account': {
    'fr': 'Continuer avec un compte BIL',
    'es': 'Continuar con una cuenta BIL',
    'tr': 'BIL hesabıyla devam et',
  },
  'Cloud account is not enabled': {
    'fr': 'Le compte cloud n’est pas activé',
    'es': 'La cuenta en la nube no está habilitada',
    'tr': 'Bulut hesabı etkin değil',
  },
  'Continue without an account': {
    'fr': 'Continuer sans compte',
    'es': 'Continuar sin una cuenta',
    'tr': 'Hesap olmadan devam et',
  },
  'Privacy first  •  No medical diagnosis  •  You stay in control': {
    'fr':
        'Confidentialité d’abord  •  Aucun diagnostic médical  •  Vous gardez le contrôle',
    'es':
        'Privacidad primero  •  Sin diagnóstico médico  •  Tú mantienes el control',
    'tr': 'Önce gizlilik  •  Tıbbi tanı yok  •  Kontrol sizde',
  },
  'Search, scan, and log with a clear line between verified and custom data.': {
    'fr':
        'Recherchez, scannez et consignez en distinguant clairement les données vérifiées des données personnalisées.',
    'es':
        'Busca, escanea y registra diferenciando claramente los datos verificados de los personalizados.',
    'tr':
        'Doğrulanmış ve özel verileri açıkça ayırarak arayın, tarayın ve kaydedin.',
  },
  'Connect sleep and recovery using only your real record.': {
    'fr':
        'Reliez sommeil et récupération uniquement à partir de vos données réelles.',
    'es': 'Relaciona sueño y recuperación usando solo tu registro real.',
    'tr': 'Uyku ve toparlanmayı yalnızca gerçek kayıtlarınızla ilişkilendirin.',
  },
  'Reviewable guidance instead of one generic plan for everyone.': {
    'fr': 'Des conseils vérifiables plutôt qu’un plan générique pour tous.',
    'es': 'Orientación revisable en lugar de un plan genérico para todos.',
    'tr': 'Herkes için tek bir genel plan yerine incelenebilir rehberlik.',
  },
  'BIL is preparing your local data safely': {
    'fr': 'BIL prépare vos données locales en toute sécurité',
    'es': 'BIL está preparando tus datos locales de forma segura',
    'tr': 'BIL yerel verilerinizi güvenle hazırlıyor',
  },
  'Body Intelligence Log is preparing your local data safely': {
    'fr': 'Body Intelligence Log prépare vos données locales en toute sécurité',
    'es':
        'Body Intelligence Log está preparando tus datos locales de forma segura',
    'tr': 'Body Intelligence Log yerel verilerinizi güvenle hazırlıyor',
  },
  'Nutrition without guesswork': {
    'fr': 'La nutrition sans approximation',
    'es': 'Nutrición sin adivinanzas',
    'tr': 'Tahminsiz beslenme',
  },
  'Understand your rhythm': {
    'fr': 'Comprenez votre rythme',
    'es': 'Comprende tu ritmo',
    'tr': 'Ritminizi anlayın',
  },
  'Progress built around you': {
    'fr': 'Une progression adaptée à vous',
    'es': 'Progreso diseñado para ti',
    'tr': 'Size göre tasarlanmış ilerleme',
  },
  'The temporary email limit has been reached. Wait up to one hour, then try once.': {
    'fr':
        'La limite temporaire d’e-mails est atteinte. Attendez jusqu’à une heure, puis réessayez une fois.',
    'es':
        'Se alcanzó el límite temporal de correos. Espera hasta una hora e inténtalo una vez.',
    'tr':
        'Geçici e-posta sınırına ulaşıldı. Bir saate kadar bekleyip bir kez daha deneyin.',
  },
  'The email address or password is incorrect.': {
    'fr': 'L’adresse e-mail ou le mot de passe est incorrect.',
    'es': 'El correo electrónico o la contraseña son incorrectos.',
    'tr': 'E-posta adresi veya parola yanlış.',
  },
  'Confirm your email address first, then try signing in.': {
    'fr': 'Confirmez d’abord votre adresse e-mail, puis reconnectez-vous.',
    'es': 'Confirma primero tu correo electrónico y vuelve a iniciar sesión.',
    'tr': 'Önce e-posta adresinizi doğrulayın, ardından tekrar giriş yapın.',
  },
  'This email is already registered. Sign in instead.': {
    'fr': 'Cette adresse est déjà enregistrée. Connectez-vous plutôt.',
    'es': 'Este correo ya está registrado. Inicia sesión.',
    'tr': 'Bu e-posta zaten kayıtlı. Bunun yerine giriş yapın.',
  },
  'The password does not meet the Supabase security requirements.': {
    'fr':
        'Le mot de passe ne respecte pas les exigences de sécurité de Supabase.',
    'es': 'La contraseña no cumple los requisitos de seguridad de Supabase.',
    'tr': 'Parola Supabase güvenlik gereksinimlerini karşılamıyor.',
  },
  'The verification link or code has expired. Request a new one.': {
    'fr': 'Le lien ou code de vérification a expiré. Demandez-en un nouveau.',
    'es': 'El enlace o código de verificación caducó. Solicita uno nuevo.',
    'tr': 'Doğrulama bağlantısı veya kodunun süresi doldu. Yenisini isteyin.',
  },
  'Account creation is temporarily unavailable.': {
    'fr': 'La création de compte est temporairement indisponible.',
    'es': 'La creación de cuentas no está disponible temporalmente.',
    'tr': 'Hesap oluşturma geçici olarak kullanılamıyor.',
  },
  'Choose a password different from the current password.': {
    'fr': 'Choisissez un mot de passe différent du mot de passe actuel.',
    'es': 'Elige una contraseña distinta de la actual.',
    'tr': 'Mevcut paroladan farklı bir parola seçin.',
  },
  'The password-recovery redirect is not allowed by Supabase.': {
    'fr':
        'La redirection de récupération du mot de passe n’est pas autorisée par Supabase.',
    'es': 'Supabase no permite la redirección de recuperación de contraseña.',
    'tr': 'Parola kurtarma yönlendirmesine Supabase izin vermiyor.',
  },
  'Authentication could not be completed now. Try again later.': {
    'fr': 'Impossible de terminer l’authentification. Réessayez plus tard.',
    'es': 'No se pudo completar la autenticación. Inténtalo más tarde.',
    'tr': 'Kimlik doğrulama tamamlanamadı. Daha sonra tekrar deneyin.',
  },
};
