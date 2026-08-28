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
              'Connected ({count})',
              'المتصلة ({count})',
            ).replaceFirst('{count}', connected ? '1' : '0'),
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
              title: Text(_consumerName(context, entry.id)),
              subtitle: Text(
                '${entry.platforms.join(' / ')} • ${entry.minimumVersion}',
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
            tr('Compatible fitness devices', 'أجهزة اللياقة المتوافقة'),
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
                  'Bluetooth fitness device and smart watch',
                  'جهاز لياقة وساعة ذكية عبر البلوتوث',
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
                      'Weight, body composition, heart rate, and SpO₂ from compatible fitness devices.',
                      'الوزن وتركيب الجسم ومعدل ضربات القلب وSpO₂ من أجهزة اللياقة المتوافقة.',
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
                  : tr('Scan for fitness devices', 'البحث عن أجهزة لياقة'),
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            tr(
              'BIL imports only values actually received after permission. Bluetooth scan is the supported pairing path; no QR connection is claimed. SpO₂ is for wellness display only, not diagnosis.',
              'لا يستورد BIL إلا القيم المستلمة فعليًا بعد الإذن. البحث عبر البلوتوث هو مسار الربط المدعوم ولا يدّعي التطبيق وجود ربط QR. عرض SpO₂ للعافية فقط وليس للتشخيص.',
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
        'Bluetooth fitness-device linking is unavailable here.',
        'ربط أجهزة اللياقة عبر البلوتوث غير متاح على هذه المنصة.',
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
        snapshot.failureCode != null
            ? 'Fitness device paired, but measurement sync failed (${snapshot.failureCode}).'
            : snapshot.batteryPercent == null
            ? 'Fitness device connected. Battery was not reported. Last sync: ${_time(context)}.'
            : 'Fitness device connected. Battery ${snapshot.batteryPercent}%. Last sync: ${_time(context)}.',
        snapshot.failureCode != null
            ? 'تم اقتران جهاز اللياقة، لكن فشلت مزامنة القياس (${snapshot.failureCode}).'
            : snapshot.batteryPercent == null
            ? 'جهاز اللياقة متصل. لم يرسل الجهاز حالة البطارية. آخر مزامنة: ${_time(context)}.'
            : 'جهاز اللياقة متصل. البطارية ${snapshot.batteryPercent}٪. آخر مزامنة: ${_time(context)}.',
      ),
      MedicalDeviceConnectionStatus.failed => _failureText(context),
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

String _fitnessProfileLabel(BuildContext context, BleMedicalProfile profile) =>
    switch (profile) {
      BleMedicalProfile.weightScale => connectedHealthText(
        context,
        'Weight',
        'الوزن',
      ),
      BleMedicalProfile.bodyComposition => connectedHealthText(
        context,
        'Body composition',
        'تركيب الجسم',
      ),
      BleMedicalProfile.heartRate => connectedHealthText(
        context,
        'Heart rate',
        'نبض القلب',
      ),
    };
