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
    this.showEarn = true,
    this.showBalance = true,
    this.repository,
    this.client,
    super.key,
  });

  final bool compact;
  final bool showEarn;
  final bool showBalance;
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

  Widget _earnAction(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? const Color(0xFFFFE6A0) : const Color(0xFF765100);
    final background = dark ? const Color(0xFF443714) : const Color(0xFFFFF0C2);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BilGoldCoin(size: 18),
        const SizedBox(width: 5),
        Text(
          communityText(context, 'Earn', 'اكسب'),
          style: TextStyle(fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
    if (widget.compact) {
      return Semantics(
        button: true,
        label: communityText(context, 'Earn in Community', 'اكسب في المجتمع'),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('ai-coach-earn-post'),
            onTap: _opening ? null : _openEarn,
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            child: const SizedBox.square(
              dimension: 48,
              child: Center(child: BilGoldCoin(size: 20)),
            ),
          ),
        ),
      );
    }
    final button = TextButton(
      key: const Key('ai-coach-earn-post'),
      onPressed: _opening ? null : _openEarn,
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: color,
        backgroundColor: background,
        side: BorderSide(color: color.withValues(alpha: .26)),
        shape: const StadiumBorder(),
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      child: content,
    );
    return button;
  }

  @override
  void dispose() {
    _visit?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showBalance) {
      return widget.showEarn ? _earnAction(context) : const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: widget.compact ? 4 : 6,
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
                  child: SizedBox(
                    height: widget.compact ? 44 : 48,
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: widget.compact ? 36 : 48,
                          minWidth: widget.compact ? 48 : 56,
                          maxWidth: widget.compact ? 64 : double.infinity,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.compact ? 6 : 8,
                          vertical: widget.compact ? 3 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BilGoldCoin(size: widget.compact ? 16 : 18),
                            SizedBox(width: widget.compact ? 4 : 5),
                            Flexible(
                              child: Text(
                                balance?.toString() ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: widget.compact ? 14 : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
        if (widget.showEarn) _earnAction(context),
      ],
    );
  }
}
