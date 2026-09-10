import 'package:flutter/material.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../connected_health_copy.dart';

/// A permission decision cannot be reopened by repeating requestAuthorization.
/// Use public system settings only; never undocumented Health privacy URLs.
Future<void> showAppleHealthPermissionReview(
  BuildContext context, {
  required Future<void> Function() onOpenSettings,
}) async {
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('apple-health-permission-review'),
      title: const Text('Apple Health'),
      content: SingleChildScrollView(
        child: Text(
          appleHealthPermissionReviewText(Localizations.localeOf(context)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(MaterialLocalizations.of(dialogContext).closeButtonLabel),
        ),
        TextButton(
          key: const Key('apple-health-open-settings'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            connectedHealthText(
              context,
              'Open system settings',
              'فتح إعدادات النظام',
            ),
          ),
        ),
      ],
    ),
  );
  if (openSettings == true && context.mounted) await onOpenSettings();
}

String appleHealthPermissionReviewText(Locale locale) =>
    appleHealthPermissionReviewCopy[BilLocalePolicy.canonicalTag(locale)] ??
    appleHealthPermissionReviewCopy['en']!;

const appleHealthPermissionReviewCopy = <String, String>{
  'en':
      'To change BIL access, open Health, tap your profile, then Apps and Services (or Apps), and select Body Intelligence Log. Review each data type there. iOS does not tell BIL which read permissions you allowed.',
  'ar':
      'لتغيير أذونات BIL، افتح تطبيق «الصحة»، ثم ملفك الشخصي، ثم «التطبيقات والخدمات» (أو «التطبيقات»)، واختر Body Intelligence Log. راجع إذن كل نوع من البيانات هناك. لا يُطلع iOS تطبيق BIL على أذونات القراءة التي سمحت بها.',
  'fr':
      'Pour modifier les accès de BIL, ouvrez Santé, votre profil, puis Apps et services (ou Apps), et sélectionnez Body Intelligence Log. Vérifiez chaque type de données. iOS ne communique pas à BIL les autorisations de lecture accordées.',
  'es':
      'Para cambiar los permisos de BIL, abre Salud, toca tu perfil, entra en Apps y servicios (o Apps) y selecciona Body Intelligence Log. Revisa cada tipo de dato. iOS no informa a BIL de los permisos de lectura concedidos.',
  'tr':
      'BIL erişimini değiştirmek için Sağlık uygulamasını, profilinizi, ardından Uygulamalar ve Servisler (veya Uygulamalar) bölümünü açıp Body Intelligence Log seçin. Her veri türünü inceleyin. iOS, izin verdiğiniz okuma erişimlerini BIL ile paylaşmaz.',
  'de':
      'Öffne Health, dein Profil und dann Apps und Dienste (oder Apps). Wähle Body Intelligence Log und prüfe die einzelnen Datentypen. iOS teilt BIL nicht mit, welche Leseberechtigungen du erteilt hast.',
  'it':
      'Per modificare gli accessi di BIL, apri Salute, il tuo profilo, poi App e servizi (o App) e seleziona Body Intelligence Log. Controlla ogni tipo di dato. iOS non comunica a BIL quali permessi di lettura hai concesso.',
  'pt-BR':
      'Para alterar o acesso do BIL, abra Saúde, seu perfil, depois Apps e Serviços (ou Apps) e selecione Body Intelligence Log. Revise cada tipo de dado. O iOS não informa ao BIL quais permissões de leitura você concedeu.',
  'pt-PT':
      'Para alterar o acesso do BIL, abra Saúde, o seu perfil, depois Aplicações e serviços (ou Aplicações) e selecione Body Intelligence Log. Reveja cada tipo de dados. O iOS não comunica ao BIL as permissões de leitura concedidas.',
  'ur':
      'BIL کی رسائی بدلنے کے لیے صحت ایپ، اپنا پروفائل، پھر ایپس اور سروسز (یا ایپس) کھولیں اور Body Intelligence Log منتخب کریں۔ ہر قسم کے ڈیٹا کی اجازت دیکھیں۔ iOS، BIL کو نہیں بتاتا کہ آپ نے پڑھنے کی کون سی اجازتیں دی ہیں۔',
  'fa':
      'برای تغییر دسترسی BIL، برنامه سلامت، نمایه خود و سپس برنامه‌ها و خدمات (یا برنامه‌ها) را باز کنید و Body Intelligence Log را انتخاب کنید. مجوز هر نوع داده را بررسی کنید. iOS مجوزهای خواندن داده را به BIL اعلام نمی‌کند.',
  'hi':
      'BIL की पहुँच बदलने के लिए स्वास्थ्य ऐप, अपनी प्रोफ़ाइल, फिर ऐप्स और सेवाएँ (या ऐप्स) खोलें और Body Intelligence Log चुनें। हर डेटा प्रकार की अनुमति देखें। iOS, BIL को नहीं बताता कि आपने पढ़ने की कौन-सी अनुमतियाँ दी हैं।',
  'id':
      'Untuk mengubah akses BIL, buka Kesehatan, profil Anda, lalu App dan Layanan (atau App), dan pilih Body Intelligence Log. Tinjau setiap jenis data. iOS tidak memberi tahu BIL izin baca yang Anda berikan.',
  'ms':
      'Untuk mengubah akses BIL, buka Kesihatan, profil anda, kemudian App dan Perkhidmatan (atau App), dan pilih Body Intelligence Log. Semak setiap jenis data. iOS tidak memberitahu BIL kebenaran membaca yang anda berikan.',
  'ja':
      'BILのアクセスを変更するには、ヘルスケアでプロフィールを開き、「アプリとサービス」（または「アプリ」）からBody Intelligence Logを選択してください。各データの権限を確認できます。iOSは許可した読み取り権限をBILに通知しません。',
  'ko':
      'BIL 접근 권한을 변경하려면 건강 앱에서 프로필을 누르고 앱 및 서비스(또는 앱)에서 Body Intelligence Log를 선택하세요. 각 데이터 유형의 권한을 확인하세요. iOS는 허용한 읽기 권한을 BIL에 알려주지 않습니다.',
  'zh-Hans':
      '要更改 BIL 的访问权限，请打开“健康”，轻点个人资料，再打开“App 与服务”（或“App”），选择 Body Intelligence Log。请逐项检查数据权限。iOS 不会告知 BIL 您允许了哪些读取权限。',
  'zh-Hant':
      '若要更改 BIL 的存取權限，請開啟「健康」，點選個人檔案，再開啟「App 與服務」（或「App」），選擇 Body Intelligence Log。請逐項檢查資料權限。iOS 不會告知 BIL 您允許了哪些讀取權限。',
  'ru':
      'Чтобы изменить доступ BIL, откройте «Здоровье», свой профиль, затем «Приложения и службы» (или «Приложения») и выберите Body Intelligence Log. Проверьте каждый тип данных. iOS не сообщает BIL, какие разрешения на чтение вы дали.',
  'bn':
      'BIL-এর অনুমতি বদলাতে স্বাস্থ্য অ্যাপ, আপনার প্রোফাইল, তারপর অ্যাপ ও পরিষেবা (বা অ্যাপ) খুলে Body Intelligence Log বেছে নিন। প্রতিটি ডেটার অনুমতি দেখুন। iOS, BIL-কে জানায় না আপনি কোন পড়ার অনুমতি দিয়েছেন।',
  'vi':
      'Để thay đổi quyền của BIL, mở Sức khỏe, hồ sơ của bạn, rồi Ứng dụng và dịch vụ (hoặc Ứng dụng), chọn Body Intelligence Log. Kiểm tra từng loại dữ liệu. iOS không cho BIL biết bạn đã cho phép những quyền đọc nào.',
  'th':
      'หากต้องการเปลี่ยนสิทธิ์ BIL ให้เปิดแอปสุขภาพ แตะโปรไฟล์ จากนั้นเลือกแอปและบริการ (หรือแอป) แล้วเลือก Body Intelligence Log ตรวจสอบสิทธิ์ของข้อมูลแต่ละประเภท iOS จะไม่แจ้ง BIL ว่าคุณอนุญาตสิทธิ์อ่านใดบ้าง',
  'pl':
      'Aby zmienić dostęp BIL, otwórz Zdrowie, swój profil, następnie Aplikacje i usługi (lub Aplikacje) i wybierz Body Intelligence Log. Sprawdź każdy typ danych. iOS nie informuje BIL, jakich uprawnień do odczytu udzielono.',
  'nl':
      'Open Gezondheid, je profiel en daarna Apps en diensten (of Apps). Kies Body Intelligence Log en controleer elk gegevenstype. iOS vertelt BIL niet welke leestoegang je hebt toegestaan.',
  'uk':
      'Щоб змінити доступ BIL, відкрийте «Здоров’я», свій профіль, потім «Програми та служби» (або «Програми») і виберіть Body Intelligence Log. Перевірте кожен тип даних. iOS не повідомляє BIL, які дозволи на читання ви надали.',
};
