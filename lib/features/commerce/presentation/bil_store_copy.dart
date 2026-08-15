import '../../../app/localization/runtime_copy.dart';

abstract final class BilStoreCopy {
  static const catalogs = <String, Map<String, String>>{
    'en': {
      'free': 'Free',
      'premium': 'Premium',
      'premium_ai_coach': 'Premium AI Coach',
      'ai_boost': 'BIL AI Boost',
      'monthly': 'Monthly',
      'annual': 'Annual',
      'trial': 'Free trial',
      'restore': 'Restore purchases',
      'manage': 'Manage subscription',
      'store_loading': 'Loading price from the store…',
      'store_unavailable': 'Price unavailable on this device',
      'purchase_error':
          'The purchase was not completed. No access was granted.',
      'ads_consent': 'Choose whether BIL may show contextual ads.',
    },
    'ar': {
      'free': 'مجاني',
      'premium': 'بريميوم',
      'premium_ai_coach': 'بريميوم AI Coach',
      'ai_boost': 'BIL AI Boost',
      'monthly': 'شهري',
      'annual': 'سنوي',
      'trial': 'تجربة مجانية',
      'restore': 'استعادة المشتريات',
      'manage': 'إدارة الاشتراك',
      'store_loading': 'جارٍ تحميل السعر من المتجر…',
      'store_unavailable': 'السعر غير متاح على هذا الجهاز',
      'purchase_error': 'لم تكتمل عملية الشراء ولم يتم منح أي صلاحية.',
      'ads_consent': 'اختر ما إذا كان بإمكان BIL عرض إعلانات سياقية.',
    },
    'fr': {
      'free': 'Gratuit',
      'premium': 'Premium',
      'premium_ai_coach': 'Premium AI Coach',
      'ai_boost': 'BIL AI Boost',
      'monthly': 'Mensuel',
      'annual': 'Annuel',
      'trial': 'Essai gratuit',
      'restore': 'Restaurer les achats',
      'manage': 'Gérer l’abonnement',
      'store_loading': 'Chargement du prix depuis la boutique…',
      'store_unavailable': 'Prix indisponible sur cet appareil',
      'purchase_error': 'L’achat n’a pas abouti. Aucun accès n’a été accordé.',
      'ads_consent':
          'Choisissez si BIL peut afficher des publicités contextuelles.',
    },
    'es': {
      'free': 'Gratis',
      'premium': 'Premium',
      'premium_ai_coach': 'Premium AI Coach',
      'ai_boost': 'BIL AI Boost',
      'monthly': 'Mensual',
      'annual': 'Anual',
      'trial': 'Prueba gratuita',
      'restore': 'Restaurar compras',
      'manage': 'Gestionar suscripción',
      'store_loading': 'Cargando el precio desde la tienda…',
      'store_unavailable': 'Precio no disponible en este dispositivo',
      'purchase_error': 'La compra no se completó. No se concedió acceso.',
      'ads_consent': 'Elige si BIL puede mostrar anuncios contextuales.',
    },
    'tr': {
      'free': 'Ücretsiz',
      'premium': 'Premium',
      'premium_ai_coach': 'Premium AI Coach',
      'ai_boost': 'BIL AI Boost',
      'monthly': 'Aylık',
      'annual': 'Yıllık',
      'trial': 'Ücretsiz deneme',
      'restore': 'Satın alımları geri yükle',
      'manage': 'Aboneliği yönet',
      'store_loading': 'Fiyat mağazadan yükleniyor…',
      'store_unavailable': 'Fiyat bu cihazda kullanılamıyor',
      'purchase_error': 'Satın alma tamamlanmadı. Erişim verilmedi.',
      'ads_consent':
          'BIL’in bağlamsal reklam gösterip gösteremeyeceğini seçin.',
    },
  };

  static String text(String locale, String key) {
    final language = locale.toLowerCase().split(RegExp('[-_]')).first;
    final english = catalogs['en']![key] ?? key;
    return catalogs[language]?[key] ??
        RuntimeCopy.resolve(english, locale) ??
        english;
  }
}
