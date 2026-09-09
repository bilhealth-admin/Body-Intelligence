import 'bil_locale_policy.dart';

/// Reviewed sleep-schedule copy for every production locale.
///
/// Placeholder tokens are preserved so duration values can be formatted at
/// runtime without using an English sentence as the localization key.
abstract final class SleepScheduleRuntimeCopy {
  static const scheduledWindow = 'Scheduled window';
  static const hours = '{hours} h';
  static const hoursMinutes = '{hours} h {minutes} min';
  static const localTimeGuidance =
      '{window} · local time; the phone adjusts reminders for timezone and daylight-saving changes.';
  static const goalGuidance =
      'For adults, planning goals start at 7 hours. The schedule is guidance; your recorded sleep remains the actual value and is never rewritten to match the goal.';

  static const sources = <String>{
    scheduledWindow,
    hours,
    hoursMinutes,
    localTimeGuidance,
    goalGuidance,
  };

  static const values = <String, Map<String, String>>{
    scheduledWindow: {
      'ar': 'نافذة النوم المجدولة',
      'en': scheduledWindow,
      'fr': 'Plage horaire programmée',
      'es': 'Horario programado',
      'tr': 'Planlanan zaman aralığı',
      'de': 'Geplantes Zeitfenster',
      'it': 'Fascia oraria programmata',
      'pt-BR': 'Janela programada',
      'pt-PT': 'Período programado',
      'ur': 'طے شدہ دورانیہ',
      'fa': 'بازه زمانی برنامه‌ریزی‌شده',
      'hi': 'निर्धारित समयावधि',
      'id': 'Jendela terjadwal',
      'ms': 'Tetingkap berjadual',
      'ja': '設定した時間帯',
      'ko': '예약된 시간대',
      'zh-Hans': '计划时段',
      'zh-Hant': '排定時段',
      'ru': 'Запланированный период',
      'bn': 'নির্ধারিত সময়সীমা',
      'vi': 'Khung giờ đã lên lịch',
      'th': 'ช่วงเวลาที่กำหนด',
      'pl': 'Zaplanowany przedział',
      'nl': 'Gepland tijdvenster',
      'uk': 'Запланований період',
    },
    hours: {
      'ar': '{hours} س',
      'en': hours,
      'fr': '{hours} heures',
      'es': '{hours} horas',
      'tr': '{hours} sa',
      'de': '{hours} Std.',
      'it': '{hours} ore',
      'pt-BR': '{hours} horas',
      'pt-PT': '{hours} horas',
      'ur': '{hours} گھنٹے',
      'fa': '{hours} ساعت',
      'hi': '{hours} घंटे',
      'id': '{hours} jam',
      'ms': '{hours} jam',
      'ja': '{hours}時間',
      'ko': '{hours}시간',
      'zh-Hans': '{hours}小时',
      'zh-Hant': '{hours}小時',
      'ru': '{hours} ч',
      'bn': '{hours} ঘণ্টা',
      'vi': '{hours} giờ',
      'th': '{hours} ชม.',
      'pl': '{hours} godz.',
      'nl': '{hours} uur',
      'uk': '{hours} год',
    },
    hoursMinutes: {
      'ar': '{hours} س {minutes} د',
      'en': hoursMinutes,
      'fr': '{hours} heures {minutes} min',
      'es': '{hours} horas {minutes} min',
      'tr': '{hours} sa {minutes} dk',
      'de': '{hours} Std. {minutes} Min.',
      'it': '{hours} ore {minutes} min',
      'pt-BR': '{hours} horas {minutes} min',
      'pt-PT': '{hours} horas {minutes} min',
      'ur': '{hours} گھنٹے {minutes} منٹ',
      'fa': '{hours} ساعت و {minutes} دقیقه',
      'hi': '{hours} घंटे {minutes} मिनट',
      'id': '{hours} jam {minutes} menit',
      'ms': '{hours} jam {minutes} minit',
      'ja': '{hours}時間{minutes}分',
      'ko': '{hours}시간 {minutes}분',
      'zh-Hans': '{hours}小时{minutes}分钟',
      'zh-Hant': '{hours}小時{minutes}分鐘',
      'ru': '{hours} ч {minutes} мин',
      'bn': '{hours} ঘণ্টা {minutes} মিনিট',
      'vi': '{hours} giờ {minutes} phút',
      'th': '{hours} ชม. {minutes} นาที',
      'pl': '{hours} godz. {minutes} min',
      'nl': '{hours} uur {minutes} min',
      'uk': '{hours} год {minutes} хв',
    },
    localTimeGuidance: {
      'ar':
          '{window} · بالتوقيت المحلي؛ يضبط الهاتف التذكيرات عند تغيّر المنطقة الزمنية والتوقيت الصيفي.',
      'en': localTimeGuidance,
      'fr':
          '{window} · heure locale ; le téléphone ajuste les rappels selon le fuseau horaire et les changements d’heure.',
      'es':
          '{window} · hora local; el teléfono ajusta los recordatorios a los cambios de zona horaria y horario de verano.',
      'tr':
          '{window} · yerel saat; telefon, saat dilimi ve yaz saati değişikliklerinde hatırlatıcıları ayarlar.',
      'de':
          '{window} · Ortszeit; das Telefon passt Erinnerungen an Zeitzonen- und Sommerzeitänderungen an.',
      'it':
          '{window} · ora locale; il telefono adatta i promemoria ai cambi di fuso orario e ora legale.',
      'pt-BR':
          '{window} · horário local; o celular ajusta os lembretes às mudanças de fuso horário e horário de verão.',
      'pt-PT':
          '{window} · hora local; o telemóvel ajusta os lembretes a alterações de fuso horário e de hora de verão.',
      'ur':
          '{window} · مقامی وقت؛ فون ٹائم زون اور ڈے لائٹ سیونگ کی تبدیلیوں کے مطابق یاددہانیاں ایڈجسٹ کرتا ہے۔',
      'fa':
          '{window} · زمان محلی؛ تلفن یادآوری‌ها را با تغییر منطقه زمانی و ساعت تابستانی تنظیم می‌کند.',
      'hi':
          '{window} · स्थानीय समय; फ़ोन समय-क्षेत्र और डेलाइट सेविंग बदलावों के अनुसार रिमाइंडर समायोजित करता है।',
      'id':
          '{window} · waktu setempat; ponsel menyesuaikan pengingat saat zona waktu dan waktu musim panas berubah.',
      'ms':
          '{window} · waktu tempatan; telefon melaraskan peringatan apabila zon waktu dan waktu musim panas berubah.',
      'ja': '{window} · 現地時刻。タイムゾーンや夏時間の変更に合わせて、スマートフォンがリマインダーを調整します。',
      'ko': '{window} · 현지 시간. 휴대전화가 시간대 및 일광 절약 시간 변경에 맞춰 알림을 조정합니다.',
      'zh-Hans': '{window} · 当地时间；手机会根据时区和夏令时变化调整提醒。',
      'zh-Hant': '{window} · 當地時間；手機會依時區和日光節約時間變更調整提醒。',
      'ru':
          '{window} · местное время; телефон корректирует напоминания при смене часового пояса и переходе на летнее время.',
      'bn':
          '{window} · স্থানীয় সময়; সময় অঞ্চল ও ডেলাইট সেভিং পরিবর্তন হলে ফোন রিমাইন্ডার সামঞ্জস্য করে।',
      'vi':
          '{window} · giờ địa phương; điện thoại điều chỉnh lời nhắc khi múi giờ và giờ mùa hè thay đổi.',
      'th':
          '{window} · เวลาท้องถิ่น โทรศัพท์จะปรับการแจ้งเตือนเมื่อเขตเวลาหรือเวลาออมแสงเปลี่ยน',
      'pl':
          '{window} · czas lokalny; telefon dostosowuje przypomnienia do zmian strefy czasowej i czasu letniego.',
      'nl':
          '{window} · lokale tijd; de telefoon past herinneringen aan bij wijzigingen in tijdzone en zomertijd.',
      'uk':
          '{window} · місцевий час; телефон коригує нагадування при зміні часового поясу та переході на літній час.',
    },
    goalGuidance: {
      'ar':
          'للبالغين تبدأ أهداف التخطيط من 7 ساعات. الجدول إرشادي؛ ويبقى نومك المسجل هو القيمة الفعلية ولا يُعدّل ليتوافق مع الهدف.',
      'en': goalGuidance,
      'fr':
          'Pour les adultes, les objectifs de planification commencent à 7 heures. Le programme est indicatif ; votre sommeil enregistré reste la valeur réelle et n’est jamais modifié pour correspondre à l’objectif.',
      'es':
          'Para adultos, los objetivos de planificación comienzan en 7 horas. El horario es orientativo; el sueño registrado sigue siendo el valor real y nunca se modifica para coincidir con el objetivo.',
      'tr':
          'Yetişkinler için planlama hedefleri 7 saatten başlar. Program yalnızca rehberdir; kaydedilen uykunuz gerçek değer olarak kalır ve hedefe uyması için asla değiştirilmez.',
      'de':
          'Für Erwachsene beginnen Planungsziele bei 7 Stunden. Der Zeitplan dient nur als Orientierung; Ihr aufgezeichneter Schlaf bleibt der tatsächliche Wert und wird nie an das Ziel angepasst.',
      'it':
          'Per gli adulti, gli obiettivi di pianificazione partono da 7 ore. Il programma è indicativo; il sonno registrato resta il valore effettivo e non viene mai modificato per coincidere con l’obiettivo.',
      'pt-BR':
          'Para adultos, as metas de planejamento começam em 7 horas. O horário é apenas uma orientação; o sono registrado continua sendo o valor real e nunca é alterado para corresponder à meta.',
      'pt-PT':
          'Para adultos, os objetivos de planeamento começam nas 7 horas. O horário é apenas uma orientação; o sono registado continua a ser o valor real e nunca é alterado para corresponder ao objetivo.',
      'ur':
          'بالغ افراد کے لیے منصوبہ بندی کے اہداف 7 گھنٹے سے شروع ہوتے ہیں۔ شیڈول صرف رہنمائی ہے؛ آپ کی ریکارڈ شدہ نیند اصل قدر رہتی ہے اور ہدف سے ملانے کے لیے کبھی تبدیل نہیں کی جاتی۔',
      'fa':
          'برای بزرگسالان، هدف‌گذاری از ۷ ساعت آغاز می‌شود. برنامه فقط راهنماست؛ خواب ثبت‌شده مقدار واقعی باقی می‌ماند و هرگز برای تطبیق با هدف بازنویسی نمی‌شود.',
      'hi':
          'वयस्कों के लिए योजना लक्ष्य 7 घंटे से शुरू होते हैं। समय-सारणी केवल मार्गदर्शन है; दर्ज की गई नींद वास्तविक मान बनी रहती है और लक्ष्य से मिलाने के लिए कभी नहीं बदली जाती।',
      'id':
          'Untuk orang dewasa, target perencanaan dimulai dari 7 jam. Jadwal hanya sebagai panduan; tidur yang tercatat tetap menjadi nilai aktual dan tidak pernah diubah agar sesuai target.',
      'ms':
          'Bagi orang dewasa, sasaran perancangan bermula pada 7 jam. Jadual hanyalah panduan; tidur yang direkodkan kekal sebagai nilai sebenar dan tidak pernah diubah untuk menyamai sasaran.',
      'ja':
          '成人の計画目標は7時間から始まります。スケジュールは目安であり、記録された睡眠が実際の値です。目標に合わせて書き換えられることはありません。',
      'ko':
          '성인의 계획 목표는 7시간부터 시작합니다. 일정은 참고용이며 기록된 수면이 실제 값으로 유지되고, 목표에 맞추기 위해 변경되지 않습니다.',
      'zh-Hans': '成人的规划目标从7小时开始。时间表仅供参考；记录的睡眠始终是实际值，绝不会为了匹配目标而改写。',
      'zh-Hant': '成人的規劃目標從7小時開始。時間表僅供參考；記錄的睡眠始終是實際值，絕不會為了符合目標而改寫。',
      'ru':
          'Для взрослых плановые цели начинаются с 7 часов. Расписание носит рекомендательный характер; записанный сон остаётся фактическим значением и никогда не изменяется под цель.',
      'bn':
          'প্রাপ্তবয়স্কদের পরিকল্পনার লক্ষ্য ৭ ঘণ্টা থেকে শুরু হয়। সময়সূচি শুধু নির্দেশনা; রেকর্ড করা ঘুমই প্রকৃত মান থাকে এবং লক্ষ্য মেলাতে কখনো পরিবর্তন করা হয় না।',
      'vi':
          'Với người lớn, mục tiêu lập kế hoạch bắt đầu từ 7 giờ. Lịch trình chỉ mang tính hướng dẫn; thời gian ngủ đã ghi vẫn là giá trị thực và không bao giờ bị sửa để khớp mục tiêu.',
      'th':
          'สำหรับผู้ใหญ่ เป้าหมายการวางแผนเริ่มที่ 7 ชั่วโมง ตารางเป็นเพียงคำแนะนำ การนอนที่บันทึกไว้ยังคงเป็นค่าจริงและจะไม่ถูกแก้ให้ตรงกับเป้าหมาย',
      'pl':
          'Dla dorosłych cele planowania zaczynają się od 7 godzin. Harmonogram jest wskazówką; zapisany sen pozostaje wartością rzeczywistą i nigdy nie jest zmieniany, aby dopasować go do celu.',
      'nl':
          'Voor volwassenen beginnen planningsdoelen bij 7 uur. Het schema is alleen een richtlijn; uw geregistreerde slaap blijft de werkelijke waarde en wordt nooit aangepast aan het doel.',
      'uk':
          'Для дорослих планові цілі починаються із 7 годин. Розклад має рекомендаційний характер; записаний сон залишається фактичним значенням і ніколи не змінюється під ціль.',
    },
  };

  static String? resolve(String source, String localeTag) {
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return null;
    return values[source]?[tag];
  }

  static bool get balanced =>
      values.keys.toSet().containsAll(sources) &&
      sources.containsAll(values.keys) &&
      values.values.every(
        (translations) =>
            translations.keys.toSet().containsAll(
              BilLocalePolicy.productionTags,
            ) &&
            BilLocalePolicy.productionTags.toSet().containsAll(
              translations.keys,
            ) &&
            translations.values.every((value) => value.trim().isNotEmpty),
      );
}
