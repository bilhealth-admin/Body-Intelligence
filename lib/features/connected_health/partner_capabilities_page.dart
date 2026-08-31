import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr/qr.dart' as qr;
import 'package:url_launcher/url_launcher.dart';

import 'partner_capabilities_copy.dart';
import 'partner_integration_registry.dart';
import 'partner_setup_copy.dart';

typedef PartnerSetupLauncher = Future<bool> Function(Uri uri);

final partnerSetupLauncherProvider = Provider<PartnerSetupLauncher>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class PartnerCapabilitiesPage extends ConsumerWidget {
  const PartnerCapabilitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(partnerIntegrationRegistryProvider);
    final launcher = ref.read(partnerSetupLauncherProvider);
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
          for (final entry in entries)
            _CapabilityTile(entry: entry, launcher: launcher),
        ],
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({required this.entry, required this.launcher});
  final PartnerIntegrationCapability entry;
  final PartnerSetupLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ready = entry.canConnect;
    final accent = ready ? const Color(0xFF16B981) : const Color(0xFFF59E0B);
    final rawSetupUrl = entry.officialSetupUrl;
    final setupUri = rawSetupUrl == null ? null : Uri.tryParse(rawSetupUrl);
    final verifiedSetupUri =
        setupUri != null &&
            PartnerIntegrationRegistry.isVerifiedOfficialSetupUri(
              entry.id,
              setupUri,
            )
        ? setupUri
        : null;
    final setupCopy = PartnerSetupCopy.of(context);
    return Semantics(
      container: true,
      enabled: ready || verifiedSetupUri != null,
      label:
          '${_text(context, entry.id)}, ${_text(context, _stateKey(entry.state))}'
          '${verifiedSetupUri == null ? '' : ', ${setupCopy.text(PartnerSetupCopy.officialSetup)}'}',
      hint: ready || verifiedSetupUri == null
          ? null
          : setupCopy.text(PartnerSetupCopy.guidanceOnly),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
              minLeadingWidth: 48,
              horizontalTitleGap: 16,
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: .28),
                      blurRadius: 12,
                    ),
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
              subtitleTextStyle: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(
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
            if (verifiedSetupUri != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: Key('partner-official-setup-${entry.id}'),
                      onPressed: () => launcher(verifiedSetupUri),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(setupCopy.text(PartnerSetupCopy.openGuide)),
                    ),
                    IconButton.outlined(
                      key: Key('partner-setup-qr-${entry.id}'),
                      tooltip: setupCopy.text(PartnerSetupCopy.showQr),
                      onPressed: () => _showVerifiedSetupQr(
                        context,
                        entry: entry,
                        uri: verifiedSetupUri,
                        launcher: launcher,
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showVerifiedSetupQr(
  BuildContext context, {
  required PartnerIntegrationCapability entry,
  required Uri uri,
  required PartnerSetupLauncher launcher,
}) async {
  if (!PartnerIntegrationRegistry.isVerifiedOfficialSetupUri(entry.id, uri)) {
    return;
  }
  final setupCopy = PartnerSetupCopy.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        '${setupCopy.text(PartnerSetupCopy.officialSetup)} · ${_text(dialogContext, entry.id)}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              link: true,
              label: setupCopy.text(PartnerSetupCopy.openGuide),
              child: InkWell(
                key: Key('verified-partner-qr-link-${entry.id}'),
                onTap: () => launcher(uri),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 220,
                  height: 220,
                  padding: const EdgeInsets.all(14),
                  color: Colors.white,
                  child: CustomPaint(
                    key: Key('verified-partner-qr-${entry.id}'),
                    painter: _VerifiedQrPainter(uri.toString()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              setupCopy.text(PartnerSetupCopy.guidanceOnly),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).closeButtonLabel),
        ),
      ],
    ),
  );
}

class _VerifiedQrPainter extends CustomPainter {
  _VerifiedQrPainter(String data)
    : data = data,
      image = qr.QrImage(
        qr.QrCode.fromData(
          data: data,
          errorCorrectLevel: qr.QrErrorCorrectLevel.M,
        ),
      );

  final String data;
  final qr.QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    const quietZone = 4;
    final dimension = image.moduleCount + quietZone * 2;
    final cell = size.shortestSide / dimension;
    final paint = Paint()..color = Colors.black;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var column = 0; column < image.moduleCount; column++) {
        if (!image.isDark(row, column)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (column + quietZone) * cell,
            (row + quietZone) * cell,
            cell.ceilToDouble(),
            cell.ceilToDouble(),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_VerifiedQrPainter oldDelegate) =>
      oldDelegate.data != data;
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
  return PartnerCapabilitiesCopy.of(context).text(key);
}
