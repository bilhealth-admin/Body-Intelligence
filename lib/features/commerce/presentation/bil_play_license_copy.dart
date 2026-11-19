/// No dialog result is reported as a purchase or benefit.
abstract final class BilPlayLicenseCopy {
  static const keys = [
    'license_unlicensed',
    'play_license_recovered',
    'play_readiness_unavailable',
    'fix_play_license',
    'play_license_recovered_pending',
  ];
  static String? text(String locale, String key) {
    final index = keys.indexOf(key);
    if (index < 0) return null;
    return (_copy[locale] ??
        (locale == 'pt' ? _copy['pt-pt'] : null) ??
        _copy[locale.split('-').first] ??
        _copy['en']!)[index];
  }

  static const _copy = <String, List<String>>{
    "en": [
      "Google Play needs an app license. No new purchase was started.",
      "Google Play verified the app license. Review the offer and tap Buy again. No new purchase was started.",
      "Google Play readiness could not be verified. No new purchase was started.",
      "Fix Google Play license",
      "App license verified. The existing transaction still needs verification. No new purchase was started.",
    ],
    "ar": [
      "يلزم ترخيص التطبيق من Google Play. لم تبدأ أي عملية شراء جديدة.",
      "تحقق Google Play من ترخيص التطبيق. راجع العرض واضغط شراء مجددًا. لم تبدأ أي عملية شراء جديدة.",
      "تعذر التحقق من جاهزية Google Play. لم تبدأ أي عملية شراء جديدة.",
      "إصلاح ترخيص Google Play",
      "تم التحقق من ترخيص التطبيق. ما زالت المعاملة الحالية بحاجة إلى التحقق. لم تبدأ أي عملية شراء جديدة.",
    ],
    "fr": [
      "Une licence Google Play est requise. Aucun nouvel achat lancé.",
      "Licence Google Play vérifiée. Vérifiez l’offre puis appuyez à nouveau sur Acheter. Aucun nouvel achat lancé.",
      "Vérification Google Play indisponible. Aucun nouvel achat lancé.",
      "Corriger la licence Google Play",
      "Licence vérifiée. La transaction existante reste à vérifier. Aucun nouvel achat lancé.",
    ],
    "es": [
      "Se requiere una licencia de Google Play. No se inició una compra nueva.",
      "Licencia de Google Play verificada. Revisa la oferta y pulsa Comprar otra vez. No se inició una compra nueva.",
      "No se pudo verificar Google Play. No se inició una compra nueva.",
      "Corregir licencia de Google Play",
      "Licencia verificada. La transacción existente aún debe verificarse. No se inició una compra nueva.",
    ],
    "tr": [
      "Google Play uygulama lisansı gerekiyor. Yeni satın alma başlatılmadı.",
      "Google Play lisansı doğrulandı. Teklifi inceleyip tekrar Satın Al’a dokunun. Yeni satın alma başlatılmadı.",
      "Google Play hazırlığı doğrulanamadı. Yeni satın alma başlatılmadı.",
      "Google Play lisansını düzelt",
      "Lisans doğrulandı. Mevcut işlem hâlâ doğrulanmalı. Yeni satın alma başlatılmadı.",
    ],
    "de": [
      "Eine Google Play-App-Lizenz ist erforderlich. Kein neuer Kauf gestartet.",
      "Google Play-Lizenz bestätigt. Angebot prüfen und erneut auf Kaufen tippen. Kein neuer Kauf gestartet.",
      "Google Play konnte nicht geprüft werden. Kein neuer Kauf gestartet.",
      "Google Play-Lizenz reparieren",
      "Lizenz bestätigt. Die vorhandene Transaktion muss noch geprüft werden. Kein neuer Kauf gestartet.",
    ],
    "it": [
      "Serve una licenza Google Play. Nessun nuovo acquisto avviato.",
      "Licenza Google Play verificata. Controlla l’offerta e tocca di nuovo Acquista. Nessun nuovo acquisto avviato.",
      "Impossibile verificare Google Play. Nessun nuovo acquisto avviato.",
      "Correggi licenza Google Play",
      "Licenza verificata. La transazione esistente richiede ancora verifica. Nessun nuovo acquisto avviato.",
    ],
    "pt-br": [
      "É necessária uma licença do Google Play. Nenhuma nova compra foi iniciada.",
      "Licença do Google Play verificada. Confira a oferta e toque em Comprar novamente. Nenhuma nova compra foi iniciada.",
      "Não foi possível verificar o Google Play. Nenhuma nova compra foi iniciada.",
      "Corrigir licença do Google Play",
      "Licença verificada. A transação existente ainda precisa ser verificada. Nenhuma nova compra foi iniciada.",
    ],
    "pt-pt": [
      "É necessária uma licença do Google Play. Não foi iniciada uma nova compra.",
      "Licença do Google Play verificada. Reveja a oferta e toque novamente em Comprar. Não foi iniciada uma nova compra.",
      "Não foi possível verificar o Google Play. Não foi iniciada uma nova compra.",
      "Corrigir licença do Google Play",
      "Licença verificada. A transação existente ainda precisa de verificação. Não foi iniciada uma nova compra.",
    ],
    "ur": [
      "Google Play ایپ لائسنس درکار ہے۔ کوئی نئی خریداری شروع نہیں ہوئی۔",
      "Google Play نے ایپ لائسنس کی تصدیق کی۔ آفر دیکھیں اور دوبارہ خریدیں دبائیں۔ کوئی نئی خریداری شروع نہیں ہوئی۔",
      "Google Play کی تیاری کی تصدیق نہیں ہو سکی۔ کوئی نئی خریداری شروع نہیں ہوئی۔",
      "Google Play لائسنس درست کریں",
      "ایپ لائسنس کی تصدیق ہوئی۔ موجودہ لین دین کی تصدیق ابھی باقی ہے۔ کوئی نئی خریداری شروع نہیں ہوئی۔",
    ],
    "fa": [
      "مجوز برنامه Google Play لازم است. خرید جدیدی شروع نشد.",
      "مجوز Google Play تأیید شد. پیشنهاد را بررسی کنید و دوباره خرید را بزنید. خرید جدیدی شروع نشد.",
      "آمادگی Google Play تأیید نشد. خرید جدیدی شروع نشد.",
      "رفع مجوز Google Play",
      "مجوز تأیید شد. تراکنش موجود هنوز نیاز به تأیید دارد. خرید جدیدی شروع نشد.",
    ],
    "hi": [
      "Google Play ऐप लाइसेंस चाहिए। कोई नई खरीद शुरू नहीं हुई।",
      "Google Play ऐप लाइसेंस सत्यापित है। ऑफ़र देखें और फिर खरीदें दबाएँ। कोई नई खरीद शुरू नहीं हुई।",
      "Google Play की तैयारी सत्यापित नहीं हो सकी। कोई नई खरीद शुरू नहीं हुई।",
      "Google Play लाइसेंस ठीक करें",
      "ऐप लाइसेंस सत्यापित है। मौजूदा लेनदेन का सत्यापन बाकी है। कोई नई खरीद शुरू नहीं हुई।",
    ],
    "id": [
      "Lisensi aplikasi Google Play diperlukan. Tidak ada pembelian baru dimulai.",
      "Lisensi Google Play terverifikasi. Tinjau penawaran dan ketuk Beli lagi. Tidak ada pembelian baru dimulai.",
      "Kesiapan Google Play tidak dapat diverifikasi. Tidak ada pembelian baru dimulai.",
      "Perbaiki lisensi Google Play",
      "Lisensi terverifikasi. Transaksi yang ada masih perlu diverifikasi. Tidak ada pembelian baru dimulai.",
    ],
    "ms": [
      "Lesen aplikasi Google Play diperlukan. Tiada pembelian baharu dimulakan.",
      "Lesen Google Play disahkan. Semak tawaran dan ketik Beli sekali lagi. Tiada pembelian baharu dimulakan.",
      "Kesediaan Google Play tidak dapat disahkan. Tiada pembelian baharu dimulakan.",
      "Baiki lesen Google Play",
      "Lesen disahkan. Transaksi sedia ada masih perlu disahkan. Tiada pembelian baharu dimulakan.",
    ],
    "ja": [
      "Google Play のアプリライセンスが必要です。新しい購入は開始されていません。",
      "Google Play のライセンスを確認しました。オファーを確認し、もう一度購入をタップしてください。新しい購入は開始されていません。",
      "Google Play の準備状況を確認できませんでした。新しい購入は開始されていません。",
      "Google Play ライセンスを修復",
      "ライセンスを確認しました。既存の取引は引き続き確認が必要です。新しい購入は開始されていません。",
    ],
    "ko": [
      "Google Play 앱 라이선스가 필요합니다. 새 구매가 시작되지 않았습니다.",
      "Google Play 라이선스를 확인했습니다. 혜택을 검토하고 구매를 다시 누르세요. 새 구매가 시작되지 않았습니다.",
      "Google Play 준비 상태를 확인할 수 없습니다. 새 구매가 시작되지 않았습니다.",
      "Google Play 라이선스 복구",
      "라이선스를 확인했습니다. 기존 거래는 아직 확인이 필요합니다. 새 구매가 시작되지 않았습니다.",
    ],
    "zh-hans": [
      "需要 Google Play 应用许可。未开始新的购买。",
      "Google Play 应用许可已验证。请查看优惠，再次点按购买。未开始新的购买。",
      "无法验证 Google Play 是否就绪。未开始新的购买。",
      "修复 Google Play 许可",
      "应用许可已验证。现有交易仍需验证。未开始新的购买。",
    ],
    "zh-hant": [
      "需要 Google Play 應用程式授權。未開始新的購買。",
      "Google Play 應用程式授權已驗證。請查看優惠，再次輕觸購買。未開始新的購買。",
      "無法驗證 Google Play 是否就緒。未開始新的購買。",
      "修復 Google Play 授權",
      "應用程式授權已驗證。現有交易仍需驗證。未開始新的購買。",
    ],
    "ru": [
      "Нужна лицензия Google Play. Новая покупка не начата.",
      "Лицензия Google Play подтверждена. Проверьте предложение и снова нажмите Купить. Новая покупка не начата.",
      "Не удалось проверить готовность Google Play. Новая покупка не начата.",
      "Исправить лицензию Google Play",
      "Лицензия подтверждена. Существующую транзакцию ещё нужно проверить. Новая покупка не начата.",
    ],
    "bn": [
      "Google Play অ্যাপ লাইসেন্স প্রয়োজন। নতুন কেনাকাটা শুরু হয়নি।",
      "Google Play অ্যাপ লাইসেন্স যাচাই হয়েছে। অফার দেখুন এবং আবার কিনুন চাপুন। নতুন কেনাকাটা শুরু হয়নি।",
      "Google Play প্রস্তুতি যাচাই করা যায়নি। নতুন কেনাকাটা শুরু হয়নি।",
      "Google Play লাইসেন্স ঠিক করুন",
      "অ্যাপ লাইসেন্স যাচাই হয়েছে। বিদ্যমান লেনদেন এখনও যাচাই করা দরকার। নতুন কেনাকাটা শুরু হয়নি।",
    ],
    "vi": [
      "Cần giấy phép ứng dụng Google Play. Chưa bắt đầu giao dịch mua mới.",
      "Đã xác minh giấy phép Google Play. Xem ưu đãi và nhấn Mua lần nữa. Chưa bắt đầu giao dịch mua mới.",
      "Không thể xác minh Google Play đã sẵn sàng. Chưa bắt đầu giao dịch mua mới.",
      "Sửa giấy phép Google Play",
      "Đã xác minh giấy phép. Giao dịch hiện có vẫn cần xác minh. Chưa bắt đầu giao dịch mua mới.",
    ],
    "th": [
      "ต้องมีใบอนุญาตแอป Google Play ยังไม่ได้เริ่มการซื้อใหม่",
      "ยืนยันใบอนุญาต Google Play แล้ว โปรดตรวจสอบข้อเสนอแล้วแตะซื้ออีกครั้ง ยังไม่ได้เริ่มการซื้อใหม่",
      "ไม่สามารถยืนยันความพร้อมของ Google Play ยังไม่ได้เริ่มการซื้อใหม่",
      "แก้ไขใบอนุญาต Google Play",
      "ยืนยันใบอนุญาตแล้ว ยังต้องตรวจสอบธุรกรรมเดิม ยังไม่ได้เริ่มการซื้อใหม่",
    ],
    "pl": [
      "Wymagana jest licencja Google Play. Nie rozpoczęto nowego zakupu.",
      "Licencja Google Play potwierdzona. Sprawdź ofertę i ponownie dotknij Kup. Nie rozpoczęto nowego zakupu.",
      "Nie udało się sprawdzić gotowości Google Play. Nie rozpoczęto nowego zakupu.",
      "Napraw licencję Google Play",
      "Licencja potwierdzona. Istniejąca transakcja nadal wymaga weryfikacji. Nie rozpoczęto nowego zakupu.",
    ],
    "nl": [
      "Een Google Play-applicentie is vereist. Geen nieuwe aankoop gestart.",
      "Google Play-licentie bevestigd. Bekijk het aanbod en tik opnieuw op Kopen. Geen nieuwe aankoop gestart.",
      "Google Play-gereedheid kon niet worden bevestigd. Geen nieuwe aankoop gestart.",
      "Google Play-licentie herstellen",
      "Licentie bevestigd. De bestaande transactie moet nog worden gecontroleerd. Geen nieuwe aankoop gestart.",
    ],
    "uk": [
      "Потрібна ліцензія застосунку Google Play. Нову покупку не розпочато.",
      "Ліцензію Google Play перевірено. Перегляньте пропозицію й знову натисніть Купити. Нову покупку не розпочато.",
      "Не вдалося перевірити готовність Google Play. Нову покупку не розпочато.",
      "Виправити ліцензію Google Play",
      "Ліцензію перевірено. Наявну транзакцію ще потрібно перевірити. Нову покупку не розпочато.",
    ],
  };
}
