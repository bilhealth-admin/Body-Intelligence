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
    'BIL imports fitness measurements only after your permission. It supports compatible fitness BLE profiles and is not a medical device.':
        'BIL importe les mesures de fitness uniquement avec votre autorisation. Il prend en charge les profils BLE d’appareils de fitness compatibles et n’est pas un dispositif médical.',
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
    'Bluetooth fitness devices': 'Appareils de fitness Bluetooth',
    'Bluetooth fitness device and smart watch':
        'Appareil de fitness Bluetooth et montre connectée',
    'Compatible fitness devices': 'Appareils de fitness compatibles',
    'Disconnect': 'Déconnecter',
    'Remove device': 'Supprimer l’appareil',
    'Connect': 'Connecter',
    'Requires Android or iPhone': 'Nécessite Android ou iPhone',
    'Scan for fitness devices': 'Rechercher des appareils de fitness',
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
    'Health source connected': 'Source santé connectée',
    'Smart-watch reading': 'Mesure de la montre connectée',
    'Latest synchronization': 'Dernière synchronisation',
    'Steps': 'Pas',
    'Heart rate': 'Fréquence cardiaque',
    'Resting heart rate': 'Fréquence au repos',
    'Active energy': 'Énergie active',
    'Sleep': 'Sommeil',
    'Weight': 'Poids',
    'Body fat': 'Masse grasse',
    'bpm': 'bpm',
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
    'Connect a fitness device': 'Connecter un appareil de fitness',
    'Connect a supported iOS or Android health source to begin.':
        'Connectez une source santé iOS ou Android compatible pour commencer.',
    'Bluetooth fitness-device linking is unavailable here.':
        'La connexion d’appareils de fitness par Bluetooth est indisponible ici.',
    'Waiting for Bluetooth permission…':
        'En attente de l’autorisation Bluetooth…',
    'Searching nearby…': 'Recherche à proximité…',
    'Connecting securely…': 'Connexion sécurisée…',
    'Connection needs attention. Try again.':
        'La connexion requiert votre attention. Réessayez.',
    'Connect verified Bluetooth measurements':
        'Connecter des mesures de fitness Bluetooth compatibles',
    'Weight, body composition, and heart rate.':
        'Poids, composition corporelle et fréquence cardiaque.',
  },
  'es': {
    'Apps & Devices': 'Aplicaciones y dispositivos',
    'All': 'Todo',
    'Connection capabilities': 'Capacidades de conexión',
    'Search connections': 'Buscar conexiones',
    'Unavailable on this device.': 'No disponible en este dispositivo.',
    'Allow weight and nutrition export': 'Permitir exportar peso y nutrición',
    'BIL imports fitness measurements only after your permission. It supports compatible fitness BLE profiles and is not a medical device.':
        'BIL importa mediciones de fitness solo con tu permiso. Admite perfiles BLE de dispositivos de fitness compatibles y no es un dispositivo médico.',
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
    'Bluetooth fitness devices': 'Dispositivos de fitness Bluetooth',
    'Bluetooth fitness device and smart watch':
        'Dispositivo de fitness Bluetooth y reloj inteligente',
    'Compatible fitness devices': 'Dispositivos de fitness compatibles',
    'Disconnect': 'Desconectar',
    'Remove device': 'Eliminar dispositivo',
    'Connect': 'Conectar',
    'Requires Android or iPhone': 'Requiere Android o iPhone',
    'Scan for fitness devices': 'Buscar dispositivos de fitness',
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
    'Health source connected': 'Fuente de salud conectada',
    'Smart-watch reading': 'Lectura del reloj inteligente',
    'Latest synchronization': 'Última sincronización',
    'Steps': 'Pasos',
    'Heart rate': 'Frecuencia cardíaca',
    'Resting heart rate': 'Frecuencia en reposo',
    'Active energy': 'Energía activa',
    'Sleep': 'Sueño',
    'Weight': 'Peso',
    'Body fat': 'Grasa corporal',
    'bpm': 'lpm',
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
    'Connect a fitness device': 'Conectar un dispositivo de fitness',
    'Connect a supported iOS or Android health source to begin.':
        'Conecta una fuente de salud compatible de iOS o Android para empezar.',
    'Bluetooth fitness-device linking is unavailable here.':
        'La vinculación de dispositivos de fitness por Bluetooth no está disponible aquí.',
    'Waiting for Bluetooth permission…': 'Esperando permiso de Bluetooth…',
    'Searching nearby…': 'Buscando cerca…',
    'Connecting securely…': 'Conectando de forma segura…',
    'Connection needs attention. Try again.':
        'La conexión requiere atención. Inténtalo de nuevo.',
    'Connect verified Bluetooth measurements':
        'Conectar mediciones de fitness Bluetooth compatibles',
    'Weight, body composition, and heart rate.':
        'Peso, composición corporal y frecuencia cardíaca.',
  },
  'tr': {
    'Apps & Devices': 'Uygulamalar ve cihazlar',
    'All': 'Tümü',
    'Connection capabilities': 'Bağlantı özellikleri',
    'Search connections': 'Bağlantılarda ara',
    'Unavailable on this device.': 'Bu cihazda kullanılamıyor.',
    'Allow weight and nutrition export':
        'Kilo ve beslenme dışa aktarımına izin ver',
    'BIL imports fitness measurements only after your permission. It supports compatible fitness BLE profiles and is not a medical device.':
        'BIL fitness ölçümlerini yalnızca izninizle içe aktarır. Uyumlu fitness cihazlarının BLE profillerini destekler ve tıbbi bir cihaz değildir.',
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
    'Bluetooth fitness devices': 'Bluetooth fitness cihazları',
    'Bluetooth fitness device and smart watch':
        'Bluetooth fitness cihazı ve akıllı saat',
    'Compatible fitness devices': 'Uyumlu fitness cihazları',
    'Disconnect': 'Bağlantıyı kes',
    'Remove device': 'Cihazı kaldır',
    'Connect': 'Bağlan',
    'Requires Android or iPhone': 'Android veya iPhone gerekir',
    'Scan for fitness devices': 'Fitness cihazlarını tara',
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
    'Health source connected': 'Sağlık kaynağı bağlı',
    'Smart-watch reading': 'Akıllı saat ölçümü',
    'Latest synchronization': 'Son eşitleme',
    'Steps': 'Adım',
    'Heart rate': 'Kalp atış hızı',
    'Resting heart rate': 'Dinlenme nabzı',
    'Active energy': 'Aktif enerji',
    'Sleep': 'Uyku',
    'Weight': 'Kilo',
    'Body fat': 'Vücut yağı',
    'bpm': 'atım/dk',
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
    'Connect a fitness device': 'Fitness cihazı bağla',
    'Connect a supported iOS or Android health source to begin.':
        'Başlamak için desteklenen bir iOS veya Android sağlık kaynağı bağlayın.',
    'Bluetooth fitness-device linking is unavailable here.':
        'Bluetooth fitness cihazı bağlantısı burada kullanılamıyor.',
    'Waiting for Bluetooth permission…': 'Bluetooth izni bekleniyor…',
    'Searching nearby…': 'Yakındakiler aranıyor…',
    'Connecting securely…': 'Güvenli bağlanıyor…',
    'Connection needs attention. Try again.':
        'Bağlantıyla ilgilenilmesi gerekiyor. Tekrar deneyin.',
    'Connect verified Bluetooth measurements':
        'Uyumlu Bluetooth fitness ölçümlerini bağla',
    'Weight, body composition, and heart rate.':
        'Kilo, vücut kompozisyonu ve kalp atış hızı.',
  },
};
