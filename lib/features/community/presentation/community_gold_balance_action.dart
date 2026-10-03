import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../data/community_repository.dart';
import '../domain/community_rewards.dart';
import 'bil_gold_coin.dart';

class CommunityGoldBalanceAction extends StatefulWidget {
  const CommunityGoldBalanceAction({this.compact = false, super.key});

  final bool compact;

  @override
  State<CommunityGoldBalanceAction> createState() =>
      _CommunityGoldBalanceActionState();
}

class _CommunityGoldBalanceActionState
    extends State<CommunityGoldBalanceAction> {
  CommunityRepository? _repository;
  Future<CommunityGoldBalance?>? _balance;

  @override
  void initState() {
    super.initState();
    _repository = _productionRepository();
    _balance = _repository == null ? null : _load();
  }

  CommunityRepository? _productionRepository() {
    if (!AppEnvironment.supabaseRuntimeReady) return null;
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

  Future<CommunityGoldBalance?> _load() async {
    final repository = _repository;
    if (repository == null) return null;
    try {
      return await repository.loadGoldBalance();
    } on Object {
      return null;
    }
  }

  Future<void> _openRewards() async {
    await context.push('/community/rewards');
    if (!mounted || _repository == null) return;
    setState(() => _balance = _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_repository == null || _balance == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<CommunityGoldBalance?>(
      future: _balance,
      builder: (context, snapshot) {
        final balance = snapshot.data?.balance;
        return Tooltip(
          message: 'BIL Gold — Earn',
          child: Semantics(
            button: true,
            label: balance == null
                ? 'BIL Gold. Earn'
                : 'BIL Gold: $balance. Earn',
            child: InkWell(
              key: const Key('ai-coach-bil-gold'),
              onTap: _openRewards,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: BoxConstraints(
                  minHeight: 46,
                  minWidth: widget.compact ? 68 : 88,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF7C94B).withValues(alpha: .55),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BilGoldCoin(size: 18),
                        const SizedBox(width: 5),
                        Text(
                          balance?.toString() ?? '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    if (!widget.compact)
                      const Text(
                        'Earn',
                        style: TextStyle(
                          color: Color(0xFFFFE7A0),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
