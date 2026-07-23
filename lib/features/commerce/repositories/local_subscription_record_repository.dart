import '../domain/commerce_plan.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_provider.dart';
import '../domain/subscription_record.dart';
import '../domain/subscription_snapshot.dart';
import 'subscription_record_repository.dart';

/// Minimal string storage boundary supplied by a platform persistence adapter.
abstract interface class CommerceKeyValueStore {
  String? read(String key);

  void write(String key, String value);

  void remove(String key);
}

/// Deterministic serialization repository for verified local subscription data.
final class LocalSubscriptionRecordRepository
    implements SubscriptionRecordRepository {
  const LocalSubscriptionRecordRepository(this._store);

  static const storageKey = 'bil.commerce.subscription_snapshot.v1';

  final CommerceKeyValueStore _store;

  @override
  SubscriptionSnapshot? read() {
    final value = _store.read(storageKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return _decode(value);
    } on FormatException {
      clear();
      return null;
    } on ArgumentError {
      clear();
      return null;
    }
  }

  @override
  void write(SubscriptionSnapshot snapshot) {
    _store.write(storageKey, _encode(snapshot));
  }

  @override
  void clear() {
    _store.remove(storageKey);
  }

  String _encode(SubscriptionSnapshot snapshot) {
    final record = snapshot.record;
    return <String>[
      '1',
      record.plan.id,
      record.lifecycle.name,
      record.provider?.name ?? '',
      record.authorityVerified ? '1' : '0',
      _date(record.startedAt),
      _date(record.currentPeriodEndsAt),
      _date(record.trialEndsAt),
      _date(record.gracePeriodEndsAt),
      _date(snapshot.verifiedAt),
      _date(snapshot.persistedAt),
    ].join('|');
  }

  SubscriptionSnapshot _decode(String value) {
    final parts = value.split('|');
    if (parts.length != 11 || parts.first != '1') {
      throw const FormatException('Unsupported subscription snapshot format.');
    }

    final plan = CommercePlan.values.singleWhere(
      (candidate) => candidate.id == parts[1],
      orElse: () => throw const FormatException('Unknown commerce plan.'),
    );
    final lifecycle = SubscriptionLifecycle.values.singleWhere(
      (candidate) => candidate.name == parts[2],
      orElse: () => throw const FormatException('Unknown lifecycle.'),
    );
    final provider = parts[3].isEmpty
        ? null
        : SubscriptionProvider.values.singleWhere(
            (candidate) => candidate.name == parts[3],
            orElse: () =>
                throw const FormatException('Unknown subscription provider.'),
          );
    final verified = switch (parts[4]) {
      '1' => true,
      '0' => false,
      _ => throw const FormatException('Invalid authority flag.'),
    };

    return SubscriptionSnapshot(
      record: SubscriptionRecord(
        plan: plan,
        lifecycle: lifecycle,
        authorityVerified: verified,
        provider: provider,
        startedAt: _parseDate(parts[5]),
        currentPeriodEndsAt: _parseDate(parts[6]),
        trialEndsAt: _parseDate(parts[7]),
        gracePeriodEndsAt: _parseDate(parts[8]),
      ),
      verifiedAt: _requiredDate(parts[9]),
      persistedAt: _requiredDate(parts[10]),
    );
  }

  String _date(DateTime? value) => value?.toUtc().toIso8601String() ?? '';

  DateTime? _parseDate(String value) {
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc() ??
        (throw const FormatException('Invalid date value.'));
  }

  DateTime _requiredDate(String value) =>
      _parseDate(value) ?? (throw const FormatException('Missing date value.'));
}
