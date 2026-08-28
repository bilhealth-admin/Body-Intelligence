import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/feature_strings.dart';
import '../domain/wellness_content_pack.dart';
import '../services/wellness_content_pack_manager.dart';

class ProfessionalContentLibraryPage extends StatefulWidget {
  const ProfessionalContentLibraryPage({
    super.key,
    required this.type,
    this.manager,
  });

  final WellnessContentType type;
  final WellnessContentPackManager? manager;

  @override
  State<ProfessionalContentLibraryPage> createState() =>
      _ProfessionalContentLibraryPageState();
}

class _ProfessionalContentLibraryPageState
    extends State<ProfessionalContentLibraryPage> {
  late final WellnessContentPackManager _manager =
      widget.manager ?? WellnessContentPackManager();
  final _search = TextEditingController();
  late Future<List<WellnessContentItem>> _items;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  void _reload() {
    _items = _manager.loadTrustedInstalledItems(
      widget.type,
      locale: Localizations.localeOf(context).languageCode,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecipes = widget.type == WellnessContentType.recipes;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRecipes
              ? _localized(
                  context,
                  'وصفات موثقة',
                  'Verified recipes',
                  'Recettes vérifiées',
                  'Recetas verificadas',
                  'Doğrulanmış tarifler',
                )
              : _localized(
                  context,
                  'تمارين احترافية',
                  'Professional workouts',
                  'Entraînements professionnels',
                  'Entrenamientos profesionales',
                  'Profesyonel antrenmanlar',
                ),
        ),
        leading: IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/wellness-library'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: FeatureStrings.of(context).get('content_library'),
            onPressed: () => context.push('/wellness/content-packs'),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<WellnessContentItem>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LibraryError(onRetry: () => setState(_reload));
          }
          final query = _search.text.trim().toLowerCase();
          final items = (snapshot.data ?? const [])
              .where(
                (item) =>
                    '${item.title} ${item.description} ${item.tags.join(' ')}'
                        .toLowerCase()
                        .contains(query),
              )
              .toList();
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: _localized(
                      context,
                      'بحث',
                      'Search',
                      'Rechercher',
                      'Buscar',
                      'Ara',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  _EmptyLibrary(type: widget.type)
                else
                  for (final item in items) ...[
                    _ContentCard(
                      item: item,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => item.videoUrl == null
                              ? _ContentDetailsPage(item: item)
                              : _VideoLessonPage(item: item),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                if (widget.type == WellnessContentType.workouts) ...[
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/wellness/workouts/log'),
                    icon: const Icon(Icons.add_task_rounded),
                    label: Text(
                      _localized(
                        context,
                        'سجّل نشاطًا من المكتبة المحلية',
                        'Log an activity from the local library',
                        'Enregistrer une activité locale',
                        'Registrar una actividad local',
                        'Yerel bir etkinlik kaydet',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48),
          const SizedBox(height: 12),
          Text(
            _localized(
              context,
              'تعذّر فتح المحتوى الموثق. بياناتك المحلية لم تتغير.',
              'Verified content could not be opened. Your local data was not changed.',
              'Le contenu vérifié n’a pas pu être ouvert.',
              'No se pudo abrir el contenido verificado.',
              'Doğrulanmış içerik açılamadı.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              _localized(
                context,
                'حاول مجددًا',
                'Retry',
                'Réessayer',
                'Reintentar',
                'Tekrar dene',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.type});
  final WellnessContentType type;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 40),
    child: Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  type == WellnessContentType.recipes
                      ? 'assets/images/professional/mediterranean_protein_bowl.png'
                      : 'assets/images/professional/strength_training_cover.png',
                  fit: BoxFit.cover,
                  cacheWidth: 720,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x99000000)],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 16,
                  end: 16,
                  bottom: 14,
                  child: Text(
                    type == WellnessContentType.recipes
                        ? _localized(
                            context,
                            'معاينة مكتبة الوصفات',
                            'Recipe library preview',
                            'Aperçu de la bibliothèque de recettes',
                            'Vista previa de la biblioteca de recetas',
                            'Tarif kitaplığı önizlemesi',
                          )
                        : _localized(
                            context,
                            'معاينة مكتبة التمارين',
                            'Workout library preview',
                            'Aperçu de la bibliothèque d’exercices',
                            'Vista previa de la biblioteca de ejercicios',
                            'Egzersiz kitaplığı önizlemesi',
                          ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _localized(
            context,
            'نزّل حزمة موثقة لتظهر المكتبة هنا. لا يضمّن BIL فيديوهات أو صورًا غير مرخصة داخل التطبيق.',
            'This original preview shows the library experience. Download a verified pack for licensed recipes or workouts; BIL never invents content.',
            'Téléchargez un pack vérifié. BIL n’intègre aucun média sans licence.',
            'Descarga un paquete verificado. BIL no incluye medios sin licencia.',
            'Doğrulanmış bir paket indirin. BIL lisanssız medya içermez.',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => context.push('/wellness/content-packs'),
          icon: const Icon(Icons.download_rounded),
          label: Text(
            _localized(
              context,
              'إدارة الحزم',
              'Manage packs',
              'Gérer les packs',
              'Gestionar paquetes',
              'Paketleri yönet',
            ),
          ),
        ),
      ],
    ),
  );
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.item, required this.onOpen});
  final WellnessContentItem item;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    final videoUrl = item.videoUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0x11000000),
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(item.description),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (item.durationMinutes != null)
                        Chip(label: Text('${item.durationMinutes} min')),
                      if (item.difficulty?.isNotEmpty == true)
                        Chip(label: Text(item.difficulty!)),
                      Chip(
                        avatar: const Icon(Icons.verified_rounded, size: 18),
                        label: Text(
                          _localized(
                            context,
                            'موثّق',
                            'Verified',
                            'Vérifié',
                            'Verificado',
                            'Doğrulandı',
                          ),
                        ),
                      ),
                      if (videoUrl != null)
                        Chip(
                          avatar: const Icon(
                            Icons.play_circle_outline,
                            size: 18,
                          ),
                          label: Text(
                            _localized(
                              context,
                              'فيديو',
                              'Video',
                              'Vidéo',
                              'Vídeo',
                              'Video',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.publisher} · ${item.licenseName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoLessonPage extends StatefulWidget {
  const _VideoLessonPage({required this.item});
  final WellnessContentItem item;
  @override
  State<_VideoLessonPage> createState() => _VideoLessonPageState();
}

class _VideoLessonPageState extends State<_VideoLessonPage> {
  late final VideoPlayerController _controller;
  late final Future<void> _ready;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(widget.item.videoUrl!);
    _ready = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.item.title)),
    body: FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              _localized(
                context,
                'الفيديو غير متاح',
                'Video unavailable',
                'Vidéo indisponible',
                'Vídeo no disponible',
                'Video kullanılamıyor',
              ),
            ),
          );
        }
        return Center(
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
        );
      },
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => setState(
        () => _controller.value.isPlaying
            ? _controller.pause()
            : _controller.play(),
      ),
      child: Icon(
        _controller.value.isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
      ),
    ),
  );
}

class _ContentDetailsPage extends StatelessWidget {
  const _ContentDetailsPage({required this.item});

  final WellnessContentItem item;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(item.title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(item.description, style: Theme.of(context).textTheme.bodyLarge),
        if (item.instructions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            _localized(
              context,
              'التعليمات',
              'Instructions',
              'Instructions',
              'Instrucciones',
              'Talimatlar',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < item.instructions.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(item.instructions[index]),
            ),
        ],
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_rounded),
          title: Text(item.publisher),
          subtitle: Text('${item.licenseName}\n${item.sourceUrl}'),
        ),
      ],
    ),
  );
}

String _localized(
  BuildContext context,
  String ar,
  String en,
  String fr,
  String es,
  String tr,
) => switch (Localizations.localeOf(context).languageCode) {
  'ar' => ar,
  'en' => en,
  'fr' => fr,
  'es' => es,
  'tr' => tr,
  _ => context.strings.text(en),
};
