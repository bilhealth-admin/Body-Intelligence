import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../global_platform/medical_devices/ble_medical_device_platform.dart';
import '../providers/medical_device_provider.dart';
import '../connected_health_copy.dart';
import '../../../shared/widgets/bil_wordmark.dart';

class HealthDevicePager extends StatefulWidget {
  const HealthDevicePager({
    super.key,
    required this.height,
    required this.pages,
    this.onPageChanged,
  });

  final double height;
  final List<Widget> pages;
  final ValueChanged<int>? onPageChanged;

  @override
  State<HealthDevicePager> createState() => _HealthDevicePagerState();
}

class _HealthDevicePagerState extends State<HealthDevicePager> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .96);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.pages.length,
            onPageChanged: (value) {
              setState(() => _page = value);
              widget.onPageChanged?.call(value);
            },
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: widget.pages[index],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.pages.length, (index) {
            final selected = index == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: selected ? 20 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF08B9D2)
                    : const Color(0xFF9FB3C1).withValues(alpha: .55),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class BilMedicalMonitor extends ConsumerWidget {
  const BilMedicalMonitor({
    super.key,
    required this.snapshot,
    required this.languageCode,
    this.compact = false,
  });

  final MedicalDeviceSnapshot snapshot;
  final String languageCode;
  final bool compact;

  String tr(String en, String ar) =>
      connectedHealthTextForLanguage(languageCode, en, ar);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected =
        snapshot.status == MedicalDeviceConnectionStatus.connected;
    final readings = snapshot.measurements
        .where((packet) => bleFitnessMeasurementKinds.contains(packet['kind']))
        .take(3)
        .toList(growable: false);
    return Semantics(
      label: tr(
        'BIL Bluetooth fitness-device display. Values appear only when received from a connected fitness device.',
        'شاشة BIL لأجهزة اللياقة عبر البلوتوث. لا تظهر القيم إلا عند استلامها من جهاز لياقة متصل.',
      ),
      child: Container(
        key: const Key('bil-live-medical-monitor'),
        margin: EdgeInsets.all(compact ? 5 : 8),
        padding: EdgeInsets.all(compact ? 5 : 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(54),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF263038),
              Color(0xFFE7ECEF),
              Color(0xFF707B82),
              Color(0xFFFFFFFF),
              Color(0xFF303A40),
            ],
            stops: [0, .22, .48, .67, 1],
          ),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44031321),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Container(
          padding: compact
              ? const EdgeInsets.fromLTRB(10, 8, 10, 6)
              : const EdgeInsets.fromLTRB(18, 14, 18, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(42),
            gradient: const RadialGradient(
              center: Alignment(-.25, -.45),
              radius: 1.15,
              colors: [Color(0xFF173B55), Color(0xFF071522)],
            ),
            border: Border.all(color: const Color(0xFF06101A), width: 5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: BilWordmark(height: compact ? 11 : 17),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected
                          ? const Color(0xFF2DDA9B)
                          : const Color(0xFF728391),
                      boxShadow: connected
                          ? const [
                              BoxShadow(
                                color: Color(0xAA2DDA9B),
                                blurRadius: 9,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    connected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_disabled_rounded,
                    color: connected ? const Color(0xFF5EE5F5) : Colors.white38,
                    size: compact ? 14 : 19,
                  ),
                ],
              ),
              SizedBox(height: compact ? 5 : 12),
              Expanded(
                child: readings.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '— —',
                            textDirection: TextDirection.ltr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 26 : 42,
                              fontWeight: FontWeight.w400,
                              letterSpacing: compact ? 3 : 5,
                            ),
                          ),
                          SizedBox(height: compact ? 3 : 10),
                          Flexible(
                            child: Text(
                              connected
                                  ? tr(
                                      'Waiting for a measured value',
                                      'بانتظار وصول قياس حقيقي',
                                    )
                                  : tr(
                                      'Connect a fitness device',
                                      'اربط جهاز لياقة',
                                    ),
                              textAlign: TextAlign.center,
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFFBBD1DE),
                                fontSize: compact ? 10 : 13,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MedicalReading(
                            packet: readings.first,
                            languageCode: languageCode,
                            primary: true,
                          ),
                          if (readings.length > 1) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                for (final packet in readings.skip(1))
                                  Expanded(
                                    child: _MedicalReading(
                                      packet: packet,
                                      languageCode: languageCode,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: compact ? 11 : 14,
                    color: Colors.white.withValues(alpha: .55),
                  ),
                  SizedBox(width: compact ? 3 : 6),
                  Expanded(
                    child: Text(
                      tr('Received via BLE', 'مستلم عبر BLE'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .55),
                        fontSize: compact ? 9 : 11,
                      ),
                    ),
                  ),
                  if (connected) ...[
                    IconButton(
                      tooltip: tr('Read again', 'قراءة جديدة'),
                      onPressed: () => ref
                          .read(medicalDeviceProvider.notifier)
                          .refreshMeasurements(),
                      icon: const Icon(Icons.refresh_rounded),
                      color: const Color(0xFF63DFF2),
                      iconSize: 20,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicalReading extends StatelessWidget {
  const _MedicalReading({
    required this.packet,
    required this.languageCode,
    this.primary = false,
  });

  final Map<String, Object?> packet;
  final String languageCode;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final kind = packet['kind'] as String? ?? '';
    final value = (packet['value'] as num).toDouble();
    final unit = packet['unit'] as String? ?? '';
    final label = switch (kind) {
      'weight' => connectedHealthTextForLanguage(
        languageCode,
        'Weight',
        'الوزن',
      ),
      'body_fat' => connectedHealthTextForLanguage(
        languageCode,
        'Body fat',
        'دهون الجسم',
      ),
      'heart_rate' => connectedHealthTextForLanguage(
        languageCode,
        'Heart rate',
        'نبض القلب',
      ),
      _ => connectedHealthTextForLanguage(languageCode, 'Measurement', 'قياس'),
    };
    final formatted = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF9FC3D6), fontSize: 11),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatted,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: primary ? 42 : 24,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  color: const Color(0xFF71DDF0),
                  fontSize: primary ? 13 : 10,
                ),
              ),
            ],
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        ),
      ],
    );
  }
}
