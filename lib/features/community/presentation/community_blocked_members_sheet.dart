import '../../../shared/widgets/bil_pearl_feature_welcome.dart';
import '../../../shared/widgets/bil_pearl_material.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/community_repository.dart';
import 'community_copy.dart';

class CommunityBlockedMembersSheet extends StatefulWidget {
  const CommunityBlockedMembersSheet({required this.repository, super.key});
  final CommunityRepository repository;
  @override
  State<CommunityBlockedMembersSheet> createState() =>
      _CommunityBlockedMembersSheetState();
}

class _CommunityBlockedMembersSheetState
    extends State<CommunityBlockedMembersSheet> {
  late final String _owner;
  late Future<List<CommunityBlockedMember>> _members;
  StreamSubscription<AuthState>? _subscription;
  String? _busy;
  bool _retired = false;
  VoidCallback? _cancelUnblockDialog;
  bool get _current {
    if (!mounted || _retired) return false;
    try {
      return widget.repository.currentUserId == _owner;
    } on AuthException {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _owner = widget.repository.currentUserId;
    _members = widget.repository.loadBlockedMembers();
    var previous = _owner;
    _subscription = widget
        .repository
        .communitySocialClient
        .auth
        .onAuthStateChange
        .listen((event) {
          final next = event.session?.user.id;
          if (next != previous || !_current) {
            _retire();
            if (mounted) setState(() {});
          }
          previous = next ?? '';
        });
  }

  @override
  void didUpdateWidget(covariant CommunityBlockedMembersSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) _retire();
  }

  @override
  void dispose() {
    _retire();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _retire() {
    _retired = true;
    _cancelUnblockDialog?.call();
  }

  void _retry() {
    if (_current) {
      setState(() {
        _members = widget.repository.loadBlockedMembers();
      });
    }
  }

  Future<bool> _confirmUnblock() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    var decided = false;
    late final DialogRoute<bool> dialog;
    dialog = DialogRoute<bool>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierColor:
          Theme.of(context).dialogTheme.barrierColor ?? Colors.black54,
      barrierDismissible: true,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (dialogContext) {
        void decide(bool unblock) {
          if (decided) return;
          decided = true;
          if (!navigator.mounted || !dialog.isActive) return;
          if (!dialogContext.mounted || !_current || !dialog.isCurrent) {
            navigator.removeRoute<bool>(dialog, false);
            return;
          }
          navigator.pop<bool>(unblock);
        }

        return BilPearlMaterialAlertDialog(
          title: Text(
            communityText(
              context,
              'Unblock this member?',
              'إلغاء حظر هذا العضو؟',
            ),
          ),
          content: Text(
            communityText(
              context,
              'This removes only your block. It does not restore a friendship or change the other member’s block.',
              'يزيل هذا حظرك فقط. لا يعيد الصداقة ولا يغيّر حظر العضو الآخر.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => decide(false),
              child: Text(communityText(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              key: const Key('community-unblock-confirm'),
              onPressed: () => decide(true),
              child: Text(communityText(context, 'Unblock', 'إلغاء الحظر')),
            ),
          ],
        );
      },
    );
    void cancelDialog() {
      decided = true;
      // Retire only this dialog, even if another route is now above it.
      scheduleMicrotask(() {
        if (navigator.mounted && dialog.isActive) {
          navigator.removeRoute<bool>(dialog, false);
        }
      });
    }

    _cancelUnblockDialog = cancelDialog;
    try {
      return await navigator.push<bool>(dialog) == true;
    } finally {
      if (identical(_cancelUnblockDialog, cancelDialog)) {
        _cancelUnblockDialog = null;
      }
    }
  }

  Future<void> _unblock(CommunityBlockedMember member) async {
    if (!_current || _busy != null) return;
    setState(() => _busy = member.id);
    try {
      final yes = await _confirmUnblock();
      if (yes != true || !mounted || !_current) {
        return;
      }
      await widget.repository.unblockMember(member.id);
      if (!mounted || !_current) {
        return;
      }
      final refreshed = widget.repository.loadBlockedMembers();
      setState(() {
        _members = refreshed;
      });
      await refreshed;
      if (!mounted || !_current) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            communityText(context, 'Block removed.', 'تم إلغاء الحظر.'),
          ),
        ),
      );
    } on Object {
      if (mounted && _current) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Could not confirm block removal. Try again.',
                'تعذر تأكيد إلغاء الحظر. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted && _current) {
        setState(() => _busy = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            communityText(context, 'Blocked members', 'الأعضاء المحظورون'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (!_current)
            Text(
              communityText(context, 'Sign-in required', 'يلزم تسجيل الدخول'),
            )
          else
            Flexible(
              child: FutureBuilder<List<CommunityBlockedMember>>(
                future: _members,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: BilFeatureWelcomeStatus());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        communityText(context, 'Retry', 'إعادة المحاولة'),
                      ),
                    );
                  }
                  if (snapshot.requireData.isEmpty) {
                    return Text(
                      communityText(
                        context,
                        'No blocked members.',
                        'لا يوجد أعضاء محظورون.',
                      ),
                    );
                  }
                  final members = snapshot.requireData;
                  return ListView.builder(
                    key: const Key('community-blocked-list'),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return _BlockedMemberRow(
                        key: ValueKey('community-blocked-row-${member.id}'),
                        member: member,
                        onUnblock: _busy == null
                            ? () => _unblock(member)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(communityText(context, 'Close', 'إغلاق')),
          ),
        ],
      ),
    ),
  );
}

class _BlockedMemberRow extends StatelessWidget {
  const _BlockedMemberRow({
    required this.member,
    required this.onUnblock,
    super.key,
  });

  final CommunityBlockedMember member;
  final VoidCallback? onUnblock;

  @override
  Widget build(BuildContext context) {
    final name =
        member.name ??
        '${communityText(context, 'BIL member', 'عضو BIL')} · ${member.id.substring(30)}';
    final unblockLabel = communityText(context, 'Unblock', 'إلغاء الحظر');
    return BilPearlMaterialCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: CircleAvatar(
                radius: 18,
                child: Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatShortDate(member.createdAt.toLocal()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: OutlinedButton(
                key: Key('community-unblock-${member.id}'),
                onPressed: onUnblock,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  unblockLabel,
                  semanticsLabel: '$unblockLabel, $name',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
