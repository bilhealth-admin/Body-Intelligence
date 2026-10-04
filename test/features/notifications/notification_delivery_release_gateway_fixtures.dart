part of 'notification_delivery_release_contract_test.dart';

late SupabaseClient _hostCloudClient;

// MOCKED_BACKEND_CONTRACTS_ONLY: explicit controlled cloud/provider gateway.
// The real settings page and durable local repository remain unchanged.
// This is not Production, APNs, FCM, or OS-delivery acceptance evidence.
class _HostCommunityPushGateway extends CommunityPushService {
  _HostCommunityPushGateway({this.enabled = false, this.providerReady = true})
    : super(_hostCloudClient);

  bool enabled;
  bool providerReady;
  bool throwLoad = false;
  bool throwSet = false;
  bool throwSync = false;
  bool initialized = true;
  bool synchronized = true;
  int revision = 1;
  Set<NotificationCategory> desired = {
    ...NotificationDeliveryPreferences.supportedCategories,
  };
  int setCalls = 0;
  int syncCalls = 0;
  int loadCalls = 0;
  Future<void>? pendingSet;
  Future<CommunityPushPreferences>? pendingLoad;
  final categoryParameters = <Map<String, bool>>[];

  @override
  Future<CommunityPushPreferences> loadPreferences() async {
    loadCalls++;
    if (throwLoad) throw StateError('Host fixture readback unavailable');
    if (pendingLoad != null) return pendingLoad!;
    return CommunityPushPreferences(
      enabled: enabled,
      timeZone: 'UTC',
      providerReady: providerReady,
      deliveryCategories: _receipt(),
    );
  }

  @override
  Future<void> setEnabled(
    bool value, {
    required NotificationDeliveryPreferences deliveryPreferences,
  }) async {
    setCalls++;
    categoryParameters.add(deliveryPreferences.pushCategoryParameters);
    if (pendingSet != null) await pendingSet;
    if (throwSet) throw StateError('Host fixture master save unavailable');
    enabled = value;
  }

  @override
  Future<CommunityPushDeliveryCategories> syncDeliveryPreferences(
    NotificationDeliveryPreferences value, {
    required CommunityPushDeliveryCategories expectedState,
  }) async {
    syncCalls++;
    categoryParameters.add(value.pushCategoryParameters);
    if (throwSync) throw StateError('Host fixture category sync unavailable');
    if (expectedState.revision != revision) {
      throw const PostgrestException(
        message: 'push_delivery_preferences_conflict',
        code: '40001',
      );
    }
    if (desired.length != value.enabledCategories.length ||
        !desired.containsAll(value.enabledCategories)) {
      desired = {...value.enabledCategories};
      revision++;
    }
    synchronized = true;
    return _receipt();
  }

  CommunityPushDeliveryCategories _receipt() => CommunityPushDeliveryCategories(
    ownerId: '11111111-1111-4111-8111-111111111111',
    initialized: initialized,
    revision: initialized ? revision : 0,
    desired: initialized ? Set.unmodifiable(desired) : null,
    effective: enabled ? Set.unmodifiable(desired) : const {},
    synchronized: synchronized,
  );
}
