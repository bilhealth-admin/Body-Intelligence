import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../shared/widgets/premium_surface.dart';

/// The Food Log landing actions. This is deliberately a BIL-owned surface:
/// the reference layout is followed without copying another app's branding or
/// advertising.
class FoodLogEntrySurface extends StatelessWidget {
  const FoodLogEntrySurface({
    super.key,
    required this.onLogFood,
    required this.onBarcode,
    required this.onVoice,
    required this.onPhoto,
    required this.onExercise,
    required this.onNotes,
    required this.onSearch,
  });

  final VoidCallback onLogFood;
  final VoidCallback onBarcode;
  final VoidCallback onVoice;
  final VoidCallback onPhoto;
  final VoidCallback onExercise;
  final VoidCallback onNotes;
  final VoidCallback onSearch;

  String _t(BuildContext context, String value) => context.strings.text(value);

  @override
  Widget build(BuildContext context) {
    final actions =
        <({BilSemanticIconKind icon, String label, VoidCallback onTap})>[
          (
            icon: BilSemanticIconKind.foodLog,
            label: _t(context, 'Log food'),
            onTap: onLogFood,
          ),
          (
            icon: BilSemanticIconKind.barcode,
            label: _t(context, 'Scan barcode'),
            onTap: onBarcode,
          ),
          (
            icon: BilSemanticIconKind.voice,
            label: _t(context, 'Log food by voice'),
            onTap: onVoice,
          ),
          (
            icon: BilSemanticIconKind.mealPhoto,
            label: _t(context, 'Analyze meal photo'),
            onTap: onPhoto,
          ),
        ];
    final secondary =
        <({BilSemanticIconKind icon, String label, VoidCallback onTap})>[
          (
            icon: BilSemanticIconKind.exercise,
            label: _t(context, 'Exercise library'),
            onTap: onExercise,
          ),
          (
            icon: BilSemanticIconKind.notes,
            label: _t(context, 'Daily notes'),
            onTap: onNotes,
          ),
          (
            icon: BilSemanticIconKind.foodSearch,
            label: _t(context, 'Search or create food'),
            onTap: onSearch,
          ),
        ];
    return PremiumSurface(
      key: const Key('food-log-entry-surface'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t(context, 'Log food'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 82,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];
              return _FoodLogActionCard(
                key: Key('food-log-primary-$index'),
                icon: action.icon,
                label: action.label,
                onTap: action.onTap,
              );
            },
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < secondary.length; index++) ...[
            ListTile(
              key: Key('food-log-secondary-$index'),
              contentPadding: EdgeInsets.zero,
              leading: BilSemanticIconBadge(kind: secondary[index].icon),
              title: Text(secondary[index].label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: secondary[index].onTap,
            ),
            if (index != secondary.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _FoodLogActionCard extends StatelessWidget {
  const _FoodLogActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final BilSemanticIconKind icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            BilSemanticIconBadge(kind: icon, size: 38, iconSize: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
