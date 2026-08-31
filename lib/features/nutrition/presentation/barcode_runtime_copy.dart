import '../../../app/localization/runtime_copy.dart';
import '../../../app/localization/bil_locale_policy.dart';

/// Reviewed, upload-safe copy for barcode image selection and analysis.
///
/// Production locales are exact rows; a missing row fails closed instead of
/// silently showing English in a released locale.
final class BarcodeImageRuntimeCopy {
  const BarcodeImageRuntimeCopy({
    required this.noBarcodeFound,
    required this.imageUnreadable,
    required this.chooseImage,
  });

  final String noBarcodeFound;
  final String imageUnreadable;
  final String chooseImage;

  static BarcodeImageRuntimeCopy of(String localeTag) {
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return _all['en']!;
    return _all[tag] ??
        (throw StateError('Missing barcode image copy for $tag.'));
  }

  static Set<String> get supportedTags => _all.keys.toSet();

  static const _all = <String, BarcodeImageRuntimeCopy>{
    'ar': BarcodeImageRuntimeCopy(
      noBarcodeFound: 'لم يتم العثور على باركود في الصورة. اختر صورة أوضح.',
      imageUnreadable: 'تعذرت قراءة صورة الباركود. لم يتم رفع أي شيء.',
      chooseImage: 'اختيار صورة باركود',
    ),
    'en': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'No barcode was found in this image. Choose a clearer photo.',
      imageUnreadable:
          'This barcode image could not be read. Nothing was uploaded.',
      chooseImage: 'Choose barcode image',
    ),
    'fr': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'Aucun code-barres n’a été trouvé dans cette image. Choisissez une photo plus nette.',
      imageUnreadable:
          'Impossible de lire l’image du code-barres. Rien n’a été envoyé.',
      chooseImage: 'Choisir une image de code-barres',
    ),
    'es': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'No se encontró ningún código de barras en esta imagen. Elige una foto más clara.',
      imageUnreadable:
          'No se pudo leer la imagen del código de barras. No se subió nada.',
      chooseImage: 'Elegir imagen del código de barras',
    ),
    'tr': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'Bu görüntüde barkod bulunamadı. Daha net bir fotoğraf seçin.',
      imageUnreadable: 'Barkod görüntüsü okunamadı. Hiçbir şey yüklenmedi.',
      chooseImage: 'Barkod görüntüsü seç',
    ),
    'de': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'In diesem Bild wurde kein Barcode gefunden. Wähle ein deutlicheres Foto.',
      imageUnreadable:
          'Dieses Barcodebild konnte nicht gelesen werden. Es wurde nichts hochgeladen.',
      chooseImage: 'Barcodebild auswählen',
    ),
    'it': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'Nessun codice a barre trovato in questa immagine. Scegli una foto più nitida.',
      imageUnreadable:
          'Impossibile leggere l’immagine del codice a barre. Non è stato caricato nulla.',
      chooseImage: 'Scegli immagine del codice a barre',
    ),
    'pt-BR': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'Nenhum código de barras foi encontrado nesta imagem. Escolha uma foto mais nítida.',
      imageUnreadable:
          'Não foi possível ler a imagem do código de barras. Nada foi enviado.',
      chooseImage: 'Escolher imagem do código de barras',
    ),
    'pt-PT': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'Não foi encontrado nenhum código de barras nesta imagem. Escolha uma fotografia mais nítida.',
      imageUnreadable:
          'Não foi possível ler a imagem do código de barras. Nada foi carregado.',
      chooseImage: 'Escolher imagem do código de barras',
    ),
    'ur': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'اس تصویر میں کوئی بار کوڈ نہیں ملا۔ زیادہ واضح تصویر منتخب کریں۔',
      imageUnreadable:
          'بار کوڈ کی یہ تصویر پڑھی نہیں جا سکی۔ کچھ بھی اپ لوڈ نہیں ہوا۔',
      chooseImage: 'بار کوڈ کی تصویر منتخب کریں',
    ),
    'fa': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'هیچ بارکدی در این تصویر پیدا نشد. عکس واضح‌تری انتخاب کنید.',
      imageUnreadable: 'این تصویر بارکد قابل خواندن نبود. چیزی بارگذاری نشد.',
      chooseImage: 'انتخاب تصویر بارکد',
    ),
    'hi': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'इस तस्वीर में कोई बारकोड नहीं मिला। अधिक साफ़ तस्वीर चुनें।',
      imageUnreadable:
          'यह बारकोड तस्वीर पढ़ी नहीं जा सकी। कुछ भी अपलोड नहीं हुआ।',
      chooseImage: 'बारकोड की तस्वीर चुनें',
    ),
    'id': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'Tidak ada kode batang yang ditemukan pada gambar ini. Pilih foto yang lebih jelas.',
      imageUnreadable:
          'Gambar kode batang ini tidak dapat dibaca. Tidak ada yang diunggah.',
      chooseImage: 'Pilih gambar kode batang',
    ),
    'ms': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'Tiada kod bar ditemui dalam imej ini. Pilih foto yang lebih jelas.',
      imageUnreadable:
          'Imej kod bar ini tidak dapat dibaca. Tiada apa-apa dimuat naik.',
      chooseImage: 'Pilih imej kod bar',
    ),
    'ja': BarcodeImageRuntimeCopy(
      noBarcodeFound: 'この画像にバーコードが見つかりません。より鮮明な写真を選択してください。',
      imageUnreadable: 'このバーコード画像を読み取れませんでした。何もアップロードされていません。',
      chooseImage: 'バーコード画像を選択',
    ),
    'ko': BarcodeImageRuntimeCopy(
      noBarcodeFound: '이 이미지에서 바코드를 찾지 못했습니다. 더 선명한 사진을 선택하세요.',
      imageUnreadable: '이 바코드 이미지를 읽을 수 없습니다. 업로드된 항목은 없습니다.',
      chooseImage: '바코드 이미지 선택',
    ),
    'zh-Hans': BarcodeImageRuntimeCopy(
      noBarcodeFound: '此图片中未找到条形码。请选择更清晰的照片。',
      imageUnreadable: '无法读取此条形码图片。未上传任何内容。',
      chooseImage: '选择条形码图片',
    ),
    'zh-Hant': BarcodeImageRuntimeCopy(
      noBarcodeFound: '此圖片中找不到條碼。請選擇更清晰的照片。',
      imageUnreadable: '無法讀取此條碼圖片。未上傳任何內容。',
      chooseImage: '選擇條碼圖片',
    ),
    'ru': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'Штрихкод на этом изображении не найден. Выберите более чёткое фото.',
      imageUnreadable:
          'Не удалось прочитать изображение штрихкода. Ничего не было отправлено.',
      chooseImage: 'Выбрать изображение штрихкода',
    ),
    'bn': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'এই ছবিতে কোনো বারকোড পাওয়া যায়নি। আরও স্পষ্ট ছবি বেছে নিন।',
      imageUnreadable: 'এই বারকোডের ছবিটি পড়া যায়নি। কিছুই আপলোড করা হয়নি।',
      chooseImage: 'বারকোডের ছবি বেছে নিন',
    ),
    'vi': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'Không tìm thấy mã vạch trong ảnh này. Hãy chọn ảnh rõ hơn.',
      imageUnreadable:
          'Không thể đọc ảnh mã vạch này. Không có nội dung nào được tải lên.',
      chooseImage: 'Chọn ảnh mã vạch',
    ),
    'th': BarcodeImageRuntimeCopy(
      noBarcodeFound: 'ไม่พบบาร์โค้ดในภาพนี้ โปรดเลือกรูปที่ชัดเจนกว่า',
      imageUnreadable: 'ไม่สามารถอ่านภาพบาร์โค้ดนี้ได้ ไม่มีการอัปโหลดข้อมูลใด',
      chooseImage: 'เลือกรูปบาร์โค้ด',
    ),
    'pl': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'Na tym obrazie nie znaleziono kodu kreskowego. Wybierz wyraźniejsze zdjęcie.',
      imageUnreadable:
          'Nie udało się odczytać obrazu kodu kreskowego. Nic nie zostało przesłane.',
      chooseImage: 'Wybierz obraz kodu kreskowego',
    ),
    'nl': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'In deze afbeelding is geen barcode gevonden. Kies een duidelijkere foto.',
      imageUnreadable:
          'Deze barcodeafbeelding kon niet worden gelezen. Er is niets geüpload.',
      chooseImage: 'Barcodeafbeelding kiezen',
    ),
    'uk': BarcodeImageRuntimeCopy(
      noBarcodeFound:
          'На цьому зображенні не знайдено штрихкод. Виберіть чіткіше фото.',
      imageUnreadable:
          'Не вдалося прочитати зображення штрихкоду. Нічого не було завантажено.',
      chooseImage: 'Вибрати зображення штрихкоду',
    ),
  };
}

class BarcodeRuntimeCopy {
  const BarcodeRuntimeCopy({
    required this.invalidTitle,
    required this.invalidBody,
    required this.notFoundTitle,
    required this.notFoundBody,
    required this.unavailableTitle,
    required this.unavailableBody,
  });

  final String invalidTitle, invalidBody, notFoundTitle, notFoundBody;
  final String unavailableTitle, unavailableBody;

  static BarcodeRuntimeCopy of(String localeTag) {
    final languageCode = localeTag.split(RegExp('[-_]')).first.toLowerCase();
    final authored = _all[languageCode];
    if (authored != null) return authored;
    final english = _all['en']!;
    String translated(String source) =>
        RuntimeCopy.resolve(source, localeTag) ?? source;
    return BarcodeRuntimeCopy(
      invalidTitle: translated(english.invalidTitle),
      invalidBody: translated(english.invalidBody),
      notFoundTitle: translated(english.notFoundTitle),
      notFoundBody: translated(english.notFoundBody),
      unavailableTitle: translated(english.unavailableTitle),
      unavailableBody: translated(english.unavailableBody),
    );
  }

  static const _all = <String, BarcodeRuntimeCopy>{
    'en': BarcodeRuntimeCopy(
      invalidTitle: 'Invalid barcode',
      invalidBody:
          'Enter a valid GTIN-8, UPC-A, EAN-13, or GTIN-14, including its check digit.',
      notFoundTitle: 'Barcode not found',
      notFoundBody: 'No trusted food record matched this barcode.',
      unavailableTitle: 'Catalog unavailable',
      unavailableBody:
          'Trusted catalogs are unavailable. BIL will not invent nutrition values.',
    ),
    'ar': BarcodeRuntimeCopy(
      invalidTitle: 'رمز غير صالح',
      invalidBody:
          'أدخل GTIN-8 أو UPC-A أو EAN-13 أو GTIN-14 صالحًا مع رقم التحقق.',
      notFoundTitle: 'لم يُعثر على الرمز',
      notFoundBody: 'لا يوجد سجل طعام موثوق يطابق هذا الرمز.',
      unavailableTitle: 'دليل الأطعمة غير متاح',
      unavailableBody:
          'الأدلة الموثوقة غير متاحة. لن يخمّن BIL القيم الغذائية.',
    ),
    'fr': BarcodeRuntimeCopy(
      invalidTitle: 'Code-barres invalide',
      invalidBody:
          'Saisissez un GTIN-8, UPC-A, EAN-13 ou GTIN-14 valide avec son chiffre de contrôle.',
      notFoundTitle: 'Code-barres introuvable',
      notFoundBody: 'Aucun aliment fiable ne correspond à ce code-barres.',
      unavailableTitle: 'Catalogue indisponible',
      unavailableBody:
          'Les catalogues fiables sont indisponibles. BIL n’inventera aucune valeur nutritionnelle.',
    ),
    'es': BarcodeRuntimeCopy(
      invalidTitle: 'Código de barras no válido',
      invalidBody:
          'Introduce un GTIN-8, UPC-A, EAN-13 o GTIN-14 válido con su dígito de control.',
      notFoundTitle: 'Código no encontrado',
      notFoundBody: 'Ningún alimento fiable coincide con este código.',
      unavailableTitle: 'Catálogo no disponible',
      unavailableBody:
          'Los catálogos fiables no están disponibles. BIL no inventará valores nutricionales.',
    ),
    'tr': BarcodeRuntimeCopy(
      invalidTitle: 'Geçersiz barkod',
      invalidBody:
          'Kontrol basamağıyla birlikte geçerli bir GTIN-8, UPC-A, EAN-13 veya GTIN-14 girin.',
      notFoundTitle: 'Barkod bulunamadı',
      notFoundBody: 'Bu barkodla eşleşen güvenilir bir yiyecek kaydı yok.',
      unavailableTitle: 'Katalog kullanılamıyor',
      unavailableBody:
          'Güvenilir kataloglar kullanılamıyor. BIL besin değerlerini uydurmaz.',
    ),
  };
}
