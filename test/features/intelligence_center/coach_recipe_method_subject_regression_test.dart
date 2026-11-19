import 'dart:convert';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_catalog_grounding.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/recipe_coach_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final lookup = RecipeCoachLookup();
  const deferred = <String, String>{
    "actual-ar-walking":
        "اقترح طريقة بسيطة لتوزيع المشي خلال اليوم، دون إنشاء خطة أو تسجيل أي بيانات.",
    "ar-goals":
        "اقترح طريقة بسيطة لمراجعة أهدافي خلال اليوم دون إنشاء أي بيانات.",
    "ar-training":
        "اقترح طريقة بسيطة لتنظيم التدريب خلال اليوم دون تسجيل أي بيانات.",
    "ar-sleep":
        "اقترح طريقة بسيطة لتحسين النوم خلال اليوم دون تسجيل أي بيانات.",
    "ar-water":
        "اقترح طريقة بسيطة لتوزيع شرب الماء خلال اليوم دون تسجيل أي بيانات.",
    "ar-settings":
        "اعطني طريقة بسيطة لتغيير إعدادات التنبيهات دون تغيير أي بيانات.",
    "ar-weight":
        "اعطني طريقة بسيطة لمتابعة وزني خلال الشهر دون تسجيل أي بيانات.",
    "ar-prepare": "تحضير روتين بسيط للنوم دون تسجيل أي بيانات.",
    "en-make-sleep": "Make a simple sleep plan without saving any data.",
    "en-morning-water":
        "Make a morning hydration reminder without changing settings.",
    "en-walking":
        "Make a simple walking schedule for today without saving data.",
    "fr-prepare":
        "Préparer une routine simple de sommeil sans enregistrer de données.",
    "es-prepare": "Preparar una rutina simple para dormir sin guardar datos.",
    "pt-prepare": "Preparar uma rotina simples de sono sem salvar dados.",
    "it-prepare": "Preparar una semplice routine del sonno senza salvare dati.",
    "tr-tarif": "Uyku hedeflerimi takip etmek için basit bir tarif ver.",
    "tr-tarifi": "Basit bir uyku rutini tarifi ver.",
    "tr-prepare": "Basit bir uyku rutini hazırla.",
    "de-prepare":
        "Eine einfache Schlafroutine zubereiten, ohne Daten zu speichern.",
    "ur-method": "نیند بہتر کرنے کی ایک سادہ ترکیب بتائیں۔",
    "fa-instructions": "دستور ساده برای تنظیم خواب بدون ثبت داده",
    "fa-way": "طرز تنظیم خواب بدون ثبت داده",
    "hi-method": "नींद सुधारने की सरल विधि बताएं।",
    "ja-method": "作り方 睡眠 スケジュール",
    "ko-method": "만드는법 수면 일정",
    "zh-method": "做法 睡眠 计划",
    "ru-prepare": "Приготовить простой план сна без сохранения данных.",
    "uk-prepare": "Приготувати простий план сну без збереження даних.",
    "th-formula": "สูตร การนอนหลับ",
    "th-method": "วิธีทำ ตารางนอน",
    "vi-cong-only": "Công việc và giấc ngủ hôm nay, không lưu dữ liệu.",
    "vi-thuc-only": "Thức dậy đúng giờ và ngủ đủ, không lưu dữ liệu.",
  };
  for (final entry in deferred.entries) {
    test('${entry.key} delegates non-food method to ordinary Coach', () async {
      final answer = await lookup.answer(
        question: entry.value,
        locale: entry.key == 'actual-ar-walking'
            ? 'ar'
            : entry.key.split('-').first,
      );
      expect(
        answer,
        isNull,
        reason: answer == null
            ? null
            : jsonEncode({'ids': answer.recipeIds, 'text': answer.text}),
      );
    });
  }
  test('actual walking question bypasses whole catalog shortcut', () async {
    final answer = await CoachCatalogGrounding().answer(
      question: deferred['actual-ar-walking']!,
      locale: 'ar',
    );
    expect(
      answer,
      isNull,
      reason: answer == null
          ? null
          : jsonEncode({
              'text': answer.text,
              'ids': answer.links.map((link) => link.id).toList(),
            }),
    );
  });
  const named = <(String, String, String)>[
    ("ar", "اعطني طريقة شكشوكه", "shakshuka"),
    ("en", "How to make herbed shakshuka", "shakshuka"),
    ("fr", "Préparer herbed shakshuka", "shakshuka"),
    ("es", "Preparar herbed shakshuka", "shakshuka"),
    ("tr", "Shakshuka tarifi", "shakshuka"),
    ("de", "Herbed shakshuka zubereiten", "shakshuka"),
    ("en", "Give me the shakshuka recipe", "shakshuka"),
    ("ar", "اعطني وصفة شكشوكة", "shakshuka"),
    ("en", "Cook chicken", ""),
    ("en", "Give me a chicken recipe", ""),
    ("vi", "Công thức herbed shakshuka", "shakshuka"),
  ];
  for (final (locale, question, id) in named) {
    test(
      '$locale preserves explicit cooking or grounded recipe: $question',
      () async {
        final answer = await lookup.answer(question: question, locale: locale);
        expect(answer, isNotNull);
        if (id.isNotEmpty) expect(answer!.recipeId, id);
        expect(answer!.links, isNotEmpty);
        expect(answer.links.every((link) => link.isTrustedLocalRoute), isTrue);
      },
    );
  }
}
