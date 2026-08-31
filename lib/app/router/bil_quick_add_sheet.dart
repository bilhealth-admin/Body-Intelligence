import 'package:flutter/material.dart';

import '../../shared/widgets/bil_wordmark.dart';
import '../localization/bil_locale_policy.dart';
import '../localization/runtime_copy.dart';
import 'bil_quick_add_locale_copy.dart';

class BilQuickAddSheet extends StatelessWidget {
  const BilQuickAddSheet({
    super.key,
    required this.onFood,
    required this.onBarcode,
    required this.onVoice,
    required this.onPhoto,
    required this.onExercise,
    required this.onNotes,
    required this.onSearch,
    this.photoAsset,
  });

  final VoidCallback onFood;
  final VoidCallback onBarcode;
  final VoidCallback onVoice;
  final VoidCallback onPhoto;
  final VoidCallback onExercise;
  final VoidCallback onNotes;
  final VoidCallback onSearch;

  /// Reserved for an approved BIL-owned photographic hero. Until one is
  /// supplied, Quick Add uses the deterministic blue surface below rather
  /// than an unrelated stock illustration.
  final String? photoAsset;

  String _text(BuildContext context, String english) {
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    return bilQuickAddAuthoredCopy[english]?[locale] ??
        bilQuickAddAuthoredCopy[english]?[Localizations.localeOf(
          context,
        ).languageCode] ??
        RuntimeCopy.resolve(english, locale) ??
        english;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = (screenHeight * .52).clamp(370.0, 520.0);
    final baseTheme = Theme.of(context);
    final dark = baseTheme.brightness == Brightness.dark;
    final bilScheme = baseTheme.colorScheme.copyWith(
      primary: dark ? const Color(0xFFAFC6FF) : const Color(0xFF1D4ED8),
      onPrimary: dark ? const Color(0xFF091A3B) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF172B57)
          : const Color(0xFFE4EDFF),
      onPrimaryContainer: dark
          ? const Color(0xFFE7EDFF)
          : const Color(0xFF071B46),
    );
    final primaryActions = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.restaurant_rounded,
        label: _text(context, 'Log food'),
        onTap: onFood,
      ),
      (
        icon: Icons.verified_rounded,
        label:
            '${_text(context, 'Scan barcode')}\n${_text(context, 'Premium')}',
        onTap: onBarcode,
      ),
      (
        icon: Icons.mic_rounded,
        label: _text(context, 'Log food by voice'),
        onTap: onVoice,
      ),
      (
        icon: Icons.center_focus_strong_rounded,
        label: _text(context, 'Analyze meal photo'),
        onTap: onPhoto,
      ),
    ];
    final secondaryActions =
        <({IconData icon, String label, VoidCallback onTap})>[
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

    return Theme(
      data: baseTheme.copyWith(colorScheme: bilScheme),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          key: const Key('quick-add-half-sheet'),
          height: sheetHeight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    key: const Key('quick-add-blue-background'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: dark
                            ? const [Color(0xFF0B1220), Color(0xFF111E35)]
                            : const [Color(0xFFF8FAFF), Color(0xFFEAF1FF)],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0x66727B80),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Expanded(
                                child: BilFullWordmark(
                                  key: Key('quick-add-wordmark'),
                                  height: 28,
                                  alignment: AlignmentDirectional.centerStart,
                                ),
                              ),
                              if (photoAsset?.trim().isNotEmpty ?? false) ...[
                                const SizedBox(width: 10),
                                ExcludeSemantics(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      photoAsset!,
                                      key: const Key('quick-add-photo-hero'),
                                      width: 52,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: primaryActions.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  mainAxisExtent: 82,
                                ),
                            itemBuilder: (context, index) {
                              final action = primaryActions[index];
                              return _PrimaryQuickAction(
                                actionKey: Key('quick-add-primary-$index'),
                                icon: action.icon,
                                label: action.label,
                                onTap: action.onTap,
                              );
                            },
                          ),
                          const SizedBox(height: 3),
                          for (
                            var index = 0;
                            index < secondaryActions.length;
                            index++
                          )
                            _QuickActionTile(
                              actionKey: Key('quick-add-secondary-$index'),
                              icon: secondaryActions[index].icon,
                              label: secondaryActions[index].label,
                              onTap: secondaryActions[index].onTap,
                            ),
                        ],
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
}

class _PrimaryQuickAction extends StatelessWidget {
  const _PrimaryQuickAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _GlassActionSurface(
    actionKey: actionKey,
    radius: 19,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 23),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: _GlassActionSurface(
      actionKey: actionKey,
      radius: 18,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}

class _GlassActionSurface extends StatelessWidget {
  const _GlassActionSurface({
    required this.actionKey,
    required this.radius,
    required this.onTap,
    required this.child,
  });

  final Key actionKey;
  final double radius;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: actionKey,
      color: scheme.surface.withValues(alpha: .94),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: child,
        ),
      ),
    );
  }
}
