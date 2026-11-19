import 'bil_locale_policy.dart';

/// Current privacy labels, reviewed-estimate result and Android health copy.
/// No permission, consent, platform scope or save behavior is changed here.
abstract final class CurrentReleaseRuntimeCopy {
  static const sources = <String>[
    "Allow friend requests",
    "Who can see my profile",
    "Your reviewed estimates were saved.",
    "Import steps, distance and active energy from Health Connect when available.",
  ];

  static const rows = <String, List<String>>{
    "ar": [
      "السماح بطلبات الصداقة",
      "من يمكنه رؤية ملفي الشخصي",
      "تم حفظ التقديرات التي راجعتها.",
      "استورد الخطوات والمسافة والطاقة النشطة من Health Connect عند توفرها.",
    ],
    "fr": [
      "Autoriser les demandes d’amitié",
      "Qui peut voir mon profil",
      "Les estimations que vous avez examinées ont été enregistrées.",
      "Importez les données de pas, de distance et d’énergie active depuis Health Connect lorsqu’elles sont disponibles.",
    ],
    "es": [
      "Permitir solicitudes de amistad",
      "Quién puede ver mi perfil",
      "Se guardaron las estimaciones que has revisado.",
      "Importa los pasos, la distancia y la energía activa de Health Connect cuando estén disponibles.",
    ],
    "tr": [
      "Arkadaşlık isteklerine izin ver",
      "Profilimi kimler görebilir",
      "Gözden geçirdiğiniz tahminler kaydedildi.",
      "Kullanılabilir olduğunda Health Connect’ten adım, mesafe ve aktif enerji verilerini içe aktarın.",
    ],
    "de": [
      "Freundschaftsanfragen zulassen",
      "Wer kann mein Profil sehen",
      "Die von dir überprüften Schätzwerte wurden gespeichert.",
      "Importiere Schritte, Distanz und aktive Energie aus Health Connect, sofern verfügbar.",
    ],
    "it": [
      "Consenti richieste di amicizia",
      "Chi può vedere il mio profilo",
      "Le stime che hai esaminato sono state salvate.",
      "Importa passi, distanza ed energia attiva da Health Connect quando disponibili.",
    ],
    "pt-BR": [
      "Permitir solicitações de amizade",
      "Quem pode ver meu perfil",
      "As estimativas que você revisou foram salvas.",
      "Importe passos, distância e energia ativa do Health Connect quando disponíveis.",
    ],
    "pt-PT": [
      "Permitir pedidos de amizade",
      "Quem pode ver o meu perfil",
      "As estimativas que reviu foram guardadas.",
      "Importe passos, distância e energia ativa do Health Connect quando disponíveis.",
    ],
    "ur": [
      "دوستی کی درخواستوں کی اجازت دیں",
      "میرا پروفائل کون دیکھ سکتا ہے",
      "جن تخمینوں کا آپ نے جائزہ لیا تھا وہ محفوظ کر دیے گئے ہیں۔",
      "دستیاب ہونے پر Health Connect سے قدموں، فاصلے اور فعال توانائی کا ڈیٹا درآمد کریں۔",
    ],
    "fa": [
      "اجازهٔ درخواست‌های دوستی",
      "چه کسانی می‌توانند نمایهٔ من را ببینند",
      "برآوردهایی که بررسی کردید ذخیره شدند.",
      "داده‌های گام‌ها، مسافت و انرژی فعال را در صورت دسترسی از Health Connect وارد کنید.",
    ],
    "hi": [
      "मित्रता अनुरोधों की अनुमति दें",
      "मेरी प्रोफ़ाइल कौन देख सकता है",
      "जिन अनुमानों की आपने समीक्षा की थी, वे सहेज दिए गए हैं।",
      "उपलब्ध होने पर Health Connect से कदम, दूरी और सक्रिय ऊर्जा का डेटा आयात करें।",
    ],
    "id": [
      "Izinkan permintaan pertemanan",
      "Siapa yang dapat melihat profil saya",
      "Perkiraan yang telah Anda tinjau sudah disimpan.",
      "Impor langkah, jarak, dan energi aktif dari Health Connect jika tersedia.",
    ],
    "ms": [
      "Benarkan permintaan persahabatan",
      "Siapa boleh melihat profil saya",
      "Anggaran yang telah anda semak telah disimpan.",
      "Import langkah, jarak dan tenaga aktif daripada Health Connect apabila tersedia.",
    ],
    "ja": [
      "友達リクエストを許可",
      "プロフィールを表示できる人",
      "確認した推定値を保存しました。",
      "利用可能な場合、Health Connect から歩数、距離、活動時の消費エネルギーを読み込みます。",
    ],
    "ko": [
      "친구 요청 허용",
      "내 프로필을 볼 수 있는 사람",
      "검토한 추정치가 저장되었습니다.",
      "사용 가능한 경우 Health Connect에서 걸음 수, 거리 및 활동 에너지를 가져옵니다.",
    ],
    "zh-Hans": [
      "允许好友请求",
      "谁可以查看我的个人资料",
      "已保存你审阅的估算值。",
      "在数据可用时，从 Health Connect 导入步数、距离和活动能量。",
    ],
    "zh-Hant": [
      "允許好友請求",
      "誰可以查看我的個人檔案",
      "已儲存你檢閱的估算值。",
      "資料可用時，從 Health Connect 匯入步數、距離和活動能量。",
    ],
    "ru": [
      "Разрешить запросы в друзья",
      "Кто может видеть мой профиль",
      "Оценочные значения, которые вы просмотрели, сохранены.",
      "Импортируйте шаги, расстояние и активную энергию из Health Connect, если эти данные доступны.",
    ],
    "bn": [
      "বন্ধুত্বের অনুরোধের অনুমতি দিন",
      "আমার প্রোফাইল কে দেখতে পারবেন",
      "আপনি পর্যালোচনা করেছেন এমন আনুমানিক মানগুলি সংরক্ষণ করা হয়েছে।",
      "উপলভ্য হলে Health Connect থেকে পদক্ষেপ, দূরত্ব এবং সক্রিয় শক্তির তথ্য আমদানি করুন।",
    ],
    "vi": [
      "Cho phép lời mời kết bạn",
      "Ai có thể xem hồ sơ của tôi",
      "Đã lưu các giá trị ước tính bạn đã xem xét.",
      "Nhập số bước, quãng đường và năng lượng hoạt động từ Health Connect khi có dữ liệu.",
    ],
    "th": [
      "อนุญาตคำขอเป็นเพื่อน",
      "ใครสามารถดูโปรไฟล์ของฉัน",
      "บันทึกค่าประมาณที่คุณตรวจทานแล้ว",
      "นำเข้าจำนวนก้าว ระยะทาง และพลังงานขณะทำกิจกรรมจาก Health Connect เมื่อมีข้อมูล",
    ],
    "pl": [
      "Zezwalaj na zaproszenia do znajomych",
      "Kto może zobaczyć mój profil",
      "Zapisano szacunkowe wartości, które zostały przez Ciebie sprawdzone.",
      "Importuj kroki, dystans i energię aktywności z Health Connect, gdy dane są dostępne.",
    ],
    "nl": [
      "Vriendschapsverzoeken toestaan",
      "Wie kan mijn profiel zien",
      "De door jou gecontroleerde schattingen zijn opgeslagen.",
      "Importeer stappen, afstand en actieve energie uit Health Connect als die gegevens beschikbaar zijn.",
    ],
    "uk": [
      "Дозволити запити в друзі",
      "Хто може бачити мій профіль",
      "Переглянуті вами орієнтовні значення збережено.",
      "Імпортуйте кроки, відстань і активну енергію з Health Connect, якщо ці дані доступні.",
    ],
  };

  static Set<String> get supported => {'en', ...rows.keys};

  static bool get balanced {
    final expected = BilLocalePolicy.productionTags.toSet();
    return supported.length == expected.length &&
        supported.containsAll(expected) &&
        sources.toSet().length == sources.length &&
        rows.values.every(
          (row) =>
              row.length == sources.length &&
              row.every((value) => value.trim().isNotEmpty),
        );
  }

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    var tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) {
      final language = localeTag
          .replaceAll('_', '-')
          .toLowerCase()
          .split('-')
          .first;
      final matches = supported.where(
        (candidate) => candidate.toLowerCase() == language,
      );
      if (matches.length == 1) tag = matches.single;
    }
    if (tag == 'en') return source;
    if (tag == null || !supported.contains(tag)) return null;
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Incomplete current release copy for $tag.');
    }
    return row[index];
  }
}
