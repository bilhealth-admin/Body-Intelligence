import 'dart:ui';

import 'package:flutter/material.dart';

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
  });

  final VoidCallback onFood;
  final VoidCallback onBarcode;
  final VoidCallback onVoice;
  final VoidCallback onPhoto;
  final VoidCallback onExercise;
  final VoidCallback onNotes;
  final VoidCallback onSearch;

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
    final sheetHeight = (screenHeight * .56).clamp(390.0, 560.0);
    final primaryActions =
        <({IconData icon, String label, VoidCallback onTap})>[
          (
            icon: Icons.restaurant_rounded,
            label: _text(context, 'Log food'),
            onTap: onFood,
          ),
          (
            icon: Icons.verified_rounded,
            label: '${_text(context, 'Scan barcode')}\nPremium',
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        key: const Key('quick-add-half-sheet'),
        height: sheetHeight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/quick_add/quick_add_spring_glass_v2.png',
                  key: const Key('quick-add-spring-background'),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
                const DecoratedBox(
                  key: Key('quick-add-low-visibility-veil'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xE9FFFFFF), Color(0xF8FFFFFF)],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
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
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: primaryActions.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                mainAxisExtent: 94,
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
                        const SizedBox(height: 5),
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
    radius: 23,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF087F73), size: 25),
          const SizedBox(height: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF172321),
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
    padding: const EdgeInsets.only(top: 8),
    child: _GlassActionSurface(
      actionKey: actionKey,
      radius: 21,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xA8D9F2EA),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF087F73), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF172321),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: const Color(0xFF64716E),
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
  Widget build(BuildContext context) => ClipRRect(
    key: actionKey,
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Material(
        color: const Color(0xA8FFFFFF),
        shadowColor: const Color(0x240B554E),
        elevation: 1.5,
        child: InkWell(onTap: onTap, child: child),
      ),
    ),
  );
}
