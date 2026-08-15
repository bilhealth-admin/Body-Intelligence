import 'dart:ui';

import 'package:flutter/material.dart';

import '../../shared/widgets/bil_wordmark.dart';
import '../localization/bil_locale_policy.dart';
import '../localization/runtime_copy.dart';
import 'bil_quick_add_locale_copy.dart';

class BilQuickAddSheet extends StatelessWidget {
  const BilQuickAddSheet({
    super.key,
    required this.onWeight,
    required this.onFood,
    required this.onBarcode,
    required this.onVoice,
    required this.onPhoto,
    required this.onWater,
    required this.onExercise,
    required this.onNotes,
    required this.onSearch,
    required this.onQuickMacros,
  });

  final VoidCallback onWeight;
  final VoidCallback onFood;
  final VoidCallback onBarcode;
  final VoidCallback onVoice;
  final VoidCallback onPhoto;
  final VoidCallback onWater;
  final VoidCallback onExercise;
  final VoidCallback onNotes;
  final VoidCallback onSearch;
  final VoidCallback onQuickMacros;

  String _text(BuildContext context, String english) {
    const copy = <String, Map<String, String>>{
      'Quick Add': {
        'ar': 'إضافة سريعة',
        'fr': 'Ajout rapide',
        'es': 'Añadir rápido',
        'tr': 'Hızlı ekle',
      },
      'Choose an action and go directly to it.': {
        'ar': 'اختر إجراءً وانتقل إليه مباشرة.',
        'fr': 'Choisissez une action pour y accéder directement.',
        'es': 'Elige una acción para ir directamente.',
        'tr': 'Doğrudan gitmek için bir işlem seçin.',
      },
      'Log food': {
        'ar': 'تسجيل الطعام',
        'fr': 'Ajouter un aliment',
        'es': 'Registrar comida',
        'tr': 'Yemek ekle',
      },
      'Scan barcode': {
        'ar': 'مسح الباركود',
        'fr': 'Scanner un code-barres',
        'es': 'Escanear código',
        'tr': 'Barkod tara',
      },
      'Log food by voice': {
        'ar': 'تسجيل الطعام بالصوت',
        'fr': 'Ajouter par la voix',
        'es': 'Registrar por voz',
        'tr': 'Sesle yemek ekle',
      },
      'Analyze meal photo': {
        'ar': 'تحليل صورة وجبة',
        'fr': 'Analyser une photo',
        'es': 'Analizar una foto',
        'tr': 'Öğün fotoğrafını analiz et',
      },
      'Water': {'ar': 'الماء', 'fr': 'Eau', 'es': 'Agua', 'tr': 'Su'},
      'Weight': {'ar': 'وزن', 'fr': 'Poids', 'es': 'Peso', 'tr': 'Kilo'},
      'Exercise library': {
        'ar': 'مكتبة التمارين',
        'fr': 'Bibliothèque d’exercices',
        'es': 'Biblioteca de ejercicios',
        'tr': 'Egzersiz kütüphanesi',
      },
      'Daily notes': {
        'ar': 'الملاحظات اليومية',
        'fr': 'Notes quotidiennes',
        'es': 'Notas diarias',
        'tr': 'Günlük notlar',
      },
      'Search or create food': {
        'ar': 'البحث عن طعام أو إنشاؤه',
        'fr': 'Rechercher ou créer un aliment',
        'es': 'Buscar o crear un alimento',
        'tr': 'Yemek ara veya oluştur',
      },
    };
    final language = Localizations.localeOf(context).languageCode;
    return bilQuickAddAuthoredCopy[english]?[language] ??
        copy[english]?[language] ??
        RuntimeCopy.resolve(
          english,
          BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
        ) ??
        english;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primaryActions =
        <({IconData icon, String label, VoidCallback onTap})>[
          (
            icon: Icons.restaurant_rounded,
            label: _text(context, 'Log food'),
            onTap: onFood,
          ),
          (
            icon: Icons.qr_code_scanner_rounded,
            label: _text(context, 'Scan barcode'),
            onTap: onBarcode,
          ),
          (
            icon: Icons.mic_none_rounded,
            label: _text(context, 'Log food by voice'),
            onTap: onVoice,
          ),
          (
            icon: Icons.center_focus_strong_rounded,
            label: _text(context, 'Analyze meal photo'),
            onTap: onPhoto,
          ),
        ];
    final actions = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.speed_rounded,
        label: _text(context, 'Quick Add'),
        onTap: onQuickMacros,
      ),
      (
        icon: Icons.water_drop_rounded,
        label: _text(context, 'Water'),
        onTap: onWater,
      ),
      (
        icon: Icons.monitor_weight_rounded,
        label: _text(context, 'Weight'),
        onTap: onWeight,
      ),
      (
        icon: Icons.fitness_center_rounded,
        label: _text(context, 'Exercise library'),
        onTap: onExercise,
      ),
      (
        icon: Icons.edit_note_rounded,
        label: _text(context, 'Daily notes'),
        onTap: onNotes,
      ),
      (
        icon: Icons.search_rounded,
        label: _text(context, 'Search or create food'),
        onTap: onSearch,
      ),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: dark
                      ? const [Color(0xFA0A1522), Color(0xFA131B2D)]
                      : [colors.surface, colors.surfaceContainerLow],
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const BilFullWordmark(height: 42),
                      const SizedBox(height: 6),
                      Text(
                        _text(
                          context,
                          'Choose an action and go directly to it.',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: primaryActions.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              mainAxisExtent: 86,
                            ),
                        itemBuilder: (context, index) {
                          final action = primaryActions[index];
                          return _PrimaryQuickAction(
                            icon: action.icon,
                            label: action.label,
                            onTap: action.onTap,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      for (final action in actions)
                        _QuickActionTile(
                          icon: action.icon,
                          label: action.label,
                          onTap: action.onTap,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryQuickAction extends StatelessWidget {
  const _PrimaryQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colors.primary, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
              color: colors.surfaceContainerLow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Icon(icon),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
