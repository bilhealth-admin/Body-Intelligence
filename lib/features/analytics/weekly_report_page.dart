import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../profile/providers/user_profile_provider.dart';
import '../commerce/domain/commerce_entitlement.dart';
import '../commerce/providers/commerce_providers.dart';
import 'weekly_report_engine.dart';
import 'weekly_report_provider.dart';

part 'weekly_report_body.dart';
part 'weekly_report_food.dart';
part 'weekly_report_components.dart';
part 'weekly_report_locale_copy.dart';

String _t(BuildContext context, String key) {
  final locale = Localizations.localeOf(context);
  final tag = locale.toLanguageTag();
  final code = locale.languageCode;
  final english = (_copy[key] ?? const {})['en'] ?? key;
  return (_copy[key] ?? const {})[tag] ??
      (_copy[key] ?? const {})[code] ??
      context.strings.text(english);
}

String _weeklyPremiumState(BuildContext context, bool active) {
  final language = Localizations.localeOf(context).languageCode;
  final copy = active
      ? const {
          'ar': 'رؤى Pro مفعّلة',
          'en': 'Pro insights active',
          'fr': 'Analyses Pro activées',
          'es': 'Análisis Pro activos',
          'tr': 'Pro analizleri etkin',
        }
      : const {
          'ar': 'افتح رؤى Pro المتقدمة',
          'en': 'Unlock advanced Pro insights',
          'fr': 'Débloquer les analyses Pro avancées',
          'es': 'Desbloquear análisis Pro avanzados',
          'tr': 'Gelişmiş Pro analizlerinin kilidini aç',
        };
  return copy[language] ?? context.strings.text(copy['en']!);
}

const _copy = <String, Map<String, String>>{
  'title': {
    'ar': 'تقريرك الأسبوعي',
    'en': 'Weekly Digest',
    'fr': 'Votre rapport hebdomadaire',
    'es': 'Tu informe semanal',
    'tr': 'Haftalık raporunuz',
  },
  'read_error': {
    'ar': 'تعذرت قراءة السجلات المحفوظة. لم تفقد بياناتك؛ حاول مرة أخرى.',
    'en': 'Saved records could not be read. Your data was not lost; try again.',
    'fr':
        'Impossible de lire les données enregistrées. Vos données ne sont pas perdues.',
    'es': 'No se pudieron leer los registros. Tus datos no se han perdido.',
    'tr': 'Kayıtlar okunamadı. Verileriniz kaybolmadı; tekrar deneyin.',
  },
  'subscription_check_unavailable': {
    'ar': 'تعذر التحقق من الاشتراك.',
    'en': 'Subscription check unavailable',
    'fr': "Vérification de l'abonnement indisponible",
    'es': 'La verificación de la suscripción no está disponible',
    'tr': 'Abonelik kontrolü kullanılamıyor',
  },
  'checking_subscription': {
    'ar': 'جارٍ التحقق من الاشتراك',
    'en': 'Checking subscription',
    'fr': "Vérification de l'abonnement",
    'es': 'Comprobando la suscripción',
    'tr': 'Abonelik kontrol ediliyor',
  },
  'feedback_error': {
    'ar': 'تعذر حفظ الملاحظات أو تحميلها.',
    'en': 'Feedback could not be saved or loaded.',
    'fr': "Impossible d'enregistrer ou de charger l'avis.",
    'es': 'No se pudieron guardar ni cargar los comentarios.',
    'tr': 'Geri bildirim kaydedilemedi veya yüklenemedi.',
  },
  'tracked_days': {
    'ar': 'سجلت بيانات في {days} من 7 أيام.',
    'en': 'You logged in {days} out of 7 days.',
    'fr': 'Vous avez enregistré des données pendant {days} jours sur 7.',
    'es': 'Registraste datos en {days} de 7 días.',
    'tr': '7 günün {days} gününde veri kaydettiniz.',
  },
  'legend_logged': {
    'ar': 'المسجل',
    'en': 'Logged',
    'fr': 'Enregistré',
    'es': 'Registrado',
    'tr': 'Kaydedilen',
  },
  'legend_goal': {
    'ar': 'الهدف',
    'en': 'Goal',
    'fr': 'Objectif',
    'es': 'Objetivo',
    'tr': 'Hedef',
  },
  'legend_no_entry': {
    'ar': 'لا إدخال',
    'en': 'No entry',
    'fr': 'Aucune saisie',
    'es': 'Sin registro',
    'tr': 'Kayıt yok',
  },
  'premium_active': {
    'ar': 'الرؤية المتقدمة مفعلة',
    'en': 'Premium insight active',
    'fr': 'Analyse Premium active',
    'es': 'Análisis Premium activo',
    'tr': 'Premium analiz etkin',
  },
  'unlock_calorie_insights': {
    'ar': 'افتح رؤى السعرات',
    'en': 'Unlock calorie insights',
    'fr': 'Débloquer les analyses caloriques',
    'es': 'Desbloquear análisis de calorías',
    'tr': 'Kalori analizlerinin kilidini aç',
  },
  'frequent_empty_action': {
    'ar': 'لا توجد أطعمة متكررة بعد. سجل الوجبات لإظهار مفضلاتك الأسبوعية.',
    'en':
        'No frequently logged foods yet. Log meals to build your weekly favorites.',
    'fr':
        'Aucun aliment fréquent pour le moment. Enregistrez vos repas pour créer vos favoris hebdomadaires.',
    'es':
        'Aún no hay alimentos frecuentes. Registra comidas para crear tus favoritos semanales.',
    'tr':
        'Henüz sık kaydedilen yiyecek yok. Haftalık favorilerinizi oluşturmak için öğün kaydedin.',
  },
  'grams_carbs': {
    'ar': 'غ كربوهيدرات',
    'en': 'g carbs',
    'fr': 'g glucides',
    'es': 'g carbohidratos',
    'tr': 'g karbonhidrat',
  },
  'grams_fat': {
    'ar': 'غ دهون',
    'en': 'g fat',
    'fr': 'g lipides',
    'es': 'g grasa',
    'tr': 'g yağ',
  },
  'no_macro_data': {
    'ar': 'لا توجد بيانات للعناصر الكبرى',
    'en': 'No macro data logged',
    'fr': 'Aucune donnée de macronutriments enregistrée',
    'es': 'No hay datos de macronutrientes registrados',
    'tr': 'Makro besin verisi kaydedilmedi',
  },
  'helpful_action': {
    'ar': 'مفيد',
    'en': 'Helpful',
    'fr': 'Utile',
    'es': 'Útil',
    'tr': 'Faydalı',
  },
  'not_helpful_action': {
    'ar': 'غير مفيد',
    'en': 'Not helpful',
    'fr': 'Pas utile',
    'es': 'No es útil',
    'tr': 'Faydalı değil',
  },
  'food': {
    'ar': 'رؤى الطعام',
    'en': 'Food Insights',
    'fr': 'Aperçu alimentaire',
    'es': 'Información alimentaria',
    'tr': 'Beslenme içgörüleri',
  },
  'food_intro': {
    'ar': 'تعرّف على توزيع الأطعمة التي سجلتها هذا الأسبوع.',
    'en': 'See how your logged foods stack up this week.',
    'fr': 'Découvrez la répartition des aliments enregistrés cette semaine.',
    'es': 'Consulta cómo se distribuyen tus alimentos registrados esta semana.',
    'tr': 'Bu hafta kaydettiğiniz yiyeceklerin dağılımını görün.',
  },
  'logged': {
    'ar': 'سجلت هذا الأسبوع:',
    'en': 'This week you logged:',
    'fr': 'Cette semaine, vous avez enregistré :',
    'es': 'Esta semana registraste:',
    'tr': 'Bu hafta kaydettikleriniz:',
  },
  'vegetables': {
    'ar': 'الخضروات',
    'en': 'Vegetables',
    'fr': 'Légumes',
    'es': 'Verduras',
    'tr': 'Sebzeler',
  },
  'fruit': {
    'ar': 'الفواكه الطازجة',
    'en': 'Fresh fruits',
    'fr': 'Fruits frais',
    'es': 'Frutas frescas',
    'tr': 'Taze meyveler',
  },
  'proteins': {
    'ar': 'البروتينات',
    'en': 'Proteins',
    'fr': 'Protéines',
    'es': 'Proteínas',
    'tr': 'Proteinler',
  },
  'snacks': {
    'ar': 'الحلويات والوجبات الخفيفة',
    'en': 'Sweets and snacks',
    'fr': 'Sucreries et collations',
    'es': 'Dulces y tentempiés',
    'tr': 'Tatlılar ve atıştırmalıklar',
  },
  'alcohol': {
    'ar': 'المشروبات الكحولية',
    'en': 'Alcoholic beverages',
    'fr': 'Boissons alcoolisées',
    'es': 'Bebidas alcohólicas',
    'tr': 'Alkollü içecekler',
  },
  'helpful': {
    'ar': 'هل كانت هذه الرؤى مفيدة؟',
    'en': 'Were these insights helpful?',
    'fr': 'Ces informations étaient-elles utiles ?',
    'es': '¿Te resultó útil esta información?',
    'tr': 'Bu bilgiler yararlı oldu mu?',
  },
  'saved': {
    'ar': 'تم حفظ ملاحظتك',
    'en': 'Feedback saved',
    'fr': 'Avis enregistré',
    'es': 'Opinión guardada',
    'tr': 'Geri bildirim kaydedildi',
  },
  'glance': {
    'ar': 'الأسبوع في لمحة',
    'en': 'Week at a Glance',
    'fr': "La semaine en un coup d'œil",
    'es': 'La semana de un vistazo',
    'tr': 'Haftaya genel bakış',
  },
  'calories': {
    'ar': 'السعرات الحرارية',
    'en': 'Calories',
    'fr': 'Calories',
    'es': 'Calorías',
    'tr': 'Kalori',
  },
  'logged_calories': {
    'ar': 'السعرات المسجلة',
    'en': 'Logged calories',
    'fr': 'Calories enregistrées',
    'es': 'Calorías registradas',
    'tr': 'Kaydedilen kalori',
  },
  'goal_unavailable': {
    'ar': 'هدف السعرات غير محدد',
    'en': 'Calorie goal not set',
    'fr': 'Objectif calorique non défini',
    'es': 'Objetivo calórico no definido',
    'tr': 'Kalori hedefi ayarlanmadı',
  },
  'burned_unavailable': {
    'ar': 'السعرات المحروقة غير متاحة في السجلات الحالية',
    'en': 'Burned calories are not available in current records',
    'fr':
        'Les calories brûlées ne sont pas disponibles dans les données actuelles',
    'es':
        'Las calorías quemadas no están disponibles en los registros actuales',
    'tr': 'Yakılan kalori mevcut kayıtlarda bulunmuyor',
  },
  'estimated_exercise_energy': {
    'en': 'Estimated exercise energy · not added to your goal',
    'ar': 'طاقة التمرين التقديرية · لا تُضاف إلى هدفك',
    'fr': 'Énergie d’exercice estimée · non ajoutée à votre objectif',
    'es': 'Energía de ejercicio estimada · no se añade a tu objetivo',
    'tr': 'Tahmini egzersiz enerjisi · hedefinize eklenmez',
    'de': 'Geschätzte Trainingsenergie · nicht zum Ziel addiert',
    'it': 'Energia stimata dell’esercizio · non aggiunta all’obiettivo',
    'pt-BR': 'Energia estimada do exercício · não adicionada à meta',
    'pt-PT': 'Energia estimada do exercício · não adicionada ao objetivo',
    'ur': 'ورزش کی تخمینی توانائی · ہدف میں شامل نہیں',
    'fa': 'انرژی تخمینی ورزش · به هدف افزوده نمی‌شود',
    'hi': 'अनुमानित व्यायाम ऊर्जा · लक्ष्य में नहीं जुड़ती',
    'id': 'Perkiraan energi olahraga · tidak ditambahkan ke target',
    'ms': 'Anggaran tenaga senaman · tidak ditambah pada sasaran',
    'ja': '推定運動エネルギー · 目標には加算されません',
    'ko': '예상 운동 에너지 · 목표에 더하지 않음',
    'zh-Hans': '估算运动能量 · 不计入目标',
    'zh-Hant': '估算運動能量 · 不計入目標',
    'ru': 'Расчётная энергия тренировки · не добавляется к цели',
    'bn': 'আনুমানিক ব্যায়াম শক্তি · লক্ষ্যে যোগ হয় না',
    'vi': 'Năng lượng tập luyện ước tính · không cộng vào mục tiêu',
    'th': 'พลังงานจากการออกกำลังกายโดยประมาณ · ไม่เพิ่มในเป้าหมาย',
    'pl': 'Szacowana energia ćwiczeń · nie jest dodawana do celu',
    'nl': 'Geschatte trainingsenergie · niet opgeteld bij je doel',
    'uk': 'Орієнтовна енергія тренування · не додається до цілі',
  },
  'macros': {
    'ar': 'العناصر الكبرى',
    'en': 'Macronutrients',
    'fr': 'Macronutriments',
    'es': 'Macronutrientes',
    'tr': 'Makro besinler',
  },
  'protein': {
    'ar': 'البروتين',
    'en': 'Protein',
    'fr': 'Protéines',
    'es': 'Proteína',
    'tr': 'Protein',
  },
  'carbs': {
    'ar': 'الكربوهيدرات',
    'en': 'Carbohydrates',
    'fr': 'Glucides',
    'es': 'Carbohidratos',
    'tr': 'Karbonhidrat',
  },
  'fat': {
    'ar': 'الدهون',
    'en': 'Fat',
    'fr': 'Lipides',
    'es': 'Grasas',
    'tr': 'Yağ',
  },
  'exercise_steps': {
    'ar': 'التمارين والخطوات',
    'en': 'Exercise and Steps',
    'fr': 'Exercice et pas',
    'es': 'Ejercicio y pasos',
    'tr': 'Egzersiz ve adımlar',
  },
  'exercise': {
    'ar': 'أيام التمرين المسجلة',
    'en': 'Logged exercise days',
    'fr': "Jours d'exercice enregistrés",
    'es': 'Días de ejercicio registrados',
    'tr': 'Kaydedilen egzersiz günleri',
  },
  'steps': {
    'ar': 'الخطوات المسجلة',
    'en': 'Logged steps',
    'fr': 'Pas enregistrés',
    'es': 'Pasos registrados',
    'tr': 'Kaydedilen adımlar',
  },
  'not_available': {
    'ar': 'غير متاح — لم يُسجل',
    'en': 'Unavailable — not recorded',
    'fr': 'Indisponible — non enregistré',
    'es': 'No disponible — no registrado',
    'tr': 'Kullanılamıyor — kaydedilmedi',
  },
  'all_time': {
    'ar': 'إجمالي السجل',
    'en': 'All-time stats',
    'fr': 'Statistiques globales',
    'es': 'Estadísticas históricas',
    'tr': 'Tüm zamanlar',
  },
  'meals': {
    'ar': 'الوجبات',
    'en': 'Meals',
    'fr': 'Repas',
    'es': 'Comidas',
    'tr': 'Öğünler',
  },
  'weights': {
    'ar': 'قياسات الوزن',
    'en': 'Weight entries',
    'fr': 'Mesures de poids',
    'es': 'Registros de peso',
    'tr': 'Kilo kayıtları',
  },
  'days': {
    'ar': 'أيام',
    'en': 'days',
    'fr': 'jours',
    'es': 'días',
    'tr': 'gün',
  },
  'records_only': {
    'ar':
        'تعتمد الأرقام على السجلات الفعلية فقط؛ لا نملأ الأيام الناقصة ولا نقدّرها.',
    'en':
        'Figures use recorded data only; missing days are never filled or estimated.',
    'fr':
        'Les chiffres utilisent uniquement les données enregistrées ; les jours manquants ne sont jamais estimés.',
    'es':
        'Las cifras usan solo datos registrados; los días sin datos nunca se estiman.',
    'tr':
        'Rakamlar yalnızca kaydedilen verilerdir; eksik günler tahmin edilmez.',
  },
  'weekly_goal': {
    'ar': 'هدف الأسبوع',
    'en': 'Weekly goal',
    'fr': 'Objectif hebdomadaire',
    'es': 'Objetivo semanal',
    'tr': 'Haftalık hedef',
  },
  'on_track': {
    'ar': 'استمر في التسجيل يوميًا لترى تقدمًا أدق.',
    'en': 'Keep logging each day for a clearer progress picture.',
    'fr': 'Continuez à enregistrer chaque jour pour mieux voir vos progrès.',
    'es': 'Sigue registrando cada día para ver mejor tu progreso.',
    'tr': 'İlerlemenizi daha net görmek için her gün kaydetmeye devam edin.',
  },
  'frequent': {
    'ar': 'الأطعمة الأكثر تسجيلًا',
    'en': 'Frequently logged foods',
    'fr': 'Aliments les plus enregistrés',
    'es': 'Alimentos más registrados',
    'tr': 'En sık kaydedilen yiyecekler',
  },
  'frequent_empty': {
    'ar': 'لا توجد أطعمة متكررة في سجلات هذا الأسبوع بعد.',
    'en': "No frequently logged foods in this week's records yet.",
    'fr': 'Aucun aliment fréquent dans les données de cette semaine.',
    'es': 'Aún no hay alimentos frecuentes en los registros de esta semana.',
    'tr': 'Bu haftanın kayıtlarında henüz sık kullanılan yiyecek yok.',
  },
  'premium_insights': {
    'ar': 'رؤى أسبوعية متقدمة',
    'en': 'Advanced weekly insights',
    'fr': 'Analyses hebdomadaires avancées',
    'es': 'Información semanal avanzada',
    'tr': 'Gelişmiş haftalık analizler',
  },
  'premium_truth': {
    'ar': 'تعتمد بطاقات BIL المتقدمة دائمًا على بياناتك المسجلة فقط.',
    'en': 'BIL advanced cards always use your recorded data only.',
    'fr':
        'Les cartes avancées BIL utilisent uniquement vos données enregistrées.',
    'es': 'Las tarjetas avanzadas de BIL usan solo tus datos registrados.',
    'tr': 'BIL gelişmiş kartları yalnızca kayıtlı verilerinizi kullanır.',
  },
  'keep_it_up': {
    'ar': 'واصل التقدم',
    'en': 'Keep It Up',
    'fr': 'Continuez ainsi',
    'es': 'Sigue así',
    'tr': 'Devam edin',
  },
  'logging_streak': {
    'ar': 'سلسلة التسجيل الحالية',
    'en': 'Current logging streak',
    'fr': "Série d'enregistrement actuelle",
    'es': 'Racha de registro actual',
    'tr': 'Mevcut kayıt serisi',
  },
  'member_since_unavailable': {
    'ar': 'غير متاح',
    'en': 'Unavailable',
    'fr': 'Indisponible',
    'es': 'No disponible',
    'tr': 'Kullanılamıyor',
  },
};

class WeeklyReportPage extends ConsumerWidget {
  const WeeklyReportPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(_t(context, 'title')),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/settings'),
      ),
      actions: [
        IconButton(
          key: const Key('weekly-report-previous'),
          constraints: const BoxConstraints.tightFor(width: 40, height: 48),
          tooltip: _weekNavigationCopy(context, previous: true),
          onPressed: () {
            final selected = ref.read(selectedWeeklyReportDateProvider);
            ref.read(selectedWeeklyReportDateProvider.notifier).state = selected
                .subtract(const Duration(days: 7));
          },
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          key: const Key('weekly-report-next'),
          constraints: const BoxConstraints.tightFor(width: 40, height: 48),
          tooltip: _weekNavigationCopy(context, previous: false),
          onPressed: _canSelectNextWeek(ref)
              ? () {
                  final selected = ref.read(selectedWeeklyReportDateProvider);
                  final today = ref.read(weeklyReportClockProvider)();
                  final candidate = selected.add(const Duration(days: 7));
                  ref.read(selectedWeeklyReportDateProvider.notifier).state =
                      candidate.isAfter(today) ? today : candidate;
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
    body: ref
        .watch(weeklyReportProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Message(_t(context, 'read_error')),
          data: (report) => _Body(report: report),
        ),
  );
}

bool _canSelectNextWeek(WidgetRef ref) {
  final selected = ref.watch(selectedWeeklyReportDateProvider);
  final today = ref.watch(weeklyReportClockProvider)();
  final selectedDay = DateTime(selected.year, selected.month, selected.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  return selectedDay.isBefore(todayDay);
}

String _weekNavigationCopy(BuildContext context, {required bool previous}) {
  const values = <String, List<String>>{
    'en': ['Previous week', 'Next week'],
    'ar': ['الأسبوع السابق', 'الأسبوع التالي'],
    'fr': ['Semaine précédente', 'Semaine suivante'],
    'es': ['Semana anterior', 'Semana siguiente'],
    'tr': ['Önceki hafta', 'Sonraki hafta'],
  };
  final language = Localizations.localeOf(context).languageCode;
  final index = previous ? 0 : 1;
  return values[language]?[index] ?? context.strings.text(values['en']![index]);
}

String _humanWeekRange(BuildContext context, String start, String end) {
  DateTime? parse(String value) => DateTime.tryParse(value);
  final from = parse(start);
  final to = parse(end);
  if (from == null || to == null) return '$start - $end';
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(from)} – ${localizations.formatMediumDate(to)}';
}
