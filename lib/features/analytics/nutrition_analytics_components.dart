part of 'nutrition_analytics_page.dart';

class _DayHeader extends ConsumerWidget {
  const _DayHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLogDateProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(selected);
    final isToday = DateUtils.isSameDay(day, today);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    void select(DateTime value) {
      ref.read(selectedLogDateProvider.notifier).state = DateUtils.dateOnly(
        value,
      );
    }

    return Semantics(
      container: true,
      label:
          '${_t(context, 'Day view')}: '
          '${MaterialLocalizations.of(context).formatFullDate(day)}',
      child: Row(
        children: [
          IconButton(
            tooltip: _t(context, 'Previous day'),
            onPressed: () => select(day.subtract(const Duration(days: 1))),
            icon: Icon(
              rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(2000),
                  lastDate: today,
                );
                if (picked != null) select(picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      _t(context, 'Day view'),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      isToday
                          ? _t(context, 'Today')
                          : MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(day),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _t(context, 'Next day'),
            onPressed: isToday
                ? null
                : () => select(day.add(const Duration(days: 1))),
            icon: Icon(
              rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Row(
      children: [
        const Spacer(),
        for (final text in ['Total', 'Goal', 'Left'])
          SizedBox(
            width: 64,
            child: Text(
              _t(context, text),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    ),
  );
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow({
    required this.label,
    required this.total,
    required this.goal,
    required this.unit,
  });
  final String label, unit;
  final double? total;
  final double? goal;
  @override
  Widget build(BuildContext context) {
    final double? left = goal == null || total == null ? null : goal! - total!;
    String f(double? v) => v == null ? '—' : '${v.round()} $unit';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          for (final value in [total, goal, left])
            SizedBox(
              width: 64,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(f(value), textAlign: TextAlign.end),
              ),
            ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });
  final String label;
  final double value, total;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final share = total <= 0 ? 0.0 : (value / total).clamp(0, 1).toDouble();
    return Semantics(
      label: label,
      value: '${(share * 100).round()}%, ${value.round()}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Container(width: 16, height: 16, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(label)),
                Text('${(share * 100).round()}% · ${value.round()}'),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: share, color: color),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final double? value;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: Text(value == null ? '—' : value!.round().toString()),
  );
}

String _t(BuildContext context, String key) =>
    _nutrientPresetCopy[Localizations.localeOf(context).languageCode]?[key] ??
    _copy[Localizations.localeOf(context).languageCode]?[key] ??
    AppLocalizations.of(context).text(_copy['en']![key] ?? key);

const _nutrientPresetCopy = <String, Map<String, String>>{
  'en': {
    'Heart Healthy': 'Heart Healthy',
    'Carb Conscious': 'Carb Conscious',
    'Saturated fat': 'Saturated fat',
    'Unknown': 'Unknown',
    'Custom nutrient goals': 'Custom nutrient goals',
  },
  'ar': {
    'Heart Healthy': 'صحي للقلب',
    'Carb Conscious': 'واعٍ بالكربوهيدرات',
    'Saturated fat': 'الدهون المشبعة',
    'Unknown': 'غير معروف',
    'Custom nutrient goals': 'أهداف المغذيات المخصصة',
  },
  'fr': {
    'Heart Healthy': 'Santé du cœur',
    'Carb Conscious': 'Maîtrise des glucides',
    'Saturated fat': 'Graisses saturées',
    'Unknown': 'Inconnu',
    'Custom nutrient goals': 'Objectifs nutritionnels personnalisés',
  },
  'es': {
    'Heart Healthy': 'Salud cardiovascular',
    'Carb Conscious': 'Control de carbohidratos',
    'Saturated fat': 'Grasa saturada',
    'Unknown': 'Desconocido',
    'Custom nutrient goals': 'Objetivos de nutrientes personalizados',
  },
  'tr': {
    'Heart Healthy': 'Kalp dostu',
    'Carb Conscious': 'Karbonhidrat kontrollü',
    'Saturated fat': 'Doymuş yağ',
    'Unknown': 'Bilinmiyor',
    'Custom nutrient goals': 'Özel besin hedefleri',
  },
};
const _copy = <String, Map<String, String>>{
  'en': {
    'Nutrition': 'Nutrition',
    'Calories': 'Calories',
    'Nutrients': 'Nutrients',
    'Macros': 'Macros',
    'Try again': 'Try again',
    'Export': 'Export',
    'Previous day': 'Previous day',
    'Next day': 'Next day',
    'Nutrition goals could not be loaded.':
        'Nutrition goals could not be loaded.',
    'No foods logged for this day.': 'No foods logged for this day.',
    'Log food to see evidence-backed nutrition totals.':
        'Log food to see evidence-backed nutrition totals.',
    'Log food': 'Log food',
    'Calorie total includes evidenced entries only; some entries are unknown.':
        'Calorie total includes evidenced entries only; some entries are unknown.',
    'Macro distribution uses evidenced carbohydrate, protein, and fat only.':
        'Macro distribution uses evidenced carbohydrate, protein, and fat only.',
    'Day view': 'Day view',
    'Today': 'Today',
    'Total': 'Total',
    'Goal': 'Goal',
    'Left': 'Left',
    'Total calories': 'Total calories',
    'Protein': 'Protein',
    'Carbohydrates': 'Carbohydrates',
    'Fiber': 'Fiber',
    'Sugar': 'Sugar',
    'Fat': 'Fat',
    'Sodium': 'Sodium',
    'Potassium': 'Potassium',
    'Calcium': 'Calcium',
    'Magnesium': 'Magnesium',
    'Phosphorus': 'Phosphorus',
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snacks',
    'other': 'Other',
    'Your recorded nutrients': 'Your recorded nutrients',
    'General adult reference': 'General adult reference values',
    'Food analysis': 'Food analysis',
    'Choose a nutrient': 'Choose a nutrient',
    'Nutrient': 'Nutrient',
    'Top contributors': 'Top contributors',
    'Unknown food': 'Unknown food',
    'Known total': 'Known total',
    'Entries with unknown values': 'Entries with unknown values',
    'Logged entries': 'Logged entries',
    'Verified snapshot': 'Verified snapshot',
    'Unverified snapshot': 'Unverified snapshot',
    'No evidenced values are available.': 'No evidenced values are available.',
    'No logged item has evidence for this nutrient.':
        'No logged item has evidence for this nutrient.',
    'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.':
        'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.',
  },
  'ar': {
    'Nutrition': 'التغذية',
    'Calories': 'السعرات',
    'Nutrients': 'العناصر الغذائية',
    'Macros': 'الماكروز',
    'Try again': 'إعادة المحاولة',
    'Export': 'تصدير',
    'Previous day': 'اليوم السابق',
    'Next day': 'اليوم التالي',
    'Nutrition goals could not be loaded.': 'تعذر تحميل أهداف التغذية.',
    'No foods logged for this day.': 'لا توجد أطعمة مسجلة لهذا اليوم.',
    'Log food to see evidence-backed nutrition totals.':
        'سجّل طعامًا لعرض إجماليات التغذية المدعومة بالدليل.',
    'Log food': 'تسجيل طعام',
    'Calorie total includes evidenced entries only; some entries are unknown.':
        'يشمل إجمالي السعرات الإدخالات المدعومة بالدليل فقط؛ بعض القيم غير معروفة.',
    'Macro distribution uses evidenced carbohydrate, protein, and fat only.':
        'يستخدم توزيع الماكروز الكربوهيدرات والبروتين والدهون المدعومة بالدليل فقط.',
    'Day view': 'عرض اليوم',
    'Today': 'اليوم',
    'Total': 'الإجمالي',
    'Goal': 'الهدف',
    'Left': 'المتبقي',
    'Total calories': 'إجمالي السعرات',
    'Protein': 'البروتين',
    'Carbohydrates': 'الكربوهيدرات',
    'Fiber': 'الألياف',
    'Sugar': 'السكر',
    'Fat': 'الدهون',
    'Sodium': 'الصوديوم',
    'Potassium': 'البوتاسيوم',
    'Calcium': 'الكالسيوم',
    'Magnesium': 'المغنيسيوم',
    'Phosphorus': 'الفوسفور',
    'breakfast': 'الإفطار',
    'lunch': 'الغداء',
    'dinner': 'العشاء',
    'snack': 'الوجبات الخفيفة',
    'other': 'أخرى',
    'Your recorded nutrients': 'العناصر الغذائية المسجلة لديك',
    'General adult reference': 'قيم مرجعية عامة للبالغين',
    'Food analysis': 'تحليل الطعام',
    'Choose a nutrient': 'اختر عنصرًا غذائيًا',
    'Nutrient': 'العنصر الغذائي',
    'Top contributors': 'أبرز مصادر العنصر المسجلة',
    'Unknown food': 'طعام غير معروف',
    'Known total': 'الإجمالي المعروف',
    'Entries with unknown values': 'إدخالات بقيم غير معروفة',
    'Logged entries': 'مرات التسجيل',
    'Verified snapshot': 'لقطة موثقة',
    'Unverified snapshot': 'لقطة غير موثقة',
    'No evidenced values are available.': 'لا تتوفر قيم مدعومة بدليل.',
    'No logged item has evidence for this nutrient.':
        'لا يحتوي أي عنصر مسجل على دليل لهذا العنصر الغذائي.',
    'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.':
        'يصف هذا التحليل مساهمات العناصر الغذائية المسجلة ولا يصنف الطعام على أنه جيد أو سيئ.',
  },
  'fr': {
    'Nutrition': 'Nutrition',
    'Calories': 'Calories',
    'Nutrients': 'Nutriments',
    'Macros': 'Macros',
    'Try again': 'Réessayer',
    'Export': 'Exporter',
    'Previous day': 'Jour précédent',
    'Next day': 'Jour suivant',
    'Nutrition goals could not be loaded.':
        'Impossible de charger les objectifs nutritionnels.',
    'No foods logged for this day.': 'Aucun aliment enregistré ce jour.',
    'Log food to see evidence-backed nutrition totals.':
        'Enregistrez un aliment pour afficher des totaux nutritionnels documentés.',
    'Log food': 'Enregistrer un aliment',
    'Calorie total includes evidenced entries only; some entries are unknown.':
        'Le total calorique inclut uniquement les entrées documentées ; certaines valeurs sont inconnues.',
    'Macro distribution uses evidenced carbohydrate, protein, and fat only.':
        'La répartition utilise uniquement les glucides, protéines et lipides documentés.',
    'Day view': 'Vue du jour',
    'Today': "Aujourd’hui",
    'Total': 'Total',
    'Goal': 'Objectif',
    'Left': 'Restant',
    'Total calories': 'Calories totales',
    'Protein': 'Protéines',
    'Carbohydrates': 'Glucides',
    'Fiber': 'Fibres',
    'Sugar': 'Sucre',
    'Fat': 'Lipides',
    'Sodium': 'Sodium',
    'Potassium': 'Potassium',
    'Calcium': 'Calcium',
    'Magnesium': 'Magnésium',
    'Phosphorus': 'Phosphore',
    'breakfast': 'Petit-déjeuner',
    'lunch': 'Déjeuner',
    'dinner': 'Dîner',
    'snack': 'Collations',
    'other': 'Autres',
    'Your recorded nutrients': 'Vos nutriments enregistrés',
    'General adult reference': 'Valeurs générales de référence pour adultes',
    'Food analysis': 'Analyse des aliments',
    'Choose a nutrient': 'Choisir un nutriment',
    'Nutrient': 'Nutriment',
    'Top contributors': 'Principales contributions',
    'Unknown food': 'Aliment inconnu',
    'Known total': 'Total connu',
    'Entries with unknown values': 'Entrées aux valeurs inconnues',
    'Logged entries': 'Entrées enregistrées',
    'Verified snapshot': 'Instantané vérifié',
    'Unverified snapshot': 'Instantané non vérifié',
    'No evidenced values are available.':
        'Aucune valeur documentée disponible.',
    'No logged item has evidence for this nutrient.':
        'Aucun aliment enregistré ne documente ce nutriment.',
    'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.':
        'Cette analyse décrit les contributions enregistrées sans qualifier les aliments de bons ou mauvais.',
  },
  'es': {
    'Nutrition': 'Nutrición',
    'Calories': 'Calorías',
    'Nutrients': 'Nutrientes',
    'Macros': 'Macros',
    'Try again': 'Reintentar',
    'Export': 'Exportar',
    'Previous day': 'Día anterior',
    'Next day': 'Día siguiente',
    'Nutrition goals could not be loaded.':
        'No se pudieron cargar los objetivos nutricionales.',
    'No foods logged for this day.': 'No hay alimentos registrados este día.',
    'Log food to see evidence-backed nutrition totals.':
        'Registra un alimento para ver totales nutricionales documentados.',
    'Log food': 'Registrar alimento',
    'Calorie total includes evidenced entries only; some entries are unknown.':
        'El total calórico incluye solo registros documentados; algunos valores son desconocidos.',
    'Macro distribution uses evidenced carbohydrate, protein, and fat only.':
        'La distribución usa solo carbohidratos, proteínas y grasas documentados.',
    'Day view': 'Vista diaria',
    'Today': 'Hoy',
    'Total': 'Total',
    'Goal': 'Objetivo',
    'Left': 'Restante',
    'Total calories': 'Calorías totales',
    'Protein': 'Proteína',
    'Carbohydrates': 'Carbohidratos',
    'Fiber': 'Fibra',
    'Sugar': 'Azúcar',
    'Fat': 'Grasa',
    'Sodium': 'Sodio',
    'Potassium': 'Potasio',
    'Calcium': 'Calcio',
    'Magnesium': 'Magnesio',
    'Phosphorus': 'Fósforo',
    'breakfast': 'Desayuno',
    'lunch': 'Almuerzo',
    'dinner': 'Cena',
    'snack': 'Tentempiés',
    'other': 'Otros',
    'Your recorded nutrients': 'Tus nutrientes registrados',
    'General adult reference': 'Valores generales de referencia para adultos',
    'Food analysis': 'Análisis de alimentos',
    'Choose a nutrient': 'Elige un nutriente',
    'Nutrient': 'Nutriente',
    'Top contributors': 'Principales contribuciones',
    'Unknown food': 'Alimento desconocido',
    'Known total': 'Total conocido',
    'Entries with unknown values': 'Registros con valores desconocidos',
    'Logged entries': 'Registros',
    'Verified snapshot': 'Datos verificados',
    'Unverified snapshot': 'Datos no verificados',
    'No evidenced values are available.':
        'No hay valores documentados disponibles.',
    'No logged item has evidence for this nutrient.':
        'Ningún alimento registrado tiene datos de este nutriente.',
    'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.':
        'Este análisis describe las contribuciones registradas sin clasificar alimentos como buenos o malos.',
  },
  'tr': {
    'Nutrition': 'Beslenme',
    'Calories': 'Kalori',
    'Nutrients': 'Besin öğeleri',
    'Macros': 'Makrolar',
    'Try again': 'Tekrar dene',
    'Export': 'Dışa aktar',
    'Previous day': 'Önceki gün',
    'Next day': 'Sonraki gün',
    'Nutrition goals could not be loaded.': 'Beslenme hedefleri yüklenemedi.',
    'No foods logged for this day.': 'Bu gün için kayıtlı yiyecek yok.',
    'Log food to see evidence-backed nutrition totals.':
        'Kanıta dayalı beslenme toplamlarını görmek için yiyecek kaydedin.',
    'Log food': 'Yiyecek kaydet',
    'Calorie total includes evidenced entries only; some entries are unknown.':
        'Kalori toplamı yalnızca kanıtlı kayıtları içerir; bazı değerler bilinmiyor.',
    'Macro distribution uses evidenced carbohydrate, protein, and fat only.':
        'Makro dağılımı yalnızca kanıtlı karbonhidrat, protein ve yağı kullanır.',
    'Day view': 'Gün görünümü',
    'Today': 'Bugün',
    'Total': 'Toplam',
    'Goal': 'Hedef',
    'Left': 'Kalan',
    'Total calories': 'Toplam kalori',
    'Protein': 'Protein',
    'Carbohydrates': 'Karbonhidrat',
    'Fiber': 'Lif',
    'Sugar': 'Şeker',
    'Fat': 'Yağ',
    'Sodium': 'Sodyum',
    'Potassium': 'Potasyum',
    'Calcium': 'Kalsiyum',
    'Magnesium': 'Magnezyum',
    'Phosphorus': 'Fosfor',
    'breakfast': 'Kahvaltı',
    'lunch': 'Öğle yemeği',
    'dinner': 'Akşam yemeği',
    'snack': 'Atıştırmalıklar',
    'other': 'Diğer',
    'Your recorded nutrients': 'Kaydedilen besin öğeleriniz',
    'General adult reference': 'Yetişkinler için genel referans değerleri',
    'Food analysis': 'Yiyecek analizi',
    'Choose a nutrient': 'Bir besin öğesi seçin',
    'Nutrient': 'Besin öğesi',
    'Top contributors': 'En büyük katkılar',
    'Unknown food': 'Bilinmeyen yiyecek',
    'Known total': 'Bilinen toplam',
    'Entries with unknown values': 'Değeri bilinmeyen kayıtlar',
    'Logged entries': 'Kayıt sayısı',
    'Verified snapshot': 'Doğrulanmış anlık kayıt',
    'Unverified snapshot': 'Doğrulanmamış anlık kayıt',
    'No evidenced values are available.': 'Kanıtlı bir değer bulunmuyor.',
    'No logged item has evidence for this nutrient.':
        'Kayıtlı hiçbir yiyecekte bu besin öğesi için kanıt yok.',
    'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.':
        'Bu analiz kayıtlı besin katkılarını açıklar; yiyecekleri iyi veya kötü diye sınıflandırmaz.',
  },
};
