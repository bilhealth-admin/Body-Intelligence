import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/premium_design_tokens.dart';
import '../../shared/widgets/premium_surface.dart';
import 'connected_health_model.dart';
import 'providers/connected_health_provider.dart';

class ConnectedHealthPage extends ConsumerWidget {
  const ConnectedHealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => arabic ? ar : en;
    final state = ref.watch(connectedHealthProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(tr('Health Hub', 'المركز الصحي')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PremiumDesignTokens.spaceMd),
          children: [
            state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                              tr('Unsupported platform', 'منصة غير مدعومة'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: PremiumDesignTokens.spaceSm),
                        Text(_statusText(snapshot.status, arabic)),
                        if (snapshot.availableSources.isNotEmpty) ...[
                          const SizedBox(height: PremiumDesignTokens.spaceSm),
                          Text(
                            '${tr('Available sources', 'المصادر المتاحة')}: ${snapshot.availableSources.join(' • ')}',
                          ),
                        ],
                        const SizedBox(height: PremiumDesignTokens.spaceMd),
                        Wrap(
                          spacing: PremiumDesignTokens.spaceSm,
                          runSpacing: PremiumDesignTokens.spaceSm,
                          children: [
                            if (snapshot.status ==
                                ConnectedHealthStatus.permissionRequired)
                              FilledButton.icon(
                                onPressed: () => ref
                                    .read(connectedHealthProvider.notifier)
                                    .requestPermissions(),
                                icon: const Icon(Icons.verified_user_outlined),
                                label: Text(
                                  tr('Grant health access', 'منح إذن الصحة'),
                                ),
                              ),
                            if (snapshot.status ==
                                    ConnectedHealthStatus.ready ||
                                snapshot.status ==
                                    ConnectedHealthStatus.synchronized ||
                                snapshot.status ==
                                    ConnectedHealthStatus.degraded)
                              FilledButton.icon(
                                onPressed: () => ref
                                    .read(connectedHealthProvider.notifier)
                                    .synchronize(),
                                icon: const Icon(Icons.sync_rounded),
                                label: Text(tr('Sync now', 'مزامنة الآن')),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(connectedHealthProvider.notifier)
                                  .refresh(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(tr('Refresh status', 'تحديث الحالة')),
                            ),
                          ],
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
                            'Privacy and data flow',
                            'الخصوصية وتدفق البيانات',
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: PremiumDesignTokens.spaceSm),
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
                        const SizedBox(height: PremiumDesignTokens.spaceSm),
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
                              leading: const Icon(Icons.monitor_heart_outlined),
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
    );
  }

  String _statusText(
    ConnectedHealthStatus status,
    bool arabic,
  ) => switch (status) {
    ConnectedHealthStatus.unavailable =>
      arabic ? 'غير متاح على هذا الجهاز.' : 'Unavailable on this device.',
    ConnectedHealthStatus.permissionRequired =>
      arabic
          ? 'يحتاج BIL إلى إذن صريح قبل قراءة البيانات الصحية.'
          : 'BIL needs explicit permission before reading health data.',
    ConnectedHealthStatus.ready =>
      arabic ? 'جاهز للمزامنة.' : 'Ready to synchronize.',
    ConnectedHealthStatus.syncing =>
      arabic ? 'تتم المزامنة الآن.' : 'Synchronizing now.',
    ConnectedHealthStatus.synchronized =>
      arabic ? 'متصل ومتزامن.' : 'Connected and synchronized.',
    ConnectedHealthStatus.degraded =>
      arabic
          ? 'تعذر الوصول إلى المصدر الأصلي. البيانات المحلية لم تتأثر.'
          : 'The native source could not be reached. Local data was not affected.',
  };
}
