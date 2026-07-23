import '../domain/subscription_snapshot.dart';

/// Persistence boundary for previously verified subscription facts.
abstract interface class SubscriptionRecordRepository {
  SubscriptionSnapshot? read();

  void write(SubscriptionSnapshot snapshot);

  void clear();
}
