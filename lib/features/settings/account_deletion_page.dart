import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';
import '../auth/apple_credential_lifecycle.dart';

part 'account_deletion_copy.dart';

@visibleForTesting
bool accountUsesAppleSignIn(User? user) {
  if (user == null) return false;
  if (user.identities?.any(
        (identity) => identity.provider.trim().toLowerCase() == 'apple',
      ) ??
      false) {
    return true;
  }
  final primaryProvider = user.appMetadata['provider'];
  if (primaryProvider is String &&
      primaryProvider.trim().toLowerCase() == 'apple') {
    return true;
  }
  final providers = user.appMetadata['providers'];
  return providers is Iterable &&
      providers.whereType<String>().any(
        (provider) => provider.trim().toLowerCase() == 'apple',
      );
}

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final _confirmation = TextEditingController();
  bool _submitting = false;

  Future<void> _openSubscriptionManagement() async {
    final uri = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => Uri.parse(
        'https://apps.apple.com/account/subscriptions',
      ),
      TargetPlatform.android => Uri.parse(
        'https://play.google.com/store/account/subscriptions',
      ),
      _ => null,
    };
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // The billing warning remains visible even when the system cannot open
      // the store link. Deletion itself is never blocked by this convenience.
    }
  }

  Future<void> _openAppleAccessInstructions() async {
    final uri = Uri.parse('https://support.apple.com/102571');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Apple access removal is an optional external follow-up after BIL data
      // deletion. A link-launch failure must never undo or block deletion.
    }
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final copy = _AccountDeletionCopy.of(context);
    final supabase = Supabase.instance;
    if (!AppEnvironment.cloudConfigured ||
        !supabase.isInitialized ||
        supabase.client.auth.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.signInRequired)));
      return;
    }
    final client = supabase.client;
    final accountOwnerId = client.auth.currentUser!.id.trim();
    final usedAppleSignIn = accountUsesAppleSignIn(client.auth.currentUser);
    final appleOwnerId = usedAppleSignIn ? accountOwnerId : null;
    if (_confirmation.text.trim().toUpperCase() != 'DELETE') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.confirmationRequired)));
      return;
    }
    setState(() => _submitting = true);
    try {
      final response = await client.rpc(
        'bil_request_account_deletion',
        params: {'p_reason': 'user_requested_in_help_center'},
      );
      if (response is! Map) throw const FormatException('invalid response');
      final requestId = response['request_id'];
      final status = response['status'];
      if (requestId is! String ||
          requestId.isEmpty ||
          status is! String ||
          (status != 'pending' && status != 'processing')) {
        throw const FormatException('invalid deletion request receipt');
      }
      var effectiveStatus = status;
      try {
        final worker = await client.functions.invoke(
          'account-data-deletion',
          body: <String, Object?>{'request_id': requestId},
        );
        final workerData = worker.data;
        if (worker.status == 200 &&
            workerData is Map &&
            workerData['status'] == 'completed' &&
            workerData['request_id'] == requestId) {
          effectiveStatus = 'completed';
        }
      } on Object {
        // The authenticated request is durable. A failed immediate Edge
        // Function call remains pending for the Storage-first retry worker.
      }

      // A valid receipt means the deletion request is durable even when the
      // worker finishes later. Clear the requesting account locally before
      // any interactive dialog so an app termination cannot leave its session
      // or Apple subject behind. Never sign out a replacement account.
      final appleIdentifierStore = usedAppleSignIn
          ? SecureAppleCredentialIdentifierStore()
          : null;
      if (appleIdentifierStore != null) {
        try {
          await appleIdentifierStore.markPendingCleanup(accountOwnerId);
        } on Object {
          // Continue with immediate cleanup. A fully unavailable Keychain must
          // never keep a durable account-deletion request signed in.
        }
      }
      await invalidateMatchingLocalSession(
        expectedOwnerId: accountOwnerId,
        readCurrentOwnerId: () => client.auth.currentUser?.id,
        signOutLocal: () => client.auth.signOut(scope: SignOutScope.local),
      );
      if (appleIdentifierStore != null &&
          appleOwnerId != null &&
          appleOwnerId.isNotEmpty) {
        try {
          await appleIdentifierStore.delete(appleOwnerId);
          await appleIdentifierStore.clearPendingCleanup(appleOwnerId);
        } on Object {
          // The durable marker remains for an automatic retry at next launch.
          // Account deletion and local sign-out do not depend on this cleanup.
        }
      }

      if (!mounted) return;
      _confirmation.clear();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(copy.requestReceived),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                effectiveStatus == 'completed'
                    ? copy.deletionCompletedBody
                    : copy.requestReceivedBody,
              ),
              if (effectiveStatus != 'completed') ...[
                const SizedBox(height: 8),
                Text(copy.pendingTimingNotice),
              ],
              const SizedBox(height: 16),
              Text('${copy.statusLabel}: ${copy.statusFor(effectiveStatus)}'),
              const SizedBox(height: 4),
              Text(copy.referenceLabel),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(requestId),
              ),
              if (usedAppleSignIn) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  copy.appleAccessTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  effectiveStatus == 'completed'
                      ? copy.appleAccessBody
                      : copy.pendingTimingNotice,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _openAppleAccessInstructions,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(copy.appleAccessLearnMore),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(copy.close),
            ),
          ],
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.failed)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _AccountDeletionCopy.of(context);
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: Text(copy.title)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.person_remove_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              copy.heading,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(copy.body),
            const SizedBox(height: 12),
            Text(
              copy.billingNotice,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _submitting ? null : _openSubscriptionManagement,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(copy.manageSubscription),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmation,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: copy.confirmationLabel,
                hintText: 'DELETE',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: Text(copy.submit),
            ),
          ],
        ),
      ),
    );
  }
}
