enum CommunityQuestCadence {
  daily('daily'),
  weekly('weekly'),
  oneTime('one_time');

  const CommunityQuestCadence(this.wireValue);
  final String wireValue;

  static CommunityQuestCadence fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Community quest cadence',
        ),
      );
}

enum CommunityQuestClaimMode {
  manual('manual'),
  auto('auto');

  const CommunityQuestClaimMode(this.wireValue);
  final String wireValue;

  static CommunityQuestClaimMode fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Community quest claim mode',
        ),
      );
}

enum CommunityQuestState {
  go('go'),
  pending('pending'),
  readyToClaim('ready_to_claim'),
  claimed('claimed');

  const CommunityQuestState(this.wireValue);
  final String wireValue;

  static CommunityQuestState fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Community quest state',
        ),
      );
}

enum CommunityQuestClaimStatus {
  claimed('claimed'),
  notReady('not_ready'),
  blocked('blocked');

  const CommunityQuestClaimStatus(this.wireValue);
  final String wireValue;

  static CommunityQuestClaimStatus fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException(
          'Invalid Community quest claim status',
        ),
      );
}

int _rewardInt(Object? value, {required String field, bool nullable = false}) {
  if (nullable && value == null) return -1;
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value % 1 == 0) return value.toInt();
  throw FormatException('Invalid Community reward field: $field');
}

class CommunityGoldBalance {
  const CommunityGoldBalance({required this.balance, this.updatedAt});

  final int balance;
  final DateTime? updatedAt;

  factory CommunityGoldBalance.fromJson(Map<String, dynamic> json) {
    final balance = _rewardInt(json['balance'], field: 'balance');
    final rawUpdatedAt = json['updated_at'];
    final updatedAt = rawUpdatedAt == null
        ? null
        : DateTime.tryParse(rawUpdatedAt.toString());
    if (rawUpdatedAt != null && updatedAt == null) {
      throw const FormatException('Invalid BIL Gold balance timestamp');
    }
    return CommunityGoldBalance(balance: balance, updatedAt: updatedAt);
  }
}

class CommunityGoldLedgerEntry {
  const CommunityGoldLedgerEntry({
    required this.id,
    required this.delta,
    required this.balanceAfter,
    required this.sourceKind,
    required this.copyKey,
    required this.createdAt,
    this.referenceKind,
    this.referenceId,
    this.reversesEntryId,
  });

  final int id;
  final int delta;
  final int balanceAfter;
  final String sourceKind;
  final String copyKey;
  final String? referenceKind;
  final String? referenceId;
  final int? reversesEntryId;
  final DateTime createdAt;

  bool get earned => delta > 0;
  bool get used => delta < 0;

  factory CommunityGoldLedgerEntry.fromJson(Map<String, dynamic> json) {
    int signedInt(Object? value, String field) {
      if (value is int) return value;
      if (value is num && value % 1 == 0) return value.toInt();
      throw FormatException('Invalid BIL Gold ledger field: $field');
    }

    final id = signedInt(json['id'], 'id');
    final delta = signedInt(json['delta'], 'delta');
    final balanceAfter = _rewardInt(
      json['balance_after'],
      field: 'balance_after',
    );
    final sourceKind = json['source_kind'];
    final copyKey = json['copy_key'];
    final referenceKind = json['reference_kind'];
    final referenceId = json['reference_id'];
    final rawReversal = json['reverses_entry_id'];
    final reversesEntryId = rawReversal == null
        ? null
        : signedInt(rawReversal, 'reverses_entry_id');
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');

    if (id < 1 ||
        delta == 0 ||
        sourceKind is! String ||
        sourceKind.isEmpty ||
        copyKey is! String ||
        copyKey.isEmpty ||
        (referenceKind != null && referenceKind is! String) ||
        (referenceId != null && referenceId is! String) ||
        createdAt == null) {
      throw const FormatException('Invalid BIL Gold ledger entry');
    }

    return CommunityGoldLedgerEntry(
      id: id,
      delta: delta,
      balanceAfter: balanceAfter,
      sourceKind: sourceKind,
      copyKey: copyKey,
      referenceKind: referenceKind as String?,
      referenceId: referenceId as String?,
      reversesEntryId: reversesEntryId,
      createdAt: createdAt,
    );
  }
}

class CommunityQuest {
  const CommunityQuest({
    required this.questKey,
    required this.cadence,
    required this.titleCopyKey,
    required this.subtitleCopyKey,
    required this.actionKind,
    required this.targetCount,
    required this.claimMode,
    required this.goldReward,
    required this.xpReward,
    required this.periodKey,
    required this.progress,
    required this.state,
    this.completedAt,
    this.claimedAt,
  });

  static final RegExp questKeyPattern = RegExp(r'^[a-z][a-z0-9_]{2,39}$');

  final String questKey;
  final CommunityQuestCadence cadence;
  final String titleCopyKey;
  final String subtitleCopyKey;
  final String actionKind;
  final int targetCount;
  final CommunityQuestClaimMode claimMode;
  final int goldReward;
  final int xpReward;
  final String periodKey;
  final int progress;
  final CommunityQuestState state;
  final DateTime? completedAt;
  final DateTime? claimedAt;

  double get completionRatio =>
      targetCount <= 0 ? 0 : (progress / targetCount).clamp(0, 1).toDouble();

  factory CommunityQuest.fromJson(Map<String, dynamic> json) {
    final questKey = json['quest_key'];
    final titleCopyKey = json['title_copy_key'];
    final subtitleCopyKey = json['subtitle_copy_key'];
    final actionKind = json['action_kind'];
    final periodKey = json['period_key'];
    final targetCount = _rewardInt(
      json['target_count'],
      field: 'target_count',
    );
    final progress = _rewardInt(json['progress'], field: 'progress');
    final goldReward = _rewardInt(json['gold_reward'], field: 'gold_reward');
    final xpReward = _rewardInt(json['xp_reward'], field: 'xp_reward');
    final completedAt = json['completed_at'] == null
        ? null
        : DateTime.tryParse(json['completed_at'].toString());
    final claimedAt = json['claimed_at'] == null
        ? null
        : DateTime.tryParse(json['claimed_at'].toString());

    if (questKey is! String ||
        !questKeyPattern.hasMatch(questKey) ||
        titleCopyKey is! String ||
        titleCopyKey.isEmpty ||
        subtitleCopyKey is! String ||
        subtitleCopyKey.isEmpty ||
        actionKind is! String ||
        actionKind.isEmpty ||
        periodKey is! String ||
        periodKey.length < 4 ||
        periodKey.length > 16 ||
        targetCount < 1 ||
        progress > targetCount ||
        (json['completed_at'] != null && completedAt == null) ||
        (json['claimed_at'] != null && claimedAt == null)) {
      throw const FormatException('Invalid Community quest');
    }

    return CommunityQuest(
      questKey: questKey,
      cadence: CommunityQuestCadence.fromWire(json['cadence']),
      titleCopyKey: titleCopyKey,
      subtitleCopyKey: subtitleCopyKey,
      actionKind: actionKind,
      targetCount: targetCount,
      claimMode: CommunityQuestClaimMode.fromWire(json['claim_mode']),
      goldReward: goldReward,
      xpReward: xpReward,
      periodKey: periodKey,
      progress: progress,
      state: CommunityQuestState.fromWire(json['state']),
      completedAt: completedAt,
      claimedAt: claimedAt,
    );
  }
}

class CommunityQuestClaimResult {
  const CommunityQuestClaimResult({
    required this.status,
    this.duplicate = false,
    this.gold = 0,
    this.xp = 0,
    this.reason,
  });

  final CommunityQuestClaimStatus status;
  final bool duplicate;
  final int gold;
  final int xp;
  final String? reason;

  factory CommunityQuestClaimResult.fromJson(Map<String, dynamic> json) {
    final duplicate = json['duplicate'];
    final reason = json['reason'];
    if (duplicate != null && duplicate is! bool) {
      throw const FormatException('Invalid Community quest duplicate flag');
    }
    if (reason != null && reason is! String) {
      throw const FormatException('Invalid Community quest claim reason');
    }
    return CommunityQuestClaimResult(
      status: CommunityQuestClaimStatus.fromWire(json['status']),
      duplicate: duplicate as bool? ?? false,
      gold: json['gold'] == null
          ? 0
          : _rewardInt(json['gold'], field: 'gold'),
      xp: json['xp'] == null
          ? 0
          : _rewardInt(json['xp'], field: 'xp'),
      reason: reason as String?,
    );
  }
}
