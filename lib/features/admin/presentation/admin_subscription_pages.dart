import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../commerce/providers/commerce_providers.dart';
import '../services/admin_subscription_service.dart';
import 'admin_console_copy.dart';

void _refreshRights(WidgetRef ref) {
  ref.invalidate(adminSubscriptionListProvider);
  ref.invalidate(verifiedSubscriptionStateProvider);
  ref.read(aiCoachUsageRefreshProvider.notifier).requestAuthoritativeReload();
}

class AdminSubscriptionGrantForm extends ConsumerStatefulWidget {
  const AdminSubscriptionGrantForm({super.key, required this.aiCoach});
  final bool aiCoach;
  @override
  ConsumerState<AdminSubscriptionGrantForm> createState() => _GrantState();
}

class _GrantState extends ConsumerState<AdminSubscriptionGrantForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _reason = TextEditingController();
  int _days = 30;
  bool _busy = false;
  String? _fingerprint, _key, _result;
  String copy(String key) => adminConsoleCopy(context, key);
  @override
  void dispose() {
    _email.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _grant() async {
    if (_busy || _form.currentState?.validate() != true) return;
    final email = _email.text.trim().toLowerCase();
    final reason = _reason.text.trim();
    final plan = widget.aiCoach ? 'premium_ai_coach' : 'premium';
    final days = _days;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(copy('confirm')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(email, textDirection: TextDirection.ltr),
            const SizedBox(height: 12),
            Text(
              '${widget.aiCoach ? 'Premium + AI Coach' : 'Premium'} · ${copy('$days')}',
            ),
            const SizedBox(height: 12),
            Text(copy('separate')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(copy('cancel')),
          ),
          FilledButton(
            key: const Key('admin-subscription-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(copy('grant')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    final fingerprint = '$email\n$plan\n$days\n$reason';
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      _key = const Uuid().v4();
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final receipt = await ref
          .read(adminSubscriptionGatewayProvider)
          .grant(
            email: email,
            planId: plan,
            durationDays: days == 0 ? null : days,
            reason: reason,
            idempotencyKey: _key!,
          );
      if (!mounted) return;
      _refreshRights(ref);
      _key = null;
      _fingerprint = null;
      setState(
        () => _result = receipt.matched
            ? receipt.changed
                  ? 'success'
                  : 'already'
            : 'missing',
      );
    } on Object catch (error) {
      if (mounted) {
        setState(
          () =>
              _result = error.toString().contains('existing_admin_subscription')
              ? 'conflict'
              : 'failed',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy('separate')),
              if (widget.aiCoach) ...[
                const SizedBox(height: 12),
                Text(copy('quota')),
              ],
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('admin-subscription-email'),
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                maxLength: 254,
                decoration: InputDecoration(labelText: copy('email')),
                validator: (value) =>
                    RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(value?.trim() ?? '')
                    ? null
                    : copy('invalidEmail'),
              ),
              DropdownButtonFormField<int>(
                key: const Key('admin-subscription-duration'),
                initialValue: _days,
                isExpanded: true,
                decoration: InputDecoration(labelText: copy('duration')),
                items: [30, 90, 365, 0]
                    .map(
                      (days) => DropdownMenuItem(
                        value: days,
                        child: Text(copy('$days')),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _days = value ?? 30),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('admin-subscription-reason'),
                controller: _reason,
                enabled: !_busy,
                maxLength: 160,
                maxLines: 2,
                decoration: InputDecoration(labelText: copy('reason')),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(
                    RegExp(r'[\u0000-\u001f\u007f]'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('admin-subscription-grant'),
                onPressed: _busy ? null : _grant,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.card_giftcard),
                label: Text(copy('grant')),
              ),
              if (_result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    copy(_result!),
                    key: const Key('admin-subscription-result'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AdminSubscriptionList extends ConsumerStatefulWidget {
  const AdminSubscriptionList({super.key});
  @override
  ConsumerState<AdminSubscriptionList> createState() => _ListState();
}

class _ListState extends ConsumerState<AdminSubscriptionList> {
  int _offset = 0;
  String? _busyId, _error;
  final Map<String, String> _revokeKeys = {};
  String copy(String key) => adminConsoleCopy(context, key);
  Widget _entryCard(AdminSubscriptionEntry entry) => Card(
    key: Key('admin-subscription-${entry.id}'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(entry.email, textDirection: TextDirection.ltr),
                const SizedBox(height: 8),
                Text(
                  '${entry.planId == 'premium' ? 'Premium' : 'Premium + AI Coach'} · ${copy(entry.status)}',
                ),
                Text(
                  '${copy('created')}: ${MaterialLocalizations.of(context).formatMediumDate(entry.createdAt.toLocal())}',
                ),
                Text(
                  entry.expiresAt == null
                      ? copy('0')
                      : '${copy('ends')}: ${MaterialLocalizations.of(context).formatMediumDate(entry.expiresAt!.toLocal())}',
                ),
              ],
            ),
          ),
          if (entry.status == 'active') ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 126,
              child: TextButton(
                key: Key('admin-revoke-${entry.id}'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _busyId != null ? null : () => _revoke(entry.id),
                child: _busyId == entry.id
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(copy('revoke'), textAlign: TextAlign.center),
              ),
            ),
          ],
        ],
      ),
    ),
  );
  Future<void> _revoke(String id) async {
    if (_busyId != null) return;
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await ref
          .read(adminSubscriptionGatewayProvider)
          .revoke(
            grantId: id,
            idempotencyKey: _revokeKeys.putIfAbsent(
              id,
              () => const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      _revokeKeys.remove(id);
      _refreshRights(ref);
    } on Object {
      if (mounted) setState(() => _error = 'failed');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(adminSubscriptionListProvider(_offset));
    return PopScope(
      canPop: _busyId == null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(copy('separate')),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const Key('admin-subscription-refresh'),
              onPressed: _busyId != null
                  ? null
                  : () => ref.invalidate(adminSubscriptionListProvider),
              icon: const Icon(Icons.refresh),
              label: Text(copy('refresh')),
            ),
          ),
          if (_error != null)
            Text(
              copy(_error!),
              key: const Key('admin-subscription-list-error'),
            ),
          result.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Column(
              children: [
                Text(copy('failed')),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(adminSubscriptionListProvider),
                  child: Text(copy('retry')),
                ),
              ],
            ),
            data: (page) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (page.rows.isEmpty) Text(copy('empty')),
                for (final entry in page.rows) _entryCard(entry),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  children: [
                    if (_offset > 0)
                      TextButton(
                        onPressed: _busyId != null
                            ? null
                            : () => setState(() => _offset -= 50),
                        child: Text(copy('previous')),
                      ),
                    if (page.hasMore)
                      TextButton(
                        onPressed: _busyId != null
                            ? null
                            : () => setState(() => _offset += 50),
                        child: Text(copy('next')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
