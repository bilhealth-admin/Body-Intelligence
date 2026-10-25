import 'bil_locale_policy.dart';

/// Owner-safe My Plan recovery guidance for all 25 production locales.
///
/// Keep recovery semantics intact: an unverified retained plan is read-only;
/// do not imply a fresh successful read or that an account switch is safe.
abstract final class SmartPlanRecoveryRuntimeCopy {
  static const sources = <String>[
    "Sign in to access your saved plan. No plan data has been deleted.",
    "The active account changed. Reopen My Plan to view the correct account.",
    "The saved plan data could not be opened safely. Review the issue before changing your plan.",
    "Your plan is saved, but its supporting information could not be checked. Retry before editing it.",
    "Your previous plan is shown read-only until its data can be verified. Retry to restore full access.",
    "Your saved plan could not be read from this device. Retry; an existing plan has not been overwritten.",
  ];
  static const rows = <String, List<String>>{
    "ar": <String>[
      "سجّل الدخول لعرض خطتك المحفوظة. لم تُحذف أي بيانات من الخطة.",
      "تغيّر الحساب النشط. افتح خطتي مجددًا لعرض بيانات الحساب الصحيح.",
      "تعذّر فتح بيانات الخطة المحفوظة بأمان. راجع المشكلة قبل تعديل خطتك.",
      "خطتك محفوظة، لكن تعذّر التحقق من بياناتها المساندة. أعد المحاولة قبل تعديلها.",
      "تظهر خطتك السابقة للقراءة فقط حتى التحقق من بياناتها. أعد المحاولة لاستعادة الوصول الكامل.",
      "تعذّرت قراءة خطتك المحفوظة من هذا الجهاز. أعد المحاولة؛ لم تُستبدل الخطة الموجودة.",
    ],
    "en": <String>[
      "Sign in to access your saved plan. No plan data has been deleted.",
      "The active account changed. Reopen My Plan to view the correct account.",
      "The saved plan data could not be opened safely. Review the issue before changing your plan.",
      "Your plan is saved, but its supporting information could not be checked. Retry before editing it.",
      "Your previous plan is shown read-only until its data can be verified. Retry to restore full access.",
      "Your saved plan could not be read from this device. Retry; an existing plan has not been overwritten.",
    ],
    "fr": <String>[
      "Connectez-vous pour accéder à votre plan enregistré. Aucune donnée du plan n’a été supprimée.",
      "Le compte actif a changé. Rouvrez Mon plan pour afficher le bon compte.",
      "Impossible d’ouvrir les données du plan enregistré en toute sécurité. Examinez le problème avant de modifier votre plan.",
      "Votre plan est enregistré, mais ses données complémentaires n’ont pas pu être vérifiées. Réessayez avant de le modifier.",
      "Votre ancien plan est en lecture seule jusqu’à vérification de ses données. Réessayez pour retrouver l’accès complet.",
      "Impossible de lire votre plan enregistré sur cet appareil. Réessayez ; aucun plan existant n’a été remplacé.",
    ],
    "es": <String>[
      "Inicia sesión para acceder a tu plan guardado. No se ha eliminado ningún dato del plan.",
      "La cuenta activa ha cambiado. Vuelve a abrir Mi plan para ver la cuenta correcta.",
      "No se pudieron abrir de forma segura los datos del plan guardado. Revisa el problema antes de modificarlo.",
      "Tu plan está guardado, pero no se pudo verificar su información de apoyo. Vuelve a intentarlo antes de editarlo.",
      "Tu plan anterior se muestra en modo de solo lectura hasta verificar sus datos. Reinténtalo para recuperar el acceso completo.",
      "No se pudo leer tu plan guardado en este dispositivo. Vuelve a intentarlo; no se ha reemplazado ningún plan existente.",
    ],
    "tr": <String>[
      "Kayıtlı planınıza erişmek için giriş yapın. Hiçbir plan verisi silinmedi.",
      "Etkin hesap değişti. Doğru hesabı görmek için Planım'ı yeniden açın.",
      "Kayıtlı plan verileri güvenli biçimde açılamadı. Planınızı değiştirmeden önce sorunu inceleyin.",
      "Planınız kayıtlı, ancak destekleyici bilgiler doğrulanamadı. Düzenlemeden önce yeniden deneyin.",
      "Önceki planınız, verileri doğrulanana kadar salt okunur gösterilir. Tam erişim için yeniden deneyin.",
      "Kayıtlı planınız bu cihazdan okunamadı. Yeniden deneyin; mevcut planın üzerine yazılmadı.",
    ],
    "de": <String>[
      "Melden Sie sich an, um auf Ihren gespeicherten Plan zuzugreifen. Es wurden keine Plandaten gelöscht.",
      "Das aktive Konto hat sich geändert. Öffnen Sie Mein Plan erneut, um das richtige Konto zu sehen.",
      "Die gespeicherten Plandaten konnten nicht sicher geöffnet werden. Prüfen Sie das Problem, bevor Sie den Plan ändern.",
      "Ihr Plan ist gespeichert, aber die zugehörigen Informationen konnten nicht geprüft werden. Versuchen Sie es vor der Bearbeitung erneut.",
      "Ihr vorheriger Plan wird bis zur Datenprüfung schreibgeschützt angezeigt. Versuchen Sie es erneut, um vollen Zugriff zu erhalten.",
      "Ihr gespeicherter Plan konnte auf diesem Gerät nicht gelesen werden. Versuchen Sie es erneut; ein bestehender Plan wurde nicht überschrieben.",
    ],
    "it": <String>[
      "Accedi per visualizzare il piano salvato. Nessun dato del piano è stato eliminato.",
      "L'account attivo è cambiato. Riapri Il mio piano per visualizzare l'account corretto.",
      "Impossibile aprire in sicurezza i dati del piano salvato. Verifica il problema prima di modificarlo.",
      "Il piano è salvato, ma non è stato possibile verificare le informazioni di supporto. Riprova prima di modificarlo.",
      "Il piano precedente è disponibile in sola lettura finché i dati non saranno verificati. Riprova per ripristinare l'accesso completo.",
      "Impossibile leggere il piano salvato su questo dispositivo. Riprova; nessun piano esistente è stato sovrascritto.",
    ],
    "pt-BR": <String>[
      "Entre na sua conta para acessar seu plano salvo. Nenhum dado do plano foi excluído.",
      "A conta ativa mudou. Abra Meu plano novamente para ver a conta correta.",
      "Não foi possível abrir com segurança os dados do plano salvo. Verifique o problema antes de alterar seu plano.",
      "Seu plano está salvo, mas não foi possível verificar as informações de apoio. Tente novamente antes de editá-lo.",
      "Seu plano anterior aparece somente para leitura até que os dados sejam verificados. Tente novamente para recuperar o acesso completo.",
      "Não foi possível ler seu plano salvo neste dispositivo. Tente novamente; nenhum plano existente foi substituído.",
    ],
    "pt-PT": <String>[
      "Inicie sessão para aceder ao seu plano guardado. Não foram eliminados dados do plano.",
      "A conta ativa mudou. Reabra O meu plano para ver a conta correta.",
      "Não foi possível abrir em segurança os dados do plano guardado. Analise o problema antes de alterar o plano.",
      "O plano está guardado, mas não foi possível verificar as informações de apoio. Tente novamente antes de o editar.",
      "O plano anterior é apresentado apenas para leitura até os dados serem verificados. Tente novamente para recuperar o acesso total.",
      "Não foi possível ler o plano guardado neste dispositivo. Tente novamente; nenhum plano existente foi substituído.",
    ],
    "ur": <String>[
      "محفوظ شدہ پلان دیکھنے کے لیے سائن اِن کریں۔ پلان کا کوئی ڈیٹا حذف نہیں ہوا۔",
      "فعال اکاؤنٹ بدل گیا ہے۔ درست اکاؤنٹ دیکھنے کے لیے میرا پلان دوبارہ کھولیں۔",
      "محفوظ پلان کا ڈیٹا محفوظ طریقے سے نہیں کھل سکا۔ پلان بدلنے سے پہلے مسئلہ دیکھیں۔",
      "آپ کا پلان محفوظ ہے، مگر متعلقہ معلومات کی تصدیق نہیں ہو سکی۔ ترمیم سے پہلے دوبارہ کوشش کریں۔",
      "پچھلا پلان ڈیٹا کی تصدیق تک صرف پڑھنے کے لیے دکھایا جاتا ہے۔ مکمل رسائی کے لیے دوبارہ کوشش کریں۔",
      "اس ڈیوائس پر محفوظ پلان پڑھا نہیں جا سکا۔ دوبارہ کوشش کریں؛ موجودہ پلان تبدیل نہیں کیا گیا۔",
    ],
    "fa": <String>[
      "برای دسترسی به برنامه ذخیره‌شده وارد شوید. هیچ داده‌ای از برنامه حذف نشده است.",
      "حساب فعال تغییر کرده است. برای دیدن حساب درست، «برنامه من» را دوباره باز کنید.",
      "داده‌های برنامه ذخیره‌شده به‌صورت ایمن باز نشد. پیش از تغییر برنامه، مشکل را بررسی کنید.",
      "برنامه شما ذخیره شده، اما اطلاعات پشتیبان آن بررسی نشد. پیش از ویرایش دوباره تلاش کنید.",
      "برنامه قبلی تا زمان تأیید داده‌ها فقط خواندنی نمایش داده می‌شود. برای دسترسی کامل دوباره تلاش کنید.",
      "برنامه ذخیره‌شده روی این دستگاه خوانده نشد. دوباره تلاش کنید؛ برنامه موجود بازنویسی نشده است.",
    ],
    "hi": <String>[
      "सहेजी गई योजना देखने के लिए साइन इन करें। योजना का कोई डेटा मिटाया नहीं गया है।",
      "सक्रिय खाता बदल गया है। सही खाते की योजना देखने के लिए मेरी योजना फिर खोलें।",
      "सहेजी गई योजना का डेटा सुरक्षित रूप से नहीं खुल सका। योजना बदलने से पहले समस्या जाँचें।",
      "आपकी योजना सहेजी गई है, लेकिन सहायक जानकारी की जाँच नहीं हो सकी। बदलाव से पहले फिर प्रयास करें।",
      "डेटा सत्यापित होने तक पिछली योजना केवल पढ़ने के लिए दिखाई जाएगी। पूरी पहुँच पाने के लिए फिर प्रयास करें।",
      "इस डिवाइस पर सहेजी गई योजना पढ़ी नहीं जा सकी। फिर प्रयास करें; मौजूदा योजना बदली नहीं गई है।",
    ],
    "id": <String>[
      "Masuk untuk mengakses rencana tersimpan. Tidak ada data rencana yang dihapus.",
      "Akun aktif telah berubah. Buka kembali Rencana Saya untuk melihat akun yang benar.",
      "Data rencana tersimpan tidak dapat dibuka dengan aman. Tinjau masalahnya sebelum mengubah rencana.",
      "Rencana Anda tersimpan, tetapi informasi pendukungnya tidak dapat diperiksa. Coba lagi sebelum mengedit.",
      "Rencana sebelumnya ditampilkan hanya untuk dibaca hingga datanya terverifikasi. Coba lagi untuk memulihkan akses penuh.",
      "Rencana tersimpan tidak dapat dibaca dari perangkat ini. Coba lagi; rencana yang ada tidak ditimpa.",
    ],
    "ms": <String>[
      "Log masuk untuk mengakses pelan tersimpan. Tiada data pelan dipadamkan.",
      "Akaun aktif telah berubah. Buka semula Pelan Saya untuk melihat akaun yang betul.",
      "Data pelan tersimpan tidak dapat dibuka dengan selamat. Semak masalah sebelum mengubah pelan.",
      "Pelan anda telah disimpan, tetapi maklumat sokongannya tidak dapat disahkan. Cuba lagi sebelum mengedit.",
      "Pelan terdahulu dipaparkan sebagai baca sahaja sehingga datanya disahkan. Cuba lagi untuk pulihkan akses penuh.",
      "Pelan tersimpan tidak dapat dibaca pada peranti ini. Cuba lagi; pelan sedia ada tidak ditulis ganti.",
    ],
    "ja": <String>[
      "保存したプランを表示するにはサインインしてください。プランのデータは削除されていません。",
      "使用中のアカウントが変更されました。正しいアカウントを表示するには「マイプラン」を開き直してください。",
      "保存したプランのデータを安全に開けませんでした。プランを変更する前に問題を確認してください。",
      "プランは保存されていますが、関連情報を確認できませんでした。編集する前に再試行してください。",
      "データが確認されるまで、以前のプランは読み取り専用で表示されます。再試行するとすべての操作を利用できます。",
      "この端末で保存済みプランを読み取れませんでした。再試行してください。既存のプランは上書きされていません。",
    ],
    "ko": <String>[
      "저장된 계획을 보려면 로그인하세요. 계획 데이터는 삭제되지 않았습니다.",
      "활성 계정이 변경되었습니다. 올바른 계정을 보려면 내 계획을 다시 여세요.",
      "저장된 계획 데이터를 안전하게 열지 못했습니다. 계획을 변경하기 전에 문제를 확인하세요.",
      "계획은 저장되었지만 관련 정보를 확인하지 못했습니다. 수정하기 전에 다시 시도하세요.",
      "데이터가 검증될 때까지 이전 계획은 읽기 전용으로 표시됩니다. 전체 접근 권한을 복구하려면 다시 시도하세요.",
      "이 기기에서 저장된 계획을 읽지 못했습니다. 다시 시도하세요. 기존 계획은 덮어쓰지 않았습니다.",
    ],
    "zh-Hans": <String>[
      "请登录以访问已保存的计划。没有删除任何计划数据。",
      "当前账户已更改。请重新打开“我的计划”以查看正确账户。",
      "无法安全地打开已保存的计划数据。修改计划前请检查问题。",
      "计划已保存，但无法验证相关支持信息。编辑前请重试。",
      "数据验证完成前，之前的计划将以只读方式显示。请重试以恢复完整访问权限。",
      "无法从此设备读取已保存的计划。请重试；现有计划未被覆盖。",
    ],
    "zh-Hant": <String>[
      "請登入以存取已儲存的計畫。沒有刪除任何計畫資料。",
      "目前帳戶已變更。請重新開啟「我的計畫」以查看正確帳戶。",
      "無法安全地開啟已儲存的計畫資料。修改計畫前請檢查問題。",
      "計畫已儲存，但無法驗證相關支援資訊。編輯前請重試。",
      "資料驗證完成前，先前的計畫會以唯讀模式顯示。請重試以恢復完整存取權限。",
      "無法從此裝置讀取已儲存的計畫。請重試；現有計畫並未被覆寫。",
    ],
    "ru": <String>[
      "Войдите, чтобы открыть сохранённый план. Данные плана не удалены.",
      "Активная учётная запись изменилась. Откройте «Мой план» снова, чтобы увидеть нужный аккаунт.",
      "Не удалось безопасно открыть данные сохранённого плана. Проверьте проблему перед изменением плана.",
      "План сохранён, но не удалось проверить дополнительные данные. Повторите попытку перед редактированием.",
      "Предыдущий план доступен только для чтения до проверки его данных. Повторите попытку, чтобы вернуть полный доступ.",
      "Не удалось прочитать сохранённый план на этом устройстве. Повторите попытку; существующий план не перезаписан.",
    ],
    "bn": <String>[
      "সংরক্ষিত পরিকল্পনা দেখতে সাইন ইন করুন। পরিকল্পনার কোনো তথ্য মুছে ফেলা হয়নি।",
      "সক্রিয় অ্যাকাউন্ট বদলেছে। সঠিক অ্যাকাউন্ট দেখতে আমার পরিকল্পনা আবার খুলুন।",
      "সংরক্ষিত পরিকল্পনার তথ্য নিরাপদে খোলা যায়নি। পরিকল্পনা বদলানোর আগে সমস্যাটি দেখুন।",
      "আপনার পরিকল্পনা সংরক্ষিত আছে, তবে সহায়ক তথ্য যাচাই করা যায়নি। সম্পাদনার আগে আবার চেষ্টা করুন।",
      "তথ্য যাচাই না হওয়া পর্যন্ত আগের পরিকল্পনা শুধু পড়ার জন্য দেখানো হবে। পূর্ণ প্রবেশাধিকার ফিরে পেতে আবার চেষ্টা করুন।",
      "এই ডিভাইসে সংরক্ষিত পরিকল্পনা পড়া যায়নি। আবার চেষ্টা করুন; বিদ্যমান পরিকল্পনা বদলে দেওয়া হয়নি।",
    ],
    "vi": <String>[
      "Đăng nhập để xem kế hoạch đã lưu. Không có dữ liệu kế hoạch nào bị xóa.",
      "Tài khoản đang dùng đã thay đổi. Mở lại Kế hoạch của tôi để xem đúng tài khoản.",
      "Không thể mở an toàn dữ liệu kế hoạch đã lưu. Hãy kiểm tra sự cố trước khi chỉnh sửa kế hoạch.",
      "Kế hoạch đã được lưu nhưng không thể xác minh thông tin hỗ trợ. Hãy thử lại trước khi chỉnh sửa.",
      "Kế hoạch trước đó chỉ được hiển thị để đọc cho đến khi dữ liệu được xác minh. Thử lại để khôi phục quyền truy cập đầy đủ.",
      "Không thể đọc kế hoạch đã lưu trên thiết bị này. Hãy thử lại; kế hoạch hiện có chưa bị ghi đè.",
    ],
    "th": <String>[
      "ลงชื่อเข้าใช้เพื่อดูแผนที่บันทึกไว้ ไม่มีข้อมูลแผนถูกลบ",
      "บัญชีที่ใช้งานเปลี่ยนไปแล้ว เปิดแผนของฉันอีกครั้งเพื่อดูบัญชีที่ถูกต้อง",
      "ไม่สามารถเปิดข้อมูลแผนที่บันทึกไว้อย่างปลอดภัยได้ ตรวจสอบปัญหาก่อนแก้ไขแผน",
      "แผนของคุณถูกบันทึกแล้ว แต่ไม่สามารถตรวจสอบข้อมูลประกอบได้ ลองอีกครั้งก่อนแก้ไข",
      "แผนก่อนหน้าจะแสดงแบบอ่านอย่างเดียวจนกว่าจะยืนยันข้อมูลได้ ลองอีกครั้งเพื่อคืนสิทธิ์เข้าถึงทั้งหมด",
      "ไม่สามารถอ่านแผนที่บันทึกไว้จากอุปกรณ์นี้ได้ ลองอีกครั้ง แผนเดิมไม่ได้ถูกเขียนทับ",
    ],
    "pl": <String>[
      "Zaloguj się, aby uzyskać dostęp do zapisanego planu. Żadne dane planu nie zostały usunięte.",
      "Aktywne konto się zmieniło. Otwórz ponownie Mój plan, aby wyświetlić właściwe konto.",
      "Nie udało się bezpiecznie otworzyć danych zapisanego planu. Sprawdź problem przed zmianą planu.",
      "Plan został zapisany, ale nie można było zweryfikować danych pomocniczych. Spróbuj ponownie przed edycją.",
      "Poprzedni plan jest tylko do odczytu do czasu weryfikacji danych. Spróbuj ponownie, aby przywrócić pełny dostęp.",
      "Nie udało się odczytać zapisanego planu na tym urządzeniu. Spróbuj ponownie; istniejący plan nie został nadpisany.",
    ],
    "nl": <String>[
      "Meld u aan om uw opgeslagen plan te bekijken. Er zijn geen plangegevens verwijderd.",
      "Het actieve account is gewijzigd. Open Mijn plan opnieuw om het juiste account te zien.",
      "De opgeslagen plangegevens konden niet veilig worden geopend. Controleer het probleem voordat u het plan wijzigt.",
      "Uw plan is opgeslagen, maar de bijbehorende informatie kon niet worden gecontroleerd. Probeer het opnieuw voordat u iets wijzigt.",
      "Uw vorige plan wordt alleen-lezen weergegeven totdat de gegevens zijn gecontroleerd. Probeer opnieuw voor volledige toegang.",
      "Uw opgeslagen plan kon niet op dit apparaat worden gelezen. Probeer opnieuw; een bestaand plan is niet overschreven.",
    ],
    "uk": <String>[
      "Увійдіть, щоб переглянути збережений план. Дані плану не видалено.",
      "Активний обліковий запис змінився. Відкрийте «Мій план» знову, щоб побачити правильний обліковий запис.",
      "Не вдалося безпечно відкрити дані збереженого плану. Перевірте проблему, перш ніж змінювати план.",
      "План збережено, але не вдалося перевірити допоміжні відомості. Повторіть спробу перед редагуванням.",
      "Попередній план доступний лише для читання, доки дані не перевірено. Повторіть спробу, щоб відновити повний доступ.",
      "Не вдалося прочитати збережений план на цьому пристрої. Повторіть спробу; наявний план не перезаписано.",
    ],
  };

  static String? resolve(String english, String localeTag) {
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return null;
    final index = sources.indexOf(english);
    if (index < 0) return null;
    return rows[tag]?[index];
  }

  static bool get balanced =>
      rows.keys.toSet().containsAll(BilLocalePolicy.productionTags) &&
      BilLocalePolicy.productionTags.toSet().containsAll(rows.keys) &&
      rows.entries.every(
        (entry) =>
            entry.value.length == sources.length &&
            entry.value.asMap().entries.every(
              (text) =>
                  text.value.trim().isNotEmpty &&
                  (entry.key == 'en' || text.value != sources[text.key]),
            ),
      );
}
