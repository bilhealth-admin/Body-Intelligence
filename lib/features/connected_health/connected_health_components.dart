part of 'connected_health_page.dart';

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
  const _ConnectedSourcesView({
    required this.snapshot,
    required this.onConnect,
  });

  final AsyncValue<ConnectedHealthSnapshot> snapshot;
  final VoidCallback onConnect;

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
      final active =
          value.status == ConnectedHealthStatus.ready ||
          value.status == ConnectedHealthStatus.syncing ||
          value.status == ConnectedHealthStatus.synchronized;
      final paused =
          value.status == ConnectedHealthStatus.degraded &&
          (value.deviceVerified ||
              value.lastSyncAt != null ||
              value.signals.isNotEmpty);
      final listed = active || paused;
      final statusColor = active
          ? const Color(0xFF178A4B)
          : paused
          ? const Color(0xFFE38B17)
          : Theme.of(context).colorScheme.outline;
      final sourceName = value.platformSource?.trim().isNotEmpty == true
          ? value.platformSource!
          : !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? 'Apple Health'
          : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'Health Connect'
          : connectedHealthText(context, 'Health source', 'مصدر صحي');
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            connectedHealthText(
              context,
              'Connected ({count})',
              'المتصلة ({count})',
            ).replaceFirst('{count}', listed ? '1' : '0'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          if (listed)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: .12),
                child: Icon(
                  paused
                      ? Icons.pause_circle_outline_rounded
                      : Icons.health_and_safety_outlined,
                  color: statusColor,
                ),
              ),
              title: Text(sourceName),
              subtitle: Text(connectedHealthStatusText(context, value.status)),
            )
          else
            PremiumSurface(
              dashboardGlass: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    connectedHealthText(
                      context,
                      'No health source is connected yet.',
                      'لا يوجد مصدر صحي متصل بعد.',
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  FilledButton.icon(
                    key: const Key('connected-sources-add-cta'),
                    onPressed: onConnect,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      connectedHealthText(
                        context,
                        'Manage sources',
                        'إدارة المصادر',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _CompatibilitySection extends StatelessWidget {
  const _CompatibilitySection();

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry
                  in BilDeviceCompatibilityMatrix.forTargetPlatform(
                    defaultTargetPlatform,
                    isWeb: kIsWeb,
                  ))
                Chip(
                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_consumerName(context, entry.id)),
                ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          TextButton.icon(
            key: const Key('health-device-capabilities-link'),
            onPressed: () => context.push('/connected-health/capabilities'),
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(
              tr('What each connection reads', 'ما الذي يقرأه كل اتصال'),
            ),
          ),
        ],
      ),
    );
  }

  String _consumerName(BuildContext context, String id) => switch (id) {
    'android-health-connect' => 'Health Connect',
    'apple-healthkit' => 'Apple Health',
    'bluetooth-sig-health-profiles' => connectedHealthText(
      context,
      'Bluetooth fitness devices',
      'أجهزة اللياقة عبر البلوتوث',
    ),
    _ => connectedHealthText(context, 'Health source', 'مصدر صحي'),
  };
}

class _FitnessDeviceSection extends ConsumerWidget {
  const _FitnessDeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String tr(String en, String ar) => connectedHealthText(context, en, ar);
    final snapshot = ref.watch(fitnessDeviceProvider);
    final controller = ref.read(fitnessDeviceProvider.notifier);
    final busy =
        snapshot.status == FitnessDeviceConnectionStatus.scanning ||
        snapshot.status == FitnessDeviceConnectionStatus.requestingPermission ||
        snapshot.status == FitnessDeviceConnectionStatus.connecting;

    return PremiumSurface(
      key: const Key('fitness-bluetooth-section'),
      dashboardGlass: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Bluetooth fitness devices', 'أجهزة اللياقة عبر البلوتوث'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Text(
            tr(
              'Supported: scales, body-composition monitors, and heart-rate monitors.',
              'المدعوم: موازين الوزن وأجهزة تركيب الجسم وأجهزة نبض القلب.',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
            const SizedBox(height: PremiumDesignTokens.spaceXs),
            Text(
              tr(
                'Apple Watch data comes through Apple Health. Do not pair Apple Watch here.',
                'تصل بيانات Apple Watch عبر Apple Health؛ لا تحاول إقران الساعة من هنا.',
              ),
            ),
          ],
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          _FitnessDeviceStatusText(
            snapshot: snapshot,
            languageCode: Localizations.localeOf(context).languageCode,
          ),
          if (snapshot.devices.isNotEmpty) ...[
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            for (final device in snapshot.devices)
              ListTile(
                key: Key('fitness-device-${device.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const BilSemanticIconBadge(
                  kind: BilSemanticIconKind.devices,
                  iconOverride: Icons.bluetooth_connected_rounded,
                  appleIconOverride: Icons.bluetooth_connected_rounded,
                ),
                title: Text(device.name),
                subtitle: Text(
                  device.profiles
                      .map((profile) => _fitnessProfileLabel(context, profile))
                      .join(' • '),
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
            key: const Key('scan-fitness-devices-button'),
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
                  : tr('Scan for fitness devices', 'البحث عن أجهزة لياقة'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FitnessDeviceStatusText extends StatelessWidget {
  const _FitnessDeviceStatusText({
    required this.snapshot,
    required this.languageCode,
  });

  final FitnessDeviceSnapshot snapshot;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    String tr(String en, String ar) => connectedHealthText(context, en, ar);
    final text = switch (snapshot.status) {
      FitnessDeviceConnectionStatus.unavailable => tr(
        'Bluetooth fitness-device linking is unavailable here.',
        'ربط أجهزة اللياقة عبر البلوتوث غير متاح على هذه المنصة.',
      ),
      FitnessDeviceConnectionStatus.idle =>
        snapshot.devices.isEmpty
            ? tr('Ready to search nearby.', 'جاهز للبحث عن الأجهزة القريبة.')
            : ConnectedHealthRuntimeCopy.format(
                context,
                ConnectedHealthRuntimeCopy.devicesFound,
                count: MaterialLocalizations.of(
                  context,
                ).formatDecimal(snapshot.devices.length),
              ),
      FitnessDeviceConnectionStatus.requestingPermission => tr(
        'Waiting for Bluetooth permission…',
        'بانتظار إذن البلوتوث…',
      ),
      FitnessDeviceConnectionStatus.scanning => tr(
        'Searching nearby…',
        'جارٍ البحث عن الأجهزة القريبة…',
      ),
      FitnessDeviceConnectionStatus.connecting => tr(
        'Connecting securely…',
        'جارٍ الاتصال الآمن…',
      ),
      FitnessDeviceConnectionStatus.connected =>
        snapshot.failureCode != null
            ? ConnectedHealthRuntimeCopy.format(
                context,
                ConnectedHealthRuntimeCopy.measurementSyncFailed,
                code: snapshot.failureCode,
              )
            : snapshot.batteryPercent == null
            ? ConnectedHealthRuntimeCopy.format(
                context,
                ConnectedHealthRuntimeCopy.connectedWithoutBattery,
                time: _time(context),
              )
            : ConnectedHealthRuntimeCopy.format(
                context,
                ConnectedHealthRuntimeCopy.connectedWithBattery,
                percent: MaterialLocalizations.of(
                  context,
                ).formatDecimal(snapshot.batteryPercent!),
                time: _time(context),
              ),
      FitnessDeviceConnectionStatus.failed => _failureText(context),
    };
    return Text(
      text,
      key: const Key('fitness-device-status'),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: snapshot.status == FitnessDeviceConnectionStatus.failed
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

  String _failureText(BuildContext context) {
    final code = snapshot.failureCode ?? 'unknown_error';
    final message = switch (code) {
      'bluetooth_disabled' => (
        'Bluetooth is off. Turn it on, then scan again.',
        'البلوتوث متوقف. فعّله ثم أعد البحث.',
      ),
      'bluetooth_permission_denied' => (
        'Bluetooth permission was denied.',
        'تم رفض إذن البلوتوث.',
      ),
      'pairing_timeout' => (
        'The device did not finish pairing in time.',
        'لم يُكمل الجهاز الاقتران ضمن المهلة.',
      ),
      'no_measurement_received' || 'gatt_timeout' => (
        'Connected, but the device did not send a supported measurement.',
        'تم الاتصال، لكن الجهاز لم يرسل قياسًا مدعومًا.',
      ),
      'unsupported_fitness_device' => (
        'This device does not expose a supported fitness BLE profile.',
        'لا يوفّر هذا الجهاز ملف BLE مدعومًا للياقة.',
      ),
      _ => (
        'Connection failed ($code). Try again or check device compatibility.',
        'تعذر الاتصال ($code). حاول مجددًا أو تحقق من توافق الجهاز.',
      ),
    };
    return connectedHealthText(context, message.$1, message.$2);
  }
}

String _fitnessProfileLabel(BuildContext context, BleFitnessProfile profile) =>
    switch (profile) {
      BleFitnessProfile.weightScale => connectedHealthText(
        context,
        'Weight',
        'الوزن',
      ),
      BleFitnessProfile.bodyComposition => connectedHealthText(
        context,
        'Body composition',
        'تركيب الجسم',
      ),
      BleFitnessProfile.heartRate => connectedHealthText(
        context,
        'Heart rate',
        'نبض القلب',
      ),
    };
