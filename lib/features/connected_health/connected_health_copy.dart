import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/runtime_copy.dart';

String connectedHealthText(
  BuildContext context,
  String english,
  String arabic,
) {
  final language = Localizations.localeOf(context).languageCode.toLowerCase();
  if (!const {'ar', 'en', 'fr', 'es', 'tr'}.contains(language)) {
    return context.strings.text(english);
  }
  return connectedHealthTextForLanguage(language, english, arabic);
}

String connectedHealthTextForLanguage(
  String languageCode,
  String english,
  String arabic,
) {
  final language = languageCode.toLowerCase();
  if (language == 'ar') return arabic;
  if (language == 'en') return english;
  return _translations[language]?[english] ??
      RuntimeCopy.resolve(english, languageCode) ??
      english;
}

const _translations = <String, Map<String, String>>{
  'fr': {
    'Apps & Devices': 'Applications et appareils',
    'All': 'Tout',
    'Connection capabilities': 'Capacités de connexion',
    'Search connections': 'Rechercher des connexions',
    'Unavailable on this device.': 'Indisponible sur cet appareil.',
    'Allow weight and nutrition export':
        'Autoriser l’export du poids et de la nutrition',
    'BIL imports measurements only after your permission. It supports standard BLE health profiles and is not a diagnostic medical device.':
        'BIL importe les mesures uniquement avec votre autorisation. Les profils de santé BLE standard sont pris en charge ; BIL n’est pas un dispositif médical de diagnostic.',
    'Health Hub': 'Centre de santé',
    'Sync now': 'Synchroniser',
    'Refresh status': 'Actualiser l’état',
    'Available sources': 'Sources disponibles',
    'Unsupported platform': 'Plateforme non prise en charge',
    'Grant health access': 'Autoriser l’accès santé',
    'Open system settings': 'Ouvrir les réglages système',
    'Allow weight export': 'Autoriser l’export du poids',
    'Disconnect health source': 'Déconnecter la source santé',
    'Privacy and data flow': 'Confidentialité et flux de données',
    'Recent synchronized signals': 'Signaux synchronisés récents',
    'No synchronized signal is available yet.':
        'Aucun signal synchronisé n’est encore disponible.',
    'Supported connections': 'Connexions prises en charge',
    'Implementation ready; physical-device verification required':
        'Implémentation prête ; vérification sur appareil physique requise',
    'Medical devices': 'Appareils médicaux',
    'Disconnect': 'Déconnecter',
    'Remove device': 'Supprimer l’appareil',
    'Connect': 'Connecter',
    'Requires Android or iPhone': 'Nécessite Android ou iPhone',
    'Scan for medical devices': 'Rechercher des appareils médicaux',
    'Ready to search nearby.': 'Prêt à rechercher à proximité.',
    'Connect now': 'Connecter maintenant',
    'Manage sources': 'Gérer les sources',
    'Read again': 'Lire à nouveau',
    'Received via BLE': 'Reçu via BLE',
    'Connected': 'Connecté',
    'Not connected': 'Non connecté',
    'Ready': 'Prêt',
    'Synchronizing': 'Synchronisation',
    'Update required': 'Mise à jour requise',
    'Needs attention': 'Attention requise',
    'No connected sources': 'Aucune source connectée',
    'Waiting for first sync': 'En attente de la première synchronisation',
    'Health source': 'Source santé',
    'Smart-watch reading': 'Mesure de la montre connectée',
    'Latest synchronization': 'Dernière synchronisation',
    'Steps': 'Pas',
    'Heart rate': 'Fréquence cardiaque',
    'Resting heart rate': 'Fréquence au repos',
    'Active energy': 'Énergie active',
    'Sleep': 'Sommeil',
    'Blood pressure': 'Tension artérielle',
    'Glucose': 'Glycémie',
    'Weight': 'Poids',
    'Blood oxygen': 'Oxygène sanguin',
    'Body fat': 'Masse grasse',
    'bpm': 'bpm',
    'Diastolic': 'Diastolique',
    'Systolic': 'Systolique',
    'Temperature': 'Température',
    'Measurement': 'Mesure',
    'no measurement': 'aucune mesure',
    'steps': 'pas',
    'sleep': 'sommeil',
    'kcal': 'kcal',
    'Try again': 'Réessayer',
    'Live health watch showing current time and available measured data':
        'Montre santé en direct affichant l’heure et les mesures disponibles',
    'Health Hub status could not be read. No data was deleted or uploaded.':
        'Impossible de lire l’état du centre de santé. Aucune donnée n’a été supprimée ni envoyée.',
    'Health Hub status could not be read.':
        'Impossible de lire l’état du centre de santé.',
    'Permission denied': 'Autorisation refusée',
    'Waiting for a measured value': 'En attente d’une mesure',
    'Connect a medical device': 'Connecter un appareil médical',
    'Connect a supported iOS or Android health source to begin.':
        'Connectez une source santé iOS ou Android compatible pour commencer.',
    'Bluetooth medical linking is unavailable here.':
        'La connexion médicale Bluetooth est indisponible ici.',
    'Waiting for Bluetooth permission…':
        'En attente de l’autorisation Bluetooth…',
    'Searching nearby…': 'Recherche à proximité…',
    'Connecting securely…': 'Connexion sécurisée…',
    'Connection needs attention. Try again.':
        'La connexion requiert votre attention. Réessayez.',
    'Connect verified Bluetooth measurements':
        'Connecter des mesures Bluetooth vérifiées',
    'Blood pressure, glucose, weight, body composition, oxygen, heart rate and temperature.':
        'Tension, glycémie, poids, composition corporelle, oxygène, fréquence cardiaque et température.',
  },
  'es': {
    'Apps & Devices': 'Aplicaciones y dispositivos',
    'All': 'Todo',
    'Connection capabilities': 'Capacidades de conexión',
    'Search connections': 'Buscar conexiones',
    'Unavailable on this device.': 'No disponible en este dispositivo.',
    'Allow weight and nutrition export': 'Permitir exportar peso y nutrición',
    'BIL imports measurements only after your permission. It supports standard BLE health profiles and is not a diagnostic medical device.':
        'BIL importa mediciones solo con tu permiso. Admite perfiles de salud BLE estándar y no es un dispositivo médico de diagnóstico.',
    'Health Hub': 'Centro de salud',
    'Sync now': 'Sincronizar ahora',
    'Refresh status': 'Actualizar estado',
    'Available sources': 'Fuentes disponibles',
    'Unsupported platform': 'Plataforma no compatible',
    'Grant health access': 'Conceder acceso a salud',
    'Open system settings': 'Abrir ajustes del sistema',
    'Allow weight export': 'Permitir exportar el peso',
    'Disconnect health source': 'Desconectar fuente de salud',
    'Privacy and data flow': 'Privacidad y flujo de datos',
    'Recent synchronized signals': 'Señales sincronizadas recientes',
    'No synchronized signal is available yet.':
        'Aún no hay señales sincronizadas disponibles.',
    'Supported connections': 'Conexiones compatibles',
    'Implementation ready; physical-device verification required':
        'Implementación lista; se requiere verificación en un dispositivo físico',
    'Medical devices': 'Dispositivos médicos',
    'Disconnect': 'Desconectar',
    'Remove device': 'Eliminar dispositivo',
    'Connect': 'Conectar',
    'Requires Android or iPhone': 'Requiere Android o iPhone',
    'Scan for medical devices': 'Buscar dispositivos médicos',
    'Ready to search nearby.': 'Listo para buscar cerca.',
    'Connect now': 'Conectar ahora',
    'Manage sources': 'Gestionar fuentes',
    'Read again': 'Leer de nuevo',
    'Received via BLE': 'Recibido por BLE',
    'Connected': 'Conectado',
    'Not connected': 'Sin conexión',
    'Ready': 'Listo',
    'Synchronizing': 'Sincronizando',
    'Update required': 'Actualización necesaria',
    'Needs attention': 'Requiere atención',
    'No connected sources': 'No hay fuentes conectadas',
    'Waiting for first sync': 'Esperando la primera sincronización',
    'Health source': 'Fuente de salud',
    'Smart-watch reading': 'Lectura del reloj inteligente',
    'Latest synchronization': 'Última sincronización',
    'Steps': 'Pasos',
    'Heart rate': 'Frecuencia cardíaca',
    'Resting heart rate': 'Frecuencia en reposo',
    'Active energy': 'Energía activa',
    'Sleep': 'Sueño',
    'Blood pressure': 'Presión arterial',
    'Glucose': 'Glucosa',
    'Weight': 'Peso',
    'Blood oxygen': 'Oxígeno en sangre',
    'Body fat': 'Grasa corporal',
    'bpm': 'lpm',
    'Diastolic': 'Diastólica',
    'Systolic': 'Sistólica',
    'Temperature': 'Temperatura',
    'Measurement': 'Medición',
    'no measurement': 'sin medición',
    'steps': 'pasos',
    'sleep': 'sueño',
    'kcal': 'kcal',
    'Try again': 'Reintentar',
    'Live health watch showing current time and available measured data':
        'Reloj de salud en vivo con la hora y las mediciones disponibles',
    'Health Hub status could not be read. No data was deleted or uploaded.':
        'No se pudo leer el estado del centro de salud. No se eliminó ni subió ningún dato.',
    'Health Hub status could not be read.':
        'No se pudo leer el estado del centro de salud.',
    'Permission denied': 'Permiso denegado',
    'Waiting for a measured value': 'Esperando una medición',
    'Connect a medical device': 'Conectar un dispositivo médico',
    'Connect a supported iOS or Android health source to begin.':
        'Conecta una fuente de salud compatible de iOS o Android para empezar.',
    'Bluetooth medical linking is unavailable here.':
        'La vinculación médica por Bluetooth no está disponible aquí.',
    'Waiting for Bluetooth permission…': 'Esperando permiso de Bluetooth…',
    'Searching nearby…': 'Buscando cerca…',
    'Connecting securely…': 'Conectando de forma segura…',
    'Connection needs attention. Try again.':
        'La conexión requiere atención. Inténtalo de nuevo.',
    'Connect verified Bluetooth measurements':
        'Conectar mediciones Bluetooth verificadas',
    'Blood pressure, glucose, weight, body composition, oxygen, heart rate and temperature.':
        'Presión, glucosa, peso, composición corporal, oxígeno, frecuencia cardíaca y temperatura.',
  },
  'tr': {
    'Apps & Devices': 'Uygulamalar ve cihazlar',
    'All': 'Tümü',
    'Connection capabilities': 'Bağlantı özellikleri',
    'Search connections': 'Bağlantılarda ara',
    'Unavailable on this device.': 'Bu cihazda kullanılamıyor.',
    'Allow weight and nutrition export':
        'Kilo ve beslenme dışa aktarımına izin ver',
    'BIL imports measurements only after your permission. It supports standard BLE health profiles and is not a diagnostic medical device.':
        'BIL ölçümleri yalnızca izninizle içe aktarır. Standart BLE sağlık profillerini destekler ve tanı amaçlı bir tıbbi cihaz değildir.',
    'Health Hub': 'Sağlık Merkezi',
    'Sync now': 'Şimdi eşitle',
    'Refresh status': 'Durumu yenile',
    'Available sources': 'Kullanılabilir kaynaklar',
    'Unsupported platform': 'Desteklenmeyen platform',
    'Grant health access': 'Sağlık erişimi ver',
    'Open system settings': 'Sistem ayarlarını aç',
    'Allow weight export': 'Kilo aktarımına izin ver',
    'Disconnect health source': 'Sağlık kaynağı bağlantısını kes',
    'Privacy and data flow': 'Gizlilik ve veri akışı',
    'Recent synchronized signals': 'Son eşitlenen sinyaller',
    'No synchronized signal is available yet.': 'Henüz eşitlenmiş sinyal yok.',
    'Supported connections': 'Desteklenen bağlantılar',
    'Implementation ready; physical-device verification required':
        'Uygulama hazır; fiziksel cihaz doğrulaması gerekli',
    'Medical devices': 'Tıbbi cihazlar',
    'Disconnect': 'Bağlantıyı kes',
    'Remove device': 'Cihazı kaldır',
    'Connect': 'Bağlan',
    'Requires Android or iPhone': 'Android veya iPhone gerekir',
    'Scan for medical devices': 'Tıbbi cihazları tara',
    'Ready to search nearby.': 'Yakındaki cihazları aramaya hazır.',
    'Connect now': 'Şimdi bağlan',
    'Manage sources': 'Kaynakları yönet',
    'Read again': 'Tekrar oku',
    'Received via BLE': 'BLE ile alındı',
    'Connected': 'Bağlı',
    'Not connected': 'Bağlı değil',
    'Ready': 'Hazır',
    'Synchronizing': 'Eşitleniyor',
    'Update required': 'Güncelleme gerekli',
    'Needs attention': 'İlgilenilmesi gerekiyor',
    'No connected sources': 'Bağlı kaynak yok',
    'Waiting for first sync': 'İlk eşitleme bekleniyor',
    'Health source': 'Sağlık kaynağı',
    'Smart-watch reading': 'Akıllı saat ölçümü',
    'Latest synchronization': 'Son eşitleme',
    'Steps': 'Adım',
    'Heart rate': 'Kalp atış hızı',
    'Resting heart rate': 'Dinlenme nabzı',
    'Active energy': 'Aktif enerji',
    'Sleep': 'Uyku',
    'Blood pressure': 'Tansiyon',
    'Glucose': 'Glikoz',
    'Weight': 'Kilo',
    'Blood oxygen': 'Kan oksijeni',
    'Body fat': 'Vücut yağı',
    'bpm': 'atım/dk',
    'Diastolic': 'Diyastolik',
    'Systolic': 'Sistolik',
    'Temperature': 'Sıcaklık',
    'Measurement': 'Ölçüm',
    'no measurement': 'ölçüm yok',
    'steps': 'adım',
    'sleep': 'uyku',
    'kcal': 'kcal',
    'Try again': 'Tekrar dene',
    'Live health watch showing current time and available measured data':
        'Geçerli saati ve mevcut ölçümleri gösteren canlı sağlık saati',
    'Health Hub status could not be read. No data was deleted or uploaded.':
        'Sağlık Merkezi durumu okunamadı. Hiçbir veri silinmedi veya yüklenmedi.',
    'Health Hub status could not be read.': 'Sağlık Merkezi durumu okunamadı.',
    'Permission denied': 'İzin reddedildi',
    'Waiting for a measured value': 'Ölçülen değer bekleniyor',
    'Connect a medical device': 'Tıbbi cihaz bağla',
    'Connect a supported iOS or Android health source to begin.':
        'Başlamak için desteklenen bir iOS veya Android sağlık kaynağı bağlayın.',
    'Bluetooth medical linking is unavailable here.':
        'Bluetooth tıbbi bağlantı burada kullanılamıyor.',
    'Waiting for Bluetooth permission…': 'Bluetooth izni bekleniyor…',
    'Searching nearby…': 'Yakındakiler aranıyor…',
    'Connecting securely…': 'Güvenli bağlanıyor…',
    'Connection needs attention. Try again.':
        'Bağlantıyla ilgilenilmesi gerekiyor. Tekrar deneyin.',
    'Connect verified Bluetooth measurements':
        'Doğrulanmış Bluetooth ölçümlerini bağla',
    'Blood pressure, glucose, weight, body composition, oxygen, heart rate and temperature.':
        'Tansiyon, glikoz, kilo, vücut bileşimi, oksijen, kalp atışı ve sıcaklık.',
  },
};
