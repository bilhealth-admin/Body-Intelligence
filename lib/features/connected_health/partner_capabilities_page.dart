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
              'Only registered and reachable integrations can connect.',
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
            '${_text(context, entry.category)}\n${_text(context, _stateKey(entry.state))}'
            '${entry.dataTypes.isEmpty ? '' : '\n${entry.dataTypes.join(' · ')}'}',
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
    'Native bridge available; device permission required.',
  PartnerIntegrationState.deviceBridge =>
    'Device bridge available; each device requires verification.',
  PartnerIntegrationState.configurationRequired =>
    'Not connectable: provider OAuth and runtime registration are not configured.',
  PartnerIntegrationState.noAdapter =>
    'Not connectable: no registered adapter.',
};

String _text(BuildContext context, String key) {
  final code = Localizations.localeOf(context).languageCode;
  return _copy[code]?[key] ?? _copy['en']![key] ?? key;
}

const _copy = <String, Map<String, String>>{
  'en': {
    'Connection capabilities': 'Connection capabilities',
    'Only registered and reachable integrations can connect.':
        'Only registered and reachable integrations can connect.',
    'health-connect': 'Health Connect',
    'healthkit': 'Apple Health',
    'medical-ble': 'Bluetooth medical devices',
    'garmin': 'Garmin',
    'fitbit': 'Fitbit',
    'samsung-health': 'Samsung Health',
    'Health platform': 'Health platform',
    'Medical device': 'Medical device',
    'Partner account': 'Partner account',
    'Native bridge available; device permission required.':
        'Native bridge available; device permission required.',
    'Device bridge available; each device requires verification.':
        'Device bridge available; each device requires verification.',
    'Not connectable: provider OAuth and runtime registration are not configured.':
        'Not connectable: provider OAuth and runtime registration are not configured.',
    'Not connectable: no registered adapter.':
        'Not connectable: no registered adapter.',
  },
  'ar': {
    'Connection capabilities': 'قدرات الاتصال',
    'Only registered and reachable integrations can connect.':
        'يمكن الاتصال فقط بالتكاملات المسجلة والقابلة للوصول.',
    'health-connect': 'Health Connect',
    'healthkit': 'Apple Health',
    'medical-ble': 'أجهزة طبية عبر البلوتوث',
    'garmin': 'Garmin',
    'fitbit': 'Fitbit',
    'samsung-health': 'Samsung Health',
    'Health platform': 'منصة صحة',
    'Medical device': 'جهاز طبي',
    'Partner account': 'حساب شريك',
    'Native bridge available; device permission required.':
        'الجسر الأصلي متاح ويتطلب إذن الجهاز.',
    'Device bridge available; each device requires verification.':
        'جسر الجهاز متاح ويتطلب التحقق من كل جهاز.',
    'Not connectable: provider OAuth and runtime registration are not configured.':
        'غير قابل للاتصال: OAuth وتسجيل التشغيل غير مهيأين.',
    'Not connectable: no registered adapter.':
        'غير قابل للاتصال: لا يوجد موصل مسجل.',
  },
  'fr': {
    'Connection capabilities': 'Capacités de connexion',
    'Only registered and reachable integrations can connect.':
        'Seules les intégrations enregistrées et accessibles peuvent se connecter.',
    'health-connect': 'Health Connect',
    'healthkit': 'Apple Health',
    'medical-ble': 'Appareils médicaux Bluetooth',
    'garmin': 'Garmin',
    'fitbit': 'Fitbit',
    'samsung-health': 'Samsung Health',
    'Health platform': 'Plateforme santé',
    'Medical device': 'Appareil médical',
    'Partner account': 'Compte partenaire',
    'Native bridge available; device permission required.':
        'Pont natif disponible ; autorisation requise.',
    'Device bridge available; each device requires verification.':
        'Pont appareil disponible ; chaque appareil doit être vérifié.',
    'Not connectable: provider OAuth and runtime registration are not configured.':
        'Non connectable : OAuth et l’enregistrement ne sont pas configurés.',
    'Not connectable: no registered adapter.':
        'Non connectable : aucun adaptateur enregistré.',
  },
  'es': {
    'Connection capabilities': 'Capacidades de conexión',
    'Only registered and reachable integrations can connect.':
        'Solo pueden conectarse integraciones registradas y accesibles.',
    'health-connect': 'Health Connect',
    'healthkit': 'Apple Health',
    'medical-ble': 'Dispositivos médicos Bluetooth',
    'garmin': 'Garmin',
    'fitbit': 'Fitbit',
    'samsung-health': 'Samsung Health',
    'Health platform': 'Plataforma de salud',
    'Medical device': 'Dispositivo médico',
    'Partner account': 'Cuenta asociada',
    'Native bridge available; device permission required.':
        'Puente nativo disponible; requiere permiso.',
    'Device bridge available; each device requires verification.':
        'Puente de dispositivo disponible; cada dispositivo requiere verificación.',
    'Not connectable: provider OAuth and runtime registration are not configured.':
        'No conectable: OAuth y el registro de ejecución no están configurados.',
    'Not connectable: no registered adapter.':
        'No conectable: no hay adaptador registrado.',
  },
  'tr': {
    'Connection capabilities': 'Bağlantı yetenekleri',
    'Only registered and reachable integrations can connect.':
        'Yalnızca kayıtlı ve erişilebilir entegrasyonlar bağlanabilir.',
    'health-connect': 'Health Connect',
    'healthkit': 'Apple Health',
    'medical-ble': 'Bluetooth tıbbi cihazlar',
    'garmin': 'Garmin',
    'fitbit': 'Fitbit',
    'samsung-health': 'Samsung Health',
    'Health platform': 'Sağlık platformu',
    'Medical device': 'Tıbbi cihaz',
    'Partner account': 'İş ortağı hesabı',
    'Native bridge available; device permission required.':
        'Yerel köprü hazır; cihaz izni gerekir.',
    'Device bridge available; each device requires verification.':
        'Cihaz köprüsü hazır; her cihaz doğrulanmalıdır.',
    'Not connectable: provider OAuth and runtime registration are not configured.':
        'Bağlanamaz: OAuth ve çalışma kaydı yapılandırılmadı.',
    'Not connectable: no registered adapter.':
        'Bağlanamaz: kayıtlı adaptör yok.',
  },
};
