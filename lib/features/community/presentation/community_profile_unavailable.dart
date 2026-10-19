part of 'community_profile_page.dart';

class _CommunityProfileUnavailable extends StatelessWidget {
  const _CommunityProfileUnavailable({required this.copy});

  final _CommunityProfileCopy copy;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: BilPearlMaterialCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_outlined, size: 52),
              const SizedBox(height: 16),
              Text(
                copy.signInRequired,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                copy.privacy,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
