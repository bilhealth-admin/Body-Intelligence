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
  Widget build(BuildContext context) =>
      BilMobileListRow(label: label, value: value, onTap: onTap);
}
