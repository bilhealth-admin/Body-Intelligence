part of 'wellness_tools_pages.dart';

class _Workout {
  const _Workout(
    this.id,
    this.en,
    this.ar,
    this.categoryEn,
    this.categoryAr,
    this.icon,
  );
  final String id;
  final String en;
  final String ar;
  final String categoryEn;
  final String categoryAr;
  final IconData icon;
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.imageAsset,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF071829), Color(0xFF123B54)],
      ),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Stack(
      children: [
        if (imageAsset != null)
          Positioned.fill(
            child: ExcludeSemantics(
              child: Image.asset(
                imageAsset!,
                fit: BoxFit.cover,
                cacheWidth: 960,
                matchTextDirection: true,
              ),
            ),
          ),
        if (imageAsset != null)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [Color(0xF2071829), Color(0xA6071829)],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF19C6DF),
                child: Icon(icon, color: const Color(0xFF071829)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFC7D9E6),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.health_and_safety_outlined, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
