import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/services/data_export_service.dart';
import '../../app/services/local_data_lifecycle_service.dart';
import '../../data/database/database_provider.dart';

class LocalExportRangePage extends ConsumerStatefulWidget {
  const LocalExportRangePage({super.key, this.initialFrom, this.initialTo});

  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  ConsumerState<LocalExportRangePage> createState() =>
      _LocalExportRangePageState();
}

class _LocalExportRangePageState extends ConsumerState<LocalExportRangePage> {
  DateTime? from;
  DateTime? to;
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    from = widget.initialFrom == null
        ? null
        : DateUtils.dateOnly(widget.initialFrom!);
    to = widget.initialTo == null
        ? null
        : DateUtils.dateOnly(widget.initialTo!);
  }

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
        _dateTile('Start date', from, (value) => setState(() => from = value)),
        _dateTile('End date', to, (value) => setState(() => to = value)),
        TextButton(
          onPressed: () => setState(() {
            from = null;
            to = null;
          }),
          child: Text(_copy(context, 'All dates')),
        ),
        const SizedBox(height: 12),
        Text(
          _copy(context, 'Files included'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          _copy(
            context,
            'Progress, meal nutrition, and exercise notes in documented CSV columns.',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: exporting ? null : _export,
          icon: exporting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_rounded),
          label: Text(_copy(context, 'Create CSV export')),
        ),
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
    onTap: () async {
      final selected = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );
      if (selected != null) update(selected);
    },
  );

  Future<void> _export() async {
    if (from != null && to != null && from!.isAfter(to!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_copy(context, 'Start date must precede end date.')),
        ),
      );
      return;
    }
    setState(() => exporting = true);
    try {
      final files = await LocalDataLifecycleService(
        ref.read(databaseProvider),
      ).exportCsvFiles(from: from, to: to);
      await const DataExportService().sharePortableCsvFiles(files);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_copy(context, 'Export could not be opened'))),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }
}

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
    'Files included': 'Files included',
    'Progress, meal nutrition, and exercise notes in documented CSV columns.':
        'Progress, meal nutrition, and exercise notes in documented CSV columns.',
    'Create CSV export': 'Create CSV export',
    'Start date must precede end date.': 'Start date must precede end date.',
    'Export could not be opened': 'Export could not be opened',
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
    'Files included': 'الملفات المشمولة',
    'Progress, meal nutrition, and exercise notes in documented CSV columns.':
        'التقدم وتغذية الوجبات وملاحظات التمرين في أعمدة CSV موثقة.',
    'Create CSV export': 'إنشاء تصدير CSV',
    'Start date must precede end date.':
        'يجب أن يسبق تاريخ البداية تاريخ النهاية.',
    'Export could not be opened': 'تعذر فتح التصدير',
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
    'Files included': 'Fichiers inclus',
    'Progress, meal nutrition, and exercise notes in documented CSV columns.':
        'Progression, nutrition des repas et notes d’exercice dans des colonnes CSV documentées.',
    'Create CSV export': 'Créer l’export CSV',
    'Start date must precede end date.':
        'La date de début doit précéder la date de fin.',
    'Export could not be opened': 'Impossible d’ouvrir l’export',
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
    'Files included': 'Archivos incluidos',
    'Progress, meal nutrition, and exercise notes in documented CSV columns.':
        'Progreso, nutrición de comidas y notas de ejercicio en columnas CSV documentadas.',
    'Create CSV export': 'Crear exportación CSV',
    'Start date must precede end date.':
        'La fecha inicial debe preceder a la final.',
    'Export could not be opened': 'No se pudo abrir la exportación',
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
    'Files included': 'Dahil edilen dosyalar',
    'Progress, meal nutrition, and exercise notes in documented CSV columns.':
        'İlerleme, öğün beslenmesi ve egzersiz notları belgelenmiş CSV sütunlarındadır.',
    'Create CSV export': 'CSV dışa aktarımı oluştur',
    'Start date must precede end date.':
        'Başlangıç tarihi bitiş tarihinden önce olmalıdır.',
    'Export could not be opened': 'Dışa aktarım açılamadı',
  },
};
