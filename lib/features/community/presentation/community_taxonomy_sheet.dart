import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CommunityTaxonomySheet extends StatelessWidget {
  const CommunityTaxonomySheet({required this.onSelectTag, super.key});

  final ValueChanged<String> onSelectTag;

  static String browseLabel(BuildContext context) =>
      _CommunityTaxonomyCopy.of(context).browse;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onSelectTag,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CommunityTaxonomySheet(onSelectTag: onSelectTag),
  );

  @override
  Widget build(BuildContext context) {
    final copy = _CommunityTaxonomyCopy.of(context);
    final categories = <(IconData, String, String, String)>[
      (
        Icons.rocket_launch_outlined,
        copy.gettingStarted,
        copy.gettingStartedBody,
        'getting-started',
      ),
      (
        Icons.monitor_weight_outlined,
        copy.healthWeightLoss,
        copy.healthWeightLossBody,
        'weight-loss',
      ),
      (
        Icons.restaurant_outlined,
        copy.foodNutrition,
        copy.foodNutritionBody,
        'nutrition',
      ),
      (Icons.menu_book_outlined, copy.recipes, copy.recipesBody, 'recipes'),
      (
        Icons.fitness_center_outlined,
        copy.fitnessExercise,
        copy.fitnessExerciseBody,
        'fitness',
      ),
      (
        Icons.self_improvement_outlined,
        copy.wellness,
        copy.wellnessBody,
        'wellness',
      ),
      (
        Icons.trending_flat_rounded,
        copy.maintainingWeight,
        copy.maintainingWeightBody,
        'maintenance',
      ),
      (
        Icons.sports_gymnastics_outlined,
        copy.gainingWeight,
        copy.gainingWeightBody,
        'muscle-gain',
      ),
      (
        Icons.emoji_events_outlined,
        copy.successStories,
        copy.successStoriesBody,
        'success-stories',
      ),
      (
        Icons.volunteer_activism_outlined,
        copy.motivation,
        copy.motivationBody,
        'motivation-support',
      ),
      (Icons.flag_outlined, copy.challenges, copy.challengesBody, 'challenges'),
      (Icons.forum_outlined, copy.debate, copy.debateBody, 'debate'),
      (
        Icons.groups_outlined,
        copy.socialCorner,
        copy.socialCornerBody,
        'social',
      ),
      (
        Icons.chat_bubble_outline,
        copy.chitChat,
        copy.chitChatBody,
        'chit-chat',
      ),
      (
        Icons.sports_esports_outlined,
        copy.funGames,
        copy.funGamesBody,
        'fun-games',
      ),
      (
        Icons.info_outline,
        copy.bilInformation,
        copy.bilInformationBody,
        'bil-information',
      ),
      (Icons.school_outlined, copy.academy, copy.academyBody, 'academy'),
      (
        Icons.lightbulb_outline,
        copy.featureSuggestions,
        copy.featureSuggestionsBody,
        'feature-request',
      ),
      (
        Icons.support_agent_outlined,
        copy.techSupport,
        copy.techSupportBody,
        'support',
      ),
    ];
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .9,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(copy.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(copy.subtitle),
            const SizedBox(height: 16),
            for (final category in categories)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(category.$1),
                  title: Text(category.$2),
                  subtitle: Text(category.$3),
                  trailing: const Icon(Icons.tag_rounded),
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelectTag(category.$4);
                  },
                ),
              ),
            const SizedBox(height: 12),
            Text(
              copy.quickLinks,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Link(
                  copy.posts,
                  Icons.forum_outlined,
                  () => Navigator.of(context).pop(),
                ),
                _Link(
                  copy.friends,
                  Icons.group_outlined,
                  () => context.push('/community/connections'),
                ),
                _Link(
                  copy.messages,
                  Icons.mail_outline,
                  () => context.push('/community/messages'),
                ),
                _Link(
                  copy.guidelines,
                  Icons.shield_outlined,
                  () => context.push('/community/safety'),
                ),
                _Link(
                  copy.help,
                  Icons.help_outline,
                  () => context.push('/help'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              copy.popularTags,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children:
                  const [
                        'nutrition',
                        'fitness',
                        'recipes',
                        'wellness',
                        'weight-loss',
                      ]
                      .map(
                        (tag) => ActionChip(
                          label: Text('#$tag'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            onSelectTag(tag);
                          },
                        ),
                      )
                      .toList(growable: false),
            ),
            const SizedBox(height: 14),
            Text(copy.noCounts, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.icon, this.onPressed);
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    onPressed: onPressed,
  );
}

class _CommunityTaxonomyCopy {
  const _CommunityTaxonomyCopy(this.values);
  final Map<String, String> values;
  String _v(String key) => values[key]!;
  String get title => _v('title');
  String get browse => _v('browse');
  String get subtitle => _v('subtitle');
  String get quickLinks => _v('quickLinks');
  String get popularTags => _v('popularTags');
  String get noCounts => _v('noCounts');
  String get gettingStarted => _v('gettingStarted');
  String get gettingStartedBody => _v('gettingStartedBody');
  String get healthWeightLoss => _v('healthWeightLoss');
  String get healthWeightLossBody => _v('healthWeightLossBody');
  String get foodNutrition => _v('foodNutrition');
  String get foodNutritionBody => _v('foodNutritionBody');
  String get recipes => _v('recipes');
  String get recipesBody => _v('recipesBody');
  String get fitnessExercise => _v('fitnessExercise');
  String get fitnessExerciseBody => _v('fitnessExerciseBody');
  String get wellness => _v('wellness');
  String get wellnessBody => _v('wellnessBody');
  String get maintainingWeight => _v('maintainingWeight');
  String get maintainingWeightBody => _v('maintainingWeightBody');
  String get gainingWeight => _v('gainingWeight');
  String get gainingWeightBody => _v('gainingWeightBody');
  String get successStories => _v('successStories');
  String get successStoriesBody => _v('successStoriesBody');
  String get motivation => _v('motivation');
  String get motivationBody => _v('motivationBody');
  String get challenges => _v('challenges');
  String get challengesBody => _v('challengesBody');
  String get debate => _v('debate');
  String get debateBody => _v('debateBody');
  String get socialCorner => _v('socialCorner');
  String get socialCornerBody => _v('socialCornerBody');
  String get chitChat => _v('chitChat');
  String get chitChatBody => _v('chitChatBody');
  String get funGames => _v('funGames');
  String get funGamesBody => _v('funGamesBody');
  String get bilInformation => _v('bilInformation');
  String get bilInformationBody => _v('bilInformationBody');
  String get academy => _v('academy');
  String get academyBody => _v('academyBody');
  String get featureSuggestions => _v('featureSuggestions');
  String get featureSuggestionsBody => _v('featureSuggestionsBody');
  String get techSupport => _v('techSupport');
  String get techSupportBody => _v('techSupportBody');
  String get posts => _v('posts');
  String get friends => _v('friends');
  String get messages => _v('messages');
  String get guidelines => _v('guidelines');
  String get help => _v('help');

  static _CommunityTaxonomyCopy of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return _CommunityTaxonomyCopy(_copy[code] ?? _copy['en']!);
  }
}

const _copy = <String, Map<String, String>>{
  'en': {
    'title': 'Community topics',
    'browse': 'Browse community topics',
    'subtitle': 'Choose a topic to start a clearly labelled BIL discussion.',
    'quickLinks': 'Quick links',
    'popularTags': 'Popular tags',
    'noCounts':
        'Counts are shown only when real community analytics are available.',
    'gettingStarted': 'Getting Started',
    'gettingStartedBody': 'Learn how to use BIL and share safe first steps.',
    'healthWeightLoss': 'Health and Weight Loss',
    'healthWeightLossBody': 'Discuss sustainable goals without medical claims.',
    'foodNutrition': 'Food and Nutrition',
    'foodNutritionBody':
        'Share practical nutrition experiences and verified sources.',
    'recipes': 'Recipes',
    'recipesBody': 'Exchange recipes and preparation ideas.',
    'fitnessExercise': 'Fitness and Exercise',
    'fitnessExerciseBody': 'Discuss movement, training, and recovery.',
    'wellness': 'Sleep, Mindfulness and Wellness',
    'wellnessBody': 'Discuss sleep, stress, and wellbeing habits.',
    'maintainingWeight': 'Maintaining Weight',
    'maintainingWeightBody': 'Share maintenance strategies and lessons.',
    'gainingWeight': 'Gaining Weight and Muscle',
    'gainingWeightBody': 'Discuss gradual weight and muscle gain.',
    'successStories': 'Success Stories',
    'successStoriesBody':
        'Share milestones and lessons without comparison pressure.',
    'motivation': 'Motivation and Support',
    'motivationBody': 'Ask for encouragement and support other members.',
    'challenges': 'Challenges',
    'challengesBody': 'Join safe, clearly defined community challenges.',
    'debate': 'Debate Club',
    'debateBody': 'Discuss evidence respectfully and cite reliable sources.',
    'socialCorner': 'Social Corner',
    'socialCornerBody': 'Connect around life beyond tracking.',
    'chitChat': 'Chit-Chat',
    'chitChatBody': 'Have friendly off-topic conversations.',
    'funGames': 'Fun and Games',
    'funGamesBody': 'Share light activities and community games.',
    'bilInformation': 'BIL Information and News',
    'bilInformationBody': 'Read verified BIL updates and announcements.',
    'academy': 'BIL Academy',
    'academyBody': 'Learn practical skills from reviewed educational material.',
    'featureSuggestions': 'Feature Suggestions',
    'featureSuggestionsBody': 'Suggest improvements for BIL.',
    'techSupport': 'Tech Support',
    'techSupportBody': 'Ask for help with BIL features.',
    'posts': 'Posts',
    'friends': 'Friends',
    'messages': 'Messages',
    'guidelines': 'Guidelines',
    'help': 'Help',
  },
  'ar': {
    'title': 'موضوعات المجتمع',
    'browse': 'تصفح موضوعات المجتمع',
    'subtitle': 'اختر موضوعًا لبدء نقاش واضح التصنيف في BIL.',
    'quickLinks': 'روابط سريعة',
    'popularTags': 'الوسوم الشائعة',
    'noCounts': 'لا تظهر الأعداد إلا عند توفر تحليلات مجتمع حقيقية.',
    'gettingStarted': 'البدء',
    'gettingStartedBody': 'تعلّم استخدام BIL وشارك خطوات أولى آمنة.',
    'healthWeightLoss': 'الصحة وخسارة الوزن',
    'healthWeightLossBody': 'ناقش أهدافًا مستدامة دون ادعاءات طبية.',
    'foodNutrition': 'الطعام والتغذية',
    'foodNutritionBody': 'شارك تجارب تغذية عملية ومصادر موثقة.',
    'recipes': 'الوصفات',
    'recipesBody': 'تبادل الوصفات وأفكار التحضير.',
    'fitnessExercise': 'اللياقة والتمارين',
    'fitnessExerciseBody': 'ناقش الحركة والتدريب والتعافي.',
    'wellness': 'النوم واليقظة والعافية',
    'wellnessBody': 'ناقش عادات النوم والتوتر والعافية.',
    'maintainingWeight': 'الحفاظ على الوزن',
    'maintainingWeightBody': 'شارك استراتيجيات الحفاظ والدروس.',
    'gainingWeight': 'زيادة الوزن والعضلات',
    'gainingWeightBody': 'ناقش الزيادة التدريجية للوزن والعضلات.',
    'successStories': 'قصص النجاح',
    'successStoriesBody': 'شارك إنجازاتك ودروسك دون ضغط المقارنة.',
    'motivation': 'التحفيز والدعم',
    'motivationBody': 'اطلب التشجيع وساند أعضاء المجتمع.',
    'challenges': 'التحديات',
    'challengesBody': 'انضم إلى تحديات مجتمعية آمنة وواضحة.',
    'debate': 'نادي النقاش',
    'debateBody': 'ناقش الأدلة باحترام واستشهد بمصادر موثوقة.',
    'socialCorner': 'الركن الاجتماعي',
    'socialCornerBody': 'تواصل حول الحياة خارج التتبع.',
    'chitChat': 'دردشة عامة',
    'chitChatBody': 'تحدث بود في موضوعات عامة.',
    'funGames': 'المرح والألعاب',
    'funGamesBody': 'شارك أنشطة خفيفة وألعابًا مجتمعية.',
    'bilInformation': 'معلومات وأخبار BIL',
    'bilInformationBody': 'اطلع على تحديثات وإعلانات BIL الموثقة.',
    'academy': 'أكاديمية BIL',
    'academyBody': 'تعلّم مهارات عملية من مواد تعليمية مراجعة.',
    'featureSuggestions': 'اقتراحات الميزات',
    'featureSuggestionsBody': 'اقترح تحسينات لتطبيق BIL.',
    'techSupport': 'الدعم التقني',
    'techSupportBody': 'اطلب المساعدة في ميزات BIL.',
    'posts': 'المشاركات',
    'friends': 'الأصدقاء',
    'messages': 'الرسائل',
    'guidelines': 'الإرشادات',
    'help': 'المساعدة',
  },
  'fr': {
    'title': 'Sujets de la communauté',
    'browse': 'Parcourir les sujets',
    'subtitle':
        'Choisissez un sujet pour lancer une discussion BIL clairement identifiée.',
    'quickLinks': 'Liens rapides',
    'popularTags': 'Tags populaires',
    'noCounts':
        'Les nombres ne sont affichés que si des statistiques réelles sont disponibles.',
    'gettingStarted': 'Bien démarrer',
    'gettingStartedBody':
        'Découvrez BIL et partagez vos premiers pas en sécurité.',
    'healthWeightLoss': 'Santé et perte de poids',
    'healthWeightLossBody':
        'Discutez d’objectifs durables sans allégations médicales.',
    'foodNutrition': 'Alimentation et nutrition',
    'foodNutritionBody':
        'Partagez des expériences pratiques et des sources vérifiées.',
    'recipes': 'Recettes',
    'recipesBody': 'Échangez des recettes et des idées de préparation.',
    'fitnessExercise': 'Fitness et exercice',
    'fitnessExerciseBody': 'Discutez mouvement, entraînement et récupération.',
    'wellness': 'Sommeil, pleine conscience et bien-être',
    'wellnessBody': 'Discutez sommeil, stress et habitudes de bien-être.',
    'maintainingWeight': 'Maintien du poids',
    'maintainingWeightBody': 'Partagez stratégies et enseignements.',
    'gainingWeight': 'Prise de poids et de muscle',
    'gainingWeightBody': 'Discutez d’une progression graduelle.',
    'successStories': 'Histoires de réussite',
    'successStoriesBody':
        'Partagez vos étapes et leçons sans pression comparative.',
    'motivation': 'Motivation et soutien',
    'motivationBody': 'Demandez des encouragements et soutenez les membres.',
    'challenges': 'Défis',
    'challengesBody': 'Rejoignez des défis sûrs et clairement définis.',
    'debate': 'Club de débat',
    'debateBody': 'Discutez des preuves avec respect et des sources fiables.',
    'socialCorner': 'Coin social',
    'socialCornerBody': 'Échangez autour de la vie au-delà du suivi.',
    'chitChat': 'Bavardage',
    'chitChatBody': 'Discutez amicalement de sujets variés.',
    'funGames': 'Jeux et détente',
    'funGamesBody': 'Partagez des activités légères et des jeux.',
    'bilInformation': 'Informations et actualités BIL',
    'bilInformationBody': 'Consultez les mises à jour BIL vérifiées.',
    'academy': 'Académie BIL',
    'academyBody': 'Apprenez avec des contenus éducatifs révisés.',
    'featureSuggestions': 'Suggestions de fonctions',
    'featureSuggestionsBody': 'Proposez des améliorations pour BIL.',
    'techSupport': 'Assistance technique',
    'techSupportBody': 'Demandez de l’aide sur les fonctions BIL.',
    'posts': 'Publications',
    'friends': 'Amis',
    'messages': 'Messages',
    'guidelines': 'Règles',
    'help': 'Aide',
  },
  'es': {
    'title': 'Temas de la comunidad',
    'browse': 'Explorar temas',
    'subtitle':
        'Elige un tema para iniciar una conversación BIL bien etiquetada.',
    'quickLinks': 'Enlaces rápidos',
    'popularTags': 'Etiquetas populares',
    'noCounts':
        'Los recuentos solo aparecen cuando hay analíticas reales disponibles.',
    'gettingStarted': 'Primeros pasos',
    'gettingStartedBody':
        'Aprende a usar BIL y comparte primeros pasos seguros.',
    'healthWeightLoss': 'Salud y pérdida de peso',
    'healthWeightLossBody':
        'Habla de objetivos sostenibles sin afirmaciones médicas.',
    'foodNutrition': 'Alimentación y nutrición',
    'foodNutritionBody':
        'Comparte experiencias prácticas y fuentes verificadas.',
    'recipes': 'Recetas',
    'recipesBody': 'Intercambia recetas e ideas de preparación.',
    'fitnessExercise': 'Fitness y ejercicio',
    'fitnessExerciseBody': 'Habla de movimiento, entrenamiento y recuperación.',
    'wellness': 'Sueño, atención plena y bienestar',
    'wellnessBody': 'Habla de sueño, estrés y hábitos de bienestar.',
    'maintainingWeight': 'Mantener el peso',
    'maintainingWeightBody': 'Comparte estrategias y aprendizajes.',
    'gainingWeight': 'Ganar peso y músculo',
    'gainingWeightBody': 'Habla de un aumento gradual de peso y músculo.',
    'successStories': 'Historias de éxito',
    'successStoriesBody':
        'Comparte logros y aprendizajes sin presión comparativa.',
    'motivation': 'Motivación y apoyo',
    'motivationBody': 'Pide ánimo y apoya a otros miembros.',
    'challenges': 'Desafíos',
    'challengesBody': 'Participa en desafíos seguros y bien definidos.',
    'debate': 'Club de debate',
    'debateBody': 'Debate evidencias con respeto y fuentes fiables.',
    'socialCorner': 'Rincón social',
    'socialCornerBody': 'Conecta sobre la vida más allá del registro.',
    'chitChat': 'Charlas',
    'chitChatBody': 'Conversa amistosamente sobre otros temas.',
    'funGames': 'Diversión y juegos',
    'funGamesBody': 'Comparte actividades ligeras y juegos.',
    'bilInformation': 'Información y noticias de BIL',
    'bilInformationBody': 'Consulta actualizaciones verificadas de BIL.',
    'academy': 'Academia BIL',
    'academyBody': 'Aprende con material educativo revisado.',
    'featureSuggestions': 'Sugerencias de funciones',
    'featureSuggestionsBody': 'Sugiere mejoras para BIL.',
    'techSupport': 'Soporte técnico',
    'techSupportBody': 'Pide ayuda con las funciones de BIL.',
    'posts': 'Publicaciones',
    'friends': 'Amigos',
    'messages': 'Mensajes',
    'guidelines': 'Normas',
    'help': 'Ayuda',
  },
  'tr': {
    'title': 'Topluluk konuları',
    'browse': 'Topluluk konularına göz at',
    'subtitle':
        'Açıkça etiketlenmiş bir BIL tartışması başlatmak için konu seçin.',
    'quickLinks': 'Hızlı bağlantılar',
    'popularTags': 'Popüler etiketler',
    'noCounts': 'Sayılar yalnızca gerçek topluluk analizleri varsa gösterilir.',
    'gettingStarted': 'Başlangıç',
    'gettingStartedBody':
        'BIL kullanımını öğrenin ve güvenli ilk adımları paylaşın.',
    'healthWeightLoss': 'Sağlık ve kilo verme',
    'healthWeightLossBody':
        'Tıbbi iddialar olmadan sürdürülebilir hedefleri konuşun.',
    'foodNutrition': 'Yemek ve beslenme',
    'foodNutritionBody':
        'Pratik deneyimleri ve doğrulanmış kaynakları paylaşın.',
    'recipes': 'Tarifler',
    'recipesBody': 'Tarifleri ve hazırlama fikirlerini paylaşın.',
    'fitnessExercise': 'Fitness ve egzersiz',
    'fitnessExerciseBody': 'Hareket, antrenman ve toparlanmayı konuşun.',
    'wellness': 'Uyku, farkındalık ve esenlik',
    'wellnessBody': 'Uyku, stres ve esenlik alışkanlıklarını konuşun.',
    'maintainingWeight': 'Kiloyu koruma',
    'maintainingWeightBody': 'Koruma stratejilerini ve deneyimleri paylaşın.',
    'gainingWeight': 'Kilo ve kas kazanımı',
    'gainingWeightBody': 'Kademeli kilo ve kas artışını konuşun.',
    'successStories': 'Başarı Hikâyeleri',
    'successStoriesBody': 'Kıyas baskısı olmadan dönüm noktalarını paylaş.',
    'motivation': 'Motivasyon ve Destek',
    'motivationBody': 'Teşvik iste ve diğer üyelere destek ol.',
    'challenges': 'Meydan Okumalar',
    'challengesBody': 'Güvenli ve açıkça tanımlanmış görevlere katıl.',
    'debate': 'Tartışma Kulübü',
    'debateBody': 'Kanıtları saygıyla ve güvenilir kaynaklarla tartış.',
    'socialCorner': 'Sosyal Köşe',
    'socialCornerBody': 'Takibin ötesindeki yaşam hakkında bağlantı kur.',
    'chitChat': 'Sohbet',
    'chitChatBody': 'Farklı konularda dostça sohbet et.',
    'funGames': 'Eğlence ve Oyunlar',
    'funGamesBody': 'Hafif etkinlikler ve topluluk oyunları paylaş.',
    'bilInformation': 'BIL Bilgi ve Haberleri',
    'bilInformationBody': 'Doğrulanmış BIL güncellemelerini oku.',
    'academy': 'BIL Akademi',
    'academyBody': 'İncelenmiş eğitim içeriğinden pratik beceriler öğren.',
    'featureSuggestions': 'Özellik önerileri',
    'featureSuggestionsBody': 'BIL için iyileştirmeler önerin.',
    'techSupport': 'Teknik destek',
    'techSupportBody': 'BIL özellikleri için yardım isteyin.',
    'posts': 'Gönderiler',
    'friends': 'Arkadaşlar',
    'messages': 'Mesajlar',
    'guidelines': 'Kurallar',
    'help': 'Yardım',
  },
};
