import 'package:flutter/widgets.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';

String nutritionText(BuildContext context, String en, String ar) =>
    nutritionTextForLanguage(
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      en,
      ar,
    );

String nutritionTextForLanguage(String localeTag, String en, String ar) {
  final normalized = localeTag.replaceAll('_', '-');
  final code = normalized.toLowerCase().split('-').first;
  if (code == 'ar') return ar;
  if (code == 'en') return en;
  return _copy[code]?[en] ?? RuntimeCopy.resolve(en, normalized) ?? en;
}

const _copy = <String, Map<String, String>>{
  'fr': {
    'Food': 'Alimentation',
    'All': 'Tout',
    'Favorites': 'Favoris',
    'Recent': 'Récents',
    'Submit for review': 'Envoyer pour examen',
    'Scan product label': 'Scanner l’étiquette du produit',
    'Food libraries': 'Bibliothèques alimentaires',
    'BIL Food Core': 'Base alimentaire BIL',
    'Download': 'Télécharger',
    'Plan required': 'Forfait requis',
    'Remove': 'Supprimer',
    'Open laptop camera': 'Ouvrir la caméra de l’ordinateur',
    'Say the food name': 'Dites le nom de l’aliment',
    'Cancel': 'Annuler',
    'Done': 'Terminé',
    'Listening…': 'Écoute…',
    'Voice input unavailable': 'Saisie vocale indisponible',
    'OK': 'OK',
    'Scan': 'Scanner',
    'Scan barcode': 'Scanner un code-barres',
    'Analyze meal photo': 'Analyser une photo de repas',
    'Search foods': 'Rechercher des aliments',
    'Barcode': 'Code-barres',
    'Custom': 'Personnalisé',
    'protein': 'protéines',
    'carbs': 'glucides',
    'fat': 'lipides',
    'fiber': 'fibres',
    'sodium': 'sodium',
    'potassium': 'potassium',
    'Nutrition pathways': 'Parcours nutritionnels',
    'Choose a pathway built around your goal.':
        'Choisissez un parcours adapté à votre objectif.',
    'Compare first, then create an editable draft. Your goals never change without approval.':
        'Comparez d’abord, puis créez un brouillon modifiable. Vos objectifs ne changent jamais sans votre accord.',
    'All pathways': 'Tous les parcours',
    'Current pathway': 'Parcours actuel',
    'Approach': 'Approche',
    'Monitoring': 'Suivi',
    'This pathway requires clinician review before activation.':
        'Ce parcours nécessite l’avis d’un professionnel avant activation.',
    'Medical supervision required': 'Suivi médical requis',
    'Review in My Plan': 'Examiner dans Mon plan',
    'Explore sleep, movement, and daily rhythm':
        'Explorer le sommeil, le mouvement et le rythme quotidien',
    'Did you mean:': 'Vouliez-vous dire :',
    'Balanced meal in the nutrition studio':
        'Repas équilibré dans le studio nutrition',
    'Log smarter. Understand your food.':
        'Enregistrez mieux. Comprenez votre alimentation.',
    'Verified search, fast scanning, and data you control.':
        'Recherche vérifiée, scan rapide et données sous votre contrôle.',
    'Searching the verified catalog and this device…':
        'Recherche dans le catalogue vérifié et cet appareil…',
    'Results include the verified catalog and this device.':
        'Les résultats incluent le catalogue vérifié et cet appareil.',
    'Showing results available on this device.':
        'Affichage des résultats disponibles sur cet appareil.',
    'Catalog unavailable — showing device results.':
        'Catalogue indisponible — affichage des résultats de l’appareil.',
    'This local food list could not be loaded.':
        'Impossible de charger cette liste d’aliments locale.',
    'Download verified libraries when needed and search them offline.':
        'Téléchargez des bibliothèques vérifiées au besoin et consultez-les hors ligne.',
    'The core library is bundled. Optional packs enter BIL only after size and cryptographic hash verification.':
        'La bibliothèque principale est intégrée. Les packs facultatifs ne sont ajoutés à BIL qu’après vérification de leur taille et de leur empreinte cryptographique.',
    'Installed and offline-ready': 'Installée et disponible hors ligne',
    'Pack downloads are not configured in this build yet. No placeholder links or unverified downloads are used.':
        'Le téléchargement des packs n’est pas encore configuré dans cette version. Aucun lien fictif ni téléchargement non vérifié n’est utilisé.',
    'No packs are currently published.':
        'Aucun pack n’est publié actuellement.',
    'The pack list could not be refreshed. Your local library still works.':
        'Impossible d’actualiser la liste des packs. Votre bibliothèque locale reste disponible.',
  },
  'es': {
    'Food': 'Alimentación',
    'All': 'Todo',
    'Favorites': 'Favoritos',
    'Recent': 'Recientes',
    'Submit for review': 'Enviar para revisión',
    'Scan product label': 'Escanear la etiqueta del producto',
    'Food libraries': 'Bibliotecas de alimentos',
    'BIL Food Core': 'Base alimentaria BIL',
    'Download': 'Descargar',
    'Plan required': 'Plan requerido',
    'Remove': 'Eliminar',
    'Open laptop camera': 'Abrir cámara del portátil',
    'Say the food name': 'Di el nombre del alimento',
    'Cancel': 'Cancelar',
    'Done': 'Listo',
    'Listening…': 'Escuchando…',
    'Voice input unavailable': 'Entrada de voz no disponible',
    'OK': 'Aceptar',
    'Scan': 'Escanear',
    'Scan barcode': 'Escanear código de barras',
    'Analyze meal photo': 'Analizar foto de la comida',
    'Search foods': 'Buscar alimentos',
    'Barcode': 'Código de barras',
    'Custom': 'Personalizado',
    'protein': 'proteína',
    'carbs': 'carbohidratos',
    'fat': 'grasa',
    'fiber': 'fibra',
    'sodium': 'sodio',
    'potassium': 'potasio',
    'Nutrition pathways': 'Rutas nutricionales',
    'Choose a pathway built around your goal.':
        'Elige una ruta adaptada a tu objetivo.',
    'Compare first, then create an editable draft. Your goals never change without approval.':
        'Compara primero y crea un borrador editable. Tus objetivos nunca cambian sin tu aprobación.',
    'All pathways': 'Todas las rutas',
    'Current pathway': 'Ruta actual',
    'Approach': 'Enfoque',
    'Monitoring': 'Seguimiento',
    'This pathway requires clinician review before activation.':
        'Esta ruta requiere revisión profesional antes de activarse.',
    'Medical supervision required': 'Se requiere supervisión médica',
    'Review in My Plan': 'Revisar en Mi plan',
    'Explore sleep, movement, and daily rhythm':
        'Explorar sueño, movimiento y ritmo diario',
    'Did you mean:': 'Quizá quisiste decir:',
    'Balanced meal in the nutrition studio':
        'Comida equilibrada en el estudio de nutrición',
    'Log smarter. Understand your food.':
        'Registra mejor. Comprende tu alimentación.',
    'Verified search, fast scanning, and data you control.':
        'Búsqueda verificada, escaneo rápido y datos bajo tu control.',
    'Searching the verified catalog and this device…':
        'Buscando en el catálogo verificado y este dispositivo…',
    'Results include the verified catalog and this device.':
        'Los resultados incluyen el catálogo verificado y este dispositivo.',
    'Showing results available on this device.':
        'Mostrando resultados disponibles en este dispositivo.',
    'Catalog unavailable — showing device results.':
        'Catálogo no disponible; se muestran resultados del dispositivo.',
    'This local food list could not be loaded.':
        'No se pudo cargar esta lista local de alimentos.',
    'Download verified libraries when needed and search them offline.':
        'Descarga bibliotecas verificadas cuando las necesites y consúltalas sin conexión.',
    'The core library is bundled. Optional packs enter BIL only after size and cryptographic hash verification.':
        'La biblioteca principal está incluida. Los paquetes opcionales solo se añaden a BIL tras verificar su tamaño y huella criptográfica.',
    'Installed and offline-ready': 'Instalada y disponible sin conexión',
    'Pack downloads are not configured in this build yet. No placeholder links or unverified downloads are used.':
        'Las descargas de paquetes aún no están configuradas en esta versión. No se usan enlaces ficticios ni descargas sin verificar.',
    'No packs are currently published.':
        'No hay paquetes publicados actualmente.',
    'The pack list could not be refreshed. Your local library still works.':
        'No se pudo actualizar la lista de paquetes. Tu biblioteca local sigue disponible.',
  },
  'tr': {
    'Food': 'Beslenme',
    'All': 'Tümü',
    'Favorites': 'Favoriler',
    'Recent': 'Son kullanılanlar',
    'Submit for review': 'İncelemeye gönder',
    'Scan product label': 'Ürün etiketini tara',
    'Food libraries': 'Yiyecek kitaplıkları',
    'BIL Food Core': 'BIL Yiyecek Temeli',
    'Download': 'İndir',
    'Plan required': 'Plan gerekli',
    'Remove': 'Kaldır',
    'Open laptop camera': 'Dizüstü kamerasını aç',
    'Say the food name': 'Yiyeceğin adını söyleyin',
    'Cancel': 'İptal',
    'Done': 'Bitti',
    'Listening…': 'Dinleniyor…',
    'Voice input unavailable': 'Sesli giriş kullanılamıyor',
    'OK': 'Tamam',
    'Scan': 'Tara',
    'Scan barcode': 'Barkod tara',
    'Analyze meal photo': 'Öğün fotoğrafını analiz et',
    'Search foods': 'Yiyecek ara',
    'Barcode': 'Barkod',
    'Custom': 'Özel',
    'protein': 'protein',
    'carbs': 'karbonhidrat',
    'fat': 'yağ',
    'fiber': 'lif',
    'sodium': 'sodyum',
    'potassium': 'potasyum',
    'Nutrition pathways': 'Beslenme yolları',
    'Choose a pathway built around your goal.':
        'Hedefinize uygun bir yol seçin.',
    'Compare first, then create an editable draft. Your goals never change without approval.':
        'Önce karşılaştırın, sonra düzenlenebilir bir taslak oluşturun. Onayınız olmadan hedefleriniz değişmez.',
    'All pathways': 'Tüm yollar',
    'Current pathway': 'Geçerli yol',
    'Approach': 'Yaklaşım',
    'Monitoring': 'İzleme',
    'This pathway requires clinician review before activation.':
        'Bu yol etkinleştirilmeden önce uzman incelemesi gerektirir.',
    'Medical supervision required': 'Tıbbi gözetim gerekli',
    'Review in My Plan': 'Planımda incele',
    'Explore sleep, movement, and daily rhythm':
        'Uyku, hareket ve günlük ritmi keşfet',
    'Did you mean:': 'Bunu mu demek istediniz:',
    'Balanced meal in the nutrition studio':
        'Beslenme stüdyosunda dengeli öğün',
    'Log smarter. Understand your food.':
        'Daha akıllı kaydedin. Yemeğinizi anlayın.',
    'Verified search, fast scanning, and data you control.':
        'Doğrulanmış arama, hızlı tarama ve kontrolünüzdeki veriler.',
    'Searching the verified catalog and this device…':
        'Doğrulanmış katalogda ve bu cihazda aranıyor…',
    'Results include the verified catalog and this device.':
        'Sonuçlar doğrulanmış kataloğu ve bu cihazı içerir.',
    'Showing results available on this device.':
        'Bu cihazdaki sonuçlar gösteriliyor.',
    'Catalog unavailable — showing device results.':
        'Katalog kullanılamıyor — cihaz sonuçları gösteriliyor.',
    'This local food list could not be loaded.':
        'Bu yerel yiyecek listesi yüklenemedi.',
    'Download verified libraries when needed and search them offline.':
        'Gerektiğinde doğrulanmış kitaplıkları indirin ve çevrimdışı arayın.',
    'The core library is bundled. Optional packs enter BIL only after size and cryptographic hash verification.':
        'Temel kitaplık uygulamaya dahildir. İsteğe bağlı paketler yalnızca boyut ve kriptografik özet doğrulamasından sonra BIL’e eklenir.',
    'Installed and offline-ready': 'Yüklü ve çevrimdışı kullanıma hazır',
    'Pack downloads are not configured in this build yet. No placeholder links or unverified downloads are used.':
        'Paket indirmeleri bu sürümde henüz yapılandırılmadı. Geçici bağlantılar veya doğrulanmamış indirmeler kullanılmaz.',
    'No packs are currently published.': 'Şu anda yayımlanmış paket yok.',
    'The pack list could not be refreshed. Your local library still works.':
        'Paket listesi yenilenemedi. Yerel kitaplığınız çalışmaya devam ediyor.',
  },
};
