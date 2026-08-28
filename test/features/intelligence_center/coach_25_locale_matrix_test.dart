import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_language_resolver.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_speech_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/intelligence_locale_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach resolves a real user question for every release locale', () {
    const samples = <String, String>{
      'ar': 'كم تبقى لي من السعرات اليوم؟',
      'en': 'How many calories remain today?',
      'fr': 'Combien de calories reste aujourd’hui ?',
      'es': '¿Cuántas calorías quedan hoy?',
      'tr': 'Bugün kaç kalori kaldı?',
      'de': 'Wie viele Kalorien sind heute übrig?',
      'it': 'Quante calorie rimangono oggi?',
      'pt-BR': 'Quantas calorias restam hoje?',
      'pt-PT': 'Quantas calorias restam hoje?',
      'ur': 'آج میری کتنی کیلوریز باقی ہیں؟',
      'fa': 'امروز چند کالری برای من باقی مانده؟',
      'hi': 'आज मेरी कितनी कैलोरी बची हैं?',
      'id': 'Berapa asupan kalori yang tersisa hari ini?',
      'ms': 'Berapa kalori berbaki untuk hari ini?',
      'ja': '今日はあと何カロリー残っていますか？',
      'ko': '오늘 칼로리가 얼마나 남았나요?',
      'zh-Hans': '我今天还剩多少卡路里？',
      'zh-Hant': '我今天還剩多少卡路里？',
      'ru': 'Сколько калорий осталось сегодня?',
      'bn': 'আজ আমার কত ক্যালোরি বাকি আছে?',
      'vi': 'Hôm nay tôi còn lại bao nhiêu calo?',
      'th': 'วันนี้ฉันเหลือแคลอรีเท่าไร?',
      'pl': 'Ile kalorii zostało mi dzisiaj?',
      'nl': 'Hoeveel calorieën heb ik vandaag over?',
      'uk': 'Скільки калорій залишилося сьогодні?',
    };
    expect(samples.keys.toSet(), BilLocalePolicy.productionTags);

    const resolver = CoachLanguageResolver();
    for (final entry in samples.entries) {
      final result = resolver.resolve(input: entry.value, uiLocale: entry.key);
      expect(result.languageTag, entry.key, reason: entry.key);
    }
  });

  test('weight sleep and goal-analysis routing works in every locale', () {
    const weight = <String, String>{
      'ar': 'كم وزني؟',
      'en': 'What is my weight?',
      'fr': 'Quel est mon poids ?',
      'es': '¿Cuánto peso?',
      'tr': 'Kilom kaç?',
      'de': 'Wie viel wiege ich?',
      'it': 'Qual è il mio peso?',
      'pt-BR': 'Qual é o meu peso atual?',
      'pt-PT': 'Qual é o meu peso atual?',
      'ur': 'میرا وزن کتنا ہے؟',
      'fa': 'وزن من چقدر است؟',
      'hi': 'मेरा वजन कितना है?',
      'id': 'Berapa berat saya?',
      'ms': 'Berapa berat saya?',
      'ja': '私の体重は？',
      'ko': '내 체중은 얼마인가요?',
      'zh-Hans': '我的体重是多少？',
      'zh-Hant': '我的體重是多少？',
      'ru': 'Какой мой вес?',
      'bn': 'আমার ওজন কত?',
      'vi': 'Cân nặng của tôi là bao nhiêu?',
      'th': 'น้ำหนักของฉันเท่าไร?',
      'pl': 'Ile ważę?',
      'nl': 'Hoeveel weeg ik?',
      'uk': 'Яка моя вага?',
    };
    const sleep = <String, String>{
      'ar': 'كم لازم أنام؟',
      'en': 'How much should I sleep?',
      'fr': 'Combien dois-je dormir ?',
      'es': '¿Cuánto debo dormir?',
      'tr': 'Ne kadar uyumalıyım?',
      'de': 'Wie lange soll ich schlafen?',
      'it': 'Quanto devo dormire?',
      'pt-BR': 'Quanto devo dormir?',
      'pt-PT': 'Quanto devo dormir?',
      'ur': 'مجھے کتنی نیند چاہیے؟',
      'fa': 'چقدر باید بخوابم؟',
      'hi': 'मुझे कितनी नींद चाहिए?',
      'id': 'Berapa lama saya harus tidur?',
      'ms': 'Berapa lama saya perlu tidur?',
      'ja': 'どのくらい睡眠が必要ですか？',
      'ko': '수면은 얼마나 필요해요?',
      'zh-Hans': '每晚需要多少睡眠？',
      'zh-Hant': '每晚需要多少睡眠？',
      'ru': 'Сколько мне нужно спать?',
      'bn': 'আমার কত ঘুম দরকার?',
      'vi': 'Tôi cần ngủ bao lâu?',
      'th': 'ฉันควรนอนกี่ชั่วโมง?',
      'pl': 'Ile godzin powinienem spać?',
      'nl': 'Hoe lang moet ik slapen?',
      'uk': 'Скільки мені потрібно спати?',
    };
    const goal = <String, String>{
      'ar': 'حلل متى أصل إلى هدفي مع الرياضة والحمية',
      'en': 'Analyze my goal timeline with diet and exercise',
      'fr': 'Analyse mon objectif avec le régime et l’entraînement',
      'es': 'Analiza mi meta con dieta y ejercicio',
      'tr': 'Hedefimi diyet ve antrenmanla analiz et',
      'de': 'Analysiere mein Ziel mit Diät und Training',
      'it': 'Analizza il mio obiettivo con dieta e allenamento',
      'pt-BR': 'Analise meu objetivo com dieta e treino',
      'pt-PT': 'Analise o meu objetivo com dieta e treino',
      'ur': 'غذا اور ورزش کے ساتھ میرے ہدف کا تجزیہ کریں',
      'fa': 'هدف من را با رژیم و ورزش تحلیل کن',
      'hi': 'आहार और व्यायाम के साथ मेरे लक्ष्य का विश्लेषण करें',
      'id': 'Analisis tujuan saya dengan diet dan olahraga',
      'ms': 'Analisis matlamat saya dengan diet dan senaman',
      'ja': '食事と運動で目標までの期間を分析して',
      'ko': '식단과 운동으로 목표 기간을 분석해 줘',
      'zh-Hans': '分析饮食和运动对目标时间的影响',
      'zh-Hant': '分析飲食和運動對目標時間的影響',
      'ru': 'Проанализируй мою цель с диетой и упражнениями',
      'bn': 'খাদ্য ও ব্যায়াম দিয়ে আমার লক্ষ্য বিশ্লেষণ করুন',
      'vi': 'Phân tích mục tiêu với chế độ ăn và tập luyện',
      'th': 'วิเคราะห์เป้าหมายด้วยอาหารและการออกกำลัง',
      'pl': 'Przeanalizuj mój cel z dietą i ćwiczeniami',
      'nl': 'Analyseer mijn doel met dieet en training',
      'uk': 'Проаналізуй мою мету з дієтою та вправами',
    };
    expect(weight.keys.toSet(), BilLocalePolicy.productionTags);
    expect(sleep.keys.toSet(), BilLocalePolicy.productionTags);
    expect(goal.keys.toSet(), BilLocalePolicy.productionTags);

    const policy = CoachSpeechPolicy();
    for (final tag in BilLocalePolicy.productionTags) {
      expect(
        policy.isWeightLookup(weight[tag]!),
        isTrue,
        reason: 'weight:$tag',
      );
      expect(
        policy.planFor(weight[tag]!),
        CoachSpeechPlan.dataLookup,
        reason: 'weight:$tag',
      );
      expect(policy.isSleepQuestion(sleep[tag]!), isTrue, reason: 'sleep:$tag');
      expect(
        policy.planFor(sleep[tag]!),
        CoachSpeechPlan.directAnswer,
        reason: 'sleep:$tag',
      );
      expect(
        policy.planFor(goal[tag]!),
        CoachSpeechPlan.goalAnalysis,
        reason: 'goal:$tag',
      );
    }
  });

  test('new Coach trust and service copy has no English fallback in 25 locales', () {
    const values = <String, String>{
      'Ready': 'جاهز',
      'Your body signal now': 'إشارة جسمك الآن',
      'Remote AI consent is off': 'موافقة الذكاء البعيد متوقفة',
      'Why this answer?': 'لماذا هذا الرد؟',
      'Personalized Remote AI': 'الذكاء البعيد المخصص',
      'The personalized AI Coach is temporarily unavailable. No message was charged; try again shortly.':
          'المدرب الذكي المخصص غير متاح مؤقتًا. لم تُحتسب الرسالة؛ حاول مجددًا بعد قليل.',
      'Hello, I’m BIL Coach.': 'مرحبًا، أنا بيل كوتش.',
      'Please wait while I check your recorded data. I’ll write the answer on screen.':
          'من فضلك انتظر بينما أراجع بياناتك المسجلة. سأكتب الإجابة على الشاشة.',
      'All right. I’m checking how exercise and diet could affect the time to your goal. I’ll write the recommendations on screen.':
          'تمام. أراجع كيف يمكن للرياضة والدايت أن يؤثرا في وقت وصولك لهدفك، وسأكتب التوصيات على الشاشة.',
      'A coach voice for this language is unavailable on this device.':
          'صوت المدرب لهذه اللغة غير متاح على هذا الجهاز.',
      'I didn’t catch that. Tap the microphone and try again.':
          'لم ألتقط كلامًا واضحًا. اضغط الميكروفون وحاول مرة أخرى.',
      'Most adults need 7–9 hours of sleep each night.':
          'يحتاج معظم البالغين إلى 7–9 ساعات من النوم كل ليلة.',
    };
    for (final tag in BilLocalePolicy.productionTags) {
      for (final entry in values.entries) {
        final resolved = intelligenceTextFor(tag, entry.key, entry.value);
        expect(resolved.trim(), isNotEmpty, reason: '$tag: ${entry.key}');
        if (tag != 'en') {
          expect(resolved, isNot(entry.key), reason: '$tag: ${entry.key}');
        }
      }
    }
  });

  test('short sleep answer remains auto-speakable in all 25 locales', () {
    const english = 'Most adults need 7–9 hours of sleep each night.';
    const arabic = 'يحتاج معظم البالغين إلى 7–9 ساعات من النوم كل ليلة.';
    const policy = CoachSpeechPolicy();
    for (final tag in BilLocalePolicy.productionTags) {
      final answer = intelligenceTextFor(tag, english, arabic);
      expect(
        policy.canSpeakWithinTenSeconds(answer),
        isTrue,
        reason: '$tag: $answer',
      );
    }
  });
}
