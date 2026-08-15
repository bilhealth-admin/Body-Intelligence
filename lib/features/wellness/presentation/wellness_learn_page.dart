import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/environment/app_environment.dart';
import 'wellness_copy.dart';

class WellnessLearnPage extends StatefulWidget {
  const WellnessLearnPage({super.key});

  @override
  State<WellnessLearnPage> createState() => _WellnessLearnPageState();
}

class _WellnessLearnPageState extends State<WellnessLearnPage> {
  String topic = 'All';
  final searchController = TextEditingController();
  String query = '';
  bool sharing = false;

  Future<void> _share(String text) async {
    if (sharing) return;
    setState(() => sharing = true);
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wellnessCopy(
                context,
                'Sharing is unavailable right now.',
                'تعذرت المشاركة الآن.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final articles = _articles(context).where((article) {
      final matchesTopic = topic == 'All' || article.topic == topic;
      final haystack = '${article.title} ${article.body} ${article.topic}'
          .toLowerCase();
      return matchesTopic &&
          (normalizedQuery.isEmpty || haystack.contains(normalizedQuery));
    }).toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(wellnessCopy(context, 'Learn', 'تعلّم')),
        actions: [
          IconButton(
            tooltip: wellnessCopy(context, 'Share', 'مشاركة'),
            onPressed: sharing
                ? null
                : () => _share(
                    wellnessCopy(
                      context,
                      'Explore general wellness education in BIL. Its internal basis and limits are shown in every article.',
                      'استكشف التثقيف الصحي العام في BIL. يظهر الأساس الداخلي وحدود الاستخدام في كل مادة.',
                    ),
                  ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
        children: [
          SearchBar(
            controller: searchController,
            hintText: wellnessCopy(
              context,
              'Search learning topics',
              'ابحث في موضوعات التعلّم',
            ),
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (query.isNotEmpty)
                IconButton(
                  tooltip: wellnessCopy(context, 'Clear search', 'مسح البحث'),
                  onPressed: () {
                    searchController.clear();
                    setState(() => query = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 24),
          if (normalizedQuery.isEmpty && topic == 'All') ...[
            Text(
              wellnessCopy(
                context,
                'Educational highlights',
                'مختارات تعليمية',
              ),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _SpotlightCard(article: _articles(context).first),
            const SizedBox(height: 30),
          ],
          Text(
            wellnessCopy(context, 'Topics', 'الموضوعات'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in const [
                'All',
                'Nutrition',
                'Movement',
                'Sleep',
                'Privacy',
              ])
                ChoiceChip(
                  selected: topic == value,
                  label: Text(_topicLabel(context, value)),
                  onSelected: (_) => setState(() => topic = value),
                ),
            ],
          ),
          const SizedBox(height: 18),
          for (final article in articles.skip(
            topic == 'All' && normalizedQuery.isEmpty ? 1 : 0,
          )) ...[_ArticleCard(article: article), const SizedBox(height: 14)],
          if (articles.isEmpty)
            _LearnEmptySearch(
              onClear: () {
                searchController.clear();
                setState(() {
                  query = '';
                  topic = 'All';
                });
              },
            ),
          if (topic == 'All' && normalizedQuery.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _learnText(
                context,
                'Explore more',
                'استكشف المزيد',
                'Explorer davantage',
                'Explorar más',
                'Daha fazlasını keşfet',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _LearnDestination(
              icon: Icons.restaurant_menu_rounded,
              title: _learnText(
                context,
                'Nutrition education',
                'التثقيف الغذائي',
                'Éducation nutritionnelle',
                'Educación nutricional',
                'Beslenme eğitimi',
              ),
              subtitle: _learnText(
                context,
                'Learn about portions and practical food skills',
                'الأدلة والحصص ومهارات الطعام العملية',
                'Données, portions et compétences alimentaires',
                'Evidencia, porciones y habilidades prácticas',
                'Kanıt, porsiyon ve pratik beslenme becerileri',
              ),
              onTap: () => context.push('/nutrition-plans'),
            ),
            _LearnDestination(
              icon: Icons.eco_outlined,
              title: _learnText(
                context,
                'Nutrients',
                'المغذيات',
                'Nutriments',
                'Nutrientes',
                'Besin öğeleri',
              ),
              subtitle: _learnText(
                context,
                'Understand macros, fiber and minerals',
                'افهم الماكروز والألياف والمعادن',
                'Comprendre les macros, fibres et minéraux',
                'Comprende macros, fibra y minerales',
                'Makroları, lifi ve mineralleri anlayın',
              ),
              onTap: () => context.push('/analytics/nutrition'),
            ),
            _LearnDestination(
              icon: Icons.auto_stories_outlined,
              title: _learnText(
                context,
                'Your progress history',
                'سجل تقدمك',
                'Votre historique de progression',
                'Tu historial de progreso',
                'İlerleme geçmişiniz',
              ),
              subtitle: _learnText(
                context,
                'Review patterns without comparisons or judgment',
                'راجع الأنماط دون مقارنة أو أحكام',
                'Observer les tendances sans comparaison ni jugement',
                'Revisa patrones sin comparaciones ni juicios',
                'Örüntüleri kıyaslama veya yargı olmadan inceleyin',
              ),
              onTap: () => context.push('/history'),
            ),
            _LearnDestination(
              icon: Icons.soup_kitchen_outlined,
              title: _learnText(
                context,
                'Recipe library',
                'مكتبة الوصفات',
                'Bibliothèque de recettes',
                'Biblioteca de recetas',
                'Tarif kitaplığı',
              ),
              subtitle: _learnText(
                context,
                'Browse recipes with their available ingredients and nutrition details',
                'وصفات متوازنة بمكونات كاملة',
                'Recettes équilibrées avec ingrédients complets',
                'Recetas equilibradas con ingredientes completos',
                'Tam malzemeli dengeli tarifler',
              ),
              onTap: () => context.push('/wellness/recipes'),
            ),
            _LearnDestination(
              icon: Icons.quiz_outlined,
              title: _learnText(
                context,
                'Wellness tools',
                'أدوات الصحة',
                'Outils de bien-être',
                'Herramientas de bienestar',
                'Sağlık araçları',
              ),
              subtitle: _learnText(
                context,
                'Explore goals, sleep, movement and recovery',
                'استكشف الأهداف والنوم والحركة والتعافي',
                'Explorer objectifs, sommeil, mouvement et récupération',
                'Explora objetivos, sueño, movimiento y recuperación',
                'Hedef, uyku, hareket ve toparlanmayı keşfedin',
              ),
              onTap: () => context.push('/wellness-library'),
            ),
            if (AppEnvironment.communityConfigured)
              _LearnDestination(
                icon: Icons.groups_2_outlined,
                title: _learnText(
                  context,
                  'Community discussions',
                  'نقاشات المجتمع',
                  'Discussions communautaires',
                  'Conversaciones de la comunidad',
                  'Topluluk tartışmaları',
                ),
                subtitle: _learnText(
                  context,
                  'Discuss food and wellness with clear safety rules',
                  'ناقش الطعام والصحة ضمن قواعد سلامة واضحة',
                  'Échanger sur l’alimentation avec des règles claires',
                  'Habla de alimentación con reglas de seguridad claras',
                  'Beslenmeyi açık güvenlik kurallarıyla tartışın',
                ),
                onTap: () => context.push('/community'),
              ),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      wellnessCopy(
                        context,
                        'BIL education is general information, not diagnosis or treatment. Its internal basis and limits are shown in every article.',
                        'محتوى BIL للتثقيف العام وليس تشخيصًا أو علاجًا. يظهر الأساس الداخلي وحدود الاستخدام داخل كل مادة.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _topicLabel(BuildContext context, String value) => switch (value) {
    'All' => wellnessCopy(context, 'All', 'الكل'),
    'Nutrition' => wellnessCopy(context, 'Nutrition', 'التغذية'),
    'Movement' => wellnessCopy(context, 'Movement', 'الحركة'),
    'Sleep' => wellnessCopy(context, 'Sleep', 'النوم'),
    'Privacy' => wellnessCopy(context, 'Privacy', 'الخصوصية'),
    _ => value,
  };
}

String _learnText(
  BuildContext context,
  String en,
  String ar,
  String fr,
  String es,
  String tr,
) => switch (Localizations.localeOf(context).languageCode) {
  'ar' => ar,
  'fr' => fr,
  'es' => es,
  'tr' => tr,
  _ => en,
};

class _LearnDestination extends StatelessWidget {
  const _LearnDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      minTileHeight: 82,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _LearnEmptySearch extends StatelessWidget {
  const _LearnEmptySearch({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            wellnessCopy(
              context,
              'No learning topics match this search.',
              'لا توجد موضوعات تعلّم تطابق هذا البحث.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onClear,
            child: Text(wellnessCopy(context, 'Clear search', 'مسح البحث')),
          ),
        ],
      ),
    ),
  );
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.article});

  final _LearnArticle article;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: InkWell(
          onTap: () => _showArticle(context, article),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(article.asset, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  article.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final _LearnArticle article;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showArticle(context, article),
        child: Row(
          children: [
            SizedBox(
              width: 116,
              height: 112,
              child: Image.asset(article.asset, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.source,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showArticle(BuildContext context, _LearnArticle article) {
  var sharing = false;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(article.body),
                const SizedBox(height: 18),
                Text(
                  article.source,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: sharing
                        ? null
                        : () async {
                            setSheetState(() => sharing = true);
                            try {
                              await SharePlus.instance.share(
                                ShareParams(
                                  text:
                                      '${article.title}\n\n${article.body}\n\n${article.source}\n\n${wellnessCopy(context, 'BIL education is general information, not diagnosis or treatment. Its internal basis and limits are shown in every article.', 'محتوى BIL للتثقيف العام وليس تشخيصًا أو علاجًا. يظهر الأساس الداخلي وحدود الاستخدام داخل كل مادة.')}',
                                ),
                              );
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      wellnessCopy(
                                        context,
                                        'Sharing is unavailable right now.',
                                        'تعذرت المشاركة الآن.',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setSheetState(() => sharing = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(
                      wellnessCopy(context, 'Share article', 'مشاركة المادة'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

List<_LearnArticle> _articles(BuildContext context) => [
  _LearnArticle(
    topic: 'Nutrition',
    asset: 'assets/images/professional/recipes/yogurt_oat_bowl.jpg',
    title: wellnessCopy(
      context,
      'How to read your food log without judgment',
      'كيف تقرأ سجل طعامك دون أحكام؟',
    ),
    body: wellnessCopy(
      context,
      'Look for a pattern across several days instead of judging one meal. Compare energy, protein, and fiber only when logs are complete and nutrition sources are documented.',
      'ابحث عن نمط يمتد عدة أيام بدل الحكم على وجبة واحدة. قارن الطاقة والبروتين والألياف فقط عندما تكون السجلات مكتملة ومصادر القيم موثقة.',
    ),
    source: wellnessCopy(
      context,
      'BIL internal editorial basis • General education',
      'أساس تحريري داخلي من BIL • تثقيف عام',
    ),
  ),
  _LearnArticle(
    topic: 'Movement',
    asset: 'assets/images/professional/workouts/brisk_walk.jpg',
    title: wellnessCopy(
      context,
      'Consistency matters more than a perfect day',
      'التدرج أهم من يوم مثالي',
    ),
    body: wellnessCopy(
      context,
      'Start with a duration that matches your current capacity, then progress gradually. Stop and seek professional assessment for sharp pain, dizziness, or unusual breathlessness.',
      'ابدأ بمدة تناسب قدرتك الحالية، ثم زد الحمل تدريجيًا. أوقف النشاط واطلب تقييمًا مختصًا عند ألم حاد أو دوار أو ضيق نفس غير معتاد.',
    ),
    source: wellnessCopy(
      context,
      'BIL internal safety basis • Not a treatment prescription',
      'أساس سلامة داخلي من BIL • ليس وصفة علاجية',
    ),
  ),
  _LearnArticle(
    topic: 'Sleep',
    asset: 'assets/images/flagship/bil_sleep_insights_v1.png',
    title: wellnessCopy(
      context,
      'Why one night cannot explain your sleep',
      'لماذا لا تكفي ليلة واحدة لفهم النوم؟',
    ),
    body: wellnessCopy(
      context,
      'BIL shows a trend only when enough recorded days exist and marks missing days instead of estimating them. Record sleep, wake time, and context honestly.',
      'يعرض BIL الاتجاه فقط عندما توجد أيام مسجلة كافية، ويميّز الأيام الناقصة بدل تقديرها. سجّل وقت النوم والاستيقاظ والسياق بصدق.',
    ),
    source: wellnessCopy(
      context,
      'BIL internal editorial content • General education',
      'محتوى تحريري داخلي من BIL • تثقيف عام',
    ),
  ),
  _LearnArticle(
    topic: 'Privacy',
    asset: 'assets/images/flagship/bil_body_intelligence_journey_v1.png',
    title: wellnessCopy(
      context,
      'Your health data stays under your control',
      'بياناتك الصحية تحت سيطرتك',
    ),
    body: wellnessCopy(
      context,
      "The log can work locally without an account. Cloud sync and supported health connections remain off until you enable their available controls. Review each feature's settings before sharing or deleting data.",
      'يمكن أن يعمل السجل محليًا دون حساب. تظل المزامنة السحابية والاتصالات الصحية المدعومة متوقفة حتى تفعّل عناصر التحكم المتاحة لها. راجع إعدادات كل ميزة قبل مشاركة البيانات أو حذفها.',
    ),
    source: wellnessCopy(
      context,
      'BIL internal privacy principles',
      'مبادئ الخصوصية الداخلية في BIL',
    ),
  ),
];

class _LearnArticle {
  const _LearnArticle({
    required this.topic,
    required this.asset,
    required this.title,
    required this.body,
    required this.source,
  });

  final String topic;
  final String asset;
  final String title;
  final String body;
  final String source;
}
