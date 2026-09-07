part of 'connected_health_page.dart';

extension on _ConnectedHealthPageState {
  Future<void> _showConnectionSearch(BuildContext context) async {
    final nativeSource = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? 'Apple Health'
        : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'Health Connect'
        : connectedHealthText(context, 'Health source', 'مصدر صحي');
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
                leading: BilSemanticIconBadge(
                  kind: BilSemanticIconKind.health,
                  size: 38,
                  iconSize: 21,
                  shape: BoxShape.rectangle,
                ),
                title: Text(nativeSource),
              ),
              ListTile(
                leading: BilSemanticIconBadge(
                  kind: BilSemanticIconKind.devices,
                  iconOverride: Icons.bluetooth_rounded,
                  appleIconOverride: CupertinoIcons.bluetooth,
                  size: 38,
                  iconSize: 21,
                  shape: BoxShape.rectangle,
                ),
                title: Text(
                  connectedHealthText(
                    context,
                    'Bluetooth fitness devices',
                    'أجهزة اللياقة عبر البلوتوث',
                  ),
                ),
              ),
              ListTile(
                key: const Key('available-connections-capabilities-link'),
                leading: BilSemanticIconBadge(
                  kind: BilSemanticIconKind.verifiedFood,
                  iconOverride: Icons.fact_check_outlined,
                  appleIconOverride: CupertinoIcons.checkmark_seal,
                  size: 38,
                  iconSize: 21,
                  shape: BoxShape.rectangle,
                ),
                title: Text(
                  connectedHealthText(
                    context,
                    'Connection capabilities',
                    'قدرات الاتصال',
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/connected-health/capabilities');
                },
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

  String _platformSourceTitle(
    BuildContext context,
    ConnectedHealthSnapshot snapshot,
  ) {
    if (snapshot.platformSource != null) return snapshot.platformSource!;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return connectedHealthText(context, 'Apple Health', 'Apple Health');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return connectedHealthText(context, 'Health Connect', 'Health Connect');
    }
    return connectedHealthText(
      context,
      'Unsupported platform',
      'منصة غير مدعومة',
    );
  }
}
