import 'bil_locale_policy.dart';

/// Reviewed 25-locale copy for the human community-moderation workflow.
///
/// Keeping this security-sensitive surface in one positional catalog makes a
/// missing locale or placeholder mismatch fail validation instead of silently
/// exposing English in a shipped locale.
abstract final class CommunityModerationRuntimeCopy {
  static const communityModeration = 'Community moderation';
  static const closeReport = 'Close report';
  static const couldNotResolveReport =
      'Could not resolve the report. Refresh and try again.';
  static const couldNotSaveDecision =
      'Could not save the moderation decision. Refresh and try again.';
  static const moderatorAccessRequired = 'Moderator access is required.';
  static const noOpenReports = 'No open reports.';
  static const noPendingPosts = 'No pending posts.';
  static const openReports = 'Open reports';
  static const postApprovedTokens =
      'Post approved. 5 BIL AI Boost tokens were granted once.';
  static const postApprovedNoDuplicate =
      'Post approved. No duplicate token grant was added.';
  static const postRejectedPrivate =
      'Post rejected. It remains private to its author.';
  static const postStatus = 'Post status: {status}';
  static const postSubmittedReview =
      'Post submitted for human review. Only you can see it until it is approved.';
  static const postsAwaitingReview = 'Posts awaiting human review';
  static const removeContent = 'Remove content';
  static const removeReportedContent = 'Remove reported content';
  static const removeReportedContentQuestion = 'Remove reported content?';
  static const reportDecisionSaved = 'Report decision saved.';
  static const queueClear = 'The moderation queue is clear.';
  static const serverVerifiesModerator =
      'The server verifies moderator access before returning any pending content.';
  static const closesReportAndRemoves =
      'This closes the report and removes the referenced post or message.';
  static const decisionAlreadySaved =
      'This moderation decision was already saved.';

  static const sources = <String>[
    communityModeration,
    closeReport,
    couldNotResolveReport,
    couldNotSaveDecision,
    moderatorAccessRequired,
    noOpenReports,
    noPendingPosts,
    openReports,
    postApprovedTokens,
    postApprovedNoDuplicate,
    postRejectedPrivate,
    postStatus,
    postSubmittedReview,
    postsAwaitingReview,
    removeContent,
    removeReportedContent,
    removeReportedContentQuestion,
    reportDecisionSaved,
    queueClear,
    serverVerifiesModerator,
    closesReportAndRemoves,
    decisionAlreadySaved,
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
      'مراجعة المجتمع',
      'إغلاق البلاغ',
      'تعذر حسم البلاغ. حدّث القائمة وحاول مجددًا.',
      'تعذر حفظ قرار المراجعة. حدّث القائمة وحاول مجددًا.',
      'يتطلب هذا القسم صلاحية مشرف.',
      'لا توجد بلاغات مفتوحة.',
      'لا توجد منشورات معلّقة.',
      'البلاغات المفتوحة',
      'تم اعتماد المنشور ومنح 5 رموز BIL AI Boost مرة واحدة.',
      'تم اعتماد المنشور دون إضافة منحة رموز مكررة.',
      'تم رفض المنشور وسيبقى خاصًا بصاحبه.',
      'حالة المنشور: {status}',
      'تم إرسال المنشور للمراجعة البشرية. لن يراه سواك حتى يتم اعتماده.',
      'منشورات بانتظار المراجعة البشرية',
      'إزالة المحتوى',
      'إزالة المحتوى المُبلّغ عنه',
      'إزالة المحتوى المُبلّغ عنه؟',
      'تم حفظ قرار البلاغ.',
      'قائمة المراجعة خالية.',
      'يتحقق الخادم من صلاحية المشرف قبل إرجاع أي محتوى معلّق.',
      'سيؤدي ذلك إلى إغلاق البلاغ وإزالة المنشور أو الرسالة المشار إليها.',
      'تم حفظ قرار المراجعة هذا من قبل.',
    ],
    'en': sources,
    'fr': [
      'Modération de la communauté',
      'Fermer le signalement',
      'Impossible de résoudre le signalement. Actualisez et réessayez.',
      'Impossible d’enregistrer la décision de modération. Actualisez et réessayez.',
      'Un accès de modérateur est requis.',
      'Aucun signalement ouvert.',
      'Aucune publication en attente.',
      'Signalements ouverts',
      'Publication approuvée. 5 jetons BIL AI Boost ont été accordés une seule fois.',
      'Publication approuvée. Aucun jeton en double n’a été accordé.',
      'Publication rejetée. Elle reste privée pour son auteur.',
      'Statut de la publication : {status}',
      'Publication envoyée à la modération humaine. Vous seul pouvez la voir jusqu’à son approbation.',
      'Publications en attente d’une vérification humaine',
      'Supprimer le contenu',
      'Supprimer le contenu signalé',
      'Supprimer le contenu signalé ?',
      'Décision concernant le signalement enregistrée.',
      'La file de modération est vide.',
      'Le serveur vérifie l’accès du modérateur avant de renvoyer tout contenu en attente.',
      'Cette action ferme le signalement et supprime la publication ou le message concerné.',
      'Cette décision de modération a déjà été enregistrée.',
    ],
    'es': [
      'Moderación de la comunidad',
      'Cerrar denuncia',
      'No se pudo resolver la denuncia. Actualiza y vuelve a intentarlo.',
      'No se pudo guardar la decisión de moderación. Actualiza y vuelve a intentarlo.',
      'Se requiere acceso de moderador.',
      'No hay denuncias abiertas.',
      'No hay publicaciones pendientes.',
      'Denuncias abiertas',
      'Publicación aprobada. Se concedieron una sola vez 5 tokens BIL AI Boost.',
      'Publicación aprobada. No se añadió ninguna concesión de tokens duplicada.',
      'Publicación rechazada. Sigue siendo privada para su autor.',
      'Estado de la publicación: {status}',
      'La publicación se envió a revisión humana. Solo tú puedes verla hasta que se apruebe.',
      'Publicaciones pendientes de revisión humana',
      'Eliminar contenido',
      'Eliminar el contenido denunciado',
      '¿Eliminar el contenido denunciado?',
      'Decisión sobre la denuncia guardada.',
      'La cola de moderación está vacía.',
      'El servidor verifica el acceso de moderador antes de devolver contenido pendiente.',
      'Esto cierra la denuncia y elimina la publicación o el mensaje indicado.',
      'Esta decisión de moderación ya estaba guardada.',
    ],
    'tr': [
      'Topluluk moderasyonu',
      'Bildirimi kapat',
      'Bildirim çözümlenemedi. Yenileyip tekrar deneyin.',
      'Moderasyon kararı kaydedilemedi. Yenileyip tekrar deneyin.',
      'Moderatör erişimi gerekiyor.',
      'Açık bildirim yok.',
      'Bekleyen gönderi yok.',
      'Açık bildirimler',
      'Gönderi onaylandı. 5 BIL AI Boost jetonu bir kez verildi.',
      'Gönderi onaylandı. Yinelenen jeton hibesi eklenmedi.',
      'Gönderi reddedildi. Yalnızca yazarı görebilir.',
      'Gönderi durumu: {status}',
      'Gönderi insan incelemesine gönderildi. Onaylanana kadar yalnızca siz görebilirsiniz.',
      'İnsan incelemesi bekleyen gönderiler',
      'İçeriği kaldır',
      'Bildirilen içeriği kaldır',
      'Bildirilen içerik kaldırılsın mı?',
      'Bildirim kararı kaydedildi.',
      'Moderasyon kuyruğu boş.',
      'Sunucu, bekleyen içerikleri döndürmeden önce moderatör erişimini doğrular.',
      'Bu işlem bildirimi kapatır ve ilgili gönderiyi veya mesajı kaldırır.',
      'Bu moderasyon kararı zaten kaydedilmiş.',
    ],
    'de': [
      'Community-Moderation',
      'Meldung schließen',
      'Die Meldung konnte nicht bearbeitet werden. Aktualisieren Sie und versuchen Sie es erneut.',
      'Die Moderationsentscheidung konnte nicht gespeichert werden. Aktualisieren Sie und versuchen Sie es erneut.',
      'Moderatorzugriff ist erforderlich.',
      'Keine offenen Meldungen.',
      'Keine ausstehenden Beiträge.',
      'Offene Meldungen',
      'Beitrag genehmigt. 5 BIL AI Boost-Token wurden einmalig gewährt.',
      'Beitrag genehmigt. Es wurde keine doppelte Token-Gutschrift hinzugefügt.',
      'Beitrag abgelehnt. Er bleibt nur für den Autor sichtbar.',
      'Beitragsstatus: {status}',
      'Der Beitrag wurde zur menschlichen Prüfung eingereicht. Bis zur Genehmigung können nur Sie ihn sehen.',
      'Beiträge, die auf eine menschliche Prüfung warten',
      'Inhalt entfernen',
      'Gemeldeten Inhalt entfernen',
      'Gemeldeten Inhalt entfernen?',
      'Entscheidung zur Meldung gespeichert.',
      'Die Moderationswarteschlange ist leer.',
      'Der Server überprüft den Moderatorzugriff, bevor ausstehende Inhalte zurückgegeben werden.',
      'Dadurch wird die Meldung geschlossen und der betreffende Beitrag oder die Nachricht entfernt.',
      'Diese Moderationsentscheidung wurde bereits gespeichert.',
    ],
    'it': [
      'Moderazione della community',
      'Chiudi segnalazione',
      'Impossibile risolvere la segnalazione. Aggiorna e riprova.',
      'Impossibile salvare la decisione di moderazione. Aggiorna e riprova.',
      'È richiesto l’accesso da moderatore.',
      'Nessuna segnalazione aperta.',
      'Nessun post in attesa.',
      'Segnalazioni aperte',
      'Post approvato. Sono stati concessi una sola volta 5 token BIL AI Boost.',
      'Post approvato. Non è stata aggiunta alcuna concessione di token duplicata.',
      'Post rifiutato. Resta privato per il suo autore.',
      'Stato del post: {status}',
      'Post inviato alla revisione umana. Solo tu puoi vederlo finché non viene approvato.',
      'Post in attesa di revisione umana',
      'Rimuovi contenuto',
      'Rimuovi il contenuto segnalato',
      'Rimuovere il contenuto segnalato?',
      'Decisione sulla segnalazione salvata.',
      'La coda di moderazione è vuota.',
      'Il server verifica l’accesso da moderatore prima di restituire contenuti in attesa.',
      'Questa azione chiude la segnalazione e rimuove il post o il messaggio indicato.',
      'Questa decisione di moderazione era già stata salvata.',
    ],
    'pt-BR': [
      'Moderação da comunidade',
      'Encerrar denúncia',
      'Não foi possível resolver a denúncia. Atualize e tente novamente.',
      'Não foi possível salvar a decisão de moderação. Atualize e tente novamente.',
      'É necessário acesso de moderador.',
      'Nenhuma denúncia aberta.',
      'Nenhuma publicação pendente.',
      'Denúncias abertas',
      'Publicação aprovada. 5 tokens BIL AI Boost foram concedidos uma única vez.',
      'Publicação aprovada. Nenhuma concessão duplicada de tokens foi adicionada.',
      'Publicação rejeitada. Ela permanece privada para seu autor.',
      'Status da publicação: {status}',
      'Publicação enviada para revisão humana. Só você pode vê-la até que seja aprovada.',
      'Publicações aguardando revisão humana',
      'Remover conteúdo',
      'Remover conteúdo denunciado',
      'Remover conteúdo denunciado?',
      'Decisão sobre a denúncia salva.',
      'A fila de moderação está vazia.',
      'O servidor verifica o acesso de moderador antes de retornar qualquer conteúdo pendente.',
      'Isso encerra a denúncia e remove a publicação ou mensagem indicada.',
      'Esta decisão de moderação já havia sido salva.',
    ],
    'pt-PT': [
      'Moderação da comunidade',
      'Fechar denúncia',
      'Não foi possível resolver a denúncia. Atualize e tente novamente.',
      'Não foi possível guardar a decisão de moderação. Atualize e tente novamente.',
      'É necessário acesso de moderador.',
      'Não existem denúncias abertas.',
      'Não existem publicações pendentes.',
      'Denúncias abertas',
      'Publicação aprovada. Foram atribuídos uma única vez 5 tokens BIL AI Boost.',
      'Publicação aprovada. Não foi adicionada qualquer atribuição duplicada de tokens.',
      'Publicação rejeitada. Permanece privada para o respetivo autor.',
      'Estado da publicação: {status}',
      'Publicação enviada para revisão humana. Só pode vê-la até ser aprovada.',
      'Publicações a aguardar revisão humana',
      'Remover conteúdo',
      'Remover conteúdo denunciado',
      'Remover conteúdo denunciado?',
      'Decisão sobre a denúncia guardada.',
      'A fila de moderação está vazia.',
      'O servidor verifica o acesso de moderador antes de devolver qualquer conteúdo pendente.',
      'Isto fecha a denúncia e remove a publicação ou mensagem indicada.',
      'Esta decisão de moderação já tinha sido guardada.',
    ],
    'ur': [
      'کمیونٹی کی نگرانی',
      'رپورٹ بند کریں',
      'رپورٹ حل نہیں ہو سکی۔ تازہ کریں اور دوبارہ کوشش کریں۔',
      'نگرانی کا فیصلہ محفوظ نہیں ہو سکا۔ تازہ کریں اور دوبارہ کوشش کریں۔',
      'نگران کی رسائی درکار ہے۔',
      'کوئی کھلی رپورٹ نہیں۔',
      'کوئی زیرِ التوا پوسٹ نہیں۔',
      'کھلی رپورٹس',
      'پوسٹ منظور ہو گئی۔ 5 BIL AI Boost ٹوکن ایک بار دیے گئے۔',
      'پوسٹ منظور ہو گئی۔ ٹوکن کی دہری گرانٹ شامل نہیں کی گئی۔',
      'پوسٹ مسترد ہو گئی۔ یہ صرف اپنے مصنف کو نظر آئے گی۔',
      'پوسٹ کی حالت: {status}',
      'پوسٹ انسانی جائزے کے لیے بھیج دی گئی۔ منظوری تک صرف آپ اسے دیکھ سکتے ہیں۔',
      'انسانی جائزے کی منتظر پوسٹس',
      'مواد ہٹائیں',
      'رپورٹ شدہ مواد ہٹائیں',
      'رپورٹ شدہ مواد ہٹائیں؟',
      'رپورٹ کا فیصلہ محفوظ ہو گیا۔',
      'نگرانی کی قطار خالی ہے۔',
      'سرور کسی زیرِ التوا مواد کو واپس کرنے سے پہلے نگران کی رسائی کی تصدیق کرتا ہے۔',
      'اس سے رپورٹ بند ہو جاتی ہے اور متعلقہ پوسٹ یا پیغام ہٹا دیا جاتا ہے۔',
      'نگرانی کا یہ فیصلہ پہلے ہی محفوظ تھا۔',
    ],
    'fa': [
      'نظارت انجمن',
      'بستن گزارش',
      'رسیدگی به گزارش ممکن نشد. تازه‌سازی کنید و دوباره امتحان کنید.',
      'ذخیره تصمیم نظارتی ممکن نشد. تازه‌سازی کنید و دوباره امتحان کنید.',
      'دسترسی ناظر لازم است.',
      'گزارش بازی وجود ندارد.',
      'پست در انتظاری وجود ندارد.',
      'گزارش‌های باز',
      'پست تأیید شد. ۵ توکن BIL AI Boost فقط یک بار اعطا شد.',
      'پست تأیید شد. توکن تکراری اعطا نشد.',
      'پست رد شد. فقط برای نویسنده آن قابل مشاهده می‌ماند.',
      'وضعیت پست: {status}',
      'پست برای بررسی انسانی ارسال شد. تا زمان تأیید فقط شما می‌توانید آن را ببینید.',
      'پست‌های در انتظار بررسی انسانی',
      'حذف محتوا',
      'حذف محتوای گزارش‌شده',
      'محتوای گزارش‌شده حذف شود؟',
      'تصمیم گزارش ذخیره شد.',
      'صف نظارت خالی است.',
      'سرور پیش از بازگرداندن محتوای در انتظار، دسترسی ناظر را تأیید می‌کند.',
      'این کار گزارش را می‌بندد و پست یا پیام موردنظر را حذف می‌کند.',
      'این تصمیم نظارتی قبلاً ذخیره شده بود.',
    ],
    'hi': [
      'समुदाय मॉडरेशन',
      'रिपोर्ट बंद करें',
      'रिपोर्ट का समाधान नहीं हो सका। रीफ़्रेश करके फिर कोशिश करें।',
      'मॉडरेशन का निर्णय सहेजा नहीं जा सका। रीफ़्रेश करके फिर कोशिश करें।',
      'मॉडरेटर की पहुँच आवश्यक है।',
      'कोई खुली रिपोर्ट नहीं है।',
      'कोई पोस्ट समीक्षा के लिए लंबित नहीं है।',
      'खुली रिपोर्ट',
      'पोस्ट स्वीकृत हुई। 5 BIL AI Boost टोकन केवल एक बार दिए गए।',
      'पोस्ट स्वीकृत हुई। टोकन का कोई डुप्लिकेट अनुदान नहीं जोड़ा गया।',
      'पोस्ट अस्वीकृत हुई। यह केवल उसके लेखक को दिखाई देगी।',
      'पोस्ट की स्थिति: {status}',
      'पोस्ट मानवीय समीक्षा के लिए भेजी गई। स्वीकृति तक इसे केवल आप देख सकते हैं।',
      'मानवीय समीक्षा की प्रतीक्षा वाली पोस्ट',
      'कंटेंट हटाएँ',
      'रिपोर्ट किया गया कंटेंट हटाएँ',
      'रिपोर्ट किया गया कंटेंट हटाएँ?',
      'रिपोर्ट का निर्णय सहेजा गया।',
      'मॉडरेशन कतार खाली है।',
      'सर्वर कोई लंबित कंटेंट लौटाने से पहले मॉडरेटर की पहुँच सत्यापित करता है।',
      'यह रिपोर्ट बंद करता है और संबंधित पोस्ट या संदेश हटा देता है।',
      'यह मॉडरेशन निर्णय पहले ही सहेजा जा चुका था।',
    ],
    'id': [
      'Moderasi komunitas',
      'Tutup laporan',
      'Laporan tidak dapat diselesaikan. Muat ulang dan coba lagi.',
      'Keputusan moderasi tidak dapat disimpan. Muat ulang dan coba lagi.',
      'Akses moderator diperlukan.',
      'Tidak ada laporan terbuka.',
      'Tidak ada postingan tertunda.',
      'Laporan terbuka',
      'Postingan disetujui. 5 token BIL AI Boost diberikan satu kali.',
      'Postingan disetujui. Tidak ada pemberian token duplikat.',
      'Postingan ditolak. Postingan tetap bersifat privat bagi penulisnya.',
      'Status postingan: {status}',
      'Postingan dikirim untuk ditinjau manusia. Hanya Anda yang dapat melihatnya hingga disetujui.',
      'Postingan yang menunggu tinjauan manusia',
      'Hapus konten',
      'Hapus konten yang dilaporkan',
      'Hapus konten yang dilaporkan?',
      'Keputusan laporan disimpan.',
      'Antrean moderasi kosong.',
      'Server memverifikasi akses moderator sebelum mengembalikan konten tertunda.',
      'Tindakan ini menutup laporan dan menghapus postingan atau pesan yang dirujuk.',
      'Keputusan moderasi ini sudah disimpan.',
    ],
    'ms': [
      'Moderasi komuniti',
      'Tutup laporan',
      'Laporan tidak dapat diselesaikan. Muat semula dan cuba lagi.',
      'Keputusan moderasi tidak dapat disimpan. Muat semula dan cuba lagi.',
      'Akses moderator diperlukan.',
      'Tiada laporan terbuka.',
      'Tiada siaran belum selesai.',
      'Laporan terbuka',
      'Siaran diluluskan. 5 token BIL AI Boost diberikan sekali.',
      'Siaran diluluskan. Tiada pemberian token pendua ditambahkan.',
      'Siaran ditolak. Ia kekal peribadi kepada pengarangnya.',
      'Status siaran: {status}',
      'Siaran dihantar untuk semakan manusia. Hanya anda boleh melihatnya sehingga diluluskan.',
      'Siaran yang menunggu semakan manusia',
      'Alih keluar kandungan',
      'Alih keluar kandungan yang dilaporkan',
      'Alih keluar kandungan yang dilaporkan?',
      'Keputusan laporan disimpan.',
      'Baris gilir moderasi kosong.',
      'Pelayan mengesahkan akses moderator sebelum mengembalikan kandungan yang belum selesai.',
      'Tindakan ini menutup laporan dan mengalih keluar siaran atau mesej yang dirujuk.',
      'Keputusan moderasi ini telah pun disimpan.',
    ],
    'ja': [
      'コミュニティのモデレーション',
      '報告を閉じる',
      '報告を処理できませんでした。更新してもう一度お試しください。',
      'モデレーションの決定を保存できませんでした。更新してもう一度お試しください。',
      'モデレーター権限が必要です。',
      '未処理の報告はありません。',
      '審査待ちの投稿はありません。',
      '未処理の報告',
      '投稿を承認しました。5 BIL AI Boostトークンが一度だけ付与されました。',
      '投稿を承認しました。トークンは重複して付与されていません。',
      '投稿を却下しました。投稿は作成者だけに表示されます。',
      '投稿の状態：{status}',
      '投稿を人による審査に提出しました。承認されるまで閲覧できるのはあなただけです。',
      '人による審査を待っている投稿',
      'コンテンツを削除',
      '報告されたコンテンツを削除',
      '報告されたコンテンツを削除しますか？',
      '報告への対応を保存しました。',
      'モデレーション待ちの項目はありません。',
      'サーバーは保留中のコンテンツを返す前にモデレーター権限を確認します。',
      'この操作で報告を閉じ、該当する投稿またはメッセージを削除します。',
      'このモデレーションの決定はすでに保存されています。',
    ],
    'ko': [
      '커뮤니티 검토',
      '신고 닫기',
      '신고를 처리하지 못했습니다. 새로고침한 후 다시 시도하세요.',
      '검토 결정을 저장하지 못했습니다. 새로고침한 후 다시 시도하세요.',
      '검토자 권한이 필요합니다.',
      '처리할 신고가 없습니다.',
      '검토 대기 중인 게시물이 없습니다.',
      '처리할 신고',
      '게시물이 승인되었습니다. 5 BIL AI Boost 토큰이 한 번만 지급되었습니다.',
      '게시물이 승인되었습니다. 토큰이 중복 지급되지 않았습니다.',
      '게시물이 거부되었습니다. 작성자에게만 표시됩니다.',
      '게시물 상태: {status}',
      '게시물이 사람의 검토를 위해 제출되었습니다. 승인될 때까지 본인만 볼 수 있습니다.',
      '사람의 검토를 기다리는 게시물',
      '콘텐츠 삭제',
      '신고된 콘텐츠 삭제',
      '신고된 콘텐츠를 삭제할까요?',
      '신고 결정이 저장되었습니다.',
      '검토 대기열이 비어 있습니다.',
      '서버는 대기 중인 콘텐츠를 반환하기 전에 검토자 권한을 확인합니다.',
      '이 작업은 신고를 닫고 해당 게시물이나 메시지를 삭제합니다.',
      '이 검토 결정은 이미 저장되었습니다.',
    ],
    'zh-Hans': [
      '社区审核',
      '关闭举报',
      '无法处理举报。请刷新后重试。',
      '无法保存审核决定。请刷新后重试。',
      '需要审核员权限。',
      '没有未处理的举报。',
      '没有待审核的帖子。',
      '未处理的举报',
      '帖子已批准。已一次性授予 5 个 BIL AI Boost 代币。',
      '帖子已批准。未重复授予代币。',
      '帖子已拒绝。该帖子仍仅对作者可见。',
      '帖子状态：{status}',
      '帖子已提交人工审核。在获得批准之前，仅你可以看到该帖子。',
      '等待人工审核的帖子',
      '移除内容',
      '移除被举报的内容',
      '要移除被举报的内容吗？',
      '举报处理决定已保存。',
      '审核队列为空。',
      '服务器会先验证审核员权限，再返回任何待处理内容。',
      '此操作会关闭举报，并移除所指的帖子或消息。',
      '此审核决定已保存过。',
    ],
    'zh-Hant': [
      '社群審核',
      '關閉檢舉',
      '無法處理檢舉。請重新整理後再試一次。',
      '無法儲存審核決定。請重新整理後再試一次。',
      '需要審核員權限。',
      '沒有未處理的檢舉。',
      '沒有待審核的貼文。',
      '未處理的檢舉',
      '貼文已核准。已一次性授予 5 個 BIL AI Boost 代幣。',
      '貼文已核准。未重複授予代幣。',
      '貼文已拒絕。該貼文仍僅對作者可見。',
      '貼文狀態：{status}',
      '貼文已提交人工審核。在獲得核准前，只有你可以看到該貼文。',
      '等待人工審核的貼文',
      '移除內容',
      '移除遭檢舉的內容',
      '要移除遭檢舉的內容嗎？',
      '檢舉處理決定已儲存。',
      '審核佇列是空的。',
      '伺服器會先驗證審核員權限，再傳回任何待處理內容。',
      '此操作會關閉檢舉，並移除所指的貼文或訊息。',
      '此審核決定先前已儲存。',
    ],
    'ru': [
      'Модерация сообщества',
      'Закрыть жалобу',
      'Не удалось обработать жалобу. Обновите список и повторите попытку.',
      'Не удалось сохранить решение модератора. Обновите список и повторите попытку.',
      'Требуется доступ модератора.',
      'Открытых жалоб нет.',
      'Нет публикаций, ожидающих проверки.',
      'Открытые жалобы',
      'Публикация одобрена. 5 токенов BIL AI Boost были начислены один раз.',
      'Публикация одобрена. Повторное начисление токенов не выполнялось.',
      'Публикация отклонена. Она остаётся видимой только автору.',
      'Статус публикации: {status}',
      'Публикация отправлена на проверку человеком. До одобрения она видна только вам.',
      'Публикации, ожидающие проверки человеком',
      'Удалить содержимое',
      'Удалить содержимое, на которое пожаловались',
      'Удалить содержимое, на которое пожаловались?',
      'Решение по жалобе сохранено.',
      'Очередь модерации пуста.',
      'Сервер проверяет доступ модератора перед возвратом ожидающего содержимого.',
      'Это закроет жалобу и удалит указанную публикацию или сообщение.',
      'Это решение модератора уже было сохранено.',
    ],
    'bn': [
      'কমিউনিটি মডারেশন',
      'রিপোর্ট বন্ধ করুন',
      'রিপোর্টটি নিষ্পত্তি করা যায়নি। রিফ্রেশ করে আবার চেষ্টা করুন।',
      'মডারেশনের সিদ্ধান্ত সংরক্ষণ করা যায়নি। রিফ্রেশ করে আবার চেষ্টা করুন।',
      'মডারেটর অ্যাক্সেস প্রয়োজন।',
      'কোনো খোলা রিপোর্ট নেই।',
      'পর্যালোচনার অপেক্ষায় কোনো পোস্ট নেই।',
      'খোলা রিপোর্ট',
      'পোস্ট অনুমোদিত হয়েছে। 5টি BIL AI Boost টোকেন একবার দেওয়া হয়েছে।',
      'পোস্ট অনুমোদিত হয়েছে। কোনো টোকেন দুবার দেওয়া হয়নি।',
      'পোস্ট প্রত্যাখ্যাত হয়েছে। এটি শুধু লেখকের কাছে দৃশ্যমান থাকবে।',
      'পোস্টের অবস্থা: {status}',
      'পোস্টটি মানব পর্যালোচনার জন্য পাঠানো হয়েছে। অনুমোদন না হওয়া পর্যন্ত শুধু আপনি এটি দেখতে পারবেন।',
      'মানব পর্যালোচনার অপেক্ষায় থাকা পোস্ট',
      'কনটেন্ট সরান',
      'রিপোর্ট করা কনটেন্ট সরান',
      'রিপোর্ট করা কনটেন্ট সরাবেন?',
      'রিপোর্টের সিদ্ধান্ত সংরক্ষিত হয়েছে।',
      'মডারেশন সারি খালি।',
      'সার্ভার অপেক্ষমাণ কনটেন্ট ফেরত দেওয়ার আগে মডারেটর অ্যাক্সেস যাচাই করে।',
      'এটি রিপোর্টটি বন্ধ করে এবং উল্লেখ করা পোস্ট বা বার্তা সরিয়ে দেয়।',
      'মডারেশনের এই সিদ্ধান্ত আগেই সংরক্ষিত হয়েছে।',
    ],
    'vi': [
      'Kiểm duyệt cộng đồng',
      'Đóng báo cáo',
      'Không thể xử lý báo cáo. Hãy làm mới và thử lại.',
      'Không thể lưu quyết định kiểm duyệt. Hãy làm mới và thử lại.',
      'Cần có quyền kiểm duyệt viên.',
      'Không có báo cáo đang mở.',
      'Không có bài viết đang chờ.',
      'Báo cáo đang mở',
      'Bài viết đã được duyệt. 5 token BIL AI Boost đã được cấp một lần.',
      'Bài viết đã được duyệt. Không có token nào được cấp trùng lặp.',
      'Bài viết đã bị từ chối. Bài viết vẫn chỉ hiển thị với tác giả.',
      'Trạng thái bài viết: {status}',
      'Bài viết đã được gửi để con người xem xét. Chỉ bạn có thể xem cho đến khi được duyệt.',
      'Bài viết đang chờ con người xem xét',
      'Xóa nội dung',
      'Xóa nội dung bị báo cáo',
      'Xóa nội dung bị báo cáo?',
      'Đã lưu quyết định về báo cáo.',
      'Hàng đợi kiểm duyệt đang trống.',
      'Máy chủ xác minh quyền kiểm duyệt trước khi trả về nội dung đang chờ.',
      'Thao tác này đóng báo cáo và xóa bài viết hoặc tin nhắn được nhắc đến.',
      'Quyết định kiểm duyệt này đã được lưu trước đó.',
    ],
    'th': [
      'การตรวจสอบชุมชน',
      'ปิดรายงาน',
      'ไม่สามารถจัดการรายงานได้ โปรดรีเฟรชแล้วลองอีกครั้ง',
      'ไม่สามารถบันทึกผลการตรวจสอบได้ โปรดรีเฟรชแล้วลองอีกครั้ง',
      'ต้องมีสิทธิ์ผู้ตรวจสอบ',
      'ไม่มีรายงานที่เปิดอยู่',
      'ไม่มีโพสต์ที่รอตรวจสอบ',
      'รายงานที่เปิดอยู่',
      'อนุมัติโพสต์แล้ว มอบโทเค็น BIL AI Boost จำนวน 5 โทเค็นเพียงครั้งเดียว',
      'อนุมัติโพสต์แล้ว ไม่มีการมอบโทเค็นซ้ำ',
      'ปฏิเสธโพสต์แล้ว โพสต์นี้ยังคงแสดงแก่ผู้เขียนเท่านั้น',
      'สถานะโพสต์: {status}',
      'ส่งโพสต์ให้ผู้ดูแลตรวจสอบแล้ว จนกว่าจะอนุมัติ มีเพียงคุณที่มองเห็นโพสต์นี้',
      'โพสต์ที่รอผู้ดูแลตรวจสอบ',
      'นำเนื้อหาออก',
      'นำเนื้อหาที่ถูกรายงานออก',
      'นำเนื้อหาที่ถูกรายงานออกหรือไม่',
      'บันทึกผลการจัดการรายงานแล้ว',
      'คิวการตรวจสอบว่างอยู่',
      'เซิร์ฟเวอร์จะยืนยันสิทธิ์ผู้ตรวจสอบก่อนส่งคืนเนื้อหาที่รอดำเนินการ',
      'การดำเนินการนี้จะปิดรายงานและนำโพสต์หรือข้อความที่อ้างถึงออก',
      'ผลการตรวจสอบนี้ได้รับการบันทึกไว้แล้ว',
    ],
    'pl': [
      'Moderowanie społeczności',
      'Zamknij zgłoszenie',
      'Nie udało się rozstrzygnąć zgłoszenia. Odśwież i spróbuj ponownie.',
      'Nie udało się zapisać decyzji moderacyjnej. Odśwież i spróbuj ponownie.',
      'Wymagany jest dostęp moderatora.',
      'Brak otwartych zgłoszeń.',
      'Brak oczekujących postów.',
      'Otwarte zgłoszenia',
      'Post zatwierdzono. Jednorazowo przyznano 5 tokenów BIL AI Boost.',
      'Post zatwierdzono. Nie dodano powtórnego przyznania tokenów.',
      'Post odrzucono. Pozostaje prywatny dla autora.',
      'Stan posta: {status}',
      'Post przesłano do weryfikacji przez człowieka. Do czasu zatwierdzenia widzisz go tylko Ty.',
      'Posty oczekujące na weryfikację przez człowieka',
      'Usuń treść',
      'Usuń zgłoszoną treść',
      'Usunąć zgłoszoną treść?',
      'Decyzja dotycząca zgłoszenia została zapisana.',
      'Kolejka moderacji jest pusta.',
      'Serwer weryfikuje dostęp moderatora przed zwróceniem oczekujących treści.',
      'Spowoduje to zamknięcie zgłoszenia i usunięcie wskazanego posta lub wiadomości.',
      'Ta decyzja moderacyjna została już zapisana.',
    ],
    'nl': [
      'Communitymoderatie',
      'Melding sluiten',
      'De melding kon niet worden afgehandeld. Vernieuw en probeer het opnieuw.',
      'De moderatiebeslissing kon niet worden opgeslagen. Vernieuw en probeer het opnieuw.',
      'Moderatortoegang is vereist.',
      'Geen open meldingen.',
      'Geen berichten in afwachting.',
      'Open meldingen',
      'Bericht goedgekeurd. Er zijn eenmalig 5 BIL AI Boost-tokens toegekend.',
      'Bericht goedgekeurd. Er zijn geen tokens dubbel toegekend.',
      'Bericht afgewezen. Het blijft alleen zichtbaar voor de auteur.',
      'Berichtstatus: {status}',
      'Bericht ingediend voor menselijke beoordeling. Tot goedkeuring kunt alleen u het zien.',
      'Berichten die wachten op menselijke beoordeling',
      'Inhoud verwijderen',
      'Gemelde inhoud verwijderen',
      'Gemelde inhoud verwijderen?',
      'Beslissing over melding opgeslagen.',
      'De moderatiewachtrij is leeg.',
      'De server controleert moderatortoegang voordat inhoud in afwachting wordt teruggestuurd.',
      'Hiermee wordt de melding gesloten en het betreffende bericht verwijderd.',
      'Deze moderatiebeslissing was al opgeslagen.',
    ],
    'uk': [
      'Модерація спільноти',
      'Закрити скаргу',
      'Не вдалося опрацювати скаргу. Оновіть список і повторіть спробу.',
      'Не вдалося зберегти рішення модератора. Оновіть список і повторіть спробу.',
      'Потрібен доступ модератора.',
      'Відкритих скарг немає.',
      'Немає дописів, що очікують перевірки.',
      'Відкриті скарги',
      'Допис схвалено. 5 токенів BIL AI Boost було нараховано один раз.',
      'Допис схвалено. Повторного нарахування токенів не додано.',
      'Допис відхилено. Він залишається видимим лише автору.',
      'Стан допису: {status}',
      'Допис надіслано на перевірку людиною. До схвалення його бачите лише ви.',
      'Дописи, що очікують перевірки людиною',
      'Видалити вміст',
      'Видалити вміст, на який поскаржилися',
      'Видалити вміст, на який поскаржилися?',
      'Рішення щодо скарги збережено.',
      'Черга модерації порожня.',
      'Сервер перевіряє доступ модератора перед поверненням вмісту, що очікує розгляду.',
      'Це закриє скаргу та видалить указаний допис або повідомлення.',
      'Це рішення модератора вже було збережено.',
    ],
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = _canonicalTag(localeTag);
    if (tag == null) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Missing community-moderation copy for $tag.');
    }
    return row[index];
  }

  static bool get balanced =>
      supported.length == BilLocalePolicy.productionTags.length &&
      supported.containsAll(BilLocalePolicy.productionTags) &&
      BilLocalePolicy.productionTags.containsAll(supported) &&
      supported.containsAll(rows.keys) &&
      rows.keys.toSet().containsAll(supported) &&
      _sameValues(rows['en'], sources) &&
      rows.entries.every(
        (entry) =>
            entry.value.length == sources.length &&
            entry.value.every((value) => value.trim().isNotEmpty) &&
            _placeholdersMatch(entry.value) &&
            (entry.key == 'en' || _isTranslated(entry.value)),
      );

  static String? _canonicalTag(String localeTag) {
    final exact = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (exact != null) return exact;
    final language = localeTag
        .trim()
        .replaceAll('_', '-')
        .toLowerCase()
        .split('-')
        .first;
    final matches = supported
        .where((candidate) => candidate.toLowerCase() == language)
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  static bool _isTranslated(List<String> translations) {
    for (var index = 0; index < sources.length; index++) {
      if (translations[index] == sources[index]) return false;
    }
    return true;
  }

  static bool _placeholdersMatch(List<String> translations) {
    for (var index = 0; index < sources.length; index++) {
      final expected = _placeholders(sources[index]);
      final actual = _placeholders(translations[index]);
      if (expected.length != actual.length) return false;
      for (
        var placeholderIndex = 0;
        placeholderIndex < expected.length;
        placeholderIndex++
      ) {
        if (expected[placeholderIndex] != actual[placeholderIndex]) {
          return false;
        }
      }
    }
    return true;
  }

  static List<String> _placeholders(String value) => RegExp(
    r'\{[^}]+\}',
  ).allMatches(value).map((match) => match.group(0)!).toList(growable: false);

  static bool _sameValues(List<String>? left, List<String> right) {
    if (left == null || left.length != right.length) return false;
    for (var index = 0; index < right.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
