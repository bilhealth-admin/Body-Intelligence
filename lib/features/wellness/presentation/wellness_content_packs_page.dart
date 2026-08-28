import 'package:flutter/material.dart';

import '../domain/wellness_content_pack.dart';
import '../services/wellness_content_pack_manager.dart';
import 'wellness_copy.dart';

class WellnessContentPacksPage extends StatefulWidget {
  const WellnessContentPacksPage({super.key});
  @override
  State<WellnessContentPacksPage> createState() =>
      _WellnessContentPacksPageState();
}

class _WellnessContentPacksPageState extends State<WellnessContentPacksPage> {
  final manager = WellnessContentPackManager();
  late Future<_PackState> state = _load();
  String? busyPack;

  Future<_PackState> _load() async => _PackState(
    catalog: await manager.fetchCatalog(),
    installed: await manager.installedPacks(),
  );
  void _reload() => setState(() => state = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          wellnessCopy(context, 'BIL content packs', 'حزم محتوى BIL'),
        ),
      ),
      body: FutureBuilder<_PackState>(
        future: state,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_rounded,
              title: wellnessCopy(
                context,
                'Catalog unavailable',
                'تعذر تحميل دليل الحزم',
              ),
              message: wellnessCopy(
                context,
                'Your saved data was not changed. Try again.',
                'لم تتغير بياناتك المحفوظة. حاول مجددًا.',
              ),
              action: _reload,
              actionLabel: wellnessCopy(context, 'Retry', 'إعادة المحاولة'),
            );
          }
          final data = snapshot.requireData;
          if (data.catalog.isEmpty) {
            return _MessageState(
              icon: Icons.download_for_offline_outlined,
              title: wellnessCopy(
                context,
                'No packs published yet',
                'الحزم غير منشورة بعد',
              ),
              message: wellnessCopy(
                context,
                'The app stays small. Verified recipe, workout, sleep and fasting packs will appear here after publishing the BIL catalog.',
                'التطبيق خفيف الآن. ستظهر حزم الوصفات والتمارين والنوم والصيام هنا بعد نشر دليل BIL الموثق.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: data.catalog.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final pack = data.catalog[index];
                InstalledWellnessContentPack? installed;
                for (final item in data.installed) {
                  if (item.id == pack.id) installed = item;
                }
                return _PackCard(
                  pack: pack,
                  installed: installed,
                  busy: busyPack == pack.id,
                  onPressed: () =>
                      installed == null ? _install(pack) : _remove(pack.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _install(WellnessContentPack pack) async {
    setState(() => busyPack = pack.id);
    try {
      await manager.install(pack);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => busyPack = null);
    }
  }

  Future<void> _remove(String id) async {
    setState(() => busyPack = id);
    try {
      await manager.remove(id);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => busyPack = null);
    }
  }

  void _showError() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        wellnessCopy(
          context,
          'Your saved data was not changed. Try again.',
          'لم تتغير بياناتك المحفوظة. حاول مجددًا.',
        ),
      ),
    ),
  );
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.installed,
    required this.busy,
    required this.onPressed,
  });
  final WellnessContentPack pack;
  final InstalledWellnessContentPack? installed;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_icon(pack.type)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pack.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Chip(label: Text(pack.minimumAccess.name.toUpperCase())),
            ],
          ),
          const SizedBox(height: 8),
          Text(pack.description),
          const SizedBox(height: 12),
          Text(
            '${pack.itemCount} ${wellnessCopy(context, 'items', 'عنصر')} · ${(pack.sizeBytes / 1048576).toStringAsFixed(1)} MB · ${pack.locale.toUpperCase()}',
          ),
          if (pack.type == WellnessContentType.workouts) ...[
            const SizedBox(height: 10),
            Text(
              installed == null
                  ? wellnessCopy(
                      context,
                      'This installs the verified routine catalog only. Workout media downloads on demand when first opened, after size and checksum verification; installing the catalog does not download every video.',
                      'يثبّت هذا دليل الروتينات الموثق فقط. تُنزّل وسائط كل تمرين عند فتحها أول مرة بعد التحقق من الحجم والبصمة، ولا تُنزّل جميع الفيديوهات مع الدليل.',
                    )
                  : wellnessCopy(
                      context,
                      'Routine details are available offline. A video becomes available offline only after its first verified download. Removing the pack also clears its cached workout media.',
                      'تفاصيل الروتينات متاحة دون اتصال. يصبح كل فيديو متاحًا دون اتصال فقط بعد تنزيله الموثق أول مرة. إزالة الحزمة تمسح أيضًا وسائطها المحفوظة.',
                    ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: busy ? null : onPressed,
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    installed == null
                        ? Icons.library_add_check_rounded
                        : Icons.delete_outline_rounded,
                  ),
            label: Text(
              installed == null
                  ? wellnessCopy(
                      context,
                      'Install verified catalog',
                      'تثبيت الدليل الموثق',
                    )
                  : wellnessCopy(
                      context,
                      'Remove pack and cached media',
                      'إزالة الحزمة ووسائطها',
                    ),
            ),
          ),
        ],
      ),
    ),
  );

  static IconData _icon(WellnessContentType type) => switch (type) {
    WellnessContentType.recipes => Icons.menu_book_rounded,
    WellnessContentType.workouts => Icons.fitness_center_rounded,
    WellnessContentType.sleep => Icons.bedtime_rounded,
    WellnessContentType.fasting => Icons.hourglass_bottom_rounded,
  };
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel,
  });
  final IconData icon;
  final String title, message;
  final VoidCallback? action;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: action, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

class _PackState {
  const _PackState({required this.catalog, required this.installed});
  final List<WellnessContentPack> catalog;
  final List<InstalledWellnessContentPack> installed;
}
