import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../data/community_repository.dart';
import '../domain/community_rewards.dart';
import 'bil_gold_coin.dart';
import 'community_account_visit.dart';
import 'community_copy.dart';

class CommunityGoldBalanceAction extends StatefulWidget {
  const CommunityGoldBalanceAction({
    this.compact = false,
    this.repository,
    this.client,
    super.key,
  });

  final bool compact;
  final CommunityRepository? repository;
  final SupabaseClient? client;

  @override
  State<CommunityGoldBalanceAction> createState() =>
      _CommunityGoldBalanceActionState();
}

class _CommunityGoldBalanceActionState
    extends State<CommunityGoldBalanceAction> {
  CommunityRepository? _repository;
  CommunityAccountVisit? _visit;
  Future<CommunityGoldBalance?>? _balance;
  CommunityGoldBalance? _lastGood;
  bool _loadFailed = false;
  int _loadGeneration = 0;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant CommunityGoldBalanceAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.client, widget.client)) {
      _visit?.dispose();
      _bind();
    }
  }

  SupabaseClient? _productionClient() {
    if (!AppEnvironment.supabaseRuntimeReady) return null;
    try {
      final supabase = Supabase.instance;
      return supabase.isInitialized ? supabase.client : null;
    } on Object {
      return null;
    }
  }

  void _bind() {
    _lastGood = null;
    _loadFailed = false;
    final client =
        widget.client ??
        widget.repository?.communitySocialClient ??
        _productionClient();
    _repository =
        widget.repository ??
        (client == null ? null : CommunityRepository(client));
    _visit = CommunityAccountVisit(
      repository: _repository,
      client: client,
      onChanged: () {
        if (!mounted) return;
        setState(() {
          _opening = false;
          _lastGood = null;
          _loadFailed = false;
          _balance = _load();
        });
      },
    );
    _balance = _load();
  }

  Future<CommunityGoldBalance?> _load() async {
    final generation = ++_loadGeneration;
    final repository = _repository;
    final ticket = _visit?.capture();
    if (repository == null || ticket == null) return null;
    try {
      final result = await ticket.run(repository.loadGoldBalance);
      if (!mounted || !ticket.isCurrent || generation != _loadGeneration) {
        return null;
      }
      setState(() {
        _lastGood = result;
        _loadFailed = false;
      });
      return result;
    } on Object {
      if (!mounted || !ticket.isCurrent || generation != _loadGeneration) {
        return null;
      }
      setState(() => _loadFailed = true);
      return _lastGood;
    }
  }

  Future<void> _open(Future<Object?> Function() navigate) async {
    if (_opening) return;
    final visit = _visit;
    final epoch = visit?.epoch;
    setState(() => _opening = true);
    try {
      await navigate();
    } finally {
      if (mounted && identical(visit, _visit) && epoch == visit?.epoch) {
        setState(() {
          _opening = false;
          _balance = _load();
        });
      }
    }
  }

  Future<void> _openRewards() =>
      _open(() => context.push('/community/rewards'));
  Future<void> _openEarn() =>
      _open(() => context.push('/community/compose?origin=earn'));

  @override
  void dispose() {
    _visit?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_repository == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final earn = communityText(context, 'Earn', 'اكسب');
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        FutureBuilder<CommunityGoldBalance?>(
          key: ValueKey(_visit?.epoch),
          future: _balance,
          builder: (context, snapshot) {
            final balance = snapshot.data?.balance;
            return Tooltip(
              message: 'BIL Gold',
              child: InkWell(
                key: const Key('ai-coach-bil-gold'),
                onTap: _opening ? null : _openRewards,
                borderRadius: BorderRadius.circular(16),
                child: Semantics(
                  button: true,
                  label: balance == null ? 'BIL Gold' : 'BIL Gold: $balance',
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 68,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BilGoldCoin(size: 18),
                        const SizedBox(width: 5),
                        Text(
                          balance?.toString() ?? '—',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (_loadFailed)
          IconButton(
            key: const Key('ai-coach-gold-retry'),
            tooltip: communityText(
              context,
              'Could not refresh BIL Gold. Tap to retry.',
              'تعذر تحديث BIL Gold. اضغط لإعادة المحاولة.',
            ),
            onPressed: () => setState(() {
              _balance = _load();
            }),
            icon: Icon(Icons.refresh_rounded, color: scheme.error, size: 18),
          ),
        TextButton.icon(
          key: const Key('ai-coach-earn-post'),
          onPressed: _opening ? null : _openEarn,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(earn),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
        ),
      ],
    );
  }
}
