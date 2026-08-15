import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../profile/providers/user_profile_provider.dart';
import '../commerce/domain/commerce_entitlement.dart';
import '../commerce/providers/commerce_providers.dart';
import 'weekly_report_engine.dart';
import 'weekly_report_provider.dart';

String _t(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  final english = (_copy[key] ?? const {})['en'] ?? key;
  return (_copy[key] ?? const {})[code] ?? context.strings.text(english);
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

class _Body extends ConsumerWidget {
  const _Body({required this.report});
  final WeeklyReportSnapshot report;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = report.days;
    final verifiedSubscription = ref.watch(verifiedSubscriptionStateProvider);
    final premiumActive = verifiedSubscription.value?.grants(
      CommerceEntitlement.advancedIntelligence,
    );
    final start = days.isEmpty ? '' : days.first.dayKey;
    final end = days.isEmpty ? '' : days.last.dayKey;
    final memberSince =
        ref.watch(accountCreatedAtProvider) ??
        ref
            .watch(userProfileProvider)
            .whenOrNull(data: (profile) => profile?.createdAt);
    final memberSinceCopy = memberSince == null
        ? _t(context, 'member_since_unavailable')
        : MaterialLocalizations.of(context).formatMediumDate(memberSince);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _humanWeekRange(context, start, end),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              key: const Key('weekly-report-calendar'),
              tooltip: context.strings.text('Choose report week'),
              onPressed: () async {
                final selected = ref.read(selectedWeeklyReportDateProvider);
                final today = ref.read(weeklyReportClockProvider)();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selected.isAfter(today) ? today : selected,
                  firstDate: DateTime(2010),
                  lastDate: today,
                );
                if (picked != null) {
                  ref.read(selectedWeeklyReportDateProvider.notifier).state =
                      picked;
                }
              },
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Food(report: report),
        const SizedBox(height: 22),
        Text(
          _t(context, 'glance'),
          key: const Key('weekly-glance-anchor'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(_t(context, 'records_only')),
        Text(
          Localizations.localeOf(context).languageCode == 'ar'
              ? 'سجلت بيانات في ${report.trackedDays} من 7 أيام.'
              : _t(
                  context,
                  'tracked_days',
                ).replaceAll('{days}', '${report.trackedDays}'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (verifiedSubscription.isLoading)
          const LinearProgressIndicator(key: Key('weekly-entitlement-loading'))
        else if (verifiedSubscription.hasError)
          ListTile(
            key: const Key('weekly-entitlement-error'),
            leading: const Icon(Icons.cloud_off_rounded),
            title: Text(_t(context, 'subscription_check_unavailable')),
            trailing: TextButton(
              onPressed: () =>
                  ref.invalidate(verifiedSubscriptionStateProvider),
              child: Text(context.strings.text('Retry')),
            ),
          ),
        _Section(
          key: const Key('weekly-calories-section'),
          title: _t(context, 'calories'),
          icon: Icons.local_fire_department_outlined,
          children: [
            _Value(
              _t(context, 'logged_calories'),
              '${report.totalCalories.toStringAsFixed(0)} kcal',
            ),
            _Value(
              _t(context, 'weekly_goal'),
              report.dailyCalorieGoal == null
                  ? '—'
                  : '${report.dailyCalorieGoal! * 7} kcal',
            ),
            _Value(_t(context, 'burned_unavailable'), '—'),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_t(context, 'on_track')),
            ),
            const SizedBox(height: 8),
            _Bars(days: days),
            const SizedBox(height: 8),
            _ChartLegend(
              items: [
                (_t(context, 'legend_logged'), const Color(0xFF006D77)),
                (_t(context, 'legend_goal'), const Color(0xFF8AA5AB)),
                (_t(context, 'legend_no_entry'), const Color(0xFFD7E2E4)),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              key: const Key('weekly-calories-premium-cta'),
              onPressed: premiumActive == false
                  ? () => context.push('/plans')
                  : null,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(
                premiumActive == true
                    ? _t(context, 'premium_active')
                    : premiumActive == false
                    ? _t(context, 'unlock_calorie_insights')
                    : _t(context, 'checking_subscription'),
              ),
            ),
            const SizedBox(height: 10),
            if (premiumActive == false) ...[
              const SizedBox(height: 6),
              OutlinedButton(
                key: const Key('weekly-go-premium'),
                onPressed: () => context.push('/plans'),
                child: Text(context.strings.text('GO PREMIUM')),
              ),
            ],
          ],
        ),
        _Section(
          key: const Key('weekly-frequent-section'),
          title: _t(context, 'frequent'),
          icon: Icons.restaurant_menu_rounded,
          children: report.frequentFoods.isEmpty
              ? [
                  const SizedBox(height: 18),
                  const Center(
                    child: Icon(Icons.soup_kitchen_outlined, size: 64),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      _t(context, 'frequent_empty_action'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 18),
                ]
              : [
                  for (final item in report.frequentFoods.entries)
                    _Value(item.key, '${item.value}\u00D7'),
                ],
        ),
        _Section(
          title: _t(context, 'premium_insights'),
          icon: premiumActive == true
              ? Icons.workspace_premium_rounded
              : premiumActive == false
              ? Icons.lock_outline_rounded
              : Icons.hourglass_top_rounded,
          children: [
            Semantics(
              key: const Key('weekly-report-premium-state'),
              label: premiumActive == null
                  ? _t(context, 'subscription_check_unavailable')
                  : _weeklyPremiumState(context, premiumActive),
              button: premiumActive == false,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: premiumActive == false
                    ? () => context.push('/plans')
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    premiumActive == true
                        ? _t(context, 'premium_truth')
                        : premiumActive == false
                        ? _weeklyPremiumState(context, false)
                        : _t(context, 'subscription_check_unavailable'),
                  ),
                ),
              ),
            ),
          ],
        ),
        _Section(
          key: const Key('weekly-macros-section'),
          title: _t(context, 'macros'),
          icon: Icons.donut_large_rounded,
          children: [
            _Value(
              _t(context, 'protein'),
              '${report.totalProteinG.toStringAsFixed(0)} g',
            ),
            _Value(
              _t(context, 'carbs'),
              '${report.totalCarbsG.toStringAsFixed(0)} g',
            ),
            _Value(
              _t(context, 'fat'),
              '${report.totalFatG.toStringAsFixed(0)} g',
            ),
            const SizedBox(height: 12),
            _MacroDistribution(report: report),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('weekly-macro-importer-link'),
              onPressed: () => context.push('/nutrition'),
              icon: const Icon(Icons.add_chart_rounded),
              label: Text(context.strings.text('Open nutrition importer')),
            ),
          ],
        ),
        _Section(
          key: const Key('weekly-exercise-section'),
          title: _t(context, 'exercise_steps'),
          icon: Icons.directions_run_rounded,
          children: [
            const Text(
              'Connect a supported app or device to bring saved activity into your weekly picture.',
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              key: const Key('weekly-connected-health-cta'),
              onPressed: () => context.push('/connected-health'),
              icon: const Icon(Icons.devices_other),
              label: Text(context.strings.text('Connect apps and devices')),
            ),
            const _Value('Weekly Step Goal', '—'),
            _Value(
              _t(context, 'exercise'),
              '${report.exerciseDays} ${_t(context, 'days')}',
            ),
            _Value(
              _t(context, 'steps'),
              report.totalSteps == null ? '—' : '${report.totalSteps}',
            ),
            const SizedBox(height: 8),
            _ActivityChart(days: days),
            const _ChartLegend(items: [('Steps Logged', Color(0xFF90CAF9))]),
          ],
        ),
        _Section(
          key: const Key('weekly-alltime-section'),
          title: _t(context, 'all_time'),
          icon: Icons.insights_rounded,
          children: [
            _Value(
              'Member since',
              memberSinceCopy,
              key: const Key('weekly-member-since-value'),
            ),
            _Value('Foods Logged', '${report.allTimeFoodCount}'),
            _Value('Meals Logged', '${report.allTimeMealCount}'),
            _Value('Exercises Logged', '${report.allTimeExerciseDays}'),
            _Value(
              'Steps Logged',
              report.allTimeSteps == null ? '—' : '${report.allTimeSteps}',
            ),
          ],
        ),
        _Section(
          key: const Key('weekly-keep-section'),
          title: _t(context, 'keep_it_up'),
          icon: Icons.local_fire_department_rounded,
          children: [
            const Center(
              child: Text(
                'Continue to log in every day to keep your streak going.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                '${report.loggingStreakDays} ${_t(context, 'days')}!',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: const Color(0xFF1976D2),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ],
    );
  }
}

class _Food extends ConsumerStatefulWidget {
  const _Food({required this.report});
  final WeeklyReportSnapshot report;

  @override
  ConsumerState<_Food> createState() => _FoodState();
}

class _FoodState extends ConsumerState<_Food> {
  String? saved;
  bool loadingFeedback = true;
  bool savingFeedback = false;
  bool feedbackError = false;
  String? failedFeedbackChoice;

  String get _feedbackKey =>
      'weekly_report_feedback_${widget.report.days.isEmpty ? 'empty' : widget.report.days.last.dayKey}';

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    if (mounted) {
      setState(() {
        loadingFeedback = true;
        feedbackError = false;
        failedFeedbackChoice = null;
      });
    }
    try {
      final value = await ref
          .read(preferencesRepositoryProvider)
          .get(_feedbackKey);
      if (mounted) setState(() => saved = value);
    } catch (_) {
      if (mounted) setState(() => feedbackError = true);
    } finally {
      if (mounted) setState(() => loadingFeedback = false);
    }
  }

  Future<void> _saveFeedback(String value) async {
    if (savingFeedback || loadingFeedback) return;
    setState(() {
      savingFeedback = true;
      feedbackError = false;
      failedFeedbackChoice = null;
    });
    try {
      await ref.read(preferencesRepositoryProvider).set(_feedbackKey, value);
      if (mounted) setState(() => saved = value);
    } catch (_) {
      if (mounted) {
        setState(() {
          feedbackError = true;
          failedFeedbackChoice = value;
        });
      }
    } finally {
      if (mounted) setState(() => savingFeedback = false);
    }
  }

  int _count(List<String> words) => widget.report.foodCategoryCounts.entries
      .where((e) => words.any((w) => e.key.contains(w)))
      .fold(0, (s, e) => s + e.value);
  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String localized(String english, String arabic) =>
        isArabic ? arabic : context.strings.text(english);
    final rows = <(String, int, String, String, Color)>[
      (
        _t(context, 'vegetables'),
        _count(['vegetable', 'خضر']),
        localized('NUTRITION SUPERSTARS', 'نجوم التغذية'),
        localized(
          'Plants packed with vitamins, minerals and antioxidants.',
          'نباتات غنية بالفيتامينات والمعادن ومضادات الأكسدة.',
        ),
        Colors.green,
      ),
      (
        _t(context, 'fruit'),
        _count(['fruit', 'فاكه']),
        localized('FULL OF FIBER', 'غنية بالألياف'),
        localized(
          'Fresh fruits add fiber, color and natural sweetness.',
          'تضيف الفواكه الطازجة الألياف واللون والحلاوة الطبيعية.',
        ),
        Colors.red,
      ),
      (
        _t(context, 'proteins'),
        _count(['protein', 'meat', 'egg', 'fish', 'legume', 'بروتين', 'لحوم']),
        localized('NUTRITION POWERHOUSES', 'مصادر غذائية قوية'),
        localized(
          'Protein-rich foods help maintain and repair muscle.',
          'تساعد الأطعمة الغنية بالبروتين في الحفاظ على العضلات وتعافيها.',
        ),
        Colors.orange,
      ),
      (
        _t(context, 'snacks'),
        _count(['snack', 'sweet', 'dessert', 'حلويات']),
        localized('ENJOY MINDFULLY', 'استمتع بوعي'),
        localized(
          'Snacks count too\u2014logging them makes the weekly picture honest.',
          'الوجبات الخفيفة مهمة أيضًا؛ تسجيلها يجعل ملخص الأسبوع أدق.',
        ),
        Colors.blue,
      ),
      (
        _t(context, 'alcohol'),
        _count(['alcohol', 'beer', 'wine', 'كحول']),
        localized('KNOW YOUR PATTERN', 'اعرف نمطك'),
        localized(
          'Alcohol can affect sleep, hydration and recovery.',
          'قد يؤثر الكحول في النوم والترطيب والتعافي.',
        ),
        Colors.teal,
      ),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(
            key: const Key('weekly-food-insights-hero'),
            builder: (context, constraints) {
              final narrow =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.3;
              final copy = Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _t(context, 'food'),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: const Color(0xFF12343B),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF006D77),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            localized('BIL INSIGHT', 'رؤية BIL'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t(context, 'food_intro'),
                      style: const TextStyle(
                        color: Color(0xFF315A62),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
              final image = SizedBox(
                width: 140,
                height: narrow ? 150 : 210,
                child: Image.asset(
                  'assets/images/professional/mediterranean_protein_bowl.png',
                  fit: BoxFit.cover,
                ),
              );
              return ColoredBox(
                color: const Color(0xFFDFF3FA),
                child: narrow
                    ? copy
                    : Row(
                        children: [
                          Expanded(child: copy),
                          image,
                        ],
                      ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  _t(context, 'logged'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                for (final row in rows)
                  ListTile(
                    key: Key('weekly-food-category-${rows.indexOf(row)}'),
                    contentPadding: const EdgeInsets.symmetric(vertical: 3),
                    leading: CircleAvatar(
                      radius: 27,
                      backgroundColor: row.$5.withValues(alpha: .14),
                      child: Text(
                        '${row.$2}',
                        style: TextStyle(
                          color: row.$5,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      row.$3,
                      style: TextStyle(
                        color: row.$5,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.$1,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(row.$4),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localized('More on the way', 'المزيد قادم'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              localized(
                                'Keep logging foods to unlock more personalized patterns and weekly insights.',
                                'واصل تسجيل الطعام لعرض أنماط ورؤى أسبوعية أكثر تخصيصًا.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  key: const Key('weekly-food-feedback-panel'),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        localized('FOOD INSIGHTS', 'رؤى الطعام'),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        saved == null
                            ? _t(context, 'helpful')
                            : _t(context, 'saved'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        localized(
                          'Your feedback helps us make these weekly patterns more useful.',
                          'تساعدنا ملاحظتك في جعل هذه الأنماط الأسبوعية أكثر فائدة.',
                        ),
                      ),
                      if (feedbackError) ...[
                        const SizedBox(height: 8),
                        Text(
                          _t(context, 'feedback_error'),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          key: const Key('weekly-food-feedback-retry'),
                          onPressed: savingFeedback
                              ? null
                              : failedFeedbackChoice == null
                              ? _loadFeedback
                              : () => _saveFeedback(failedFeedbackChoice!),
                          child: Text(context.strings.text('Retry')),
                        ),
                      ],
                      Wrap(
                        key: const Key('weekly-food-feedback-actions'),
                        alignment: WrapAlignment.center,
                        children: [
                          IconButton(
                            key: const Key('weekly-food-feedback-up'),
                            onPressed: loadingFeedback || savingFeedback
                                ? null
                                : () => _saveFeedback('up'),
                            tooltip: _t(context, 'helpful_action'),
                            icon: Icon(
                              saved == 'up'
                                  ? Icons.thumb_up_rounded
                                  : Icons.thumb_up_outlined,
                              size: 28,
                            ),
                          ),
                          IconButton(
                            key: const Key('weekly-food-feedback-down'),
                            onPressed: loadingFeedback || savingFeedback
                                ? null
                                : () => _saveFeedback('down'),
                            tooltip: _t(context, 'not_helpful_action'),
                            icon: Icon(
                              saved == 'down'
                                  ? Icons.thumb_down_rounded
                                  : Icons.thumb_down_outlined,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [...children],
          ),
        ),
      ],
    ),
  );
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _Bars extends StatelessWidget {
  const _Bars({required this.days});
  final List<WeeklyReportDay> days;
  @override
  Widget build(BuildContext context) {
    final max = days.fold<double>(0, (m, d) => d.calories > m ? d.calories : m);
    const labels = ['M', 'T', 'W', 'T', 'F', 'Sa', 'Su'];
    return Semantics(
      label: max == 0 ? 'No foods logged' : 'Weekly calories chart',
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            Column(
              children: [
                for (final axis in const ['3000', '2000', '1000', '0'])
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            axis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
              ],
            ),
            Positioned.fill(
              left: 40,
              top: 10,
              bottom: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (max == 0)
                            const Expanded(child: SizedBox())
                          else
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: 18,
                                  height: 130 * days[i].calories / 3000,
                                  color: const Color(0xFF006D77),
                                ),
                              ),
                            ),
                          Text(labels[i], style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (max == 0)
              const Center(
                child: Text(
                  'No foods logged',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items});
  final List<(String, Color)> items;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 6,
    children: [
      for (final item in items)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.$2,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  item.$1,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _MacroDistribution extends StatefulWidget {
  const _MacroDistribution({required this.report});
  final WeeklyReportSnapshot report;
  @override
  State<_MacroDistribution> createState() => _MacroDistributionState();
}

class _MacroDistributionState extends State<_MacroDistribution> {
  bool showTooltip = false;
  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final total = report.totalProteinG + report.totalCarbsG + report.totalFatG;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: 'Weekly macro goal and consumed chart. Tap for details.',
          child: GestureDetector(
            key: const Key('weekly-macro-chart'),
            onTap: () => setState(() => showTooltip = !showTooltip),
            child: Semantics(
              label: 'Weekly macro goal and consumed chart',
              child: SizedBox(
                height: 180,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        for (final axis in const [
                          '100%',
                          '75%',
                          '50%',
                          '25%',
                          '0%',
                        ])
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 38,
                                  child: Text(
                                    axis,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Positioned(
                      left: 42,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        children: [
                          for (final key in const ['protein', 'carbs', 'fat'])
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(_t(context, key)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (total <= 0)
                      Center(
                        child: Text(
                          _t(context, 'no_macro_data'),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      )
                    else
                      Positioned(
                        left: 48,
                        right: 8,
                        top: 10,
                        bottom: 24,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final value in [
                              report.totalProteinG,
                              report.totalCarbsG,
                              report.totalFatG,
                            ])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.bottomCenter,
                                    heightFactor: value / total,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF006D77),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showTooltip)
          Card(
            key: const Key('weekly-macro-tooltip'),
            color: const Color(0xFF263238),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.35,
                  fontFamily: 'RobotoEvidence',
                  decoration: TextDecoration.none,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly logged totals',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${report.totalProteinG.toStringAsFixed(1)} g protein',
                    ),
                    Text(
                      '${report.totalCarbsG.toStringAsFixed(1)} ${_t(context, 'grams_carbs')}',
                    ),
                    Text(
                      '${report.totalFatG.toStringAsFixed(1)} ${_t(context, 'grams_fat')}',
                    ),
                    Text(
                      context.strings.text(
                        'Macro goals are unavailable for this report.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        const _ChartLegend(
          items: [('Logged protein, carbs and fat share', Color(0xFF006D77))],
        ),
      ],
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.days});
  final List<WeeklyReportDay> days;
  @override
  Widget build(BuildContext context) {
    final maximum = days
        .where((day) => day.steps != null)
        .fold<int>(0, (value, day) => day.steps! > value ? day.steps! : value);
    return Semantics(
      label: 'Seven day exercise and steps chart',
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            Column(
              children: [
                for (final axis in const ['10k', '7.5k', '5k', '2.5k', '0'])
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            axis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
              ],
            ),
            if (maximum == 0)
              const Center(
                child: Text(
                  'No steps logged',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              )
            else
              Positioned(
                left: 42,
                right: 0,
                top: 8,
                bottom: 24,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FractionallySizedBox(
                            heightFactor: (day.steps ?? 0) / maximum,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF90CAF9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Positioned(
              left: 42,
              right: 0,
              bottom: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final label in const [
                    'M',
                    'T',
                    'W',
                    'T',
                    'F',
                    'Sa',
                    'Su',
                  ])
                    Text(context.strings.text(label)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(value, textAlign: TextAlign.center),
    ),
  );
}
