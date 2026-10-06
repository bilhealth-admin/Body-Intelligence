import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../profile/services/profile_photo_service.dart';
import '../data/community_repository.dart';
import '../domain/community_text_policy.dart';
import '../services/community_entry_coordinator.dart';
import 'community_copy.dart';
import 'community_entry_copy.dart';
import 'community_entry_welcome.dart';
import 'community_return_button.dart';
import 'community_surface.dart';
import 'community_welcome.dart';

/// Defers constructing a social destination until its owner has a saved profile
/// and a valid server code. Premium and moderator authorization stay outside.
class CommunityEntryGate extends ConsumerStatefulWidget {
  const CommunityEntryGate({
    required this.child,
    this.repository,
    this.showWelcome = false,
    this.welcomeDuration = const Duration(milliseconds: 2200),
    this.syncPhoto,
    super.key,
  });
  final Widget child;
  final CommunityRepository? repository;
  final bool showWelcome;
  final Duration welcomeDuration;

  /// An injectable, owner-aware seam; false means the optional photo is pending.
  final Future<bool> Function()? syncPhoto;

  @override
  ConsumerState<CommunityEntryGate> createState() => _CommunityEntryGateState();
}

class _CommunityEntryGateState extends ConsumerState<CommunityEntryGate> {
  final _name = TextEditingController();
  CommunityRepository? _repository;
  CommunityEntryCoordinator? _coordinator;
  CommunityEntryReceipt? _receipt;
  StreamSubscription<AuthState>? _auth;
  Timer? _welcomeTimer;
  String? _owner;
  bool _checking = true;
  bool _saving = false;
  bool _failedCheck = false;
  bool _welcomePending = false;
  String? _saveError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _welcomePending = widget.showWelcome;
    if (_welcomePending) {
      _welcomeTimer = Timer(widget.welcomeDuration, () {
        if (mounted) setState(() => _welcomePending = false);
      });
    }
    _bind();
  }

  String? _currentOwner(CommunityRepository? repository) {
    try {
      return repository?.currentUserId;
    } on Object {
      return null;
    }
  }

  void _bind() {
    unawaited(_auth?.cancel());
    _auth = null;
    SupabaseClient? client;
    _repository = widget.repository;
    if (_repository != null) {
      client = _repository!.communitySocialClient;
    } else if (AppEnvironment.communityConfigured) {
      try {
        if (Supabase.instance.isInitialized) client = Supabase.instance.client;
      } on Object {
        client = null;
      }
      if (client != null && client.auth.currentUser != null) {
        _repository = CommunityRepository(client);
      }
    }
    _owner = _currentOwner(_repository);
    _coordinator = _repository == null
        ? null
        : CommunityEntryCoordinator(_repository!);
    if (client != null) {
      final observedClient = client;
      _auth = client.auth.onAuthStateChange.listen(
        (_) {
          if (!mounted) return;
          final next = widget.repository == null
              ? observedClient.auth.currentUser?.id
              : _currentOwner(widget.repository);
          if (next == _owner) return;
          _generation++;
          setState(() {
            _owner = next;
            _repository =
                widget.repository ??
                (next == null ? null : CommunityRepository(observedClient));
            _coordinator = _repository == null
                ? null
                : CommunityEntryCoordinator(_repository!);
            _receipt = null;
            _saveError = null;
            _name.clear();
            _saving = false;
          });
          unawaited(_check());
        },
        onError: (Object _, StackTrace _) {
          // Authentication owns recovery. Never manufacture a member on failure.
        },
      );
    }
    unawaited(_check());
  }

  @override
  void didUpdateWidget(covariant CommunityEntryGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _generation++;
      _receipt = null;
      _saveError = null;
      _saving = false;
      _name.clear();
      _bind();
    }
  }

  bool _sameOperation(int generation, String? owner) =>
      mounted &&
      generation == _generation &&
      owner == _owner &&
      owner == _currentOwner(_repository);

  Future<void> _check() async {
    final generation = ++_generation;
    final owner = _owner;
    final coordinator = _coordinator;
    setState(() {
      _checking = true;
      _failedCheck = false;
      _receipt = null;
    });
    try {
      final receipt = owner == null
          ? null
          : await coordinator?.check().timeout(const Duration(seconds: 20));
      if (_sameOperation(generation, owner)) setState(() => _receipt = receipt);
    } on Object {
      if (_sameOperation(generation, owner)) {
        setState(() => _failedCheck = true);
      }
    } finally {
      if (_sameOperation(generation, owner)) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    final coordinator = _coordinator;
    final owner = _owner;
    if (coordinator == null || owner == null || _saving || _checking) return;
    final generation = _generation;
    final name = _name.text.trim();
    if (name.length < 2 || name.length > 60) {
      setState(
        () => _saveError = CommunityEntryCopy.text(
          context,
          CommunityEntryCopyKey.invalidName,
        ),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final receipt = await coordinator
          .save(
            displayName: name,
            localeCode: BilLocalePolicy.canonicalTag(
              Localizations.localeOf(context),
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (!_sameOperation(generation, owner)) return;
      setState(() => _receipt = receipt);
      // Optional photo never holds the member behind a spinner. The existing
      // service independently checks local/auth owners before every mutation.
      unawaited(_syncOptionalPhoto(generation, owner));
    } on CommunityTextPolicyException catch (error) {
      if (_sameOperation(generation, owner)) {
        setState(
          () => _saveError = error.localizedMessage(
            BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
          ),
        );
      }
    } on Object {
      if (_sameOperation(generation, owner)) {
        setState(
          () => _saveError = CommunityEntryCopy.text(
            context,
            CommunityEntryCopyKey.saveFailed,
          ),
        );
      }
    } finally {
      if (_sameOperation(generation, owner)) setState(() => _saving = false);
    }
  }

  Future<void> _syncOptionalPhoto(int generation, String owner) async {
    if (!_sameOperation(generation, owner)) return;
    var synced = true;
    try {
      final override = widget.syncPhoto;
      if (override != null) {
        synced = await override();
      } else if (widget.repository == null) {
        final result = await ref
            .read(profilePhotoServiceProvider)
            .syncStoredPhotoToCommunity();
        synced = result == null || result.cloudSynced;
      }
    } on Object {
      synced = false;
    }
    if (!mounted || !_sameOperation(generation, owner)) return;
    if (!synced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CommunityEntryCopy.text(
              context,
              CommunityEntryCopyKey.photoPending,
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _generation++;
    _welcomeTimer?.cancel();
    unawaited(_auth?.cancel());
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CommunitySurface(child: Builder(builder: _buildGate));

  Widget _buildGate(BuildContext context) {
    if (_receipt != null &&
        !_checking &&
        !_welcomePending &&
        _receipt!.profile.userId == _owner) {
      return KeyedSubtree(
        key: ValueKey('community-member-$_owner'),
        child: widget.child,
      );
    }
    return Scaffold(
      key: const Key('community-entry-gate'),
      appBar: AppBar(
        leading: const CommunityReturnButton(),
        title: Text(communityText(context, 'BIL Community', 'مجتمع BIL')),
      ),
      body: SafeArea(
        child: _welcomePending
            ? const CommunityWelcome()
            : _checking
            ? const Center(child: CircularProgressIndicator())
            : _owner == null
            ? Center(
                child: FilledButton.icon(
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.login_rounded),
                  label: Text(
                    communityText(context, 'Sign in', 'تسجيل الدخول'),
                  ),
                ),
              )
            : _failedCheck
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 42),
                      const SizedBox(height: 16),
                      Text(
                        communityText(
                          context,
                          'Could not load your community profile safely.',
                          'تعذر تحميل ملف المجتمع بأمان.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('community-entry-retry'),
                        onPressed: _check,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          communityText(context, 'Retry', 'إعادة المحاولة'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : CommunityEntryWelcome(
                name: _name,
                saving: _saving,
                error: _saveError,
                onContinue: _save,
              ),
      ),
    );
  }
}
