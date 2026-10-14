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
            _retired = true;
            if (mounted) setState(() {});
          }
          previous = next ?? '';
        });
  }

  @override
  void didUpdateWidget(covariant CommunityBlockedMembersSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) _retired = true;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _retry() {
    if (_current) {
      setState(() {
        _members = widget.repository.loadBlockedMembers();
      });
    }
  }

  Future<void> _unblock(CommunityBlockedMember member) async {
    if (!_current || _busy != null) return;
    setState(() => _busy = member.id);
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
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
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(communityText(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              key: const Key('community-unblock-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(communityText(context, 'Unblock', 'إلغاء الحظر')),
            ),
          ],
        ),
      );
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
                    return const Center(child: CircularProgressIndicator());
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
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final member in snapshot.requireData)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  member.name ??
                                      '${communityText(context, 'BIL member', 'عضو BIL')} · ${member.id.substring(30)}',
                                ),
                                Text(
                                  MaterialLocalizations.of(
                                    context,
                                  ).formatShortDate(member.createdAt.toLocal()),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: OutlinedButton.icon(
                                    key: Key('community-unblock-${member.id}'),
                                    onPressed: _busy == null
                                        ? () => _unblock(member)
                                        : null,
                                    icon: const Icon(
                                      Icons.person_add_alt_1_outlined,
                                    ),
                                    label: Text(
                                      communityText(
                                        context,
                                        'Unblock',
                                        'إلغاء الحظر',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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
