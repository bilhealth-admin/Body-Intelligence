import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../food_name_health_sync_policy.dart';
import '../providers/connected_health_provider.dart';

class FoodNameHealthSyncCard extends ConsumerWidget {
  const FoodNameHealthSyncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = FoodNameHealthSyncPreferenceRepository(
      ref.watch(preferencesRepositoryProvider),
    );
    return StreamBuilder<FoodNameHealthSyncStatus>(
      stream: repository.watch(),
      builder: (context, snapshot) {
        final status =
            snapshot.data ??
            FoodNameHealthSyncPolicy.evaluate(requested: false);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _text(context, 0),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _text(
                    context,
                    status.capability ==
                            FoodNameHealthSyncCapability.unavailable
                        ? 6
                        : 1,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_text(context, 2)),
                  subtitle: Text(
                    _text(
                      context,
                      status.capability ==
                              FoodNameHealthSyncCapability.unavailable
                          ? 5
                          : status.active
                          ? 3
                          : 4,
                    ),
                  ),
                  value: status.active,
                  onChanged:
                      status.capability ==
                          FoodNameHealthSyncCapability.unavailable
                      ? null
                      : (requested) async {
                          if (requested) {
                            await ref
                                .read(connectedHealthProvider.notifier)
                                .requestWeightWritePermission();
                          }
                          await repository.rememberRequest(requested);
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _text(BuildContext context, int index) {
  final locale = Localizations.localeOf(context);
  final code = locale.languageCode;
  final authored = _copy[code];
  if (authored != null) return authored[index];
  final english = _copy['en']![index];
  return RuntimeCopy.resolve(english, BilLocalePolicy.canonicalTag(locale)) ??
      english;
}

const _copy = <String, List<String>>{
  'en': [
    'Food names in connected health',
    'With your permission, BIL can export a meal name, calories, and macros to connected health. You can revoke access at any time.',
    'Sync food names and nutrition',
    'Food-name and nutrition sync is enabled',
    'Turn on to request connected-health nutrition access.',
    'Nutrition export is unavailable on this platform.',
    'This platform does not support BIL nutrition export. Your local meal records are unchanged.',
  ],
  'ar': [
    'أسماء الطعام في الصحة المتصلة',
    'بإذنك، يستطيع BIL تصدير اسم الوجبة والسعرات والمغذيات الكبرى إلى الصحة المتصلة. يمكنك إلغاء الوصول في أي وقت.',
    'مزامنة أسماء الطعام والتغذية',
    'مزامنة أسماء الطعام والتغذية مفعلة',
    'فعّل الخيار لطلب إذن التغذية في الصحة المتصلة.',
    'تصدير التغذية غير متاح على هذه المنصة.',
    'لا تدعم هذه المنصة تصدير التغذية من BIL. تظل سجلات وجباتك المحلية دون تغيير.',
  ],
  'fr': [
    'Noms des aliments dans la santé connectée',
    'Avec votre autorisation, BIL peut exporter le nom du repas, les calories et les macros. Vous pouvez révoquer cet accès à tout moment.',
    'Synchroniser les noms et la nutrition',
    'La synchronisation est activée',
    'Activez cette option pour demander l’accès Nutrition.',
    'L’export nutritionnel n’est pas disponible sur cette plateforme.',
    'Cette plateforme ne prend pas en charge l’export nutritionnel de BIL. Vos repas locaux restent inchangés.',
  ],
  'es': [
    'Nombres de alimentos en salud conectada',
    'Con tu permiso, BIL puede exportar el nombre de la comida, calorías y macros. Puedes revocar el acceso en cualquier momento.',
    'Sincronizar nombres y nutrición',
    'La sincronización está activada',
    'Actívalo para solicitar acceso a Nutrición.',
    'La exportación de nutrición no está disponible en esta plataforma.',
    'Esta plataforma no admite la exportación nutricional de BIL. Tus comidas locales no cambian.',
  ],
  'tr': [
    'Bağlı sağlıkta yiyecek adları',
    'İzninizle BIL öğün adını, kalorileri ve makroları bağlı sağlığa aktarabilir. Erişimi istediğiniz zaman kaldırabilirsiniz.',
    'Yiyecek adlarını ve beslenmeyi eşitle',
    'Beslenme eşitlemesi etkin',
    'Beslenme erişimi istemek için açın.',
    'Beslenme aktarımı bu platformda kullanılamıyor.',
    'Bu platform BIL beslenme aktarımını desteklemiyor. Yerel öğün kayıtlarınız değişmez.',
  ],
};
