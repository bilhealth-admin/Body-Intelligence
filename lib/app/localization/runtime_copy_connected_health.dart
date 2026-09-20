import 'package:flutter/widgets.dart';

import 'bil_locale_policy.dart';

/// Reviewed copy for measured fitness connection status and guidance.
///
/// Values remain templates until [format] is called so runtime values never
/// become lookup keys and silently fall back to English.
abstract final class ConnectedHealthRuntimeCopy {
  static const importedRecords =
      '{count} new records were imported during the last synchronization.';
  static const devicesFound = '{count} fitness device(s) found.';
  static const measurementSyncFailed =
      'Fitness device paired, but measurement sync failed ({code}).';
  static const connectedWithoutBattery =
      'Fitness device connected. Battery was not reported. Last sync: {time}.';
  static const connectedWithBattery =
      'Fitness device connected. Battery {percent}%. Last sync: {time}.';
  static const approvedCategoriesOnly =
      'Only approved health categories are read. Sync stays local and keeps the original source of every value.';
  static const connectionDataDetails = 'What each connection reads';
  static const supportedFitnessDevices =
      'Supported: scales, body-composition monitors, and heart-rate monitors.';
  static const appleWatchViaHealth =
      'Apple Watch data comes through Apple Health. Do not pair Apple Watch here.';

  static const sources = <String>[
    importedRecords,
    devicesFound,
    measurementSyncFailed,
    connectedWithoutBattery,
    connectedWithBattery,
    approvedCategoriesOnly,
    connectionDataDetails,
    supportedFitnessDevices,
    appleWatchViaHealth,
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
      'تم استيراد {count} سجل جديد خلال آخر مزامنة.',
      'تم العثور على {count} من أجهزة اللياقة.',
      'تم اقتران جهاز اللياقة، لكن فشلت مزامنة القياس ({code}).',
      'جهاز اللياقة متصل. لم يرسل الجهاز حالة البطارية. آخر مزامنة: {time}.',
      'جهاز اللياقة متصل. البطارية {percent}٪. آخر مزامنة: {time}.',
      'لا تُقرأ إلا فئات البيانات الصحية التي وافقت عليها. تبقى المزامنة محلية ويُحتفظ بالمصدر الأصلي لكل قيمة.',
      'ما الذي يقرأه كل اتصال',
      'المدعوم: موازين الوزن وأجهزة قياس تركيب الجسم وأجهزة مراقبة معدل نبض القلب.',
      'تصل بيانات Apple Watch عبر Apple Health. لا تقرن Apple Watch من هنا.',
    ],
    'en': sources,
    'fr': [
      '{count} nouveaux enregistrements ont été importés lors de la dernière synchronisation.',
      '{count} appareils de fitness trouvés.',
      'Appareil de fitness associé, mais la synchronisation des mesures a échoué ({code}).',
      'Appareil de fitness connecté. La batterie n’a pas été communiquée. Dernière synchronisation : {time}.',
      'Appareil de fitness connecté. Batterie {percent} %. Dernière synchronisation : {time}.',
      'Seules les catégories de santé autorisées sont lues. La synchronisation reste locale et conserve la source d’origine de chaque valeur.',
      'Ce que lit chaque connexion',
      'Pris en charge : balances, impédancemètres et cardiofréquencemètres.',
      'Les données de l’Apple Watch transitent par Apple Santé. Ne jumelez pas l’Apple Watch ici.',
    ],
    'es': [
      'Se importaron {count} registros nuevos durante la última sincronización.',
      'Se encontraron {count} dispositivos de fitness.',
      'El dispositivo de fitness se vinculó, pero falló la sincronización de mediciones ({code}).',
      'Dispositivo de fitness conectado. No se informó la batería. Última sincronización: {time}.',
      'Dispositivo de fitness conectado. Batería {percent} %. Última sincronización: {time}.',
      'Solo se leen las categorías de salud autorizadas. La sincronización permanece local y conserva la fuente original de cada valor.',
      'Qué lee cada conexión',
      'Compatibles: básculas, monitores de composición corporal y monitores de frecuencia cardíaca.',
      'Los datos del Apple Watch llegan a través de Salud de Apple. No enlaces el Apple Watch aquí.',
    ],
    'tr': [
      'Son eşitlemede {count} yeni kayıt içe aktarıldı.',
      '{count} fitness cihazı bulundu.',
      'Fitness cihazı eşleştirildi ancak ölçüm eşitlemesi başarısız oldu ({code}).',
      'Fitness cihazı bağlı. Pil bilgisi bildirilmedi. Son eşitleme: {time}.',
      'Fitness cihazı bağlı. Pil %{percent}. Son eşitleme: {time}.',
      'Yalnızca onayladığınız sağlık kategorileri okunur. Eşitleme cihazda kalır ve her değerin özgün kaynağını korur.',
      'Her bağlantının okuduğu veriler',
      'Desteklenenler: tartılar, vücut kompozisyonu ölçerler ve kalp atış hızı monitörleri.',
      'Apple Watch verileri Apple Health üzerinden gelir. Apple Watch’u burada eşleştirmeyin.',
    ],
    'de': [
      'Bei der letzten Synchronisierung wurden {count} neue Datensätze importiert.',
      '{count} Fitnessgeräte gefunden.',
      'Fitnessgerät gekoppelt, aber die Messwertsynchronisierung ist fehlgeschlagen ({code}).',
      'Fitnessgerät verbunden. Der Akkustand wurde nicht gemeldet. Letzte Synchronisierung: {time}.',
      'Fitnessgerät verbunden. Akku {percent} %. Letzte Synchronisierung: {time}.',
      'Es werden nur genehmigte Gesundheitskategorien gelesen. Die Synchronisierung erfolgt lokal und die ursprüngliche Quelle jedes Werts bleibt erhalten.',
      'Welche Daten die einzelnen Verbindungen lesen',
      'Unterstützt: Waagen, Körperanalysewaagen und Herzfrequenzmesser.',
      'Apple-Watch-Daten werden über Apple Health bereitgestellt. Koppeln Sie die Apple Watch nicht hier.',
    ],
    'it': [
      'Durante l’ultima sincronizzazione sono stati importati {count} nuovi record.',
      'Trovati {count} dispositivi fitness.',
      'Dispositivo fitness associato, ma la sincronizzazione delle misurazioni non è riuscita ({code}).',
      'Dispositivo fitness connesso. Batteria non comunicata. Ultima sincronizzazione: {time}.',
      'Dispositivo fitness connesso. Batteria {percent}%. Ultima sincronizzazione: {time}.',
      'Vengono lette solo le categorie di dati sanitari autorizzate. La sincronizzazione resta locale e conserva la fonte originale di ogni valore.',
      'Dati letti da ogni connessione',
      'Dispositivi supportati: bilance, monitor della composizione corporea e cardiofrequenzimetri.',
      'I dati di Apple Watch arrivano tramite Apple Salute. Non abbinare Apple Watch qui.',
    ],
    'pt-BR': [
      '{count} novos registros foram importados na última sincronização.',
      '{count} dispositivos fitness encontrados.',
      'Dispositivo fitness pareado, mas a sincronização das medições falhou ({code}).',
      'Dispositivo fitness conectado. A bateria não foi informada. Última sincronização: {time}.',
      'Dispositivo fitness conectado. Bateria {percent}%. Última sincronização: {time}.',
      'Somente as categorias de saúde autorizadas são lidas. A sincronização permanece local e mantém a fonte original de cada valor.',
      'O que cada conexão lê',
      'Compatíveis: balanças, monitores de composição corporal e monitores de frequência cardíaca.',
      'Os dados do Apple Watch chegam pelo app Saúde. Não emparelhe o Apple Watch aqui.',
    ],
    'pt-PT': [
      'Foram importados {count} novos registos na última sincronização.',
      'Foram encontrados {count} dispositivos de fitness.',
      'Dispositivo de fitness emparelhado, mas a sincronização das medições falhou ({code}).',
      'Dispositivo de fitness ligado. A bateria não foi comunicada. Última sincronização: {time}.',
      'Dispositivo de fitness ligado. Bateria {percent}%. Última sincronização: {time}.',
      'Só são lidas as categorias de saúde autorizadas. A sincronização permanece local e mantém a fonte original de cada valor.',
      'O que cada ligação lê',
      'Compatíveis: balanças, monitores de composição corporal e monitores de frequência cardíaca.',
      'Os dados do Apple Watch chegam através da app Saúde. Não emparelhe o Apple Watch aqui.',
    ],
    'ur': [
      'آخری ہم آہنگی میں {count} نئے ریکارڈ درآمد کیے گئے۔',
      '{count} فٹنس آلات ملے۔',
      'فٹنس آلہ جڑ گیا، لیکن پیمائش کی ہم آہنگی ناکام رہی ({code})۔',
      'فٹنس آلہ منسلک ہے۔ بیٹری کی اطلاع نہیں ملی۔ آخری ہم آہنگی: {time}۔',
      'فٹنس آلہ منسلک ہے۔ بیٹری {percent}٪۔ آخری ہم آہنگی: {time}۔',
      'صرف آپ کی منظور کردہ صحت کی اقسام پڑھی جاتی ہیں۔ ہم آہنگی آلے پر رہتی ہے اور ہر قدر کا اصل ماخذ محفوظ رکھتی ہے۔',
      'ہر کنکشن کیا پڑھتا ہے',
      'معاون آلات: وزن کے ترازو، جسمانی ساخت کے مانیٹر اور دل کی دھڑکن کے مانیٹر۔',
      'Apple Watch کا ڈیٹا Apple Health کے ذریعے آتا ہے۔ Apple Watch کو یہاں جوڑا نہ بنائیں۔',
    ],
    'fa': [
      'در آخرین همگام‌سازی {count} رکورد جدید وارد شد.',
      '{count} دستگاه تناسب اندام پیدا شد.',
      'دستگاه تناسب اندام جفت شد، اما همگام‌سازی اندازه‌گیری ناموفق بود ({code}).',
      'دستگاه تناسب اندام متصل است. وضعیت باتری ارسال نشد. آخرین همگام‌سازی: {time}.',
      'دستگاه تناسب اندام متصل است. باتری {percent}٪. آخرین همگام‌سازی: {time}.',
      'فقط دسته‌های سلامت تأییدشده خوانده می‌شوند. همگام‌سازی روی دستگاه می‌ماند و منبع اصلی هر مقدار را حفظ می‌کند.',
      'داده‌هایی که هر اتصال می‌خواند',
      'دستگاه‌های پشتیبانی‌شده: ترازو، نمایشگر ترکیب بدن و نمایشگر ضربان قلب.',
      'داده‌های Apple Watch از طریق Apple Health دریافت می‌شوند. Apple Watch را اینجا جفت نکنید.',
    ],
    'hi': [
      'पिछले सिंक में {count} नए रिकॉर्ड इंपोर्ट हुए।',
      '{count} फ़िटनेस डिवाइस मिले।',
      'फ़िटनेस डिवाइस पेयर हुआ, लेकिन माप सिंक नहीं हुआ ({code})।',
      'फ़िटनेस डिवाइस कनेक्टेड है। बैटरी की जानकारी नहीं मिली। पिछला सिंक: {time}।',
      'फ़िटनेस डिवाइस कनेक्टेड है। बैटरी {percent}%। पिछला सिंक: {time}।',
      'केवल आपकी स्वीकृत स्वास्थ्य श्रेणियाँ पढ़ी जाती हैं। सिंक डिवाइस पर रहता है और हर मान का मूल स्रोत सुरक्षित रखता है।',
      'हर कनेक्शन क्या पढ़ता है',
      'समर्थित: वज़न मापने वाली मशीनें, शरीर संरचना मॉनिटर और हृदय गति मॉनिटर।',
      'Apple Watch का डेटा Apple Health के ज़रिए आता है। Apple Watch को यहाँ पेयर न करें।',
    ],
    'id': [
      '{count} catatan baru diimpor saat sinkronisasi terakhir.',
      '{count} perangkat kebugaran ditemukan.',
      'Perangkat kebugaran tersambung, tetapi sinkronisasi pengukuran gagal ({code}).',
      'Perangkat kebugaran terhubung. Status baterai tidak dilaporkan. Sinkronisasi terakhir: {time}.',
      'Perangkat kebugaran terhubung. Baterai {percent}%. Sinkronisasi terakhir: {time}.',
      'Hanya kategori kesehatan yang Anda setujui yang dibaca. Sinkronisasi tetap berlangsung secara lokal dan mempertahankan sumber asli setiap nilai.',
      'Data yang dibaca tiap koneksi',
      'Didukung: timbangan, monitor komposisi tubuh, dan monitor detak jantung.',
      'Data Apple Watch masuk melalui Apple Health. Jangan pasangkan Apple Watch di sini.',
    ],
    'ms': [
      '{count} rekod baharu diimport semasa penyegerakan terakhir.',
      '{count} peranti kecergasan ditemui.',
      'Peranti kecergasan dipasangkan, tetapi penyegerakan ukuran gagal ({code}).',
      'Peranti kecergasan disambungkan. Bateri tidak dilaporkan. Penyegerakan terakhir: {time}.',
      'Peranti kecergasan disambungkan. Bateri {percent}%. Penyegerakan terakhir: {time}.',
      'Hanya kategori kesihatan yang anda luluskan dibaca. Penyegerakan kekal setempat dan mengekalkan sumber asal setiap nilai.',
      'Data yang dibaca oleh setiap sambungan',
      'Disokong: penimbang, monitor komposisi badan dan monitor kadar denyutan jantung.',
      'Data Apple Watch diterima melalui Apple Health. Jangan pasangkan Apple Watch di sini.',
    ],
    'ja': [
      '前回の同期で新しい記録 {count} 件を取り込みました。',
      'フィットネス機器が {count} 台見つかりました。',
      'フィットネス機器はペアリングされましたが、測定の同期に失敗しました（{code}）。',
      'フィットネス機器は接続済みです。バッテリー情報はありません。最終同期: {time}。',
      'フィットネス機器は接続済みです。バッテリー {percent}%。最終同期: {time}。',
      '許可したヘルスケア項目だけが読み取られます。同期は端末内で行われ、各値の元のデータソースが保持されます。',
      '各接続で読み取るデータ',
      '対応機器：体重計、体組成計、心拍数モニター。',
      'Apple Watch のデータは Apple ヘルスケア経由で取得します。ここでは Apple Watch をペアリングしないでください。',
    ],
    'ko': [
      '마지막 동기화에서 새 기록 {count}개를 가져왔습니다.',
      '피트니스 기기 {count}개를 찾았습니다.',
      '피트니스 기기가 페어링되었지만 측정값 동기화에 실패했습니다({code}).',
      '피트니스 기기가 연결되었습니다. 배터리 정보가 없습니다. 마지막 동기화: {time}.',
      '피트니스 기기가 연결되었습니다. 배터리 {percent}%. 마지막 동기화: {time}.',
      '승인한 건강 카테고리만 읽습니다. 동기화는 기기 내에서 이루어지며 각 값의 원래 출처가 유지됩니다.',
      '각 연결에서 읽는 데이터',
      '지원 기기: 체중계, 체성분 측정기, 심박수 모니터.',
      'Apple Watch 데이터는 Apple 건강을 통해 가져옵니다. 여기에서 Apple Watch를 페어링하지 마세요.',
    ],
    'zh-Hans': [
      '上次同步已导入 {count} 条新记录。',
      '找到 {count} 台健身设备。',
      '健身设备已配对，但测量同步失败（{code}）。',
      '健身设备已连接。设备未报告电量。上次同步：{time}。',
      '健身设备已连接。电量 {percent}%。上次同步：{time}。',
      '只会读取您批准的健康类别。同步在本机完成，并保留每项数值的原始来源。',
      '每种连接读取的数据',
      '支持：体重秤、身体成分监测仪和心率监测仪。',
      'Apple Watch 数据通过 Apple 健康获取。请勿在此处配对 Apple Watch。',
    ],
    'zh-Hant': [
      '上次同步已匯入 {count} 筆新記錄。',
      '找到 {count} 台健身裝置。',
      '健身裝置已配對，但測量同步失敗（{code}）。',
      '健身裝置已連線。裝置未回報電量。上次同步：{time}。',
      '健身裝置已連線。電量 {percent}%。上次同步：{time}。',
      '只會讀取您允許的健康類別。同步會在本機完成，並保留每項數值的原始來源。',
      '每種連線讀取的資料',
      '支援：體重計、身體組成監測器和心率監測器。',
      'Apple Watch 資料透過 Apple 健康取得。請勿在此處配對 Apple Watch。',
    ],
    'ru': [
      'При последней синхронизации импортировано новых записей: {count}.',
      'Найдено фитнес-устройств: {count}.',
      'Фитнес-устройство сопряжено, но синхронизация измерений не удалась ({code}).',
      'Фитнес-устройство подключено. Уровень заряда не сообщён. Последняя синхронизация: {time}.',
      'Фитнес-устройство подключено. Заряд {percent}%. Последняя синхронизация: {time}.',
      'Считываются только одобренные вами категории данных о здоровье. Синхронизация выполняется локально и сохраняет исходный источник каждого значения.',
      'Какие данные считывает каждое подключение',
      'Поддерживаются весы, анализаторы состава тела и пульсометры.',
      'Данные Apple Watch поступают через Apple Health. Не подключайте Apple Watch здесь.',
    ],
    'bn': [
      'শেষ সিঙ্কে {count}টি নতুন রেকর্ড ইমপোর্ট হয়েছে।',
      '{count}টি ফিটনেস ডিভাইস পাওয়া গেছে।',
      'ফিটনেস ডিভাইস পেয়ার হয়েছে, কিন্তু পরিমাপ সিঙ্ক ব্যর্থ ({code})।',
      'ফিটনেস ডিভাইস সংযুক্ত। ব্যাটারির তথ্য পাওয়া যায়নি। শেষ সিঙ্ক: {time}।',
      'ফিটনেস ডিভাইস সংযুক্ত। ব্যাটারি {percent}%। শেষ সিঙ্ক: {time}।',
      'শুধু আপনার অনুমোদিত স্বাস্থ্য বিভাগগুলো পড়া হয়। সিঙ্ক ডিভাইসেই থাকে এবং প্রতিটি মানের মূল উৎস সংরক্ষণ করে।',
      'প্রতিটি সংযোগ যে তথ্য পড়ে',
      'সমর্থিত: ওজন মাপার স্কেল, শরীরের গঠন মনিটর এবং হৃদস্পন্দন মনিটর।',
      'Apple Watch-এর ডেটা Apple Health-এর মাধ্যমে আসে। এখানে Apple Watch পেয়ার করবেন না।',
    ],
    'vi': [
      'Đã nhập {count} bản ghi mới trong lần đồng bộ gần nhất.',
      'Đã tìm thấy {count} thiết bị thể chất.',
      'Thiết bị thể chất đã ghép đôi, nhưng không thể đồng bộ số đo ({code}).',
      'Thiết bị thể chất đã kết nối. Thiết bị không báo pin. Lần đồng bộ gần nhất: {time}.',
      'Thiết bị thể chất đã kết nối. Pin {percent}%. Lần đồng bộ gần nhất: {time}.',
      'Chỉ các danh mục sức khỏe bạn phê duyệt mới được đọc. Quá trình đồng bộ diễn ra cục bộ và giữ nguyên nguồn gốc của từng giá trị.',
      'Dữ liệu mà từng kết nối đọc',
      'Được hỗ trợ: cân, thiết bị đo thành phần cơ thể và thiết bị theo dõi nhịp tim.',
      'Dữ liệu Apple Watch được lấy qua Apple Health. Không ghép đôi Apple Watch tại đây.',
    ],
    'th': [
      'นำเข้าระเบียนใหม่ {count} รายการในการซิงค์ล่าสุดแล้ว',
      'พบอุปกรณ์ฟิตเนส {count} เครื่อง',
      'จับคู่อุปกรณ์ฟิตเนสแล้ว แต่ซิงค์ค่าที่วัดไม่สำเร็จ ({code})',
      'เชื่อมต่ออุปกรณ์ฟิตเนสแล้ว ไม่มีข้อมูลแบตเตอรี่ ซิงค์ล่าสุด: {time}',
      'เชื่อมต่ออุปกรณ์ฟิตเนสแล้ว แบตเตอรี่ {percent}% ซิงค์ล่าสุด: {time}',
      'ระบบจะอ่านเฉพาะหมวดหมู่สุขภาพที่คุณอนุญาต การซิงค์จะอยู่ภายในอุปกรณ์และเก็บแหล่งที่มาเดิมของแต่ละค่าไว้',
      'ข้อมูลที่แต่ละการเชื่อมต่ออ่าน',
      'รองรับ: เครื่องชั่ง เครื่องวัดองค์ประกอบร่างกาย และเครื่องวัดอัตราการเต้นของหัวใจ',
      'ข้อมูล Apple Watch มาจาก Apple Health โปรดอย่าจับคู่ Apple Watch ที่นี่',
    ],
    'pl': [
      'Podczas ostatniej synchronizacji zaimportowano {count} nowych rekordów.',
      'Znaleziono {count} urządzeń fitness.',
      'Urządzenie fitness sparowano, ale synchronizacja pomiarów nie powiodła się ({code}).',
      'Urządzenie fitness jest połączone. Nie zgłoszono stanu baterii. Ostatnia synchronizacja: {time}.',
      'Urządzenie fitness jest połączone. Bateria {percent}%. Ostatnia synchronizacja: {time}.',
      'Odczytywane są tylko zatwierdzone przez Ciebie kategorie zdrowotne. Synchronizacja odbywa się lokalnie i zachowuje pierwotne źródło każdej wartości.',
      'Dane odczytywane przez każde połączenie',
      'Obsługiwane: wagi, analizatory składu ciała i monitory tętna.',
      'Dane z Apple Watch są pobierane przez Apple Health. Nie paruj tutaj zegarka Apple Watch.',
    ],
    'nl': [
      'Bij de laatste synchronisatie zijn {count} nieuwe records geïmporteerd.',
      '{count} fitnessapparaten gevonden.',
      'Fitnessapparaat gekoppeld, maar het synchroniseren van metingen is mislukt ({code}).',
      'Fitnessapparaat verbonden. Batterijstatus niet gemeld. Laatste synchronisatie: {time}.',
      'Fitnessapparaat verbonden. Batterij {percent}%. Laatste synchronisatie: {time}.',
      'Alleen de door jou goedgekeurde gezondheidscategorieën worden gelezen. De synchronisatie blijft lokaal en bewaart de oorspronkelijke bron van elke waarde.',
      'Wat elke verbinding leest',
      'Ondersteund: weegschalen, lichaamscompositiemeters en hartslagmeters.',
      'Apple Watch-gegevens worden via Apple Gezondheid opgehaald. Koppel de Apple Watch hier niet.',
    ],
    'uk': [
      'Під час останньої синхронізації імпортовано {count} нових записів.',
      'Знайдено фітнес-пристроїв: {count}.',
      'Фітнес-пристрій спаровано, але синхронізація вимірювань не вдалася ({code}).',
      'Фітнес-пристрій підключено. Рівень заряду не повідомлено. Остання синхронізація: {time}.',
      'Фітнес-пристрій підключено. Заряд {percent}%. Остання синхронізація: {time}.',
      'Зчитуються лише схвалені вами категорії даних про здоров’я. Синхронізація виконується локально та зберігає початкове джерело кожного значення.',
      'Які дані зчитує кожне підключення',
      'Підтримуються ваги, аналізатори складу тіла та пульсометри.',
      'Дані Apple Watch надходять через Apple Health. Не підключайте Apple Watch тут.',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing connected-health runtime copy for $tag.');
    }
    return row[index];
  }

  static String format(
    BuildContext context,
    String source, {
    String? count,
    String? code,
    String? time,
    String? percent,
  }) {
    final tag = BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
    return formatForTag(
      tag,
      source,
      count: count,
      code: code,
      time: time,
      percent: percent,
    );
  }

  static String formatForTag(
    String localeTag,
    String source, {
    String? count,
    String? code,
    String? time,
    String? percent,
  }) {
    var value = resolve(source, localeTag) ?? source;
    if (count != null) value = value.replaceAll('{count}', count);
    if (code != null) value = value.replaceAll('{code}', code);
    if (time != null) value = value.replaceAll('{time}', time);
    if (percent != null) value = value.replaceAll('{percent}', percent);
    return value;
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
