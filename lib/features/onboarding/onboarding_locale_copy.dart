import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';

String onboardingText(BuildContext context, String english, String arabic) {
  final locale = Localizations.localeOf(context);
  final code = locale.languageCode;
  if (code == 'ar') return arabic;
  final authored = onboardingAuthoredCopy[english]?[code];
  if (authored != null) return authored;
  final exact = RuntimeCopy.resolve(
    english,
    BilLocalePolicy.canonicalTag(locale),
  );
  return exact ?? AppLocalizations(locale).text(english);
}

const onboardingAuthoredCopy = <String, Map<String, String>>{
  'WELCOME TO BODY CALIBRATION': {
    'fr': 'BIENVENUE DANS LE CALIBRAGE CORPOREL',
    'es': 'TE DAMOS LA BIENVENIDA A LA CALIBRACIÓN CORPORAL',
    'tr': 'VÜCUT KALİBRASYONUNA HOŞ GELDİNİZ',
  },
  'Let’s build your\nbody model.': {
    'fr': 'Construisons votre\nmodèle corporel.',
    'es': 'Construyamos tu\nmodelo corporal.',
    'tr': 'Vücut modelinizi\noluşturalım.',
  },
  'BIL Calibration': {
    'fr': 'Calibrage BIL',
    'es': 'Calibración BIL',
    'tr': 'BIL Kalibrasyonu',
  },
  '8 focused steps': {
    'fr': '8 étapes ciblées',
    'es': '8 pasos específicos',
    'tr': '8 odaklı adım',
  },
  'Heart rate': {
    'fr': 'Fréquence cardiaque',
    'es': 'Frecuencia cardíaca',
    'tr': 'Kalp hızı',
  },
  '7-day trend': {
    'fr': 'Tendance sur 7 jours',
    'es': 'Tendencia de 7 días',
    'tr': '7 günlük eğilim',
  },
  'Predicted energy': {
    'fr': 'Énergie prévue',
    'es': 'Energía prevista',
    'tr': 'Tahmini enerji',
  },
  'Data quality': {
    'fr': 'Qualité des données',
    'es': 'Calidad de los datos',
    'tr': 'Veri kalitesi',
  },
  'High': {'fr': 'Élevée', 'es': 'Alta', 'tr': 'Yüksek'},
  'PRIVATE BODY INTELLIGENCE': {
    'fr': 'INTELLIGENCE CORPORELLE PRIVÉE',
    'es': 'INTELIGENCIA CORPORAL PRIVADA',
    'tr': 'ÖZEL VÜCUT ZEKÂSI',
  },
  'Welcome': {'fr': 'Bienvenue', 'es': 'Bienvenido', 'tr': 'Hoş geldiniz'},
  'Start your journey toward a healthier, stronger and smarter body with a personal model that learns from your data.': {
    'fr':
        'Commencez votre parcours vers un corps plus sain, plus fort et plus intelligent avec un modèle personnel qui apprend de vos données.',
    'es':
        'Comienza tu camino hacia un cuerpo más sano, fuerte e inteligente con un modelo personal que aprende de tus datos.',
    'tr':
        'Verilerinizden öğrenen kişisel bir modelle daha sağlıklı, güçlü ve akıllı bir bedene doğru yolculuğunuza başlayın.',
  },
  'Evidence and confidence stay visible.': {
    'fr': 'Les preuves et le niveau de confiance restent visibles.',
    'es': 'La evidencia y el nivel de confianza permanecen visibles.',
    'tr': 'Kanıtlar ve güven düzeyi görünür kalır.',
  },
  'Measured facts remain separate from estimates.': {
    'fr': 'Les faits mesurés restent séparés des estimations.',
    'es': 'Los hechos medidos permanecen separados de las estimaciones.',
    'tr': 'Ölçülen gerçekler tahminlerden ayrı tutulur.',
  },
  'Private': {'fr': 'Privé', 'es': 'Privado', 'tr': 'Özel'},
  'Offline': {'fr': 'Hors ligne', 'es': 'Sin conexión', 'tr': 'Çevrimdışı'},
  'Explainable': {
    'fr': 'Explicable',
    'es': 'Explicable',
    'tr': 'Açıklanabilir',
  },
  'Understand every insight': {
    'fr': 'Comprenez chaque analyse',
    'es': 'Comprende cada análisis',
    'tr': 'Her içgörüyü anlayın',
  },
  'Science first': {
    'fr': 'La science d’abord',
    'es': 'La ciencia primero',
    'tr': 'Önce bilim',
  },
  'Start your journey': {
    'fr': 'Commencer votre parcours',
    'es': 'Comienza tu recorrido',
    'tr': 'Yolculuğunuza başlayın',
  },
  'No account required. Nothing is uploaded.': {
    'fr': 'Aucun compte requis. Rien n’est envoyé.',
    'es': 'No se requiere cuenta. No se sube nada.',
    'tr': 'Hesap gerekmez. Hiçbir şey yüklenmez.',
  },
  'Back': {'fr': 'Retour', 'es': 'Atrás', 'tr': 'Geri'},
  'Save': {'fr': 'Enregistrer', 'es': 'Guardar', 'tr': 'Kaydet'},
  'Not now': {'fr': 'Pas maintenant', 'es': 'Ahora no', 'tr': 'Şimdi değil'},
  'Sign in': {'fr': 'Se connecter', 'es': 'Iniciar sesión', 'tr': 'Giriş yap'},
  'Begin calibration': {
    'fr': 'Commencer le calibrage',
    'es': 'Iniciar calibración',
    'tr': 'Kalibrasyonu başlat',
  },
  'BIL could not calculate the initial plan. Please review the values and try again.': {
    'fr':
        'BIL n’a pas pu calculer le plan initial. Vérifiez les valeurs et réessayez.',
    'es':
        'BIL no pudo calcular el plan inicial. Revisa los valores e inténtalo de nuevo.',
    'tr':
        'BIL başlangıç planını hesaplayamadı. Değerleri kontrol edip tekrar deneyin.',
  },
  'Important health information': {
    'fr': 'Informations de santé importantes',
    'es': 'Información de salud importante',
    'tr': 'Önemli sağlık bilgisi',
  },
  'Accept & continue': {
    'fr': 'Accepter et continuer',
    'es': 'Aceptar y continuar',
    'tr': 'Kabul et ve devam et',
  },
  'BIL provides educational, personalized estimates and does not replace diagnosis or medical care. By continuing, you acknowledge that final medical decisions remain with you and your clinician.': {
    'fr':
        'BIL fournit des estimations éducatives et personnalisées sans remplacer un diagnostic ni des soins médicaux. En continuant, vous reconnaissez que les décisions médicales finales vous appartiennent avec votre médecin.',
    'es':
        'BIL ofrece estimaciones educativas y personalizadas y no sustituye el diagnóstico ni la atención médica. Al continuar, reconoces que las decisiones médicas finales corresponden a ti y a tu profesional sanitario.',
    'tr':
        'BIL eğitici ve kişiselleştirilmiş tahminler sunar; tanı veya tıbbi bakımın yerini almaz. Devam ederek nihai tıbbi kararların size ve hekiminize ait olduğunu kabul edersiniz.',
  },
  'Could not save the profile on this device. No data was uploaded.': {
    'fr':
        'Impossible d’enregistrer le profil sur cet appareil. Aucune donnée n’a été envoyée.',
    'es':
        'No se pudo guardar el perfil en este dispositivo. No se subió ningún dato.',
    'tr': 'Profil bu cihaza kaydedilemedi. Hiçbir veri yüklenmedi.',
  },
};
