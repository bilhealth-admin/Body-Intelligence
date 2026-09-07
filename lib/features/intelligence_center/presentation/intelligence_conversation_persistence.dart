part of 'intelligence_center_page.dart';

@visibleForTesting
bool coachConversationSaveIsCurrent({
  required int saveEpoch,
  required int currentEpoch,
  required String? saveConversationId,
  required String? activeConversationId,
}) => saveEpoch == currentEpoch && saveConversationId == activeConversationId;

@visibleForTesting
String coachGreetingKeyForHour(int hour) {
  if (hour < 0 || hour > 23) {
    throw ArgumentError.value(hour, 'hour', 'must be from 0 through 23');
  }
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

@visibleForTesting
String coachGreetingSeparator({required bool arabic}) =>
    arabic ? '\u060C' : ',';

extension _IntelligenceConversationPersistence on _IntelligenceCenterPageState {
  Future<void> _loadConversation() async {
    if (!mounted) return;
    if (conversationReady) {
      _updateState(() => conversationReady = false);
    }
    try {
      final preferences = conversationPreferences;
      final storedValues = await Future.wait([
        preferences.get('intelligenceConversationV1'),
        preferences.get('intelligenceConversationContextV1'),
        preferences.get('intelligenceConversationActiveIdV1'),
        preferences.get(_conversationHistoryKey),
      ]);
      final stored = storedValues[0];
      final storedContextFingerprint = storedValues[1];
      final storedConversationId = storedValues[2]?.trim();
      final historyArchive = decodeCoachConversationHistory(storedValues[3]);
      final contextRevision = await _coachContextRevision();
      if (!mounted) return;
      final restored = <IntelligenceMessage>[];
      var storedMessageValues = <Object?>[];
      var storedTranscriptReadable = stored != null && stored.isEmpty;
      final contextFingerprintChanged =
          storedContextFingerprint != contextRevision.fingerprint;
      // Conversation history is user-owned content, not a cache of the current
      // health snapshot. A context change, including a legacy transcript that
      // predates fingerprints, must never delete or skip the stored turns.
      if (stored != null && stored.isNotEmpty) {
        try {
          final decoded = jsonDecode(stored);
          if (decoded is! List) throw const FormatException();
          storedMessageValues = List<Object?>.from(decoded);
          storedTranscriptReadable = true;
          for (final value in decoded.whereType<Map>()) {
            final message = _presentationSafeMessage(
              IntelligenceMessage.fromJson(Map<String, Object?>.from(value)),
            );
            restored.add(message);
          }
        } catch (_) {
          // A malformed snapshot is not a valid transcript to restore. Keep
          // the current session usable without treating a context change as a
          // clear.
          restored.clear();
          storedMessageValues = <Object?>[];
          storedTranscriptReadable = false;
        }
      }
      final resolvedConversationId = resolveCoachActiveConversationId(
        storedActiveConversationId: storedConversationId,
        archive: historyArchive,
        currentMessages: storedMessageValues,
      );
      final selectionNeedsMigration =
          (storedConversationId == null || storedConversationId.isEmpty) &&
          resolvedConversationId != null;
      if (!storedTranscriptReadable && resolvedConversationId != null) {
        final selected = historyArchive.conversations
            .cast<Map<String, Object?>?>()
            .firstWhere(
              (entry) => entry?['id'] == resolvedConversationId,
              orElse: () => null,
            );
        final archivedMessages = selected?['messages'];
        if (archivedMessages is List) {
          for (final value in archivedMessages.whereType<Map>()) {
            try {
              restored.add(
                _presentationSafeMessage(
                  IntelligenceMessage.fromJson(
                    Map<String, Object?>.from(value),
                  ),
                ),
              );
            } on Object {
              // Preserve every other valid turn if one archived item is
              // damaged.
            }
          }
        }
      }
      final displayName = await _resolvedCoachDisplayName();
      if (!mounted) return;
      final now = ref.read(intelligenceConversationClockProvider)();
      final welcome = _sessionWelcome(displayName, at: now);
      _updateState(() {
        activeConversationId = resolvedConversationId;
        introVisible = true;
        conversationReady = true;
        sessionWelcomeMessage = IntelligenceMessage(
          id: 'welcome-session-${now.microsecondsSinceEpoch}',
          role: IntelligenceMessageRole.bil,
          kind: IntelligenceMessageKind.coach,
          text: welcome,
          createdAt: now,
          modality: IntelligenceMessageModality.system,
        );
        messages
          ..clear()
          ..addAll(
            restored.where((message) => !message.id.startsWith('welcome')),
          );
      });
      // Keep the fingerprint for diagnostics/migrations, but never rewrite the
      // transcript merely because the current health context changed.
      if (contextFingerprintChanged ||
          historyArchive.needsMigration ||
          selectionNeedsMigration) {
        try {
          await preferences.setMany(<String, String>{
            if (contextFingerprintChanged)
              'intelligenceConversationContextV1': contextRevision.fingerprint,
            if (historyArchive.needsMigration || selectionNeedsMigration)
              _conversationHistoryKey: encodeCoachConversationHistory(
                conversations: historyArchive.conversations,
                activeConversationId: resolvedConversationId,
              ),
            _activeConversationIdKey: ?resolvedConversationId,
          });
        } on Object {
          // Metadata migration is best-effort; the restored transcript is
          // already present in memory and remains user-owned content.
        }
      }
      // Keep the session welcome at the beginning of the chronological list.
      // New user turns and replies call _scrollToLatest themselves, so opening
      // a restored chat never jumps past the primary introduction.
    } on Object {
      // A local read failure must not leave Coach permanently disabled. Show a
      // fresh session welcome, but never merge a partial restore over a user
      // turn.
      if (mounted) {
        final now = ref.read(intelligenceConversationClockProvider)();
        _updateState(() {
          sessionWelcomeMessage ??= IntelligenceMessage(
            id: 'welcome-session-${now.microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: _sessionWelcome(null, at: now),
            createdAt: now,
            modality: IntelligenceMessageModality.system,
          );
          conversationReady = true;
        });
      }
    }
  }

  Future<({DateTime? changedAt, String fingerprint, bool hasContext})>
  _coachContextRevision({
    WeightRepository? weightRepository,
    DailyLogRepository? dailyLogRepository,
  }) async {
    // Resolve provider-owned dependencies before the first await. A queued
    // conversation save is allowed to finish after this page is disposed.
    final WeightRepository weightSource =
        weightRepository ?? conversationWeightRepository;
    final DailyLogRepository dailyLogSource =
        dailyLogRepository ?? conversationDailyLogRepository;
    DateTime? latest;
    var weightCount = 0;
    var dailyLogCount = 0;
    String? oldestWeightDay;
    String? latestWeightDay;
    try {
      final weights = await weightSource.getAll();
      weightCount = weights.length;
      for (final entry in weights) {
        if (latest == null || entry.updatedAt.isAfter(latest)) {
          latest = entry.updatedAt;
        }
        final day = entry.dayKey;
        if (day != null) {
          if (oldestWeightDay == null || day.compareTo(oldestWeightDay) < 0) {
            oldestWeightDay = day;
          }
          if (latestWeightDay == null || day.compareTo(latestWeightDay) > 0) {
            latestWeightDay = day;
          }
        }
      }
    } on Object {
      // Conversation restore must remain available if one local source fails.
    }
    try {
      final logs = await dailyLogSource.getAll();
      dailyLogCount = logs.length;
      for (final log in logs) {
        if (latest == null || log.updatedAt.isAfter(latest)) {
          latest = log.updatedAt;
        }
      }
    } on Object {
      // The available source still provides a safe lower-bound cutoff.
    }
    final fingerprint = <String>[
      'w:$weightCount',
      'wo:${oldestWeightDay ?? '-'}',
      'wl:${latestWeightDay ?? '-'}',
      'd:$dailyLogCount',
      'u:${latest?.toUtc().microsecondsSinceEpoch ?? 0}',
    ].join('|');
    return (
      changedAt: latest,
      fingerprint: fingerprint,
      hasContext: weightCount > 0 || dailyLogCount > 0,
    );
  }

  String _sessionWelcome(String? displayName, {required DateTime at}) {
    final hour = at.hour;
    final greeting = switch (coachGreetingKeyForHour(hour)) {
      'Good morning' => tr('Good morning', 'صباح الخير'),
      'Good afternoon' => tr('Good afternoon', 'مساء الخير'),
      _ => tr('Good evening', 'مساء الخير'),
    };
    final name = displayName?.trim();
    final memberName = name == null || name.isEmpty
        ? tr('BIL member', 'عضو BIL')
        : name;
    final next = tr(
      'I’m ready for your next useful decision.',
      'أنا جاهز لقرارك المفيد التالي.',
    );
    final separator = coachGreetingSeparator(arabic: arabic);
    return '$greeting$separator $memberName. $next';
  }

  Future<String?> _resolvedCoachDisplayName() async {
    final localName =
        (await ref.read(preferencesRepositoryProvider).get('displayName'))
            ?.trim();
    if (localName?.isNotEmpty == true) return localName;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final metadata = user?.userMetadata;
      final emailLocalPart = user?.email?.trim().split('@').first.toLowerCase();
      for (final key in const ['display_name', 'full_name', 'name']) {
        final value = metadata?[key]?.toString().trim();
        if (value?.isNotEmpty == true &&
            !value!.contains('@') &&
            value.toLowerCase() != emailLocalPart) {
          return value;
        }
      }
    } on Object {
      // A greeting never depends on cloud availability.
    }
    return null;
  }

  void _scrollToLatest({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !conversationScroll.hasClients) return;
      // The conversation is chronological. The maximum extent is the newest
      // turn, which also keeps a short new conversation anchored at the top
      // instead of leaving a large blank area above the first message.
      final target = conversationScroll.position.maxScrollExtent;
      if (jump) {
        conversationScroll.jumpTo(target);
      } else {
        conversationScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _saveConversation() async {
    // Capture every provider-owned dependency synchronously. `dispose` cannot
    // await, but the resulting repository operations remain valid after the
    // WidgetRef itself is no longer usable.
    final preferences = conversationPreferences;
    final weightRepository = conversationWeightRepository;
    final dailyLogRepository = conversationDailyLogRepository;
    final persistentMessages = messages
        .where((message) => !message.id.startsWith('welcome'))
        .toList(growable: false);
    final saveConversationId = activeConversationId;
    final saveEpoch = conversationPersistenceEpoch;
    final encodedMessages = jsonEncode(
      persistentMessages.map((item) => item.toJson()).toList(),
    );
    final previousSave = conversationPersistenceTail;

    Future<void> persistSnapshot() async {
      try {
        await previousSave;
      } on Object {
        // A prior best-effort failure must not block later snapshots.
      }
      if (!coachConversationSaveIsCurrent(
        saveEpoch: saveEpoch,
        currentEpoch: conversationPersistenceEpoch,
        saveConversationId: saveConversationId,
        activeConversationId: activeConversationId,
      )) {
        return;
      }
      try {
        // Persist the user-owned transcript before the diagnostic context
        // fingerprint. Large local histories must not widen the loss window
        // for the newest turn.
        await preferences.setMany({
          'intelligenceConversationV1': encodedMessages,
          'intelligenceConversationActiveIdV1': ?saveConversationId,
        });
        if (!coachConversationSaveIsCurrent(
          saveEpoch: saveEpoch,
          currentEpoch: conversationPersistenceEpoch,
          saveConversationId: saveConversationId,
          activeConversationId: activeConversationId,
        )) {
          return;
        }
        final contextRevision = await _coachContextRevision(
          weightRepository: weightRepository,
          dailyLogRepository: dailyLogRepository,
        );
        if (!coachConversationSaveIsCurrent(
          saveEpoch: saveEpoch,
          currentEpoch: conversationPersistenceEpoch,
          saveConversationId: saveConversationId,
          activeConversationId: activeConversationId,
        )) {
          return;
        }
        await preferences.set(
          'intelligenceConversationContextV1',
          contextRevision.fingerprint,
        );
      } on Object {
        // Conversation persistence is best-effort. A local storage failure
        // must not escape an unawaited save and terminate a valid reply.
      }
    }

    final save = persistSnapshot();
    conversationPersistenceTail = save;
    await save;
  }

  void _beginConversationForUserAction() {
    // The empty Coach surface and history inspection never create chats. The
    // first explicit user turn supplies the durable identity synchronously so
    // overlapping best-effort saves all target that same conversation.
    activeConversationId ??=
        'conversation-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _invalidatePendingConversationSaves() async {
    conversationPersistenceEpoch += 1;
    try {
      await conversationPersistenceTail;
    } on Object {
      // The next conversation can still replace a failed old snapshot.
    }
  }

  Future<void> _clearConversation() async {
    _cancelCurrentCoachRequest();
    await _invalidatePendingConversationSaves();
    try {
      final preferences = ref.read(preferencesRepositoryProvider);
      final historyArchive = decodeCoachConversationHistory(
        await preferences.get(_conversationHistoryKey),
      );
      await preferences.mutate(
        set: <String, String>{
          _conversationHistoryKey: encodeCoachConversationHistory(
            conversations: historyArchive.conversations,
            activeConversationId: null,
          ),
        },
        remove: const <String>{
          'intelligenceConversationV1',
          'intelligenceConversationContextV1',
          'intelligenceConversationActiveIdV1',
        },
      );
      activeConversationId = null;
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'The local conversation could not be cleared. Your data was unchanged.',
              'تعذر مسح المحادثة المحلية. لم تتغير بياناتك.',
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    final displayName = await _resolvedCoachDisplayName();
    if (!mounted) return;
    final now = ref.read(intelligenceConversationClockProvider)();
    final welcome = _sessionWelcome(displayName, at: now);
    _updateState(() {
      sessionWelcomeMessage = IntelligenceMessage(
        id: 'welcome-${now.microsecondsSinceEpoch}',
        role: IntelligenceMessageRole.bil,
        kind: IntelligenceMessageKind.coach,
        text: welcome,
        createdAt: now,
        modality: IntelligenceMessageModality.system,
      );
      messages.clear();
    });
    unawaited(_saveConversation());
  }
}
