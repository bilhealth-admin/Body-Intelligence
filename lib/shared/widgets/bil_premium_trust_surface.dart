import 'package:flutter/material.dart';

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
