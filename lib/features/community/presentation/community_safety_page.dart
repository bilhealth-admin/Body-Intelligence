import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../data/community_repository.dart';
import '../domain/community_content_policy.dart';
import 'community_copy.dart';

typedef CommunityPolicyUrlLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchCommunityPolicyUrl(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class CommunitySafetyPage extends StatefulWidget {
  const CommunitySafetyPage({
    this.repository,
    this.policyUrlLauncher,
    this.onDecline,
    super.key,
  });

  final CommunityRepository? repository;
  final CommunityPolicyUrlLauncher? policyUrlLauncher;
  final VoidCallback? onDecline;

  @override
  State<CommunitySafetyPage> createState() => _CommunitySafetyPageState();
}

class _CommunitySafetyPageState extends State<CommunitySafetyPage> {
  CommunityRepository? _repository;
  Future<CommunityPolicyState>? _policyState;
  String? _loadedLanguageCode;
  bool _readAndAgree = false;
  bool _saving = false;
  bool _openingDocument = false;

  String get _languageCode =>
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
  String _t(String en, String ar) =>
      communityTextForLanguage(_languageCode, en, ar);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository ??= widget.repository ?? _productionRepository();
    final languageCode = _languageCode;
    if (_repository != null &&
        (_policyState == null || _loadedLanguageCode != languageCode)) {
      _loadedLanguageCode = languageCode;
      _readAndAgree = false;
      _policyState = _repository!.loadCommunityPolicyState(
        localeCode: languageCode,
      );
    }
  }

  @override
  void didUpdateWidget(covariant CommunitySafetyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      final repository = widget.repository ?? _productionRepository();
      final languageCode = _languageCode;
      _repository = repository;
      _loadedLanguageCode = languageCode;
      _readAndAgree = false;
      _saving = false;
      _policyState = repository?.loadCommunityPolicyState(
        localeCode: languageCode,
      );
    }
  }

  CommunityRepository? _productionRepository() {
    if (!AppEnvironment.communityConfigured) return null;
    try {
      final supabase = Supabase.instance;
      if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
        return null;
      }
      return CommunityRepository(supabase.client);
    } on AssertionError {
      return null;
    } on StateError {
      return null;
    }
  }

  void _retry() {
    final repository = widget.repository ?? _productionRepository();
    setState(() {
      _repository = repository;
      _readAndAgree = false;
      _loadedLanguageCode = _languageCode;
      _policyState = repository?.loadCommunityPolicyState(
        localeCode: _languageCode,
      );
    });
  }

  Future<void> _openPolicy(CommunityContentPolicy policy) async {
    if (_openingDocument) return;
    setState(() => _openingDocument = true);
    var opened = false;
    try {
      opened = await (widget.policyUrlLauncher ?? _launchCommunityPolicyUrl)(
        _localizedPolicyDocumentUrl(policy.documentUrl),
      );
    } on Object {
      opened = false;
    } finally {
      if (mounted) setState(() => _openingDocument = false);
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'The policy could not be opened. Try again before accepting.',
              'تعذر فتح السياسة. حاول مجددًا قبل الموافقة.',
            ),
          ),
        ),
      );
    }
  }

  Uri _localizedPolicyDocumentUrl(Uri documentUrl) {
    if (_languageCode != 'ar' ||
        documentUrl.scheme != 'https' ||
        documentUrl.host.toLowerCase() != 'www.bilhealth.com' ||
        documentUrl.path != '/community-guidelines') {
      return documentUrl;
    }
    return documentUrl.replace(
      queryParameters: {...documentUrl.queryParameters, 'lang': 'ar'},
    );
  }

  Future<void> _accept(CommunityContentPolicy policy) async {
    if (_saving || !_readAndAgree) return;
    final repository = _repository;
    if (repository == null) return;
    final languageCode = _languageCode;
    setState(() => _saving = true);
    try {
      await repository.acceptContentPolicy(policy.version);
      final verifiedState = await repository.loadCommunityPolicyState(
        localeCode: languageCode,
      );
      final verifiedPolicy = verifiedState.policy;
      if (verifiedState.status != CommunityPolicyStatus.accepted ||
          verifiedPolicy == null ||
          verifiedPolicy.version != policy.version ||
          verifiedState.acceptedVersion != policy.version) {
        throw StateError('Community policy acceptance was not verified');
      }
      if (!mounted ||
          !identical(_repository, repository) ||
          _loadedLanguageCode != languageCode) {
        return;
      }
      setState(() => _policyState = Future.value(verifiedState));
    } on Object {
      if (!mounted ||
          !identical(_repository, repository) ||
          _loadedLanguageCode != languageCode) {
        return;
      }
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
      if (mounted && identical(_repository, repository)) {
        setState(() => _saving = false);
      }
    }
  }

  void _notNow() {
    final onDecline = widget.onDecline;
    if (onDecline != null) {
      onDecline();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(false);
      return;
    }
    context.go('/community');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_t('Safety & community policy', 'الأمان وسياسة المجتمع')),
    ),
    body: _policyState == null
        ? _PolicyLoadError(languageCode: _languageCode, onRetry: _retry)
        : FutureBuilder<CommunityPolicyState>(
            future: _policyState,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _PolicyLoading(languageCode: _languageCode);
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _PolicyLoadError(
                  languageCode: _languageCode,
                  onRetry: _retry,
                );
              }
              final state = snapshot.data!;
              if (state.status == CommunityPolicyStatus.unavailable) {
                return _NoActivePolicy(
                  languageCode: _languageCode,
                  onRetry: _retry,
                );
              }
              final policy = state.policy;
              if (policy == null) {
                return _PolicyLoadError(
                  languageCode: _languageCode,
                  onRetry: _retry,
                );
              }
              final accepted =
                  state.status == CommunityPolicyStatus.accepted &&
                  state.acceptedVersion == policy.version;
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
                          leading: const BilSemanticIconBadge(
                            kind: BilSemanticIconKind.legal,
                          ),
                          title: Text(_t('Content policy', 'سياسة المحتوى')),
                          subtitle: SelectableText(
                            '${policy.version}\n${policy.documentUrl}',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const Key('open-community-policy'),
                              onPressed: _openingDocument
                                  ? null
                                  : () => _openPolicy(policy),
                              icon: _openingDocument
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.open_in_new_rounded),
                              label: Text(_t('Read policy', 'قراءة السياسة')),
                            ),
                          ),
                        ),
                        if (!accepted) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _t(
                                'Publishing, comments, and messages stay locked until you review and accept this version.',
                                'يبقى النشر والتعليقات والرسائل مقفلة حتى تراجع هذه النسخة وتوافق عليها.',
                              ),
                            ),
                          ),
                          CheckboxListTile(
                            key: const Key('confirm-community-policy'),
                            value: _readAndAgree,
                            onChanged: _saving
                                ? null
                                : (value) => setState(
                                    () => _readAndAgree = value ?? false,
                                  ),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              _t(
                                'I have read and agree to this policy version.',
                                'قرأت هذه النسخة من السياسة وأوافق عليها.',
                              ),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const Key('accept-community-policy'),
                              onPressed: accepted || _saving || !_readAndAgree
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
                                    : _t('Accept policy', 'أوافق على السياسة'),
                              ),
                            ),
                          ),
                        ),
                        if (!accepted)
                          TextButton(
                            key: const Key('community-policy-not-now'),
                            onPressed: _saving ? null : _notNow,
                            child: Text(_t('Not now', 'ليس الآن')),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SafetyTile(
                    kind: BilSemanticIconKind.privacy,
                    title: _t('Health logs stay private', 'سجلاتك الصحية خاصة'),
                    body: _t(
                      'BIL never posts weight, meals, or measurements without an explicit share action.',
                      'لا ينشر BIL وزنًا أو وجبة أو قياسًا دون إجراء مشاركة واضح منك.',
                    ),
                  ),
                  _SafetyTile(
                    kind: BilSemanticIconKind.moderation,
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
                    kind: BilSemanticIconKind.moderation,
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
    required this.kind,
    required this.title,
    required this.body,
  });
  final BilSemanticIconKind kind;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: BilSemanticIconBadge(kind: kind),
      title: Text(title),
      subtitle: Text(body),
    ),
  );
}

class _PolicyLoading extends StatelessWidget {
  const _PolicyLoading({required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context) => _PolicyStatusMessage(
    key: const Key('community-policy-loading'),
    icon: Icons.hourglass_top_rounded,
    title: communityTextForLanguage(
      languageCode,
      'Checking Community policy…',
      'جارٍ التحقق من سياسة المجتمع…',
    ),
    body: communityTextForLanguage(
      languageCode,
      'Publishing, comments, and messages stay locked until verification finishes.',
      'يبقى النشر والتعليقات والرسائل مقفلة حتى اكتمال التحقق.',
    ),
    loading: true,
  );
}

class _PolicyLoadError extends StatelessWidget {
  const _PolicyLoadError({required this.languageCode, required this.onRetry});

  final String languageCode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _PolicyStatusMessage(
    key: const Key('community-policy-error'),
    icon: Icons.gpp_maybe_outlined,
    title: communityTextForLanguage(
      languageCode,
      'Community policy could not be verified',
      'تعذر التحقق من سياسة المجتمع',
    ),
    body: communityTextForLanguage(
      languageCode,
      'Publishing, comments, and messages remain locked. Check your connection and retry.',
      'يبقى النشر والتعليقات والرسائل مقفلة. تحقق من الاتصال وأعد المحاولة.',
    ),
    retryLabel: communityTextForLanguage(
      languageCode,
      'Retry',
      'إعادة المحاولة',
    ),
    onRetry: onRetry,
  );
}

class _NoActivePolicy extends StatelessWidget {
  const _NoActivePolicy({required this.languageCode, required this.onRetry});

  final String languageCode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _PolicyStatusMessage(
    key: const Key('community-policy-unavailable'),
    icon: Icons.policy_outlined,
    title: communityTextForLanguage(
      languageCode,
      'No active Community policy is available',
      'لا توجد سياسة مجتمع فعالة',
    ),
    body: communityTextForLanguage(
      languageCode,
      'Publishing, comments, and messages are locked until BIL publishes a production policy. No acceptance has been recorded.',
      'النشر والتعليقات والرسائل مقفلة حتى ينشر BIL سياسة إنتاج فعلية. لم تُسجّل أي موافقة.',
    ),
    retryLabel: communityTextForLanguage(
      languageCode,
      'Check again',
      'تحقق مجددًا',
    ),
    onRetry: onRetry,
  );
}

class _PolicyStatusMessage extends StatelessWidget {
  const _PolicyStatusMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.loading = false,
    this.retryLabel,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool loading;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          if (loading) ...[
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
          if (onRetry != null && retryLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('community-policy-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}
