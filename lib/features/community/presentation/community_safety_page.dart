import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../data/community_repository.dart';
import 'community_copy.dart';

class CommunitySafetyPage extends StatefulWidget {
  const CommunitySafetyPage({super.key});

  @override
  State<CommunitySafetyPage> createState() => _CommunitySafetyPageState();
}

class _CommunitySafetyPageState extends State<CommunitySafetyPage> {
  CommunityRepository? _repository;
  Future<Map<String, dynamic>?>? _policy;
  bool _accepted = false;
  bool _saving = false;

  String get _languageCode => Localizations.localeOf(context).languageCode;
  String _t(String en, String ar) =>
      communityTextForLanguage(_languageCode, en, ar);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_policy != null || !AppEnvironment.communityConfigured) return;
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    _repository = CommunityRepository(client);
    _policy = _repository!.loadActiveContentPolicy(
      localeCode: Localizations.localeOf(context).languageCode,
    );
  }

  Future<void> _accept(Map<String, dynamic> policy) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository!.acceptContentPolicy(policy['version'] as String);
      if (mounted) setState(() => _accepted = true);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Consent could not be saved. Publishing remains locked.',
              'تعذر حفظ الموافقة الآن. لم يتم فتح النشر.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_t('Safety & community policy', 'الأمان وسياسة المجتمع')),
    ),
    body: _policy == null
        ? _Unavailable(languageCode: _languageCode)
        : FutureBuilder<Map<String, dynamic>?>(
            future: _policy,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final policy = snapshot.data;
              if (snapshot.hasError || policy == null) {
                return _Unavailable(languageCode: _languageCode);
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(Icons.shield_outlined, size: 52),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      'A community built around privacy and dignity.',
                      'مجتمع يحترم الخصوصية والإنسان.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.policy_outlined),
                          title: Text(_t('Content policy', 'سياسة المحتوى')),
                          subtitle: Text(
                            '${policy['version']} · ${policy['document_url']}',
                          ),
                        ),
                        FutureBuilder<bool>(
                          future: _repository!.hasAcceptedContentPolicy(
                            policy['version'] as String,
                          ),
                          builder: (context, acceptance) {
                            final accepted =
                                _accepted || (acceptance.data ?? false);
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: FilledButton.icon(
                                key: const Key('accept-community-policy'),
                                onPressed: accepted || _saving
                                    ? null
                                    : () => _accept(policy),
                                icon: Icon(
                                  accepted
                                      ? Icons.verified_user_outlined
                                      : Icons.check_circle_outline,
                                ),
                                label: Text(
                                  accepted
                                      ? _t('Accepted', 'تمت الموافقة')
                                      : _t(
                                          'Accept policy',
                                          'أوافق على السياسة',
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SafetyTile(
                    icon: Icons.health_and_safety_outlined,
                    title: _t('Health logs stay private', 'سجلاتك الصحية خاصة'),
                    body: _t(
                      'BIL never posts weight, meals, or measurements without an explicit share action.',
                      'لا ينشر BIL وزنًا أو وجبة أو قياسًا دون إجراء مشاركة واضح منك.',
                    ),
                  ),
                  _SafetyTile(
                    icon: Icons.report_outlined,
                    title: _t(
                      'Report, block, and delete',
                      'الإبلاغ والحظر والحذف',
                    ),
                    body: _t(
                      'You can report content, block a member, and delete your own content or messages.',
                      'يمكنك الإبلاغ عن المحتوى، حظر العضو، وحذف محتواك أو رسائلك.',
                    ),
                  ),
                  _SafetyTile(
                    icon: Icons.speed_outlined,
                    title: _t('Abuse prevention', 'مكافحة الإساءة'),
                    body: _t(
                      'Rate limits, human moderation, and metadata-only audit trails protect the community.',
                      'حدود إرسال ومراجعة بشرية وسجل تدقيق بلا نصوص خاصة.',
                    ),
                  ),
                ],
              );
            },
          ),
  );
}

class _SafetyTile extends StatelessWidget {
  const _SafetyTile({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
    ),
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.languageCode});
  final String languageCode;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        communityTextForLanguage(
          languageCode,
          'Community is unavailable in this build and remains hidden until secure cloud configuration is complete.',
          'المجتمع غير مفعّل في هذا الإصدار. يبقى مغلقًا حتى تكتمل إعدادات السحابة الآمنة.',
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
