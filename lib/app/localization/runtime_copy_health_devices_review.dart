import 'bil_locale_policy.dart';

/// Exact 25-locale copy for the repaired health/device surfaces.
abstract final class HealthDevicesReviewCopy {
  static const sources = <String>[
    'Synchronizing…',
    'Connection status',
    'Heart-rate variability',
    'Distance',
    'bpm',
    'Fitness readings',
  ];
  static const rows = <String, List<String>>{
    'en': sources,
    'ar': [
      'تتم المزامنة…',
      'حالة الاتصال',
      'تباين معدل القلب',
      'المسافة',
      'نبضة/د',
      'قراءات اللياقة',
    ],
    'fr': [
      'Synchronisation…',
      'État de la connexion',
      'Variabilité de la fréquence cardiaque',
      'Distance',
      'bpm',
      'Mesures de forme physique',
    ],
    'es': [
      'Sincronizando…',
      'Estado de la conexión',
      'Variabilidad de la frecuencia cardíaca',
      'Distancia',
      'lat/min',
      'Mediciones de actividad física',
    ],
    'tr': [
      'Eşitleniyor…',
      'Bağlantı durumu',
      'Kalp atış hızı değişkenliği',
      'Mesafe',
      'atım/dk',
      'Fitness ölçümleri',
    ],
    'de': [
      'Synchronisierung…',
      'Verbindungsstatus',
      'Herzfrequenzvariabilität',
      'Entfernung',
      'S/min',
      'Fitnessmesswerte',
    ],
    'it': [
      'Sincronizzazione…',
      'Stato della connessione',
      'Variabilità della frequenza cardiaca',
      'Distanza',
      'bpm',
      'Misurazioni fitness',
    ],
    'pt-BR': [
      'Sincronizando…',
      'Status da conexão',
      'Variabilidade da frequência cardíaca',
      'Distância',
      'bpm',
      'Medições de atividade física',
    ],
    'pt-PT': [
      'A sincronizar…',
      'Estado da ligação',
      'Variabilidade da frequência cardíaca',
      'Distância',
      'bpm',
      'Medições de atividade física',
    ],
    'ur': [
      'ہم وقت ہو رہا ہے…',
      'کنکشن کی حالت',
      'دل کی دھڑکن میں تغیر',
      'فاصلہ',
      'دھڑکن/منٹ',
      'فٹنس پیمائشیں',
    ],
    'fa': [
      'در حال همگام‌سازی…',
      'وضعیت اتصال',
      'تغییرپذیری ضربان قلب',
      'مسافت',
      'ضربان/دقیقه',
      'اندازه‌گیری‌های تناسب اندام',
    ],
    'hi': [
      'सिंक हो रहा है…',
      'कनेक्शन की स्थिति',
      'हृदय गति परिवर्तनशीलता',
      'दूरी',
      'धड़कन/मिनट',
      'फ़िटनेस माप',
    ],
    'id': [
      'Menyinkronkan…',
      'Status koneksi',
      'Variabilitas detak jantung',
      'Jarak',
      'denyut/mnt',
      'Pengukuran kebugaran',
    ],
    'ms': [
      'Menyegerakkan…',
      'Status sambungan',
      'Kebolehubahan kadar denyutan jantung',
      'Jarak',
      'denyutan/min',
      'Bacaan kecergasan',
    ],
    'ja': ['同期中…', '接続状態', '心拍変動', '距離', '拍/分', 'フィットネス測定値'],
    'ko': ['동기화 중…', '연결 상태', '심박 변이도', '거리', '회/분', '피트니스 측정값'],
    'zh-Hans': ['正在同步…', '连接状态', '心率变异性', '距离', '次/分', '健身测量数据'],
    'zh-Hant': ['正在同步…', '連線狀態', '心率變異性', '距離', '次/分', '健身測量資料'],
    'ru': [
      'Синхронизация…',
      'Состояние подключения',
      'Вариабельность сердечного ритма',
      'Расстояние',
      'уд/мин',
      'Показатели активности',
    ],
    'bn': [
      'সিঙ্ক হচ্ছে…',
      'সংযোগের অবস্থা',
      'হৃদস্পন্দনের পরিবর্তনশীলতা',
      'দূরত্ব',
      'স্পন্দন/মিনিট',
      'ফিটনেস পরিমাপ',
    ],
    'vi': [
      'Đang đồng bộ…',
      'Trạng thái kết nối',
      'Biến thiên nhịp tim',
      'Quãng đường',
      'nhịp/phút',
      'Chỉ số thể chất',
    ],
    'th': [
      'กำลังซิงค์…',
      'สถานะการเชื่อมต่อ',
      'ความแปรปรวนของอัตราการเต้นหัวใจ',
      'ระยะทาง',
      'ครั้ง/นาที',
      'ค่าการออกกำลังกาย',
    ],
    'pl': [
      'Synchronizowanie…',
      'Stan połączenia',
      'Zmienność rytmu serca',
      'Dystans',
      'ud/min',
      'Pomiary aktywności',
    ],
    'nl': [
      'Synchroniseren…',
      'Verbindingsstatus',
      'Hartslagvariabiliteit',
      'Afstand',
      'sl/min',
      'Fitnessmetingen',
    ],
    'uk': [
      'Синхронізація…',
      'Стан з’єднання',
      'Варіабельність серцевого ритму',
      'Відстань',
      'уд/хв',
      'Показники активності',
    ],
  };
  static String? resolve(String source, String tag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final canonical = BilLocalePolicy.canonicalTag(
      BilLocalePolicy.localeFromTag(tag),
    );
    return rows[canonical]?[index];
  }

  static bool get balanced =>
      rows.length == 25 &&
      rows.values.every(
        (row) =>
            row.length == sources.length &&
            row.every((text) => text.trim().isNotEmpty),
      );
}
