part of 'community_hub_page.dart';

/// Direct entry to the same owner-bound editor used by Community and Drafts.
/// The router runs the existing profile/code gate before mounting this page.
/// Opening it prepares private input only; publishing remains an explicit action.
class CommunityComposePage extends StatefulWidget {
  const CommunityComposePage({
    this.repository,
    this.imagePicker,
    this.fromEarn = false,
    super.key,
  });

  final CommunityRepository? repository;
  final CommunityPostImagePickerContract? imagePicker;
  final bool fromEarn;

  @override
  State<CommunityComposePage> createState() => _CommunityComposePageState();
}

class _CommunityComposePageState extends State<CommunityComposePage> {
  final _draft = _CommunityComposerDraft();
  late final _defaultImagePicker = CommunityPostImagePicker();
  CommunityRepository? _repository;
  bool _repositoryChanged = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _productionRepository();
  }

  @override
  void didUpdateWidget(covariant CommunityComposePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      // Permanently retire this wrapper, including A -> null -> A. Never
      // mount a new editor around input retained from a previous repository.
      _repositoryChanged = true;
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
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    if (repository == null || _repositoryChanged) {
      return Scaffold(
        key: const Key('community-compose-entry-unavailable'),
        appBar: AppBar(leading: const CommunityReturnButton()),
        body: Center(
          child: Text(
            _repositoryChanged
                ? communityText(
                    context,
                    'Your account changed. Return to Community to continue.',
                    'تغير حسابك. ارجع إلى المجتمع للمتابعة.',
                  )
                : communityText(
                    context,
                    'Sign in required',
                    'تسجيل الدخول مطلوب',
                  ),
          ),
        ),
      );
    }
    return _CommunityPostComposerPage(
      repository: repository,
      imagePicker: widget.imagePicker ?? _defaultImagePicker,
      draft: _draft,
      fromEarn: widget.fromEarn,
    );
  }
}
