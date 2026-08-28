import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'partner_integration_registry.dart';

class PartnerCapabilitiesPage extends ConsumerWidget {
  const PartnerCapabilitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(partnerIntegrationRegistryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_text(context, 'Connection capabilities'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _text(
              context,
              'Choose a supported health source. Availability depends on your device and permissions.',
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in entries) _CapabilityTile(entry: entry),
        ],
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({required this.entry});
  final PartnerIntegrationCapability entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ready = entry.canConnect;
    final accent = ready ? const Color(0xFF16B981) : const Color(0xFFF59E0B);
    return Semantics(
      container: true,
      enabled: ready,
      label:
          '${_text(context, entry.id)}, ${_text(context, _stateKey(entry.state))}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: .16),
              colors.surface.withValues(alpha: .94),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: .42)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 10,
          ),
          minLeadingWidth: 48,
          horizontalTitleGap: 16,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: .28), blurRadius: 12),
              ],
            ),
            child: Icon(
              ready ? Icons.link_rounded : Icons.link_off_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          title: Text(_text(context, entry.id)),
          subtitle: Text(
            '${_text(context, entry.category)}\n${_text(context, _stateKey(entry.state))}',
          ),
          isThreeLine: true,
          titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
          subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            height: 1.35,
            color: colors.onSurfaceVariant,
          ),
          trailing: Icon(
            ready ? Icons.verified_rounded : Icons.info_rounded,
            color: accent,
            size: 28,
          ),
        ),
      ),
    );
  }
}

String _stateKey(PartnerIntegrationState state) => switch (state) {
  PartnerIntegrationState.nativeBridge =>
    'Available on supported devices after permission',
  PartnerIntegrationState.deviceBridge =>
    'Available after Bluetooth permission',
  PartnerIntegrationState.configurationRequired => 'Not available yet',
  PartnerIntegrationState.noAdapter => 'Not available yet',
};

String _text(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return _copy[code]?[key] ?? _copy['en']![key] ?? key;
}

const _copy = <String, Map<String, String>>{
  'en': {
    'Connection capabilities': 'Connection capabilities',
    'Choose a supported health source. Availability depends on your device and permissions.':
        'Choose a supported health source. Availability depends on your device and permissions.',
    'health-connect': 'Health Connect',
    'healthkit': 'Apple Health',
    'medical-ble': 'Bluetooth fitness devices',
    'garmin': 'Garmin',
    'fitbit': 'Fitbit',
    'samsung-health': 'Samsung Health',
    'Health platform': 'Health platform',
    'Medical device': 'Fitness device',
    'Partner account': 'Partner account',
    'Available on supported devices after permission':
        'Available on supported devices after permission',
    'Available after Bluetooth permission':
        'Available after Bluetooth permission',
    'Not available yet': 'Not available yet',
  },
  'ar': {
    'Connection capabilities': 'قدرات الاتصال',
    'Choose a supported health source. Availability depends on your device and permissions.':
        'اختر مصدرًا صحيًا مدعومًا. يعتمد التوفر على جهازك والأذونات.',
    'health-connect': 'Health Connect',
    'healthkit': 'Apple Health',
    'medical-ble': 'أجهزة لياقة عبر البلوتوث',
    'garmin': 'Garmin',
    'fitbit': 'Fitbit',
    'samsung-health': 'Samsung Health',
    'Health platform': 'منصة صحة',
    'Medical device': 'جهاز لياقة',
    'Partner account': 'حساب شريك',
    'Available on supported devices after permission':
        'متاح على الأجهزة المدعومة بعد منح الإذن',
    'Available after Bluetooth permission': 'متاح بعد منح إذن البلوتوث',
    'Not available yet': 'غير متاح حاليًا',
  },
  'fr': {
    'Connection capabilities': 'Capacités de connexion',
    'Choose a supported health source. Availability depends on your device and permissions.':
        'Choisissez une source de santé compatible. La disponibilité dépend de votre appareil et des autorisations.',
    'health-connect': 'Health Connect',
    'healthkit': 'Apple Health',
    'medical-ble': 'Appareils de fitness Bluetooth',
    'garmin': 'Garmin',
    'fitbit': 'Fitbit',
    'samsung-health': 'Samsung Health',
    'Health platform': 'Plateforme santé',
    'Medical device': 'Appareil de fitness',
    'Partner account': 'Compte partenaire',
    'Available on supported devices after permission':
        'Disponible sur les appareils compatibles après autorisation',
    'Available after Bluetooth permission':
        'Disponible après autorisation Bluetooth',
    'Not available yet': 'Pas encore disponible',
  },
  'es': {
    'Connection capabilities': 'Capacidades de conexión',
    'Choose a supported health source. Availability depends on your device and permissions.':
        'Elige una fuente de salud compatible. La disponibilidad depende del dispositivo y los permisos.',
    'health-connect': 'Health Connect',
    'healthkit': 'Apple Health',
    'medical-ble': 'Dispositivos de fitness Bluetooth',
    'garmin': 'Garmin',
    'fitbit': 'Fitbit',
    'samsung-health': 'Samsung Health',
    'Health platform': 'Plataforma de salud',
    'Medical device': 'Dispositivo de fitness',
    'Partner account': 'Cuenta asociada',
    'Available on supported devices after permission':
        'Disponible en dispositivos compatibles después del permiso',
    'Available after Bluetooth permission':
        'Disponible después del permiso de Bluetooth',
    'Not available yet': 'Aún no disponible',
  },
  'tr': {
    'Connection capabilities': 'Bağlantı yetenekleri',
    'Choose a supported health source. Availability depends on your device and permissions.':
        'Desteklenen bir sağlık kaynağı seçin. Kullanılabilirlik cihazınıza ve izinlere bağlıdır.',
    'health-connect': 'Health Connect',
    'healthkit': 'Apple Health',
    'medical-ble': 'Bluetooth fitness cihazları',
    'garmin': 'Garmin',
    'fitbit': 'Fitbit',
    'samsung-health': 'Samsung Health',
    'Health platform': 'Sağlık platformu',
    'Medical device': 'Fitness cihazı',
    'Partner account': 'İş ortağı hesabı',
    'Available on supported devices after permission':
        'İzin verildikten sonra desteklenen cihazlarda kullanılabilir',
    'Available after Bluetooth permission':
        'Bluetooth izninden sonra kullanılabilir',
    'Not available yet': 'Henüz kullanılamıyor',
  },
};
