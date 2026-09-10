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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    Widget labelText() => Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w400,
        height: 1.25,
      ),
    );

    Widget valueText() => Text(
      value,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      // Screen readers and a long press still expose the complete value.
      semanticsLabel: value,
      textAlign: Directionality.of(context) == TextDirection.rtl
          ? TextAlign.left
          : TextAlign.right,
      textDirection: icon == Icons.alternate_email_rounded
          ? TextDirection.ltr
          : null,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w400,
        height: 1.25,
      ),
    );

    final textContent = Row(
      children: [
        Expanded(flex: 5, child: labelText()),
        const SizedBox(width: 12),
        Expanded(flex: 7, child: valueText()),
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
              BilNativeSettingsIcon(
                kind: _profileRowIconKind(icon),
                symbol: _profileRowSymbol(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Tooltip(message: '$label: $value', child: textContent),
              ),
            ],
          ),
        ),
      ),
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

  static BilSettingsSymbol _profileRowSymbol(IconData icon) {
    if (icon == Icons.photo_camera_outlined) return BilSettingsSymbol.camera;
    if (icon == Icons.alternate_email_rounded) return BilSettingsSymbol.email;
    if (icon == Icons.height_rounded) return BilSettingsSymbol.height;
    if (icon == Icons.wc_rounded) return BilSettingsSymbol.people;
    if (icon == Icons.cake_outlined) return BilSettingsSymbol.calendar;
    if (icon == Icons.markunread_mailbox_outlined) {
      return BilSettingsSymbol.postal;
    }
    return BilNativeSettingsIcon.symbolFor(_profileRowIconKind(icon));
  }
}
