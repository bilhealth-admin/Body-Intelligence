import 'package:flutter/material.dart';

import '../../../data/database/app_database.dart';

Future<Food?> showBarcodeFoodReviewDialog(
  BuildContext context, {
  required String barcode,
  required List<Food> candidates,
}) async {
  if (candidates.isEmpty) return null;
  var selected = candidates.first;
  final copy = _BarcodeReviewCopy.of(
    Localizations.localeOf(context).languageCode,
  );
  return showDialog<Food>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(copy.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${copy.barcode}: $barcode'),
              const SizedBox(height: 12),
              RadioGroup<int>(
                groupValue: candidates.indexOf(selected),
                onChanged: (index) {
                  if (index != null) {
                    setDialogState(() => selected = candidates[index]);
                  }
                },
                child: Column(
                  children: [
                    for (var index = 0; index < candidates.length; index++)
                      Builder(
                        builder: (_) {
                          final food = candidates[index];
                          return RadioListTile<int>(
                            value: index,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              food.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${copy.serving}: ${_number(food.servingSize)} ${food.servingUnit}\n'
                              '${copy.source}: ${food.source} · '
                              '${food.verified ? copy.verified : copy.unverified}',
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(copy.notice, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(copy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, selected),
            child: Text(copy.useFood),
          ),
        ],
      ),
    ),
  );
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

class _BarcodeReviewCopy {
  const _BarcodeReviewCopy({
    required this.title,
    required this.barcode,
    required this.serving,
    required this.source,
    required this.verified,
    required this.unverified,
    required this.notice,
    required this.cancel,
    required this.useFood,
  });

  final String title, barcode, serving, source, verified, unverified;
  final String notice, cancel, useFood;

  static _BarcodeReviewCopy of(String language) =>
      _all[language] ?? _all['en']!;

  static const _all = <String, _BarcodeReviewCopy>{
    'en': _BarcodeReviewCopy(
      title: 'Review food and serving',
      barcode: 'GTIN',
      serving: 'Serving',
      source: 'Source',
      verified: 'verified',
      unverified: 'not verified',
      notice:
          'Confirm the product, source, and serving before adding it. BIL does not infer missing nutrition.',
      cancel: 'Cancel',
      useFood: 'Use this food',
    ),
    'ar': _BarcodeReviewCopy(
      title: 'راجع الطعام والحصة',
      barcode: 'الرمز العالمي',
      serving: 'الحصة',
      source: 'المصدر',
      verified: 'موثّق',
      unverified: 'غير موثّق',
      notice:
          'تأكد من المنتج والمصدر والحصة قبل الإضافة. لا يخمّن BIL بيانات غذائية مفقودة.',
      cancel: 'إلغاء',
      useFood: 'استخدام هذا الطعام',
    ),
    'fr': _BarcodeReviewCopy(
      title: 'Vérifier l’aliment et la portion',
      barcode: 'GTIN',
      serving: 'Portion',
      source: 'Source',
      verified: 'vérifié',
      unverified: 'non vérifié',
      notice:
          'Confirmez le produit, la source et la portion avant l’ajout. BIL n’invente aucune donnée nutritionnelle.',
      cancel: 'Annuler',
      useFood: 'Utiliser cet aliment',
    ),
    'es': _BarcodeReviewCopy(
      title: 'Revisar alimento y porción',
      barcode: 'GTIN',
      serving: 'Porción',
      source: 'Fuente',
      verified: 'verificado',
      unverified: 'sin verificar',
      notice:
          'Confirma el producto, la fuente y la porción antes de añadirlo. BIL no estima datos nutricionales faltantes.',
      cancel: 'Cancelar',
      useFood: 'Usar este alimento',
    ),
    'tr': _BarcodeReviewCopy(
      title: 'Yiyecek ve porsiyonu incele',
      barcode: 'GTIN',
      serving: 'Porsiyon',
      source: 'Kaynak',
      verified: 'doğrulandı',
      unverified: 'doğrulanmadı',
      notice:
          'Eklemeden önce ürünü, kaynağı ve porsiyonu doğrulayın. BIL eksik besin verilerini tahmin etmez.',
      cancel: 'İptal',
      useFood: 'Bu yiyeceği kullan',
    ),
  };
}
