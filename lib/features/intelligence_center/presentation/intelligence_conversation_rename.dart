part of 'intelligence_center_page.dart';

extension _IntelligenceConversationRename on _IntelligenceCenterPageState {
  Future<void> _renameConversation(String id) async {
    if (!mounted || !conversationReady) return;
    final preferences = conversationPreferences;
    final database = ref.read(databaseProvider);
    final witness = ref.read(coachNativeOwnerWitnessProvider);
    final epoch = conversationPersistenceEpoch;
    var retired = false;
    final subscription = witness?.changes.listen((owner) {
      if (owner != database.localOwnerId) retired = true;
    }, onError: (Object _, StackTrace _) => retired = true);
    bool current() =>
        mounted &&
        !retired &&
        epoch == conversationPersistenceEpoch &&
        identical(ref.read(databaseProvider), database) &&
        (witness == null || witness.readOwner() == database.localOwnerId);
    try {
      if (id == activeConversationId) {
        await _archiveCurrentConversation(<Map<String, Object?>>[]);
      }
      if (!current()) return;
      final raw = await preferences.get(_conversationHistoryKey);
      if (!mounted || !current()) return;
      final entries = decodeCoachConversationHistory(raw).conversations;
      final entry = entries.where((entry) => entry['id'] == id).firstOrNull;
      if (entry == null) throw StateError('conversation_missing');
      await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => CoachConversationRenameDialog(
          title: '${entry['title'] ?? ''}',
          onSave: (title) async {
            if (!current()) throw StateError('conversation_owner_changed');
            final previous = conversationPersistenceTail;
            Future<void> write() async {
              try {
                await previous;
              } on Object {
                /* Prior best-effort saves cannot hide a rename failure. */
              }
              if (!current()) throw StateError('conversation_owner_changed');
              await preferences.update(_conversationHistoryKey, (latest) {
                // Replies can arrive while the editor is open. Merge the
                // live transcript inside the same serialized transaction,
                // after queued message saves, rather than its opening copy.
                if (activeConversationId == id) {
                  final persistent = messages
                      .where((message) => !message.id.startsWith('welcome'))
                      .map((message) => message.toJson())
                      .toList(growable: false);
                  // Rename must not recreate an entry deleted meanwhile.
                  if (!decodeCoachConversationHistory(
                    latest,
                  ).conversations.any((entry) => entry['id'] == id)) {
                    throw StateError('conversation_missing');
                  }
                  latest = upsertCoachConversationArchive(
                    raw: latest,
                    id: id,
                    automaticTitle: title,
                    createdAt: DateTime.now().toIso8601String(),
                    messages: persistent,
                    activeId: activeConversationId,
                  );
                }
                return renameCoachConversationInArchive(latest, id, title);
              }, isCurrent: current);
              if (current() && activeConversationId == id) {
                _updateState(() => activeConversationTitle = title);
              }
            }

            final saving = write();
            conversationPersistenceTail = saving;
            await saving;
          },
        ),
      );
    } on Object {
      if (mounted && current()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Could not rename this conversation. Try again.',
                'تعذّرت إعادة تسمية المحادثة. أعد المحاولة.',
              ),
            ),
          ),
        );
      }
    } finally {
      await subscription?.cancel();
    }
  }
}
