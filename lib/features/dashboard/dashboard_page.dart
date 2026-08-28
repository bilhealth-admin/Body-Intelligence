import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/services/runtime_permission_policy.dart';
import '../cloud_platform/presentation/cloud_sync_consent_notice.dart';
import '../life_context/providers/life_context_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'providers/dashboard_provider.dart';
import 'widgets/dashboard_composition.dart';
import 'widgets/dashboard_grid.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_shell.dart';
import 'widgets/dashboard_top_bar.dart';
import 'widgets/first_value_handoff_card.dart';

/// Keeps pull-to-refresh responsive even when a provider or device source is
/// slow. The refresh work continues safely after the indicator is dismissed.
@visibleForTesting
const dashboardRefreshIndicatorMaximum = Duration(milliseconds: 850);

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  Future<void> manageProfilePhoto(
    BuildContext context,
    WidgetRef ref,
    Uint8List? currentPhoto,
    String locale,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(_dashboardText(locale, 'takePhotoNow')),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: Text(
                currentPhoto == null
                    ? _dashboardText(locale, 'addPhoto')
                    : _dashboardText(locale, 'changePhoto'),
              ),
              onTap: () => Navigator.pop(sheetContext, 'choose'),
            ),
            if (currentPhoto != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(_dashboardText(locale, 'removePhoto')),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: Text(_dashboardText(locale, 'profileSettings')),
              onTap: () => Navigator.pop(sheetContext, 'profile'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final repository = ref.read(preferencesRepositoryProvider);
    if (action == 'profile') {
      context.push('/profile-settings');
      return;
    }
    if (action == 'remove') {
      try {
        await repository.remove('profilePhoto');
      } on Object {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_dashboardText(locale, 'removeFailed'))),
        );
      }
      return;
    }

    if (action == 'camera') {
      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
        final allowed = await _ensureCameraPermission(context);
        if (!allowed || !context.mounted) return;
      }
      try {
        final captured =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
            ? await showDialog<XFile>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _WindowsCameraCapture(locale: locale),
              )
            : await ImagePicker().pickImage(
                source: ImageSource.camera,
                imageQuality: 86,
                maxWidth: 1400,
                maxHeight: 1400,
              );
        if (captured == null || !context.mounted) return;
        final bytes = await captured.readAsBytes();
        if (!context.mounted) return;
        await repository.set('profilePhoto', base64Encode(bytes));
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_dashboardText(locale, 'cameraUnavailable'))),
        );
      }
      return;
    }

    const imageTypes = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
      uniformTypeIdentifiers: ['public.jpeg', 'public.png', 'public.webp'],
      webWildCards: ['image/*'],
    );
    try {
      final selected = await openFile(acceptedTypeGroups: [imageTypes]);
      if (selected == null || !context.mounted) return;
      final bytes = await selected.readAsBytes();
      if (!context.mounted) return;
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_dashboardText(locale, 'imageTooLarge'))),
        );
        return;
      }
      await repository.set('profilePhoto', base64Encode(bytes));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_dashboardText(locale, 'imageOpenFailed'))),
      );
    }
  }

  Future<bool> _ensureCameraPermission(BuildContext context) async {
    const policy = BilRuntimePermissionPolicy();
    final current = await policy.status(BilRuntimeCapability.camera);
    if (current == BilRuntimePermissionState.granted) return true;
    if (!context.mounted) return false;
    final blocked = current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.strings.text(
            blocked ? 'Camera access is off' : 'Allow camera for this action?',
          ),
        ),
        content: Text(
          context.strings.text(
            blocked
                ? 'Enable camera access in system settings to take a profile photo. You can still choose a photo with the system picker.'
                : 'BIL opens the camera only after you choose Take photo now. It never requests camera access at startup.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Not now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.strings.text(
                blocked ? 'Open system settings' : 'Continue',
              ),
            ),
          ),
        ],
      ),
    );
    if (proceed != true) return false;
    if (blocked) {
      await policy.openSettings();
      return false;
    }
    return await policy.request(BilRuntimeCapability.camera) ==
        BilRuntimePermissionState.granted;
  }

  Future<void> refresh(BuildContext context, WidgetRef ref) async {
    final refreshWork = _refreshDashboardData(context, ref);
    await Future.any<void>([
      refreshWork,
      Future<void>.delayed(dashboardRefreshIndicatorMaximum),
    ]);
  }

  Future<void> _refreshDashboardData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await Future.wait([
        ref.refresh(latestWeightProvider.future),
        ref.refresh(weightHistoryProvider.future),
        ref.refresh(userProfileProvider.future),
        ref.refresh(todayMealsProvider.future),
        ref.refresh(todayWaterProvider.future),
        ref.refresh(allMealsProvider.future),
        ref.refresh(allWaterProvider.future),
        ref.refresh(weightReminderSkippedTodayProvider.future),
        ref.refresh(todayLifeContextProvider.future),
      ], eagerError: true).timeout(const Duration(seconds: 6));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('Today is up to date.'))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.text(
                'Some local Today data could not be refreshed.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedLocale = Localizations.localeOf(context);
    // Legacy dashboard helpers resolve copy outside a BuildContext. Keep their
    // release-locale source synchronized even on a cold deep link, where the
    // process-wide fallback may still be English during the first frame.
    AppLocalizations.activate(resolvedLocale);
    final locale = resolvedLocale.languageCode.toLowerCase();
    final showFirstValue = ref.watch(firstValueHandoffProvider).value ?? false;
    final profilePhoto = ref.watch(profilePhotoProvider).value;
    final profilePhotoUrl = ref.watch(profilePhotoPublicUrlProvider).value;

    final hero = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CloudSyncConsentNotice(),
        DashboardTopBar(
          profilePhoto: profilePhoto,
          profilePhotoUrl: profilePhotoUrl,
          onProfile: () =>
              manageProfilePhoto(context, ref, profilePhoto, locale),
        ),
        const SizedBox(height: 18),
        if (showFirstValue) ...[
          FirstValueHandoffCard(
            onContinue: () async {
              try {
                await ref
                    .read(preferencesRepositoryProvider)
                    .remove('firstValueHandoffPending');
                if (context.mounted) {
                  context.push('/daily-check-in');
                }
              } on Object {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_dashboardText(locale, 'checkInFailed')),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 18),
        ],
      ],
    );

    const dashboardIconBlue = Color(0xFF2563EB);
    final baseTheme = Theme.of(context);
    final dashboardTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: dashboardIconBlue,
        primaryContainer: const Color(0xFFE4EDFF),
      ),
      iconTheme: baseTheme.iconTheme.copyWith(color: dashboardIconBlue),
    );

    return Theme(
      data: dashboardTheme,
      child: DashboardShell(
        onRefresh: () => refresh(context, ref),
        child: DashboardComposition(
          hero: hero,
          content: const DashboardGrid(hero: DashboardHeader()),
        ),
      ),
    );
  }
}

class _WindowsCameraCapture extends StatefulWidget {
  const _WindowsCameraCapture({required this.locale});

  final String locale;

  @override
  State<_WindowsCameraCapture> createState() => _WindowsCameraCaptureState();
}

class _WindowsCameraCaptureState extends State<_WindowsCameraCapture> {
  CameraController? controller;
  String? error;
  bool capturing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera found');
      }
      final next = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() => controller = next);
    } catch (_) {
      if (mounted) {
        setState(() => error = _dashboardText(widget.locale, 'cameraFailed'));
      }
    }
  }

  Future<void> _capture() async {
    final active = controller;
    if (active == null || capturing || !active.value.isInitialized) return;
    setState(() => capturing = true);
    try {
      final image = await active.takePicture();
      if (mounted) Navigator.pop(context, image);
    } catch (_) {
      if (mounted) {
        setState(() {
          capturing = false;
          error = _dashboardText(widget.locale, 'captureFailed');
        });
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = controller;
    return AlertDialog(
      title: Text(_dashboardText(widget.locale, 'takeProfilePhoto')),
      content: SizedBox(
        width: 520,
        height: 390,
        child: error != null
            ? Center(child: Text(error!, textAlign: TextAlign.center))
            : active == null || !active.value.isInitialized
            ? const Center(child: CircularProgressIndicator())
            : ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CameraPreview(active),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_dashboardText(widget.locale, 'cancel')),
        ),
        FilledButton.icon(
          onPressed: error == null && active?.value.isInitialized == true
              ? _capture
              : null,
          icon: capturing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt_rounded),
          label: Text(_dashboardText(widget.locale, 'capture')),
        ),
      ],
    );
  }
}

String _dashboardText(String locale, String key) =>
    _dashboardPageCopy[locale]?[key] ?? _dashboardPageCopy['en']![key]!;

const _dashboardPageCopy = <String, Map<String, String>>{
  'en': {
    'takePhotoNow': 'Take a photo now',
    'addPhoto': 'Add profile photo',
    'changePhoto': 'Change profile photo',
    'removePhoto': 'Remove profile photo',
    'profileSettings': 'Profile settings',
    'removeFailed':
        'The local photo could not be removed. Your data was unchanged.',
    'checkInFailed': 'The check-in could not be opened. Try again.',
    'cameraFailed':
        'Could not start the camera. Check that it is connected and allowed in Windows privacy settings.',
    'captureFailed': 'Could not capture the photo. Try again.',
    'takeProfilePhoto': 'Take profile photo',
    'cancel': 'Cancel',
    'capture': 'Capture',
    'cameraUnavailable':
        'Camera capture is unavailable on this device. Choose a saved image instead.',
    'imageTooLarge': 'Choose an image smaller than 5 MB.',
    'imageOpenFailed': 'The image could not be opened or saved locally.',
  },
  'ar': {
    'takePhotoNow': 'التقاط صورة الآن',
    'addPhoto': 'إضافة صورة شخصية',
    'changePhoto': 'تغيير الصورة الشخصية',
    'removePhoto': 'حذف الصورة الشخصية',
    'profileSettings': 'إعدادات الملف',
    'removeFailed': 'تعذر حذف الصورة المحلية. لم تتغير بياناتك.',
    'checkInFailed': 'تعذر فتح القياس الآن. حاول مرة أخرى.',
    'cameraFailed':
        'تعذر تشغيل الكاميرا. تحقق من توصيلها ومن سماح Windows للتطبيق باستخدامها.',
    'captureFailed': 'تعذر التقاط الصورة. حاول مرة أخرى.',
    'takeProfilePhoto': 'التقاط صورة شخصية',
    'cancel': 'إلغاء',
    'capture': 'التقاط',
    'cameraUnavailable':
        'التصوير المباشر غير متاح على هذا الجهاز. اختر صورة من الجهاز.',
    'imageTooLarge': 'اختر صورة أصغر من 5 ميجابايت.',
    'imageOpenFailed': 'تعذر فتح الصورة أو حفظها محليًا.',
  },
  'fr': {
    'takePhotoNow': 'Prendre une photo maintenant',
    'addPhoto': 'Ajouter une photo de profil',
    'changePhoto': 'Modifier la photo de profil',
    'removePhoto': 'Supprimer la photo de profil',
    'profileSettings': 'Paramètres du profil',
    'removeFailed':
        'Impossible de supprimer la photo locale. Vos données n’ont pas été modifiées.',
    'checkInFailed': 'Impossible d’ouvrir la saisie. Réessayez.',
    'cameraFailed':
        'Impossible de démarrer la caméra. Vérifiez sa connexion et l’autorisation dans les paramètres de confidentialité de Windows.',
    'captureFailed': 'Impossible de prendre la photo. Réessayez.',
    'takeProfilePhoto': 'Prendre une photo de profil',
    'cancel': 'Annuler',
    'capture': 'Prendre',
    'cameraUnavailable':
        'La prise de vue directe n’est pas disponible sur cet appareil. Choisissez une image enregistrée.',
    'imageTooLarge': 'Choisissez une image de moins de 5 Mo.',
    'imageOpenFailed':
        'Impossible d’ouvrir ou d’enregistrer l’image localement.',
  },
  'es': {
    'takePhotoNow': 'Hacer una foto ahora',
    'addPhoto': 'Añadir foto de perfil',
    'changePhoto': 'Cambiar foto de perfil',
    'removePhoto': 'Eliminar foto de perfil',
    'profileSettings': 'Ajustes del perfil',
    'removeFailed':
        'No se pudo eliminar la foto local. Tus datos no cambiaron.',
    'checkInFailed': 'No se pudo abrir el registro. Inténtalo de nuevo.',
    'cameraFailed':
        'No se pudo iniciar la cámara. Comprueba que esté conectada y permitida en la privacidad de Windows.',
    'captureFailed': 'No se pudo hacer la foto. Inténtalo de nuevo.',
    'takeProfilePhoto': 'Hacer foto de perfil',
    'cancel': 'Cancelar',
    'capture': 'Capturar',
    'cameraUnavailable':
        'La cámara no está disponible en este dispositivo. Elige una imagen guardada.',
    'imageTooLarge': 'Elige una imagen de menos de 5 MB.',
    'imageOpenFailed': 'No se pudo abrir ni guardar la imagen localmente.',
  },
  'tr': {
    'takePhotoNow': 'Şimdi fotoğraf çek',
    'addPhoto': 'Profil fotoğrafı ekle',
    'changePhoto': 'Profil fotoğrafını değiştir',
    'removePhoto': 'Profil fotoğrafını kaldır',
    'profileSettings': 'Profil ayarları',
    'removeFailed': 'Yerel fotoğraf kaldırılamadı. Verileriniz değişmedi.',
    'checkInFailed': 'Kayıt açılamadı. Tekrar deneyin.',
    'cameraFailed':
        'Kamera başlatılamadı. Bağlantıyı ve Windows gizlilik izinlerini kontrol edin.',
    'captureFailed': 'Fotoğraf çekilemedi. Tekrar deneyin.',
    'takeProfilePhoto': 'Profil fotoğrafı çek',
    'cancel': 'İptal',
    'capture': 'Çek',
    'cameraUnavailable':
        'Bu cihazda doğrudan kamera kullanılamıyor. Kayıtlı bir görüntü seçin.',
    'imageTooLarge': '5 MB’tan küçük bir görüntü seçin.',
    'imageOpenFailed': 'Görüntü açılamadı veya yerel olarak kaydedilemedi.',
  },
};
