import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/premium_design_tokens.dart';
import '../../shared/widgets/premium_surface.dart';
import 'connected_health_model.dart';
import 'connected_health_copy.dart';
import 'device_compatibility.dart';
import 'providers/connected_health_provider.dart';
import 'providers/medical_device_provider.dart';
import 'widgets/food_name_health_sync_card.dart';

@visibleForTesting
bool connectedHealthCanRequestPermissions(ConnectedHealthStatus status) =>
    status == ConnectedHealthStatus.permissionRequired ||
    status == ConnectedHealthStatus.permissionDenied;

class ConnectedHealthPage extends ConsumerStatefulWidget {
  const ConnectedHealthPage({super.key});

  @override
  ConsumerState<ConnectedHealthPage> createState() =>
      _ConnectedHealthPageState();
}

class _ConnectedHealthPageState extends ConsumerState<ConnectedHealthPage> {
  bool _connectedOnly = false;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => connectedHealthText(context, en, ar);
    final state = ref.watch(connectedHealthProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(tr('Apps & Devices', 'التطبيقات والأجهزة')),
        ),
        actions: [
          IconButton(
            tooltip: tr('Connection capabilities', 'قدرات الاتصال'),
            onPressed: () => context.push('/connected-health/capabilities'),
            icon: const Icon(Icons.fact_check_outlined),
          ),
          IconButton(
            tooltip: tr('Search connections', 'بحث في الاتصالات'),
            onPressed: () => _showConnectionSearch(context),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Row(
            children: [
              Expanded(
                child: _ConnectionTab(
                  label: tr('All', 'الكل'),
                  selected: !_connectedOnly,
                  onTap: () => setState(() => _connectedOnly = false),
                ),
              ),
              Expanded(
                child: _ConnectionTab(
                  label: tr('Connected', 'المتصلة'),
                  selected: _connectedOnly,
                  onTap: () => setState(() => _connectedOnly = true),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _connectedOnly
          ? _ConnectedSourcesView(snapshot: state)
          : SafeArea(
              child: Semantics(
                container: true,
                label: tr('Health Hub', 'المركز الصحي'),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                  children: [
                    state.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => PremiumSurface(
                        dashboardGlass: true,
                        child: Text(
                          tr(
                            'Health Hub status could not be read.',
                            'تعذر قراءة حالة المركز الصحي.',
                          ),
                        ),
                      ),
                      data: (snapshot) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PremiumSurface(
                            dashboardGlass: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  snapshot.platformSource ??
                                      tr(
                                        'Unsupported platform',
                                        'منصة غير مدعومة',
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(
                                  height: PremiumDesignTokens.spaceSm,
                                ),
                                Semantics(
                                  label: tr(
                                    'Connection status',
                                    'حالة الاتصال',
                                  ),
                                  value: _statusText(context, snapshot.status),
                                  child: Text(
                                    _statusText(context, snapshot.status),
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                  ),
                                ),
                                if (snapshot.availableSources.isNotEmpty) ...[
                                  const SizedBox(
                                    height: PremiumDesignTokens.spaceSm,
                                  ),
                                  Text(
                                    '${tr('Available sources', 'المصادر المتاحة')}: ${snapshot.availableSources.join(' • ')}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                          height: 1.35,
                                        ),
                                  ),
                                ],
                                const SizedBox(
                                  height: PremiumDesignTokens.spaceMd,
                                ),
                                Wrap(
                                  spacing: PremiumDesignTokens.spaceSm,
                                  runSpacing: PremiumDesignTokens.spaceSm,
                                  children: [
                                    if (connectedHealthCanRequestPermissions(
                                      snapshot.status,
                                    ))
                                      FilledButton.icon(
                                        onPressed: () => ref
                                            .read(
                                              connectedHealthProvider.notifier,
                                            )
                                            .requestPermissions(),
                                        icon: const Icon(
                                          Icons.verified_user_outlined,
                                        ),
                                        label: Text(
                                          tr(
                                            'Grant health access',
                                            'منح إذن الصحة',
                                          ),
                                        ),
                                      ),
                                    if (snapshot.status ==
                                            ConnectedHealthStatus
                                                .updateRequired ||
                                        snapshot.status ==
                                            ConnectedHealthStatus
                                                .permissionDenied ||
                                        snapshot.failureCode ==
                                            'revoke_in_system_settings_required')
                                      OutlinedButton.icon(
                                        onPressed: () => ref
                                            .read(
                                              connectedHealthProvider.notifier,
                                            )
                                            .openSystemSettings(),
                                        icon: const Icon(
                                          Icons.settings_outlined,
                                        ),
                                        label: Text(
                                          tr(
                                            'Open system settings',
                                            'فتح إعدادات النظام',
                                          ),
                                        ),
                                      ),
                                    if (snapshot.deviceVerified)
                                      OutlinedButton.icon(
                                        onPressed: () => ref
                                            .read(
                                              connectedHealthProvider.notifier,
                                            )
                                            .requestWeightWritePermission(),
                                        icon: const Icon(
                                          Icons.monitor_weight_outlined,
                                        ),
                                        label: Text(
                                          tr(
                                            defaultTargetPlatform ==
                                                    TargetPlatform.iOS
                                                ? 'Allow weight export'
                                                : 'Allow weight and nutrition export',
                                            defaultTargetPlatform ==
                                                    TargetPlatform.iOS
                                                ? 'السماح بتصدير الوزن'
                                                : 'السماح بتصدير الوزن والتغذية',
                                          ),
                                        ),
                                      ),
                                    if (snapshot.deviceVerified)
                                      TextButton.icon(
                                        onPressed: () => ref
                                            .read(
                                              connectedHealthProvider.notifier,
                                            )
                                            .revokePermissions(),
                                        icon: const Icon(
                                          Icons.link_off_rounded,
                                        ),
                                        label: Text(
                                          tr(
                                            'Disconnect health source',
                                            'فصل مصدر الصحة',
                                          ),
                                        ),
                                      ),
                                    if (snapshot.status ==
                                            ConnectedHealthStatus.ready ||
                                        snapshot.status ==
                                            ConnectedHealthStatus
                                                .synchronized ||
                                        snapshot.status ==
                                            ConnectedHealthStatus.degraded)
                                      FilledButton.icon(
                                        onPressed: () => ref
                                            .read(
                                              connectedHealthProvider.notifier,
                                            )
                                            .synchronize(),
                                        icon: const Icon(Icons.sync_rounded),
                                        label: Text(
                                          tr('Sync now', 'مزامنة الآن'),
                                        ),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: () => ref
                                          .read(
                                            connectedHealthProvider.notifier,
                                          )
                                          .refresh(),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: Text(
                                        tr('Refresh status', 'تحديث الحالة'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: PremiumDesignTokens.spaceMd),
                          const _MedicalDeviceSection(),
                          const SizedBox(height: PremiumDesignTokens.spaceMd),
                          const FoodNameHealthSyncCard(),
                          const SizedBox(height: PremiumDesignTokens.spaceMd),
                          _CompatibilitySection(
                            languageCode: Localizations.localeOf(
                              context,
                            ).languageCode,
                          ),
                          const SizedBox(height: PremiumDesignTokens.spaceMd),
                          PremiumSurface(
                            dashboardGlass: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  tr(
                                    'Privacy and data flow',
                                    'الخصوصية وتدفق البيانات',
                                  ),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(
                                  height: PremiumDesignTokens.spaceSm,
                                ),
                                Text(
                                  tr(
                                    'BIL reads only the health categories you authorize. Synchronization is local-first, preserves source provenance, and does not enable cloud upload, analytics, or commerce.',
                                    'يقرأ BIL فقط فئات الصحة التي تسمح بها. المزامنة محلية أولًا وتحافظ على مصدر كل قيمة، ولا تفعّل الرفع السحابي أو التحليلات أو التجارة.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: PremiumDesignTokens.spaceMd),
                          PremiumSurface(
                            dashboardGlass: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  tr(
                                    'Recent synchronized signals',
                                    'أحدث الإشارات المتزامنة',
                                  ),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(
                                  height: PremiumDesignTokens.spaceSm,
                                ),
                                if (snapshot.signals.isEmpty)
                                  Text(
                                    tr(
                                      'No synchronized signal is available yet.',
                                      'لا توجد إشارة متزامنة متاحة بعد.',
                                    ),
                                  )
                                else
                                  for (final signal in snapshot.signals)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.monitor_heart_outlined,
                                      ),
                                      title: Text(signal.key),
                                      subtitle: Text(signal.source),
                                      trailing: Text(
                                        '${signal.value.toStringAsFixed(signal.value == signal.value.roundToDouble() ? 0 : 1)} ${signal.unit}',
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showConnectionSearch(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                connectedHealthText(
                  context,
                  'Available connections',
                  'الاتصالات المتاحة',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: Text(
                  connectedHealthText(
                    context,
                    'Health Connect / Apple Health',
                    'Health Connect / Apple Health',
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bluetooth_rounded),
                title: Text(
                  connectedHealthText(
                    context,
                    'Bluetooth medical devices',
                    'أجهزة طبية عبر البلوتوث',
                  ),
                ),
              ),
              Text(
                connectedHealthText(
                  context,
                  'Only integrations implemented and verified by BIL are listed.',
                  'تظهر فقط الاتصالات المنفذة والمتحقق منها داخل BIL.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(BuildContext context, ConnectedHealthStatus status) {
    String tr(String en, String ar) => connectedHealthText(context, en, ar);
    return switch (status) {
      ConnectedHealthStatus.unavailable => tr(
        'Unavailable on this device.',
        'غير متاح على هذا الجهاز.',
      ),
      ConnectedHealthStatus.updateRequired => tr(
        'The health provider must be installed or updated.',
        'يلزم تثبيت مصدر الصحة أو تحديثه.',
      ),
      ConnectedHealthStatus.permissionRequired => tr(
        'BIL needs explicit permission before reading health data.',
        'يحتاج BIL إلى إذن صريح قبل قراءة البيانات الصحية.',
      ),
      ConnectedHealthStatus.permissionDenied => tr(
        'Permission was denied. You can grant it later in system settings.',
        'تم رفض الإذن. يمكنك منحه لاحقًا من إعدادات النظام.',
      ),
      ConnectedHealthStatus.authorizationRequested => tr(
        'The Health access request completed. Apple does not reveal read permission status; only records it provides will appear.',
        'اكتمل طلب الوصول إلى الصحة. لا تكشف Apple حالة إذن القراءة؛ لن تظهر إلا السجلات التي يوفرها النظام.',
      ),
      ConnectedHealthStatus.ready => tr(
        'Ready to synchronize.',
        'جاهز للمزامنة.',
      ),
      ConnectedHealthStatus.syncing => tr(
        'Synchronizing now.',
        'تتم المزامنة الآن.',
      ),
      ConnectedHealthStatus.synchronized => tr(
        'Connected and synchronized.',
        'متصل ومتزامن.',
      ),
      ConnectedHealthStatus.degraded => tr(
        'The native source could not be reached. Local data was not affected.',
        'تعذر الوصول إلى المصدر الأصلي. البيانات المحلية لم تتأثر.',
      ),
    };
  }
}

class _ConnectionTab extends StatelessWidget {
  const _ConnectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _ConnectedSourcesView extends StatelessWidget {
  const _ConnectedSourcesView({required this.snapshot});

  final AsyncValue<ConnectedHealthSnapshot> snapshot;

  @override
  Widget build(BuildContext context) => snapshot.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, _) => Center(
      child: Text(
        connectedHealthText(
          context,
          'Connection status is unavailable.',
          'حالة الاتصال غير متاحة.',
        ),
      ),
    ),
    data: (value) {
      final connected =
          value.status == ConnectedHealthStatus.ready ||
          value.status == ConnectedHealthStatus.syncing ||
          value.status == ConnectedHealthStatus.synchronized ||
          value.status == ConnectedHealthStatus.degraded;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            connectedHealthText(
              context,
              'Connected (${connected ? 1 : 0})',
              'المتصلة (${connected ? 1 : 0})',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          if (connected)
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.health_and_safety_outlined),
              ),
              title: Text(value.platformSource ?? 'Health Connect'),
              subtitle: Text(
                connectedHealthText(
                  context,
                  'Connected and ready to synchronize',
                  'متصل وجاهز للمزامنة',
                ),
              ),
            )
          else
            PremiumSurface(
              dashboardGlass: true,
              child: Text(
                connectedHealthText(
                  context,
                  'No health source is connected yet.',
                  'لا يوجد مصدر صحي متصل بعد.',
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _CompatibilitySection extends StatelessWidget {
  const _CompatibilitySection({required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => connectedHealthText(context, en, ar);
    return PremiumSurface(
      key: const Key('health-device-compatibility'),
      dashboardGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Supported connections', 'الاتصالات المدعومة'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          for (final entry in BilDeviceCompatibilityMatrix.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_outlined),
              title: Text(entry.protocol),
              subtitle: Text(
                '${entry.platforms.join(' / ')} • ${entry.minimumVersion}\n'
                '${tr('Implementation ready; physical-device verification required', 'جاهز برمجيًا؛ يلزم تحقق بجهاز فعلي')}',
              ),
              isThreeLine: true,
            ),
        ],
      ),
    );
  }
}

class _MedicalDeviceSection extends ConsumerWidget {
  const _MedicalDeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String tr(String en, String ar) => connectedHealthText(context, en, ar);
    final snapshot = ref.watch(medicalDeviceProvider);
    final controller = ref.read(medicalDeviceProvider.notifier);
    final busy =
        snapshot.status == MedicalDeviceConnectionStatus.scanning ||
        snapshot.status == MedicalDeviceConnectionStatus.requestingPermission ||
        snapshot.status == MedicalDeviceConnectionStatus.connecting;

    return PremiumSurface(
      key: const Key('medical-bluetooth-section'),
      dashboardGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Medical devices', 'الأجهزة الطبية'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          LayoutBuilder(
            builder: (context, constraints) {
              final image = Image.asset(
                'assets/images/connected_health/bil_medical_hub.png',
                key: const Key('bil-medical-device-image'),
                fit: BoxFit.contain,
                semanticLabel: tr(
                  'Bluetooth medical monitor and smart watch',
                  'جهاز مراقبة طبي وساعة ذكية عبر البلوتوث',
                ),
              );
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tr(
                      'Connect verified Bluetooth measurements',
                      'اربط قياسات البلوتوث الموثوقة',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceXs),
                  Text(
                    tr(
                      'Blood pressure, glucose, weight, body composition, oxygen, heart rate and temperature.',
                      'ضغط الدم، السكر، الوزن، تركيب الجسم، الأكسجين، النبض والحرارة.',
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  _MedicalStatusText(
                    snapshot: snapshot,
                    languageCode: Localizations.localeOf(context).languageCode,
                  ),
                ],
              );
              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    SizedBox(height: 190, child: image),
                    copy,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: SizedBox(height: 210, child: image)),
                  const SizedBox(width: PremiumDesignTokens.spaceMd),
                  Expanded(child: copy),
                ],
              );
            },
          ),
          if (snapshot.devices.isNotEmpty) ...[
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            for (final device in snapshot.devices)
              ListTile(
                key: Key('medical-device-${device.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bluetooth_connected_rounded),
                title: Text(device.name),
                subtitle: Text(
                  device.profiles.map((profile) => profile.name).join(' • '),
                ),
                trailing: snapshot.connectedDeviceId == device.id
                    ? Wrap(
                        children: [
                          IconButton(
                            tooltip: tr('Disconnect', 'قطع الاتصال'),
                            onPressed: controller.disconnect,
                            icon: const Icon(Icons.link_off_rounded),
                          ),
                          IconButton(
                            tooltip: tr('Remove device', 'حذف الجهاز'),
                            onPressed: () => controller.removeDevice(device.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      )
                    : FilledButton(
                        onPressed: busy
                            ? null
                            : () => controller.connect(device),
                        child: Text(tr('Connect', 'اتصال')),
                      ),
              ),
          ],
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          FilledButton.icon(
            key: const Key('scan-medical-devices-button'),
            onPressed: !snapshot.supported || busy ? null : controller.scan,
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth_searching_rounded),
            label: Text(
              !snapshot.supported
                  ? tr('Requires Android or iPhone', 'يتطلب Android أو iPhone')
                  : tr('Scan for medical devices', 'البحث عن أجهزة طبية'),
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            tr(
              'BIL imports measurements only after your permission. It supports standard BLE health profiles and is not a diagnostic medical device.',
              'لا يستورد BIL القياسات إلا بعد موافقتك. يدعم ملفات BLE الصحية القياسية ولا يُعد جهازًا طبيًا للتشخيص.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MedicalStatusText extends StatelessWidget {
  const _MedicalStatusText({
    required this.snapshot,
    required this.languageCode,
  });

  final MedicalDeviceSnapshot snapshot;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => connectedHealthText(context, en, ar);
    final text = switch (snapshot.status) {
      MedicalDeviceConnectionStatus.unavailable => tr(
        'Bluetooth medical linking is unavailable here.',
        'الربط الطبي غير متاح على هذه المنصة.',
      ),
      MedicalDeviceConnectionStatus.idle =>
        snapshot.devices.isEmpty
            ? tr('Ready to search nearby.', 'جاهز للبحث عن الأجهزة القريبة.')
            : tr(
                '${snapshot.devices.length} device(s) found.',
                'تم العثور على ${snapshot.devices.length} جهاز.',
              ),
      MedicalDeviceConnectionStatus.requestingPermission => tr(
        'Waiting for Bluetooth permission…',
        'بانتظار إذن البلوتوث…',
      ),
      MedicalDeviceConnectionStatus.scanning => tr(
        'Searching nearby…',
        'جارٍ البحث عن الأجهزة القريبة…',
      ),
      MedicalDeviceConnectionStatus.connecting => tr(
        'Connecting securely…',
        'جارٍ الاتصال الآمن…',
      ),
      MedicalDeviceConnectionStatus.connected => tr(
        snapshot.batteryPercent == null
            ? 'Medical device connected. Battery was not reported. Last sync: ${_time(context)}.'
            : 'Medical device connected. Battery ${snapshot.batteryPercent}%. Last sync: ${_time(context)}.',
        snapshot.batteryPercent == null
            ? 'الجهاز الطبي متصل. لم يرسل الجهاز حالة البطارية. آخر مزامنة: ${_time(context)}.'
            : 'الجهاز الطبي متصل. البطارية ${snapshot.batteryPercent}٪. آخر مزامنة: ${_time(context)}.',
      ),
      MedicalDeviceConnectionStatus.failed => tr(
        'Connection needs attention. Try again.',
        'تعذر الاتصال. حاول مرة أخرى.',
      ),
    };
    return Text(
      text,
      key: const Key('medical-device-status'),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: snapshot.status == MedicalDeviceConnectionStatus.failed
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _time(BuildContext context) => snapshot.lastMeasurementAt == null
      ? connectedHealthTextForLanguage(
          languageCode,
          'no measurement',
          'لا يوجد قياس',
        )
      : TimeOfDay.fromDateTime(
          snapshot.lastMeasurementAt!.toLocal(),
        ).format(context);
}
