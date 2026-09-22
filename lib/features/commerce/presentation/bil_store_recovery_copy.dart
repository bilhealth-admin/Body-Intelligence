/// Recovery messages do not imply that a charge failed or revoke existing access.
abstract final class BilStoreRecoveryCopy {
  static const keys = [
    'purchase_error',
    'purchase_verification_unavailable',
    'purchase_awaiting_approval',
  ];

  static String? text(String locale, String key) {
    if (key == 'purchase_owned_by_another_account') {
      return _ownershipConflict[locale] ??
          _ownershipConflict[locale.split('-').first] ??
          _ownershipConflict['en']!;
    }
    final index = keys.indexOf(key);
    if (index < 0) return null;
    final copy =
        _copy[locale] ?? _copy[locale.split('-').first] ?? _copy['en']!;
    return copy[index];
  }

  static const _ownershipConflict = <String, String>{
    'en':
        'This purchase is linked to another BIL account. Sign in to the original account or contact support. Do not purchase again to restore access.',
    'ar':
        'هذا الشراء مرتبط بحساب BIL آخر. سجّل الدخول بالحساب الأصلي أو تواصل مع الدعم. لا تشترِ مرة أخرى لاستعادة الوصول.',
    'fr':
        'Cet achat est lié à un autre compte BIL. Connectez-vous au compte d’origine ou contactez l’assistance. Ne rachetez pas pour rétablir l’accès.',
    'es':
        'Esta compra está vinculada a otra cuenta BIL. Inicia sesión en la cuenta original o contacta con soporte. No vuelvas a comprar para recuperar el acceso.',
    'tr':
        'Bu satın alım başka bir BIL hesabına bağlı. İlk hesapla oturum açın veya destekle iletişime geçin. Erişimi geri almak için tekrar satın almayın.',
    'de':
        'Dieser Kauf ist mit einem anderen BIL-Konto verknüpft. Melde dich beim ursprünglichen Konto an oder kontaktiere den Support. Kaufe nicht erneut, um den Zugriff wiederherzustellen.',
    'it':
        'Questo acquisto è collegato a un altro account BIL. Accedi all’account originale o contatta l’assistenza. Non acquistare di nuovo per ripristinare l’accesso.',
    'pt-br':
        'Esta compra está vinculada a outra conta BIL. Entre na conta original ou contate o suporte. Não compre novamente para recuperar o acesso.',
    'pt-pt':
        'Esta compra está associada a outra conta BIL. Inicie sessão na conta original ou contacte o suporte. Não volte a comprar para recuperar o acesso.',
    'ur':
        'یہ خریداری دوسرے BIL اکاؤنٹ سے منسلک ہے۔ اصل اکاؤنٹ میں سائن ان کریں یا سپورٹ سے رابطہ کریں۔ رسائی بحال کرنے کے لیے دوبارہ خریداری نہ کریں۔',
    'fa':
        'این خرید به حساب BIL دیگری متصل است. وارد حساب اصلی شوید یا با پشتیبانی تماس بگیرید. برای بازیابی دسترسی دوباره خرید نکنید.',
    'hi':
        'यह खरीद दूसरे BIL खाते से जुड़ी है। मूल खाते में साइन इन करें या सहायता से संपर्क करें। पहुँच बहाल करने के लिए दोबारा खरीद न करें।',
    'id':
        'Pembelian ini terhubung ke akun BIL lain. Masuk ke akun asal atau hubungi dukungan. Jangan membeli lagi untuk memulihkan akses.',
    'ms':
        'Pembelian ini dipautkan kepada akaun BIL lain. Log masuk ke akaun asal atau hubungi sokongan. Jangan beli lagi untuk memulihkan akses.',
    'ja':
        'この購入は別のBILアカウントに紐付いています。元のアカウントにサインインするか、サポートにお問い合わせください。アクセスを復元するために再購入しないでください。',
    'ko':
        '이 구매는 다른 BIL 계정에 연결되어 있습니다. 원래 계정으로 로그인하거나 지원팀에 문의하세요. 이용 권한을 복원하기 위해 다시 구매하지 마세요.',
    'zh-hans': '此购买关联了另一个 BIL 账户。请登录原账户或联系支持。请勿为了恢复访问权限而再次购买。',
    'zh-hant': '此購買項目連結至另一個 BIL 帳戶。請登入原帳戶或聯絡支援。請勿為了恢復存取權而再次購買。',
    'ru':
        'Эта покупка привязана к другому аккаунту BIL. Войдите в исходный аккаунт или обратитесь в поддержку. Не покупайте повторно для восстановления доступа.',
    'bn':
        'এই কেনাকাটা অন্য BIL অ্যাকাউন্টের সঙ্গে যুক্ত। মূল অ্যাকাউন্টে সাইন ইন করুন বা সহায়তায় যোগাযোগ করুন। অ্যাক্সেস ফিরে পেতে আবার কিনবেন না।',
    'vi':
        'Giao dịch mua này được liên kết với tài khoản BIL khác. Đăng nhập vào tài khoản gốc hoặc liên hệ hỗ trợ. Không mua lại để khôi phục quyền truy cập.',
    'th':
        'การซื้อนี้เชื่อมกับบัญชี BIL อื่น โปรดเข้าสู่ระบบด้วยบัญชีเดิมหรือติดต่อฝ่ายสนับสนุน อย่าซื้อซ้ำเพื่อกู้คืนสิทธิ์การเข้าถึง',
    'pl':
        'Ten zakup jest powiązany z innym kontem BIL. Zaloguj się na pierwotne konto lub skontaktuj się z pomocą. Nie kupuj ponownie, aby odzyskać dostęp.',
    'nl':
        'Deze aankoop is gekoppeld aan een ander BIL-account. Log in op het oorspronkelijke account of neem contact op met de ondersteuning. Koop niet opnieuw om toegang te herstellen.',
    'uk':
        'Ця покупка прив’язана до іншого облікового запису BIL. Увійдіть у початковий обліковий запис або зверніться до підтримки. Не купуйте повторно для відновлення доступу.',
  };

  static const _copy = <String, List<String>>{
    'en': [
      'The store could not complete this request. Try again later.',
      'Purchase confirmation is unavailable. Check your balance or restore purchases before trying again.',
      'Waiting for store approval…',
    ],
    'ar': [
      'تعذر إكمال الطلب من المتجر. يمكنك المحاولة لاحقًا.',
      'تعذر تأكيد الشراء الآن. تحقق من رصيدك أو استعد مشترياتك قبل المحاولة مجددًا.',
      'بانتظار موافقة المتجر…',
    ],
    'fr': [
      'La boutique n’a pas pu traiter cette demande. Réessayez plus tard.',
      'L’achat ne peut pas être confirmé. Vérifiez votre solde ou restaurez vos achats avant de réessayer.',
      'En attente de l’approbation de la boutique…',
    ],
    'es': [
      'La tienda no pudo completar la solicitud. Inténtalo más tarde.',
      'No se puede confirmar la compra. Consulta tu saldo o restaura las compras antes de reintentarlo.',
      'Esperando la aprobación de la tienda…',
    ],
    'tr': [
      'Mağaza bu isteği tamamlayamadı. Daha sonra tekrar deneyin.',
      'Satın alma doğrulanamıyor. Tekrar denemeden önce bakiyenizi kontrol edin veya satın alımları geri yükleyin.',
      'Mağaza onayı bekleniyor…',
    ],
    'de': [
      'Der Store konnte die Anfrage nicht abschließen. Versuche es später erneut.',
      'Der Kauf kann nicht bestätigt werden. Prüfe dein Guthaben oder stelle Käufe wieder her, bevor du es erneut versuchst.',
      'Warten auf die Freigabe des Stores…',
    ],
    'it': [
      'Lo store non ha completato la richiesta. Riprova più tardi.',
      'Impossibile confermare l’acquisto. Controlla il saldo o ripristina gli acquisti prima di riprovare.',
      'In attesa dell’approvazione dello store…',
    ],
    'pt-br': [
      'A loja não concluiu a solicitação. Tente novamente mais tarde.',
      'Não foi possível confirmar a compra. Confira seu saldo ou restaure as compras antes de tentar novamente.',
      'Aguardando aprovação da loja…',
    ],
    'pt-pt': [
      'A loja não concluiu o pedido. Tente novamente mais tarde.',
      'Não foi possível confirmar a compra. Verifique o saldo ou restaure as compras antes de tentar novamente.',
      'A aguardar aprovação da loja…',
    ],
    'ur': [
      'اسٹور درخواست مکمل نہیں کر سکا۔ بعد میں دوبارہ کوشش کریں۔',
      'خریداری کی تصدیق نہیں ہو سکی۔ دوبارہ کوشش سے پہلے اپنا بیلنس دیکھیں یا خریداری بحال کریں۔',
      'اسٹور کی منظوری کا انتظار ہے…',
    ],
    'fa': [
      'فروشگاه نتوانست درخواست را تکمیل کند. بعداً دوباره تلاش کنید.',
      'تأیید خرید ممکن نیست. پیش از تلاش دوباره، موجودی را بررسی یا خریدها را بازیابی کنید.',
      'در انتظار تأیید فروشگاه…',
    ],
    'hi': [
      'स्टोर अनुरोध पूरा नहीं कर सका। बाद में फिर कोशिश करें।',
      'खरीद की पुष्टि उपलब्ध नहीं है। फिर कोशिश करने से पहले बैलेंस देखें या खरीद बहाल करें।',
      'स्टोर की मंज़ूरी की प्रतीक्षा है…',
    ],
    'id': [
      'Toko tidak dapat menyelesaikan permintaan ini. Coba lagi nanti.',
      'Pembelian belum dapat dikonfirmasi. Periksa saldo atau pulihkan pembelian sebelum mencoba lagi.',
      'Menunggu persetujuan toko…',
    ],
    'ms': [
      'Kedai tidak dapat melengkapkan permintaan ini. Cuba lagi kemudian.',
      'Pembelian tidak dapat disahkan. Semak baki atau pulihkan pembelian sebelum mencuba lagi.',
      'Menunggu kelulusan kedai…',
    ],
    'ja': [
      'ストアでリクエストを完了できませんでした。後でもう一度お試しください。',
      '購入を確認できません。再試行する前に残高を確認するか、購入を復元してください。',
      'ストアの承認を待っています…',
    ],
    'ko': [
      '스토어가 요청을 완료하지 못했습니다. 나중에 다시 시도하세요.',
      '구매를 확인할 수 없습니다. 다시 시도하기 전에 잔액을 확인하거나 구매를 복원하세요.',
      '스토어 승인을 기다리는 중…',
    ],
    'zh-hans': ['商店无法完成此请求，请稍后重试。', '暂时无法确认购买。重试前请检查余额或恢复购买。', '正在等待商店批准…'],
    'zh-hant': ['商店無法完成此請求，請稍後再試。', '暫時無法確認購買。重試前請檢查餘額或回復購買項目。', '正在等待商店批准…'],
    'ru': [
      'Магазин не смог выполнить запрос. Повторите попытку позже.',
      'Не удалось подтвердить покупку. Перед повторной попыткой проверьте баланс или восстановите покупки.',
      'Ожидание одобрения магазина…',
    ],
    'bn': [
      'স্টোর অনুরোধটি সম্পন্ন করতে পারেনি। পরে আবার চেষ্টা করুন।',
      'কেনাকাটা নিশ্চিত করা যাচ্ছে না। আবার চেষ্টা করার আগে ব্যালেন্স দেখুন বা কেনাকাটা পুনরুদ্ধার করুন।',
      'স্টোরের অনুমোদনের অপেক্ষায়…',
    ],
    'vi': [
      'Cửa hàng không thể hoàn tất yêu cầu. Vui lòng thử lại sau.',
      'Chưa thể xác nhận giao dịch. Hãy kiểm tra số dư hoặc khôi phục giao dịch mua trước khi thử lại.',
      'Đang chờ cửa hàng phê duyệt…',
    ],
    'th': [
      'ร้านค้าไม่สามารถดำเนินการตามคำขอได้ โปรดลองใหม่ภายหลัง',
      'ยังยืนยันการซื้อไม่ได้ โปรดตรวจสอบยอดคงเหลือหรือกู้คืนการซื้อก่อนลองอีกครั้ง',
      'กำลังรอการอนุมัติจากร้านค้า…',
    ],
    'pl': [
      'Sklep nie mógł zrealizować żądania. Spróbuj ponownie później.',
      'Nie można potwierdzić zakupu. Przed ponowną próbą sprawdź saldo lub przywróć zakupy.',
      'Oczekiwanie na zatwierdzenie przez sklep…',
    ],
    'nl': [
      'De winkel kon dit verzoek niet voltooien. Probeer het later opnieuw.',
      'De aankoop kan niet worden bevestigd. Controleer je saldo of herstel aankopen voordat je het opnieuw probeert.',
      'Wachten op goedkeuring van de winkel…',
    ],
    'uk': [
      'Магазин не зміг виконати запит. Спробуйте пізніше.',
      'Не вдалося підтвердити покупку. Перед повторною спробою перевірте баланс або відновіть покупки.',
      'Очікування схвалення магазину…',
    ],
  };
}
