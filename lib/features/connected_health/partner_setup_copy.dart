import 'package:flutter/widgets.dart';

import '../../app/localization/bil_locale_policy.dart';

/// Reviewed copy for links and QR codes that point only to official vendor
/// guidance. This surface never describes a BIL data connection.
final class PartnerSetupCopy {
  const PartnerSetupCopy._(this._values);

  static const officialSetup = 'Official setup';
  static const openGuide = 'Open official setup guide';
  static const showQr = 'Show setup QR';
  static const guidanceOnly =
      'Official vendor guidance only. This QR opens the vendor setup page; it does not connect or pair data with BIL.';

  static const sources = <String>[
    officialSetup,
    openGuide,
    showQr,
    guidanceOnly,
  ];

  static const supported = <String>{
    'ar',
    'en',
    'fr',
    'es',
    'tr',
    'de',
    'it',
    'pt-BR',
    'pt-PT',
    'ur',
    'fa',
    'hi',
    'id',
    'ms',
    'ja',
    'ko',
    'zh-Hans',
    'zh-Hant',
    'ru',
    'bn',
    'vi',
    'th',
    'pl',
    'nl',
    'uk',
  };

  static const rows = <String, List<String>>{
    'ar': [
      'الإعداد الرسمي',
      'فتح دليل الإعداد الرسمي',
      'عرض QR للإعداد',
      'إرشادات الشركة الرسمية فقط. يفتح QR صفحة إعداد الشركة، ولا يربط البيانات بـ BIL أو يقرنها.',
    ],
    'en': sources,
    'fr': [
      'Configuration officielle',
      'Ouvrir le guide de configuration officiel',
      'Afficher le QR de configuration',
      'Guide officiel du fournisseur uniquement. Ce QR ouvre la page de configuration du fournisseur ; il ne connecte ni n’associe les données à BIL.',
    ],
    'es': [
      'Configuración oficial',
      'Abrir la guía oficial de configuración',
      'Mostrar QR de configuración',
      'Solo orientación oficial del proveedor. Este QR abre su página de configuración; no conecta ni vincula datos con BIL.',
    ],
    'tr': [
      'Resmî kurulum',
      'Resmî kurulum kılavuzunu aç',
      'Kurulum QR kodunu göster',
      'Yalnızca resmî satıcı rehberi. Bu QR satıcının kurulum sayfasını açar; verileri BIL’e bağlamaz veya eşleştirmez.',
    ],
    'de': [
      'Offizielle Einrichtung',
      'Offizielle Einrichtungsanleitung öffnen',
      'Einrichtungs-QR anzeigen',
      'Nur offizielle Herstelleranleitung. Dieser QR öffnet die Einrichtungsseite des Herstellers; er verbindet oder koppelt keine Daten mit BIL.',
    ],
    'it': [
      'Configurazione ufficiale',
      'Apri la guida ufficiale alla configurazione',
      'Mostra il QR di configurazione',
      'Solo indicazioni ufficiali del fornitore. Questo QR apre la pagina di configurazione del fornitore; non collega né abbina dati a BIL.',
    ],
    'pt-BR': [
      'Configuração oficial',
      'Abrir guia oficial de configuração',
      'Mostrar QR de configuração',
      'Somente orientação oficial do fornecedor. Este QR abre a página de configuração do fornecedor; ele não conecta nem vincula dados ao BIL.',
    ],
    'pt-PT': [
      'Configuração oficial',
      'Abrir guia oficial de configuração',
      'Mostrar QR de configuração',
      'Apenas orientação oficial do fornecedor. Este QR abre a página de configuração do fornecedor; não liga nem associa dados ao BIL.',
    ],
    'ur': [
      'سرکاری سیٹ اپ',
      'سرکاری سیٹ اپ گائیڈ کھولیں',
      'سیٹ اپ QR دکھائیں',
      'صرف سرکاری وینڈر کی رہنمائی۔ یہ QR وینڈر کا سیٹ اپ صفحہ کھولتا ہے؛ یہ ڈیٹا کو BIL سے منسلک یا پیئر نہیں کرتا۔',
    ],
    'fa': [
      'راه‌اندازی رسمی',
      'باز کردن راهنمای رسمی راه‌اندازی',
      'نمایش QR راه‌اندازی',
      'فقط راهنمای رسمی شرکت. این QR صفحه راه‌اندازی شرکت را باز می‌کند؛ داده‌ها را به BIL متصل یا جفت نمی‌کند.',
    ],
    'hi': [
      'आधिकारिक सेटअप',
      'आधिकारिक सेटअप गाइड खोलें',
      'सेटअप QR दिखाएं',
      'केवल आधिकारिक वेंडर मार्गदर्शन। यह QR वेंडर का सेटअप पेज खोलता है; यह डेटा को BIL से कनेक्ट या पेयर नहीं करता।',
    ],
    'id': [
      'Penyiapan resmi',
      'Buka panduan penyiapan resmi',
      'Tampilkan QR penyiapan',
      'Hanya panduan resmi vendor. QR ini membuka halaman penyiapan vendor; tidak menghubungkan atau memasangkan data dengan BIL.',
    ],
    'ms': [
      'Persediaan rasmi',
      'Buka panduan persediaan rasmi',
      'Tunjukkan QR persediaan',
      'Panduan vendor rasmi sahaja. QR ini membuka halaman persediaan vendor; ia tidak menyambung atau memasangkan data dengan BIL.',
    ],
    'ja': [
      '公式セットアップ',
      '公式セットアップガイドを開く',
      'セットアップQRを表示',
      'ベンダーの公式ガイドのみです。このQRはベンダーのセットアップページを開くもので、BILとデータを接続またはペアリングしません。',
    ],
    'ko': [
      '공식 설정',
      '공식 설정 안내 열기',
      '설정 QR 표시',
      '공식 업체 안내입니다. 이 QR은 업체 설정 페이지를 열 뿐, 데이터를 BIL과 연결하거나 페어링하지 않습니다.',
    ],
    'zh-Hans': [
      '官方设置',
      '打开官方设置指南',
      '显示设置二维码',
      '仅供官方厂商指南。此二维码会打开厂商设置页面；不会将数据与 BIL 连接或配对。',
    ],
    'zh-Hant': [
      '官方設定',
      '開啟官方設定指南',
      '顯示設定 QR 碼',
      '僅提供官方廠商指南。此 QR 碼會開啟廠商設定頁面；不會將資料與 BIL 連線或配對。',
    ],
    'ru': [
      'Официальная настройка',
      'Открыть официальное руководство',
      'Показать QR-код настройки',
      'Только официальное руководство поставщика. Этот QR-код открывает страницу настройки; он не подключает и не сопрягает данные с BIL.',
    ],
    'bn': [
      'অফিসিয়াল সেটআপ',
      'অফিসিয়াল সেটআপ গাইড খুলুন',
      'সেটআপ QR দেখান',
      'কেবল অফিসিয়াল ভেন্ডর নির্দেশনা। এই QR ভেন্ডরের সেটআপ পেজ খোলে; এটি BIL-এর সাথে ডেটা সংযোগ বা পেয়ার করে না।',
    ],
    'vi': [
      'Thiết lập chính thức',
      'Mở hướng dẫn thiết lập chính thức',
      'Hiển thị QR thiết lập',
      'Chỉ là hướng dẫn chính thức của nhà cung cấp. QR này mở trang thiết lập của nhà cung cấp; không kết nối hay ghép dữ liệu với BIL.',
    ],
    'th': [
      'การตั้งค่าทางการ',
      'เปิดคู่มือตั้งค่าทางการ',
      'แสดง QR สำหรับตั้งค่า',
      'คำแนะนำจากผู้จัดจำหน่ายทางการเท่านั้น QR นี้เปิดหน้าตั้งค่าของผู้จัดจำหน่ายเท่านั้น ไม่ได้เชื่อมต่อหรือจับคู่ข้อมูลกับ BIL',
    ],
    'pl': [
      'Oficjalna konfiguracja',
      'Otwórz oficjalny przewodnik konfiguracji',
      'Pokaż kod QR konfiguracji',
      'Wyłącznie oficjalne wskazówki dostawcy. Ten kod QR otwiera stronę konfiguracji dostawcy; nie łączy ani nie paruje danych z BIL.',
    ],
    'nl': [
      'Officiële installatie',
      'Officiële installatiegids openen',
      'Installatie-QR tonen',
      'Alleen officiële instructies van de leverancier. Deze QR opent de installatiepagina van de leverancier; er worden geen gegevens met BIL verbonden of gekoppeld.',
    ],
    'uk': [
      'Офіційне налаштування',
      'Відкрити офіційний посібник',
      'Показати QR-код налаштування',
      'Лише офіційні вказівки постачальника. Цей QR-код відкриває сторінку налаштування; він не підключає і не спаровує дані з BIL.',
    ],
  };

  static PartnerSetupCopy of(BuildContext context) =>
      forTag(BilLocalePolicy.canonicalTag(Localizations.localeOf(context)));

  static PartnerSetupCopy forTag(String localeTag) {
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    final row = tag == null ? null : rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing partner setup copy for $localeTag.');
    }
    return PartnerSetupCopy._(row);
  }

  final List<String> _values;

  String text(String source) {
    final index = sources.indexOf(source);
    if (index < 0) throw StateError('Unknown partner setup copy: $source');
    return _values[index];
  }

  static bool get balanced =>
      supported.length == 25 &&
      rows.keys.toSet().containsAll(supported) &&
      supported.containsAll(rows.keys) &&
      rows.values.every(
        (row) =>
            row.length == sources.length &&
            row.every((value) => value.trim().isNotEmpty),
      ) &&
      _sameValues(rows['en'], sources);

  static bool _sameValues(List<String>? left, List<String> right) {
    if (left == null || left.length != right.length) return false;
    for (var index = 0; index < right.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
