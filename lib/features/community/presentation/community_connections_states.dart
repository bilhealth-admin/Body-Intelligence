part of 'community_connections_page.dart';

class _ConnectionsEducation extends StatelessWidget {
  const _ConnectionsEducation({required this.copy});
  final _ConnectionsCopy copy;

  @override
  Widget build(BuildContext context) => BilPearlMaterialCard(
    child: ListTile(
      leading: const BilSemanticIconBadge(kind: BilSemanticIconKind.privacy),
      title: Text(copy.educationTitle),
      subtitle: Text(copy.educationBody),
    ),
  );
}

class _ConnectionsUnavailable extends StatelessWidget {
  const _ConnectionsUnavailable({required this.copy});

  final _ConnectionsCopy copy;

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
              const Icon(Icons.group_off_outlined, size: 52),
              const SizedBox(height: 16),
              Text(
                copy.signInRequired,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('community-connections-add-friends'),
                onPressed: () => context.push('/login'),
                icon: const BilNavigationFeedback(
                  child: Icon(Icons.login_rounded),
                ),
                label: Text(copy.signIn),
              ),
              const SizedBox(height: 18),
              _ConnectionsEducation(copy: copy),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ConnectionsLoadError extends StatelessWidget {
  const _ConnectionsLoadError({required this.copy, required this.onRetry});

  final _ConnectionsCopy copy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 52),
          const SizedBox(height: 12),
          Text(copy.loadFailed, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const BilNavigationFeedback(
              child: Icon(Icons.refresh_rounded),
            ),
            label: Text(copy.retry),
          ),
        ],
      ),
    ),
  );
}

class _ConnectionsLoading extends StatelessWidget {
  const _ConnectionsLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BilFeatureWelcomeStatus(),
          const SizedBox(height: 14),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _EmptyConnections extends StatelessWidget {
  const _EmptyConnections({required this.copy, required this.onFindPeople});
  final _ConnectionsCopy copy;
  final VoidCallback onFindPeople;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded, size: 56),
          const SizedBox(height: 12),
          Text(copy.empty, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onFindPeople,
            icon: const Icon(Icons.person_search_rounded),
            label: Text(copy.findPeople),
          ),
        ],
      ),
    ),
  );
}
