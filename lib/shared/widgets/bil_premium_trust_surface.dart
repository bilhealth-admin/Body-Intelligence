import 'package:flutter/material.dart';

import 'bil_coach_identity.dart';

/// Premium, non-diagnostic trust surface for consent and privacy explanations.
///
/// This widget deliberately owns presentation only. Callers keep the existing
/// consent, permission, navigation, and persistence behavior.
class BilPremiumTrustSurface extends StatelessWidget {
  const BilPremiumTrustSurface({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.eyebrow,
    this.points = const <BilPremiumTrustPoint>[],
  });

  final IconData icon;
  final String title;
  final String body;
  final String? eyebrow;
  final List<BilPremiumTrustPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(24);
    return Semantics(
      container: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: dark
                  ? const <Color>[Color(0xFF0A0B0E), Color(0xFF11151C)]
                  : const <Color>[Color(0xFFFFFFFF), Color(0xFFF3F7FF)],
            ),
            border: Border.all(
              color: dark
                  ? const Color(0xFF2A3140)
                  : scheme.primary.withValues(alpha: .14),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .28 : .08),
                blurRadius: 28,
                spreadRadius: -12,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF0A84FF), Color(0xFF6D5DFB)],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(
                            0xFF3A63FF,
                          ).withValues(alpha: dark ? .30 : .18),
                          blurRadius: 20,
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 23),
                  ),
                ),
                if (eyebrow?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(
                    eyebrow!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .35,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.15,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
                if (points.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final point in points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(
                                alpha: dark ? .16 : .08,
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              point.icon,
                              size: 15,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              point.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                height: 1.42,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BilPremiumTrustPoint {
  const BilPremiumTrustPoint({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Premium switch surface for third-party or privacy consent settings.
///
/// The caller continues to own the consent state and persistence. This widget
/// only standardizes the presentation, disabled/loading states, and semantics.
class BilPremiumConsentToggle extends StatelessWidget {
  const BilPremiumConsentToggle({
    super.key,
    this.controlKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.loading = false,
  });

  final Key? controlKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(22);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: dark
                ? const <Color>[Color(0xFF090A0D), Color(0xFF12161D)]
                : const <Color>[Color(0xFFFFFFFF), Color(0xFFF4F7FF)],
          ),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 12, 8),
          child: SwitchListTile.adaptive(
            key: controlKey,
            contentPadding: EdgeInsets.zero,
            value: value,
            onChanged: loading ? null : onChanged,
            activeTrackColor: scheme.primary,
            secondary: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF0A84FF), Color(0xFF6D5DFB)],
                ),
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 22),
            ),
            title: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A concise disclosure row used by the Remote AI consent sheet.
@immutable
class BilPremiumAiConsentPoint {
  const BilPremiumAiConsentPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// Presents Remote AI consent as one scroll-safe, large-text-safe surface.
///
/// Callers still own consent persistence, verification, retries and fail-closed
/// behavior. This widget only standardizes disclosure and presentation.
Future<bool?> showBilPremiumAiConsentSheet({
  required BuildContext context,
  required String title,
  required String intro,
  required List<BilPremiumAiConsentPoint> points,
  required String allowLabel,
  required String declineLabel,
  Key? allowKey,
  Key? declineKey,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .68),
    builder: (sheetContext) => _BilPremiumAiConsentSheet(
      title: title,
      intro: intro,
      points: points,
      allowLabel: allowLabel,
      declineLabel: declineLabel,
      allowKey: allowKey,
      declineKey: declineKey,
    ),
  );
}

class _BilPremiumAiConsentSheet extends StatelessWidget {
  const _BilPremiumAiConsentSheet({
    required this.title,
    required this.intro,
    required this.points,
    required this.allowLabel,
    required this.declineLabel,
    this.allowKey,
    this.declineKey,
  });

  final String title;
  final String intro;
  final List<BilPremiumAiConsentPoint> points;
  final String allowLabel;
  final String declineLabel;
  final Key? allowKey;
  final Key? declineKey;

  static const _splashCyan = Color(0xFF64D8FF);
  static const _splashViolet = Color(0xFF7568FF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final horizontal = textScale >= 1.7 ? 12.0 : 18.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        0,
        8,
        8 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_splashCyan, _splashViolet],
              ),
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: _splashCyan.withValues(alpha: .18),
                  blurRadius: 34,
                  spreadRadius: -10,
                  offset: const Offset(0, -4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: .32),
                  blurRadius: 36,
                  spreadRadius: -12,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.4),
              child: Material(
                color: dark ? const Color(0xFF080B10) : scheme.surface,
                borderRadius: BorderRadius.circular(32.6),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant.withValues(alpha: .24),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 78,
                        height: 78,
                        padding: const EdgeInsets.all(2.4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_splashCyan, _splashViolet],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _splashCyan.withValues(alpha: .28),
                              blurRadius: 28,
                              spreadRadius: -7,
                            ),
                          ],
                        ),
                        child: const ClipOval(
                          child: BilCoachPortrait(
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: dark ? Colors.white : scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        intro,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: dark
                              ? const Color(0xFFC5D2E3)
                              : scheme.onSurfaceVariant,
                          height: 1.48,
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (var index = 0; index < points.length; index++) ...[
                        _BilPremiumAiConsentRow(
                          point: points[index],
                          dark: dark,
                        ),
                        if (index != points.length - 1)
                          const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: allowKey,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1677FF),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            textStyle: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(allowLabel, textAlign: TextAlign.center),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          key: declineKey,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: dark
                                ? Colors.white
                                : scheme.onSurface,
                            backgroundColor: dark
                                ? Colors.white.withValues(alpha: .055)
                                : scheme.surfaceContainerLow,
                            minimumSize: const Size.fromHeight(54),
                            side: BorderSide(
                              color: dark
                                  ? Colors.white.withValues(alpha: .12)
                                  : scheme.outlineVariant,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            textStyle: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            declineLabel,
                            textAlign: TextAlign.center,
                          ),
                        ),
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

class _BilPremiumAiConsentRow extends StatelessWidget {
  const _BilPremiumAiConsentRow({required this.point, required this.dark});

  final BilPremiumAiConsentPoint point;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .055)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark
              ? const Color(0xFF64D8FF).withValues(alpha: .16)
              : scheme.outlineVariant.withValues(alpha: .72),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF64D8FF).withValues(alpha: dark ? .24 : .18),
                  const Color(0xFF7568FF).withValues(alpha: dark ? .22 : .14),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              point.icon,
              size: 21,
              color: dark ? const Color(0xFFC8F3FF) : const Color(0xFF125B91),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: dark ? Colors.white : scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  point.body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: dark
                        ? const Color(0xFFC5D2E3)
                        : scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
