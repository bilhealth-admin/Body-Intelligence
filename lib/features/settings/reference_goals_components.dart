part of 'reference_goals_page.dart';

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 68,
    title: Text(label),
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: Text(
        value,
        textAlign: TextAlign.end,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ),
    onTap: onTap,
  );
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow(this.title, this.subtitle, this.onTap);
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _PremiumRow extends ConsumerWidget {
  const _PremiumRow(
    this.title,
    this.subtitle, {
    required this.route,
    required this.stateKey,
  });
  final String title;
  final String subtitle;
  final String route;
  final Key stateKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(verifiedSubscriptionStateProvider);
    final active =
        entitlement.value?.grants(CommerceEntitlement.advancedIntelligence) ??
        false;
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode;
    final status = active
        ? const {
                'ar': 'مفعّلة',
                'en': 'Active',
                'fr': 'Activée',
                'es': 'Activa',
                'tr': 'Etkin',
              }[language] ??
              RuntimeCopy.resolve('Active', locale.toLanguageTag()) ??
              'Active'
        : const {
                'ar': 'ميزة Pro مقفلة',
                'en': 'Locked Pro feature',
                'fr': 'Fonction Pro verrouillée',
                'es': 'Función Pro bloqueada',
                'tr': 'Kilitli Pro özelliği',
              }[language] ??
              RuntimeCopy.resolve(
                'Locked Pro feature',
                locale.toLanguageTag(),
              ) ??
              'Locked Pro feature';
    return Semantics(
      key: stateKey,
      label: '$title, $status',
      button: entitlement.hasValue || entitlement.hasError,
      child: ListTile(
        enabled: entitlement.hasValue || entitlement.hasError,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFFFFDA76), Color(0xFFB77A08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: active
                ? null
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: .7)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x4DB77A08),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ]
                : const [],
          ),
          child: entitlement.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  active
                      ? Icons.workspace_premium_rounded
                      : entitlement.hasError
                      ? Icons.refresh_rounded
                      : Icons.lock_outline_rounded,
                  color: active
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
        ),
        onTap: !entitlement.hasValue
            ? entitlement.hasError
                  ? () => ref.invalidate(verifiedSubscriptionStateProvider)
                  : null
            : () => GoRouter.of(
                context,
              ).push(premiumGoalDestination(active, route)),
      ),
    );
  }
}

class _ChoicePage extends StatefulWidget {
  const _ChoicePage({
    required this.title,
    required this.options,
    required this.selected,
    required this.translate,
  });
  final String title;
  final List<String> options;
  final String selected;
  final String Function(String) translate;
  @override
  State<_ChoicePage> createState() => _ChoicePageState();
}

class _ChoicePageState extends State<_ChoicePage> {
  late String selected = widget.selected;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(widget.title),
      actions: [
        IconButton(
          icon: const Icon(Icons.check_rounded),
          onPressed: () => Navigator.pop(context, selected),
        ),
      ],
    ),
    body: ListView(
      children: widget.options
          .map(
            (option) => ListTile(
              minTileHeight: 66,
              title: Text(widget.translate(option)),
              trailing: option == selected
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => setState(() => selected = option),
            ),
          )
          .toList(),
    ),
  );
}

class _StoredFitnessNumber extends ConsumerStatefulWidget {
  const _StoredFitnessNumber(this.keyName, this.label);
  final String keyName;
  final String label;
  @override
  ConsumerState<_StoredFitnessNumber> createState() =>
      _StoredFitnessNumberState();
}

class _StoredFitnessNumberState extends ConsumerState<_StoredFitnessNumber> {
  int value = 0;
  bool editorOpen = false;
  @override
  void initState() {
    super.initState();
    ref.read(preferencesRepositoryProvider).get(widget.keyName).then((saved) {
      if (mounted) setState(() => value = int.tryParse(saved ?? '') ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(
      _copy[widget.label]?[Localizations.localeOf(context).languageCode] ??
          widget.label,
    ),
    trailing: Text(
      '$value',
      style: TextStyle(color: Theme.of(context).colorScheme.primary),
    ),
    onTap: () async {
      if (editorOpen) return;
      editorOpen = true;
      final maximum = widget.keyName == 'goals.workoutsPerWeek' ? 14 : 300;
      int? next;
      try {
        next = await showDialog<int>(
          context: context,
          builder: (dialogContext) {
            var draft = value;
            return StatefulBuilder(
              builder: (_, setDialog) => AlertDialog(
                title: Text(
                  _copy[widget.label]?[Localizations.localeOf(
                        context,
                      ).languageCode] ??
                      widget.label,
                ),
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: draft > 0
                          ? () => setDialog(() => draft--)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Text(
                      '$draft',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    IconButton(
                      onPressed: draft < maximum
                          ? () => setDialog(() => draft++)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, draft),
                    child: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
            );
          },
        );
      } finally {
        await WidgetsBinding.instance.endOfFrame;
        editorOpen = false;
      }
      final saved = next;
      if (saved == null) return;
      setState(() => value = saved);
      await ref
          .read(preferencesRepositoryProvider)
          .set(widget.keyName, '$saved');
    },
  );
}

const _copy = <String, Map<String, String>>{
  'Goals': {
    'ar': 'الأهداف',
    'fr': 'Objectifs',
    'es': 'Objetivos',
    'tr': 'Hedefler',
  },
  'Starting Weight': {
    'ar': 'وزن البداية',
    'fr': 'Poids initial',
    'es': 'Peso inicial',
    'tr': 'Başlangıç kilosu',
  },
  'Starting Date': {
    'ar': 'تاريخ البداية',
    'fr': 'Date de départ',
    'es': 'Fecha de inicio',
    'tr': 'Başlangıç tarihi',
  },
  'Current Weight': {
    'ar': 'الوزن الحالي',
    'fr': 'Poids actuel',
    'es': 'Peso actual',
    'tr': 'Mevcut kilo',
  },
  'Goal Weight': {
    'ar': 'الوزن المستهدف',
    'fr': 'Poids cible',
    'es': 'Peso objetivo',
    'tr': 'Hedef kilo',
  },
  'Weekly Goal': {
    'ar': 'الهدف الأسبوعي',
    'fr': 'Objectif hebdomadaire',
    'es': 'Objetivo semanal',
    'tr': 'Haftalık hedef',
  },
  'Activity Level': {
    'ar': 'مستوى النشاط',
    'fr': "Niveau d’activité",
    'es': 'Nivel de actividad',
    'tr': 'Aktivite düzeyi',
  },
  'Nutrition Goals': {
    'ar': 'أهداف التغذية',
    'fr': 'Objectifs nutritionnels',
    'es': 'Objetivos nutricionales',
    'tr': 'Beslenme hedefleri',
  },
  'Fitness Goals': {
    'ar': 'أهداف اللياقة',
    'fr': 'Objectifs sportifs',
    'es': 'Objetivos de actividad',
    'tr': 'Fitness hedefleri',
  },
  'Kilograms': {
    'ar': 'كيلوغرامات',
    'fr': 'Kilogrammes',
    'es': 'Kilogramos',
    'tr': 'Kilogram',
  },
  'kg': {'ar': 'كجم', 'fr': 'kg', 'es': 'kg', 'tr': 'kg'},
  'Are You Sure?': {
    'ar': 'هل أنت متأكد؟',
    'fr': 'Êtes-vous sûr ?',
    'es': '¿Estás seguro?',
    'tr': 'Emin misiniz?',
  },
  'Updating your weekly goal will remove any custom goals. Would you like to continue?': {
    'ar':
        'سيؤدي تحديث هدفك الأسبوعي إلى إزالة أي أهداف مخصصة. هل تريد المتابعة؟',
    'fr': 'La mise à jour supprimera vos objectifs personnalisés. Continuer ?',
    'es': 'Actualizarlo eliminará tus objetivos personalizados. ¿Continuar?',
    'tr': 'Güncelleme özel hedefleri kaldırır. Devam edilsin mi?',
  },
  'No': {'ar': 'لا', 'fr': 'Non', 'es': 'No', 'tr': 'Hayır'},
  'Yes': {'ar': 'نعم', 'fr': 'Oui', 'es': 'Sí', 'tr': 'Evet'},
  'Lose 0.2 kg per week': {
    'ar': 'خسارة 0.2 كجم أسبوعيًا',
    'fr': 'Perdre 0,2 kg par semaine',
    'es': 'Perder 0,2 kg por semana',
    'tr': 'Haftada 0,2 kg ver',
  },
  'Lose 0.5 kg per week': {
    'ar': 'خسارة 0.5 كجم أسبوعيًا',
    'fr': 'Perdre 0,5 kg par semaine',
    'es': 'Perder 0,5 kg por semana',
    'tr': 'Haftada 0,5 kg ver',
  },
  'Lose 0.8 kg per week': {
    'ar': 'خسارة 0.8 كجم أسبوعيًا',
    'fr': 'Perdre 0,8 kg par semaine',
    'es': 'Perder 0,8 kg por semana',
    'tr': 'Haftada 0,8 kg ver',
  },
  'Lose 1 kg per week': {
    'ar': 'خسارة 1 كجم أسبوعيًا',
    'fr': 'Perdre 1 kg par semaine',
    'es': 'Perder 1 kg por semana',
    'tr': 'Haftada 1 kg ver',
  },
  'Maintain weight': {
    'ar': 'الحفاظ على الوزن',
    'fr': 'Maintenir le poids',
    'es': 'Mantener el peso',
    'tr': 'Kiloyu koru',
  },
  'Gain 0.2 kg per week': {
    'ar': 'زيادة 0.2 كجم أسبوعيًا',
    'fr': 'Prendre 0,2 kg par semaine',
    'es': 'Ganar 0,2 kg por semana',
    'tr': 'Haftada 0,2 kg al',
  },
  'Gain 0.5 kg per week': {
    'ar': 'زيادة 0.5 كجم أسبوعيًا',
    'fr': 'Prendre 0,5 kg par semaine',
    'es': 'Ganar 0,5 kg por semana',
    'tr': 'Haftada 0,5 kg al',
  },
  'Not Very Active': {
    'ar': 'قليل النشاط',
    'fr': 'Peu actif',
    'es': 'Poco activo',
    'tr': 'Az aktif',
  },
  'Lightly Active': {
    'ar': 'نشاط خفيف',
    'fr': 'Légèrement actif',
    'es': 'Ligeramente activo',
    'tr': 'Hafif aktif',
  },
  'Active': {'ar': 'نشيط', 'fr': 'Actif', 'es': 'Activo', 'tr': 'Aktif'},
  'Very Active': {
    'ar': 'نشيط جدًا',
    'fr': 'Très actif',
    'es': 'Muy activo',
    'tr': 'Çok aktif',
  },
  'Calorie, Carbs, Protein and Fat Goals': {
    'ar': 'أهداف السعرات والكربوهيدرات والبروتين والدهون',
    'fr': 'Objectifs calories et macros',
    'es': 'Objetivos de calorías y macros',
    'tr': 'Kalori ve makro hedefleri',
  },
  'Customize your default or daily goals.': {
    'ar': 'خصص أهدافك الافتراضية أو اليومية.',
    'fr': 'Personnalisez vos objectifs.',
    'es': 'Personaliza tus objetivos.',
    'tr': 'Hedeflerinizi özelleştirin.',
  },
  'Different goals by day': {
    'ar': 'أهداف مختلفة حسب اليوم',
    'fr': 'Objectifs différents selon le jour',
    'es': 'Objetivos diferentes según el día',
    'tr': 'Güne göre farklı hedefler',
  },
  'Set calories and macros for each day of the week.': {
    'ar': 'حدد السعرات والماكروز لكل يوم من أيام الأسبوع.',
    'fr': 'Définissez calories et macros pour chaque jour.',
    'es': 'Define calorías y macros para cada día.',
    'tr': 'Haftanın her günü için kalori ve makroları ayarlayın.',
  },
  'Calorie Goals By Meal': {
    'ar': 'أهداف السعرات حسب الوجبة',
    'fr': 'Calories par repas',
    'es': 'Calorías por comida',
    'tr': 'Öğün başına kalori',
  },
  'Stay on track with a calorie goal for each meal.': {
    'ar': 'حدد هدف سعرات لكل وجبة.',
    'fr': 'Un objectif calorique par repas.',
    'es': 'Un objetivo por comida.',
    'tr': 'Her öğün için hedef.',
  },
  'Show Carbs, Protein and Fat By Meal': {
    'ar': 'عرض الماكروز حسب الوجبة',
    'fr': 'Macros par repas',
    'es': 'Macros por comida',
    'tr': 'Öğün makroları',
  },
  'View carbs, protein and fat by gram or percent.': {
    'ar': 'اعرضها بالغرام أو النسبة.',
    'fr': 'En grammes ou pourcentage.',
    'es': 'En gramos o porcentaje.',
    'tr': 'Gram veya yüzde olarak.',
  },
  'Additional Nutrient Goals': {
    'ar': 'أهداف المغذيات الإضافية',
    'fr': 'Objectifs nutritionnels supplémentaires',
    'es': 'Objetivos adicionales',
    'tr': 'Ek besin hedefleri',
  },
  'Workouts/Week': {
    'ar': 'تمارين/أسبوع',
    'fr': 'Séances/semaine',
    'es': 'Entrenamientos/semana',
    'tr': 'Egzersiz/hafta',
  },
  'Minutes/Workout': {
    'ar': 'دقائق/تمرين',
    'fr': 'Minutes/séance',
    'es': 'Minutos/entrenamiento',
    'tr': 'Dakika/egzersiz',
  },
  'Exercise Calories': {
    'ar': 'سعرات التمرين',
    'fr': "Calories d’exercice",
    'es': 'Calorías del ejercicio',
    'tr': 'Egzersiz kalorileri',
  },
  'Decide whether to adjust daily goals when you exercise.': {
    'ar': 'حدد ما إذا كانت الأهداف اليومية تتغير مع التمرين.',
    'fr': 'Ajuster les objectifs avec l’exercice.',
    'es': 'Ajustar objetivos al hacer ejercicio.',
    'tr': 'Egzersizde hedefleri ayarla.',
  },
};
