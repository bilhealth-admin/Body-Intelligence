// The reference-style More page does not currently expose every destructive
// maintenance action retained here for the full Settings surface.
// ignore_for_file: unused_element

part of 'settings_page.dart';

String _settingsActionText(BuildContext context, String key) {
  const copy = <String, Map<String, String>>{
    'restart_title': {
      'en': 'Restart account experience?',
      'ar': 'بدء تجربة الحساب من جديد؟',
      'fr': 'Relancer l’expérience du compte ?',
      'es': '¿Reiniciar la experiencia de la cuenta?',
      'tr': 'Hesap deneyimi yeniden başlatılsın mı?',
    },
    'restart_body': {
      'en':
          'Only the cloud account will be signed out. All local health records will remain on this device.',
      'ar':
          'سيتم تسجيل خروج الحساب السحابي فقط. ستبقى جميع سجلاتك الصحية المحلية محفوظة على هذا الجهاز.',
      'fr':
          'Seul le compte cloud sera déconnecté. Tous les dossiers de santé locaux resteront sur cet appareil.',
      'es':
          'Solo se cerrará la sesión de la cuenta en la nube. Todos los registros de salud locales permanecerán en este dispositivo.',
      'tr':
          'Yalnızca bulut hesabından çıkış yapılır. Tüm yerel sağlık kayıtları bu cihazda kalır.',
    },
    'cancel': {
      'en': 'Cancel',
      'ar': 'إلغاء',
      'fr': 'Annuler',
      'es': 'Cancelar',
      'tr': 'İptal',
    },
    'sign_out': {
      'en': 'Sign out',
      'ar': 'تسجيل الخروج',
      'fr': 'Se déconnecter',
      'es': 'Cerrar sesión',
      'tr': 'Çıkış yap',
    },
    'sign_out_failed': {
      'en': 'Sign-out could not be completed. Your local data was unchanged.',
      'ar': 'تعذر تسجيل الخروج الآن. بقيت بياناتك المحلية كما هي.',
      'fr':
          'La déconnexion a échoué. Vos données locales n’ont pas été modifiées.',
      'es': 'No se pudo cerrar la sesión. Tus datos locales no cambiaron.',
      'tr': 'Çıkış tamamlanamadı. Yerel verileriniz değiştirilmedi.',
    },
    'export_failed': {
      'en':
          'The local export could not be created. No data was deleted or uploaded.',
      'ar': 'تعذر إنشاء التصدير المحلي. لم يتم حذف أو رفع أي بيانات.',
      'fr':
          'L’exportation locale n’a pas pu être créée. Aucune donnée n’a été supprimée ni envoyée.',
      'es':
          'No se pudo crear la exportación local. No se eliminó ni subió ningún dato.',
      'tr':
          'Yerel dışa aktarma oluşturulamadı. Hiçbir veri silinmedi veya yüklenmedi.',
    },
    'review_title': {
      'en': 'Review your initial setup?',
      'ar': 'مراجعة الإعداد الأولي؟',
      'fr': 'Revoir votre configuration initiale ?',
      'es': '¿Revisar la configuración inicial?',
      'tr': 'İlk kurulum gözden geçirilsin mi?',
    },
    'review_body': {
      'en':
          'Onboarding will open while keeping your profile, weight records, meals, and all local data. Nothing will be deleted or uploaded.',
      'ar':
          'سيُفتح الإعداد الأولي مع الاحتفاظ بملفك وسجلات الوزن والطعام وجميع بياناتك. لن يتم حذف أو رفع أي شيء.',
      'fr':
          'La configuration s’ouvrira en conservant votre profil, vos poids, vos repas et toutes vos données locales. Rien ne sera supprimé ni envoyé.',
      'es':
          'La configuración se abrirá conservando tu perfil, registros de peso, comidas y todos los datos locales. No se eliminará ni subirá nada.',
      'tr':
          'Kurulum; profiliniz, kilo kayıtlarınız, öğünleriniz ve tüm yerel verileriniz korunarak açılır. Hiçbir şey silinmez veya yüklenmez.',
    },
    'open_setup': {
      'en': 'Open setup',
      'ar': 'فتح الإعداد',
      'fr': 'Ouvrir la configuration',
      'es': 'Abrir configuración',
      'tr': 'Kurulumu aç',
    },
    'setup_failed': {
      'en': 'Initial setup could not be opened. Your data was unchanged.',
      'ar': 'تعذر فتح الإعداد الأولي الآن. لم تتغير بياناتك.',
      'fr':
          'La configuration initiale n’a pas pu être ouverte. Vos données n’ont pas été modifiées.',
      'es':
          'No se pudo abrir la configuración inicial. Tus datos no cambiaron.',
      'tr': 'İlk kurulum açılamadı. Verileriniz değiştirilmedi.',
    },
  };
  final languageCode = Localizations.localeOf(context).languageCode;
  return copy[key]![languageCode] ?? copy[key]!['en']!;
}

extension _SettingsPageActions on SettingsPage {
  Future<void> _restartAccountExperience(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_settingsActionText(context, 'restart_title')),
        content: Text(_settingsActionText(context, 'restart_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_settingsActionText(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_settingsActionText(context, 'sign_out')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (AppEnvironment.cloudConfigured) {
        await Supabase.instance.client.auth.signOut();
      }
      await ref
          .read(preferencesRepositoryProvider)
          .remove('accountGatewayReviewed');
      ref.invalidate(accountGatewayReviewedProvider);
      if (context.mounted) {
        context.go('/account-gateway');
      }
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_settingsActionText(context, 'sign_out_failed')),
        ),
      );
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final database = ref.read(databaseProvider);
      final lifecycle = LocalDataLifecycleService(database);
      final files = await lifecycle.exportCsvFiles();
      await const DataExportService().sharePortableCsvFiles(files);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text('Choose where to save your private export.'),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_settingsActionText(context, 'export_failed'))),
      );
    }
  }

  Future<void> _reviewSetupAgain(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_settingsActionText(context, 'review_title')),
        content: Text(_settingsActionText(context, 'review_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_settingsActionText(context, 'cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.tune_rounded),
            label: Text(_settingsActionText(context, 'open_setup')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .set('forceOnboarding', 'true');
      if (context.mounted) {
        context.go('/onboarding');
      }
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_settingsActionText(context, 'setup_failed'))),
      );
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.text('Reset all local data?')),
        content: Text(
          context.strings.text(
            'A validated local recovery snapshot will replace any older snapshot before your profile, goals, logs, meals, custom foods, and settings are reset.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.strings.text('Reset')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    BuildContext? progressDialogContext;
    final progressDialogReady = Completer<void>();

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) {
          progressDialogContext = dialogContext;
          if (!progressDialogReady.isCompleted) {
            progressDialogReady.complete();
          }
          return PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      context.strings.text(
                        'Deleting local data. Please wait...',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await progressDialogReady.future;
    try {
      final database = ref.read(databaseProvider);
      await LocalRecoveryService(database).resetWithRecovery();
      await SeedData.seedStarterCatalog(ref.read(foodRepositoryProvider));
      ref.invalidate(userProfileProvider);
      ref.invalidate(measurementSystemProvider);
      ref.invalidate(appSettingsProvider);
      ref.invalidate(foodRepositoryProvider);

      final dialogContext = progressDialogContext;
      if (dialogContext != null && dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
      if (!context.mounted) return;
      await Future<void>.delayed(Duration.zero);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/account-gateway');
        }
      });
    } catch (_) {
      final dialogContext = progressDialogContext;
      if (dialogContext != null && dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              'Your data was not reset or uploaded. Try opening it again.',
            ),
          ),
        ),
      );
    }
  }
}
