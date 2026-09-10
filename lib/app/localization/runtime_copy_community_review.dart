/// Community discovery copy. UI language never rewrites member-authored text.
abstract final class CommunityReviewCopy {
  static const keys = <String>[
    'Posts',
    'Shared with BIL members',
    'Workout videos',
    'Videos & training routines',
  ];

  static const translations = <String, List<String>>{
    'en': [
      'Posts',
      'Shared with BIL members',
      'Workout videos',
      'Videos & training routines',
    ],
    'ar': [
      'المنشورات',
      'مشاركات أعضاء BIL',
      'فيديوهات التمارين',
      'فيديوهات وروتينات تدريبية',
    ],
    'fr': [
      'Publications',
      'Partagé avec les membres BIL',
      'Vidéos d’entraînement',
      'Vidéos et routines d’entraînement',
    ],
    'es': [
      'Publicaciones',
      'Compartido con miembros de BIL',
      'Vídeos de ejercicio',
      'Vídeos y rutinas de entrenamiento',
    ],
    'tr': [
      'Gönderiler',
      'BIL üyeleriyle paylaşılanlar',
      'Egzersiz videoları',
      'Videolar ve antrenman rutinleri',
    ],
    'de': [
      'Beiträge',
      'Mit BIL-Mitgliedern geteilt',
      'Trainingsvideos',
      'Videos und Trainingsroutinen',
    ],
    'it': [
      'Post',
      'Condiviso con i membri BIL',
      'Video di allenamento',
      'Video e routine di allenamento',
    ],
    'pt-BR': [
      'Publicações',
      'Compartilhado com membros BIL',
      'Vídeos de treino',
      'Vídeos e rotinas de treino',
    ],
    'pt-PT': [
      'Publicações',
      'Partilhado com membros BIL',
      'Vídeos de treino',
      'Vídeos e rotinas de treino',
    ],
    'ur': [
      'پوسٹس',
      'BIL اراکین کی شیئر کردہ پوسٹس',
      'ورزش کی ویڈیوز',
      'ویڈیوز اور ورزش کے معمولات',
    ],
    'fa': [
      'پست‌ها',
      'اشتراک‌گذاری با اعضای BIL',
      'ویدیوهای تمرین',
      'ویدیوها و برنامه‌های تمرین',
    ],
    'hi': [
      'पोस्ट',
      'BIL सदस्यों के साथ साझा किया गया',
      'व्यायाम वीडियो',
      'वीडियो और व्यायाम दिनचर्याएँ',
    ],
    'id': [
      'Postingan',
      'Dibagikan dengan anggota BIL',
      'Video latihan',
      'Video dan rutinitas latihan',
    ],
    'ms': [
      'Siaran',
      'Dikongsi dengan ahli BIL',
      'Video senaman',
      'Video dan rutin latihan',
    ],
    'ja': ['投稿', 'BILメンバーと共有', 'トレーニング動画', '動画とトレーニングルーティン'],
    'ko': ['게시물', 'BIL 회원과 공유', '운동 영상', '영상 및 운동 루틴'],
    'zh-Hans': ['动态', '与 BIL 成员分享', '训练视频', '视频与训练计划'],
    'zh-Hant': ['動態', '與 BIL 成員分享', '訓練影片', '影片與訓練計畫'],
    'ru': [
      'Публикации',
      'Публикации участников BIL',
      'Видео тренировок',
      'Видео и программы тренировок',
    ],
    'bn': [
      'পোস্ট',
      'BIL সদস্যদের সঙ্গে শেয়ার করা',
      'ব্যায়ামের ভিডিও',
      'ভিডিও ও ব্যায়ামের রুটিন',
    ],
    'vi': [
      'Bài viết',
      'Chia sẻ với thành viên BIL',
      'Video tập luyện',
      'Video và lịch tập luyện',
    ],
    'th': [
      'โพสต์',
      'แชร์กับสมาชิก BIL',
      'วิดีโอออกกำลังกาย',
      'วิดีโอและโปรแกรมออกกำลังกาย',
    ],
    'pl': [
      'Posty',
      'Udostępnione członkom BIL',
      'Filmy treningowe',
      'Filmy i plany treningowe',
    ],
    'nl': [
      'Berichten',
      'Gedeeld met BIL-leden',
      'Trainingsvideo’s',
      'Video’s en trainingsroutines',
    ],
    'uk': [
      'Дописи',
      'Дописи учасників BIL',
      'Відео тренувань',
      'Відео та програми тренувань',
    ],
  };

  static String? resolve(String english, String localeTag) {
    final status = statusKeys.contains(english);
    final index = (status ? statusKeys : keys).indexOf(english);
    if (index < 0) return null;
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    for (final entry in (status ? statusTranslations : translations).entries) {
      if (entry.key.toLowerCase() == normalized) return entry.value[index];
    }
    return null;
  }

  static const statusKeys = <String>[
    'Approved',
    'Pending review',
    'Rejected',
    'Request pending',
  ];

  static const statusTranslations = <String, List<String>>{
    'en': ['Approved', 'Pending review', 'Rejected', 'Request pending'],
    'ar': ['معتمد', 'بانتظار المراجعة', 'مرفوض', 'الطلب قيد الانتظار'],
    'fr': ['Approuvé', 'En attente d’examen', 'Refusé', 'Demande en attente'],
    'es': [
      'Aprobado',
      'Pendiente de revisión',
      'Rechazado',
      'Solicitud pendiente',
    ],
    'tr': ['Onaylandı', 'İnceleme bekliyor', 'Reddedildi', 'İstek beklemede'],
    'de': ['Genehmigt', 'Wird geprüft', 'Abgelehnt', 'Anfrage ausstehend'],
    'it': [
      'Approvato',
      'In attesa di revisione',
      'Rifiutato',
      'Richiesta in sospeso',
    ],
    'pt-BR': [
      'Aprovado',
      'Aguardando análise',
      'Rejeitado',
      'Solicitação pendente',
    ],
    'pt-PT': ['Aprovado', 'A aguardar revisão', 'Rejeitado', 'Pedido pendente'],
    'ur': ['منظور شدہ', 'جائزے کا منتظر', 'مسترد', 'درخواست زیرِ التوا'],
    'fa': ['تأیید شده', 'در انتظار بررسی', 'رد شده', 'درخواست در انتظار'],
    'hi': ['स्वीकृत', 'समीक्षा लंबित', 'अस्वीकृत', 'अनुरोध लंबित'],
    'id': [
      'Disetujui',
      'Menunggu peninjauan',
      'Ditolak',
      'Permintaan tertunda',
    ],
    'ms': ['Diluluskan', 'Menunggu semakan', 'Ditolak', 'Permintaan menunggu'],
    'ja': ['承認済み', '審査待ち', '却下', '申請中'],
    'ko': ['승인됨', '검토 대기 중', '거절됨', '요청 대기 중'],
    'zh-Hans': ['已通过', '待审核', '已拒绝', '请求待处理'],
    'zh-Hant': ['已通過', '待審核', '已拒絕', '請求待處理'],
    'ru': ['Одобрено', 'На проверке', 'Отклонено', 'Запрос ожидает ответа'],
    'bn': [
      'অনুমোদিত',
      'পর্যালোচনার অপেক্ষায়',
      'প্রত্যাখ্যাত',
      'অনুরোধ অপেক্ষমাণ',
    ],
    'vi': ['Đã duyệt', 'Chờ xét duyệt', 'Bị từ chối', 'Yêu cầu đang chờ'],
    'th': ['อนุมัติแล้ว', 'รอการตรวจสอบ', 'ถูกปฏิเสธ', 'คำขอรอดำเนินการ'],
    'pl': [
      'Zatwierdzono',
      'Oczekuje na sprawdzenie',
      'Odrzucono',
      'Oczekujące zaproszenie',
    ],
    'nl': [
      'Goedgekeurd',
      'Wacht op beoordeling',
      'Afgewezen',
      'Verzoek in behandeling',
    ],
    'uk': [
      'Схвалено',
      'Очікує перевірки',
      'Відхилено',
      'Запит очікує відповіді',
    ],
  };
}
