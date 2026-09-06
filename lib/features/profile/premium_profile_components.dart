part of 'premium_profile_page.dart';

class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.name,
    required this.photo,
    required this.onPhoto,
  });
  final String name;
  final Uint8List? photo;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Row(
        children: [
          InkWell(
            onTap: onPhoto,
            borderRadius: BorderRadius.circular(46),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                BilAccountAvatar(radius: 38, photoBytes: photo),
                PositionedDirectional(
                  end: -2,
                  bottom: -2,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.primary,
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  profileLocaleText(
                    context,
                    'Edit profile and photo',
                    'تعديل الملف والصورة',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => BilMobileSectionHeader(label);
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bodyFontSize = theme.textTheme.bodyLarge?.fontSize ?? 16;
    final scaledBodyFontSize = MediaQuery.textScalerOf(
      context,
    ).scale(bodyFontSize);

    Widget labelText() => Text(
      label,
      softWrap: true,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w400,
        height: 1.25,
      ),
    );

    Widget valueText({required bool stacked}) => Text(
      value,
      softWrap: true,
      textAlign: stacked ? TextAlign.start : TextAlign.end,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w400,
        height: 1.25,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackText = constraints.maxWidth < 360 || scaledBodyFontSize > 19;
        final textContent = stackText
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelText(),
                  const SizedBox(height: 2),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: valueText(stacked: true),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 5, child: labelText()),
                  const SizedBox(width: 12),
                  Expanded(flex: 7, child: valueText(stacked: false)),
                ],
              );

        return Material(
          color: colors.surface,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 16, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.outlineVariant, width: .8),
                ),
              ),
              child: Row(
                children: [
                  BilSemanticIconBadge(
                    kind: _profileRowIconKind(icon),
                    iconOverride: icon,
                    appleIconOverride: icon,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: textContent),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static BilSemanticIconKind _profileRowIconKind(IconData icon) {
    if (icon == Icons.photo_camera_outlined ||
        icon == Icons.badge_outlined ||
        icon == Icons.alternate_email_rounded ||
        icon == Icons.wc_rounded ||
        icon == Icons.cake_outlined) {
      return BilSemanticIconKind.profile;
    }
    if (icon == Icons.height_rounded || icon == Icons.straighten_rounded) {
      return BilSemanticIconKind.measurements;
    }
    if (icon == Icons.location_on_outlined) {
      return BilSemanticIconKind.location;
    }
    if (icon == Icons.schedule_rounded) return BilSemanticIconKind.time;
    if (icon == Icons.restaurant_menu_rounded) {
      return BilSemanticIconKind.nutrition;
    }
    if (icon == Icons.flag_outlined || icon == Icons.track_changes_rounded) {
      return BilSemanticIconKind.goals;
    }
    if (icon == Icons.monitor_weight_outlined) {
      return BilSemanticIconKind.weight;
    }
    if (icon == Icons.directions_run_rounded) {
      return BilSemanticIconKind.exercise;
    }
    if (icon == Icons.tune_rounded) return BilSemanticIconKind.preferences;
    return BilSemanticIconKind.profile;
  }
}
