import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/services/local_data_lifecycle_service.dart';
import '../../data/database/database_provider.dart';
import '../intelligence_center/settings_commands/coach_export_command.dart';

class LocalExportRangePage extends ConsumerStatefulWidget {
  const LocalExportRangePage({
    super.key,
    this.initialFrom,
    this.initialTo,
    this.initialDatasets,
    this.commandService,
  });

  final DateTime? initialFrom;
  final DateTime? initialTo;
  final Set<String>? initialDatasets;

  /// Test seam only. Production uses the existing local lifecycle + share
  /// services and never bypasses the two-step prepare/share boundary.
  final CoachExportCommandService? commandService;

  @override
  ConsumerState<LocalExportRangePage> createState() =>
      _LocalExportRangePageState();
}

class _LocalExportRangePageState extends ConsumerState<LocalExportRangePage> {
  static const _allDatasets = <String>{
    'progress',
    'meal_nutrition',
    'exercise_notes',
  };

  DateTime? from;
  DateTime? to;
  late Set<String> datasets;
  bool preparing = false;
  bool sharing = false;
  CoachPreparedExport? prepared;

  @override
  void initState() {
    super.initState();
    from = widget.initialFrom == null
        ? null
        : DateUtils.dateOnly(widget.initialFrom!);
    to = widget.initialTo == null
        ? null
        : DateUtils.dateOnly(widget.initialTo!);
    final requested = widget.initialDatasets;
    datasets =
        requested != null &&
            requested.isNotEmpty &&
            requested.every(_allDatasets.contains)
        ? Set<String>.of(requested)
        : Set<String>.of(_allDatasets);
  }

  CoachExportCommandService get _service =>
      widget.commandService ??
      CoachExportCommandService.production(
        LocalDataLifecycleService(ref.read(databaseProvider)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_copy(context, 'Export local data'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _copy(context, 'Choose an inclusive date range'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          _copy(
            context,
            'Only authoritative data stored on this device is exported.',
          ),
        ),
        const SizedBox(height: 16),
        _dateTile('Start date', from, (value) => _changeScope(from: value)),
        _dateTile('End date', to, (value) => _changeScope(to: value)),
        TextButton(
          onPressed: () => _changeScope(clearDates: true),
          child: Text(_copy(context, 'All dates')),
        ),
        const SizedBox(height: 12),
        Text(
          _copy(context, 'Data included'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final dataset in _allDatasets)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: datasets.contains(dataset),
            title: Text(_copy(context, _datasetLabel(dataset))),
            onChanged: preparing || sharing
                ? null
                : (selected) => _toggleDataset(dataset, selected == true),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: preparing || sharing || datasets.isEmpty ? null : _prepare,
          icon: preparing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined),
          label: Text(_copy(context, 'Create CSV export')),
        ),
        if (prepared case final ready?) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _copy(context, 'Export files are ready'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _copy(
                      context,
                      'Prepared locally. Nothing has been shared yet.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final name in ready.files.keys) Text('• $name'),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: sharing ? null : _sharePrepared,
                    icon: sharing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(_copy(context, 'Share prepared export')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _dateTile(
    String key,
    DateTime? value,
    ValueChanged<DateTime> update,
  ) => ListTile(
    title: Text(_copy(context, key)),
    subtitle: Text(
      value == null
          ? _copy(context, 'Not limited')
          : MaterialLocalizations.of(context).formatMediumDate(value),
    ),
    trailing: const Icon(Icons.calendar_today_outlined),
    onTap: preparing || sharing
        ? null
        : () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (selected != null) update(selected);
          },
  );

  void _changeScope({DateTime? from, DateTime? to, bool clearDates = false}) {
    setState(() {
      if (clearDates) {
        this.from = null;
        this.to = null;
      } else {
        if (from != null) this.from = from;
        if (to != null) this.to = to;
      }
      prepared = null;
    });
  }

  void _toggleDataset(String dataset, bool selected) {
    setState(() {
      if (selected) {
        datasets.add(dataset);
      } else {
        datasets.remove(dataset);
      }
      prepared = null;
    });
  }

  Future<void> _prepare() async {
    if (from != null && to != null && from!.isAfter(to!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_copy(context, 'Start date must precede end date.')),
        ),
      );
      return;
    }
    if (datasets.isEmpty) return;
    setState(() => preparing = true);
    try {
      final ready = await _service.prepare(
        from: from,
        to: to,
        datasets: Set<String>.of(datasets),
      );
      if (!mounted) return;
      setState(() => prepared = ready);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(context, 'Export files are ready. Nothing has been shared.'),
          ),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_copy(context, 'Export could not be created')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Future<void> _sharePrepared() async {
    final ready = prepared;
    if (ready == null) return;
    setState(() => sharing = true);
    try {
      await _service.sharePrepared(ready);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copy(
                context,
                'Share sheet returned. Your device controls delivery.',
              ),
            ),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_copy(context, 'Share sheet could not open'))),
        );
      }
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }
}

String _datasetLabel(String dataset) => switch (dataset) {
  'progress' => 'Progress',
  'meal_nutrition' => 'Meal nutrition',
  'exercise_notes' => 'Exercise notes',
  _ => dataset,
};

String _copy(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return _localized[code]?[key] ?? _localized['en']![key] ?? key;
}

const _localized = <String, Map<String, String>>{
  'en': {
    'Export local data': 'Export local data',
    'Choose an inclusive date range': 'Choose an inclusive date range',
    'Only authoritative data stored on this device is exported.':
        'Only authoritative data stored on this device is exported.',
    'Start date': 'Start date',
    'End date': 'End date',
    'All dates': 'All dates',
    'Not limited': 'Not limited',
    'Data included': 'Data included',
    'Progress': 'Progress',
    'Meal nutrition': 'Meal nutrition',
    'Exercise notes': 'Exercise notes',
    'Create CSV export': 'Create CSV export',
    'Export files are ready': 'Export files are ready',
    'Prepared locally. Nothing has been shared yet.':
        'Prepared locally. Nothing has been shared yet.',
    'Share prepared export': 'Share prepared export',
    'Export files are ready. Nothing has been shared.':
        'Export files are ready. Nothing has been shared.',
    'Share sheet returned. Your device controls delivery.':
        'Share sheet returned. Your device controls delivery.',
    'Start date must precede end date.': 'Start date must precede end date.',
    'Export could not be created': 'Export could not be created',
    'Share sheet could not open': 'Share sheet could not open',
  },
  'ar': {
    'Export local data': 'تصدير البيانات المحلية',
    'Choose an inclusive date range': 'اختر نطاق تاريخ شاملًا',
    'Only authoritative data stored on this device is exported.':
        'تُصدّر فقط البيانات الموثوقة المخزنة على هذا الجهاز.',
    'Start date': 'تاريخ البداية',
    'End date': 'تاريخ النهاية',
    'All dates': 'كل التواريخ',
    'Not limited': 'غير محدد',
    'Data included': 'البيانات المشمولة',
    'Progress': 'التقدم',
    'Meal nutrition': 'تغذية الوجبات',
    'Exercise notes': 'ملاحظات التمرين',
    'Create CSV export': 'إنشاء تصدير CSV',
    'Export files are ready': 'ملفات التصدير جاهزة',
    'Prepared locally. Nothing has been shared yet.':
        'تم تجهيزها محليًا. لم تتم مشاركة أي شيء بعد.',
    'Share prepared export': 'مشاركة التصدير الجاهز',
    'Export files are ready. Nothing has been shared.':
        'ملفات التصدير جاهزة. لم تتم مشاركة أي شيء.',
    'Share sheet returned. Your device controls delivery.':
        'أُغلقت واجهة المشاركة. جهازك هو الذي يتحكم بالتسليم.',
    'Start date must precede end date.':
        'يجب أن يسبق تاريخ البداية تاريخ النهاية.',
    'Export could not be created': 'تعذر إنشاء التصدير',
    'Share sheet could not open': 'تعذر فتح واجهة المشاركة',
  },
  'fr': {
    'Export local data': 'Exporter les données locales',
    'Choose an inclusive date range': 'Choisissez une plage de dates inclusive',
    'Only authoritative data stored on this device is exported.':
        'Seules les données fiables stockées sur cet appareil sont exportées.',
    'Start date': 'Date de début',
    'End date': 'Date de fin',
    'All dates': 'Toutes les dates',
    'Not limited': 'Sans limite',
    'Data included': 'Données incluses',
    'Progress': 'Progression',
    'Meal nutrition': 'Nutrition des repas',
    'Exercise notes': 'Notes d’exercice',
    'Create CSV export': 'Créer l’export CSV',
    'Export files are ready': 'Les fichiers d’export sont prêts',
    'Prepared locally. Nothing has been shared yet.':
        'Préparé localement. Rien n’a encore été partagé.',
    'Share prepared export': 'Partager l’export préparé',
    'Export files are ready. Nothing has been shared.':
        'Les fichiers sont prêts. Rien n’a été partagé.',
    'Share sheet returned. Your device controls delivery.':
        'La feuille de partage est fermée. Votre appareil contrôle la livraison.',
    'Start date must precede end date.':
        'La date de début doit précéder la date de fin.',
    'Export could not be created': 'Impossible de créer l’export',
    'Share sheet could not open': 'Impossible d’ouvrir la feuille de partage',
  },
  'es': {
    'Export local data': 'Exportar datos locales',
    'Choose an inclusive date range': 'Elige un intervalo de fechas inclusivo',
    'Only authoritative data stored on this device is exported.':
        'Solo se exportan los datos fiables guardados en este dispositivo.',
    'Start date': 'Fecha inicial',
    'End date': 'Fecha final',
    'All dates': 'Todas las fechas',
    'Not limited': 'Sin límite',
    'Data included': 'Datos incluidos',
    'Progress': 'Progreso',
    'Meal nutrition': 'Nutrición de comidas',
    'Exercise notes': 'Notas de ejercicio',
    'Create CSV export': 'Crear exportación CSV',
    'Export files are ready': 'Los archivos de exportación están listos',
    'Prepared locally. Nothing has been shared yet.':
        'Preparado localmente. Aún no se ha compartido nada.',
    'Share prepared export': 'Compartir exportación preparada',
    'Export files are ready. Nothing has been shared.':
        'Los archivos están listos. No se ha compartido nada.',
    'Share sheet returned. Your device controls delivery.':
        'La hoja de compartir se cerró. Tu dispositivo controla la entrega.',
    'Start date must precede end date.':
        'La fecha inicial debe preceder a la final.',
    'Export could not be created': 'No se pudo crear la exportación',
    'Share sheet could not open': 'No se pudo abrir la hoja de compartir',
  },
  'tr': {
    'Export local data': 'Yerel verileri dışa aktar',
    'Choose an inclusive date range': 'Dahil olan tarih aralığını seçin',
    'Only authoritative data stored on this device is exported.':
        'Yalnızca bu cihazda saklanan güvenilir veriler dışa aktarılır.',
    'Start date': 'Başlangıç tarihi',
    'End date': 'Bitiş tarihi',
    'All dates': 'Tüm tarihler',
    'Not limited': 'Sınırsız',
    'Data included': 'Dahil edilen veriler',
    'Progress': 'İlerleme',
    'Meal nutrition': 'Öğün beslenmesi',
    'Exercise notes': 'Egzersiz notları',
    'Create CSV export': 'CSV dışa aktarımı oluştur',
    'Export files are ready': 'Dışa aktarma dosyaları hazır',
    'Prepared locally. Nothing has been shared yet.':
        'Yerel olarak hazırlandı. Henüz hiçbir şey paylaşılmadı.',
    'Share prepared export': 'Hazırlanan dışa aktarımı paylaş',
    'Export files are ready. Nothing has been shared.':
        'Dosyalar hazır. Hiçbir şey paylaşılmadı.',
    'Share sheet returned. Your device controls delivery.':
        'Paylaşım sayfası kapandı. Teslimatı cihazınız kontrol eder.',
    'Start date must precede end date.':
        'Başlangıç tarihi bitiş tarihinden önce olmalıdır.',
    'Export could not be created': 'Dışa aktarım oluşturulamadı',
    'Share sheet could not open': 'Paylaşım sayfası açılamadı',
  },
};
