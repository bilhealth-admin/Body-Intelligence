part of 'community_hub_page.dart';

class _SignInRequired extends StatelessWidget {
  const _SignInRequired();

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_outlined, size: 54),
              const SizedBox(height: 16),
              Text(
                communityText(
                  context,
                  'Sign in to open community, friends, and messages.',
                  'سجّل الدخول لفتح المجتمع والأصدقاء والرسائل.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                communityText(
                  context,
                  'Health logs are never posted automatically. You choose every share.',
                  'لا تُنشر سجلاتك الصحية تلقائيًا. أنت تختار كل مشاركة.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.login_rounded),
                label: Text(communityText(context, 'Sign in', 'تسجيل الدخول')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('community-browse-topics-signed-out'),
                onPressed: () => CommunityTaxonomySheet.show(
                  context,
                  onSelectTag: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          communityText(
                            context,
                            'Sign in to start a discussion in this topic.',
                            'سجّل الدخول لبدء نقاش في هذا الموضوع.',
                          ),
                        ),
                      ),
                    );
                  },
                ),
                icon: const Icon(Icons.grid_view_rounded),
                label: Text(CommunityTaxonomySheet.browseLabel(context)),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push('/trust-support'),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: Text(
                  communityText(
                    context,
                    'Privacy & safety',
                    'الخصوصية والأمان',
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
