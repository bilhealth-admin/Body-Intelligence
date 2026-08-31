import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../profile/services/profile_photo_service.dart';
import '../data/community_repository.dart';
import '../domain/community_identity_projection.dart';
import '../domain/community_models.dart';
import '../domain/community_text_policy.dart';
import 'community_copy.dart';

class CommunityProfilePage extends ConsumerStatefulWidget {
  const CommunityProfilePage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  ConsumerState<CommunityProfilePage> createState() =>
      _CommunityProfilePageState();
}

class _CommunityProfilePageState extends ConsumerState<CommunityProfilePage> {
  CommunityRepository? _repository;
  final _name = TextEditingController();
  final _bio = TextEditingController();
  late Future<void> _loading;
  bool _discoverable = true;
  CommunityProfileVisibility _visibility = CommunityProfileVisibility.friends;
  CommunityMessagePermission _messages = CommunityMessagePermission.friends;
  bool _allowFriendRequests = true;
  bool _allowFollows = false;
  bool _saving = false;
  bool _photoBusy = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository;
      _loading = _load();
      return;
    }
    if (!AppEnvironment.supabaseRuntimeReady) {
      _loading = Future.value();
      return;
    }
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      _loading = Future.value();
      return;
    }
    _repository = CommunityRepository(client);
    _loading = _load();
  }

  Future<void> _load() async {
    final profile = await _repository!.loadMyProfile();
    String? myProfileDisplayName;
    if (widget.repository == null &&
        (profile == null || profile.displayName.trim().isEmpty)) {
      try {
        myProfileDisplayName = await ref
            .read(preferencesRepositoryProvider)
            .get('displayName');
      } on Object {
        // Community remains usable with the privacy-safe BIL alias when the
        // device-local profile store is temporarily unavailable.
      }
    }
    _name.text = CommunityIdentityProjection.resolveDisplayName(
      communityDisplayName: profile?.displayName,
      myProfileDisplayName: myProfileDisplayName,
    );
    if (profile == null) {
      return;
    }
    _bio.text = profile.bio ?? '';
    _avatarUrl = profile.avatarUrl;
    _discoverable = profile.discoverable;
    _visibility = profile.visibility;
    _messages = profile.allowMessagesFrom;
    _allowFriendRequests = profile.allowFriendRequests;
    _allowFollows = profile.allowFollows;
  }

  void _retryLoad() {
    final retry = _load();
    setState(() {
      _loading = retry;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final copy = _CommunityProfileCopy.of(context);
    if (_name.text.trim().length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.invalidName)));
      return;
    }
    setState(() => _saving = true);
    try {
      final localeCode = BilLocalePolicy.canonicalTag(
        Localizations.localeOf(context),
      );
      await _repository!.saveMyProfile(
        displayName: _name.text,
        bio: _bio.text,
        localeCode: localeCode,
        discoverable: _discoverable,
        visibility: _visibility,
        allowFriendRequests: _allowFriendRequests,
        allowFollows: _allowFollows,
        allowMessagesFrom: _messages,
      );
      if (widget.repository == null) {
        await ref
            .read(preferencesRepositoryProvider)
            .mutate(set: {'displayName': _name.text.trim()});
        final photoResult = await ref
            .read(profilePhotoServiceProvider)
            .syncStoredPhotoToCommunity();
        if (photoResult?.publicUrl != null) {
          _avatarUrl = photoResult!.publicUrl;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.saved)));
    } on CommunityTextPolicyException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.localizedMessage(
              Localizations.localeOf(context).toLanguageTag(),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.saveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_photoBusy || _saving) return;
    setState(() => _photoBusy = true);
    try {
      final result = await ref
          .read(profilePhotoServiceProvider)
          .chooseAndSave();
      if (!mounted || result == null) return;
      setState(() {
        if (result.publicUrl != null) _avatarUrl = result.publicUrl;
      });
      if (!result.cloudSynced && AppEnvironment.supabaseRuntimeReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.text(
                'Your photo is saved on this device. Community sync will retry when the cloud is available.',
              ),
            ),
          ),
        );
      }
    } on ProfilePhotoTooLargeException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text('Choose an image smaller than 5 MB.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _CommunityProfileCopy.of(context);
    final localPhoto = widget.repository == null
        ? ref.watch(profilePhotoProvider).value
        : null;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(copy.title)),
        body: _repository == null
            ? _CommunityProfileUnavailable(copy: copy)
            : FutureBuilder<void>(
                future: _loading,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(copy.loadFailed, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _retryLoad,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(copy.retry),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.center,
                        child: Semantics(
                          button: true,
                          label: context.strings.text('Profile photo'),
                          child: InkWell(
                            key: const Key('community-profile-photo'),
                            onTap: _photoBusy ? null : _pickPhoto,
                            customBorder: const CircleBorder(),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                BilAccountAvatar(
                                  radius: 42,
                                  photoBytes: localPhoto,
                                  networkUrl: _avatarUrl,
                                  borderColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                ),
                                PositionedDirectional(
                                  end: -4,
                                  bottom: -4,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: _photoBusy
                                        ? const SizedBox.square(
                                            dimension: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.photo_camera_rounded,
                                            size: 17,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        enabled: !_saving,
                        controller: _name,
                        maxLength: 60,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: copy.displayName,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        enabled: !_saving,
                        controller: _bio,
                        maxLength: 280,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(labelText: copy.bio),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _discoverable,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _discoverable = value),
                        title: Text(copy.discoverable),
                        subtitle: Text(copy.discoverableHelp),
                      ),
                      const Divider(height: 32),
                      DropdownButtonFormField<CommunityProfileVisibility>(
                        initialValue: _visibility,
                        decoration: InputDecoration(
                          labelText: copy.profileVisibility,
                        ),
                        items: CommunityProfileVisibility.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(copy.visibilityLabel(value)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                () => _visibility = value ?? _visibility,
                              ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _allowFriendRequests,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _allowFriendRequests = value),
                        title: Text(copy.allowFriendRequests),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _allowFollows,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _allowFollows = value),
                        title: Text(copy.allowFollows),
                      ),
                      DropdownButtonFormField<CommunityMessagePermission>(
                        initialValue: _messages,
                        decoration: InputDecoration(
                          labelText: copy.messagePermission,
                        ),
                        items: CommunityMessagePermission.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(copy.messageLabel(value)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                () => _messages = value ?? _messages,
                              ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('community-profile-save'),
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(copy.save),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        copy.privacy,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _requestDeletion,
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: Text(copy.deleteAccount),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Future<void> _requestDeletion() async {
    final copy = _CommunityProfileCopy.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.deleteAccount),
        content: Text(copy.deleteAccountHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(copy.requestDeletion),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _repository!.requestAccountDeletion(
        reason: 'user_requested_in_app',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.deletionQueued)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.deletionFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CommunityProfileUnavailable extends StatelessWidget {
  const _CommunityProfileUnavailable({required this.copy});

  final _CommunityProfileCopy copy;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_outlined, size: 52),
              const SizedBox(height: 16),
              Text(
                copy.signInRequired,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                copy.privacy,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CommunityProfileCopy {
  const _CommunityProfileCopy({
    required this.languageCode,
    required this.title,
    required this.displayName,
    required this.bio,
    required this.discoverable,
    required this.discoverableHelp,
    required this.save,
    required this.saved,
    required this.invalidName,
    required this.loadFailed,
    required this.saveFailed,
    required this.privacy,
  });

  factory _CommunityProfileCopy.of(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return switch (language) {
      'ar' => const _CommunityProfileCopy(
        languageCode: 'ar',
        title: 'ملف المجتمع',
        displayName: 'الاسم الظاهر',
        bio: 'نبذة',
        discoverable: 'السماح بالعثور عليّ',
        discoverableHelp: 'يمكن للأعضاء العثور عليك وإرسال طلب صداقة.',
        save: 'حفظ الملف',
        saved: 'تم حفظ ملف المجتمع.',
        invalidName: 'اكتب اسمًا من حرفين على الأقل.',
        loadFailed: 'تعذر تحميل ملف المجتمع بأمان.',
        saveFailed: 'تعذر حفظ الملف الآن. حاول مجددًا.',
        privacy: 'لا تظهر قياساتك أو يومياتك الصحية في ملف المجتمع.',
      ),
      'fr' => const _CommunityProfileCopy(
        languageCode: 'fr',
        title: 'Profil communautaire',
        displayName: 'Nom affiché',
        bio: 'Bio',
        discoverable: 'Autoriser la découverte',
        discoverableHelp: 'Les membres peuvent vous trouver et vous inviter.',
        save: 'Enregistrer',
        saved: 'Profil enregistré.',
        invalidName: 'Saisissez au moins deux caractères.',
        loadFailed: 'Impossible de charger le profil.',
        saveFailed: 'Impossible d’enregistrer maintenant.',
        privacy: 'Vos mesures et journaux de santé restent privés.',
      ),
      'es' => const _CommunityProfileCopy(
        languageCode: 'es',
        title: 'Perfil de comunidad',
        displayName: 'Nombre visible',
        bio: 'Biografía',
        discoverable: 'Permitir que me encuentren',
        discoverableHelp:
            'Los miembros pueden encontrarte y enviarte solicitudes.',
        save: 'Guardar',
        saved: 'Perfil guardado.',
        invalidName: 'Escribe al menos dos caracteres.',
        loadFailed: 'No se pudo cargar el perfil.',
        saveFailed: 'No se pudo guardar ahora.',
        privacy: 'Tus medidas y registros de salud siguen siendo privados.',
      ),
      'tr' => const _CommunityProfileCopy(
        languageCode: 'tr',
        title: 'Topluluk profili',
        displayName: 'Görünen ad',
        bio: 'Hakkında',
        discoverable: 'Bulunmama izin ver',
        discoverableHelp: 'Üyeler sizi bulabilir ve istek gönderebilir.',
        save: 'Kaydet',
        saved: 'Profil kaydedildi.',
        invalidName: 'En az iki karakter yazın.',
        loadFailed: 'Profil yüklenemedi.',
        saveFailed: 'Profil şu anda kaydedilemedi.',
        privacy: 'Sağlık ölçümleriniz ve günlükleriniz gizli kalır.',
      ),
      _ => _CommunityProfileCopy.extended(context),
    };
  }

  factory _CommunityProfileCopy.extended(BuildContext context) {
    String t(String value) => AppLocalizations.of(context).text(value);
    return _CommunityProfileCopy(
      languageCode: BilLocalePolicy.canonicalTag(
        Localizations.localeOf(context),
      ),
      title: t('Community profile'),
      displayName: t('Display name'),
      bio: t('Bio'),
      discoverable: t('Let people find me'),
      discoverableHelp: t('Members can find you and send a friend request.'),
      save: t('Save profile'),
      saved: t('Community profile saved.'),
      invalidName: t('Enter at least two characters.'),
      loadFailed: t('Could not load your community profile safely.'),
      saveFailed: t('Could not save your profile now. Try again.'),
      privacy: t('Your measurements and health logs stay private.'),
    );
  }

  final String languageCode,
      title,
      displayName,
      bio,
      discoverable,
      discoverableHelp;
  final String save, saved, invalidName, loadFailed, saveFailed, privacy;
}

extension _CommunityPrivacyCopy on _CommunityProfileCopy {
  String _t(String en, String ar) =>
      communityTextForLanguage(languageCode, en, ar);
  String get profileVisibility =>
      _t('Who can see my profile', 'من يمكنه رؤية ملفي');
  String get allowFriendRequests =>
      _t('Allow friend requests', 'السماح بطلبات الصداقة');
  String get allowFollows => _t('Allow follows', 'السماح بالمتابعة');
  String get messagePermission => _t('Who can message me', 'من يمكنه مراسلتي');
  String get deleteAccount =>
      _t('Delete account and data', 'حذف الحساب والبيانات');
  String get deleteAccountHelp => _t(
    'Push is disabled immediately and a secure request is queued to permanently delete all account data. This cannot be undone after processing. Deleting BIL does not cancel an App Store or Google Play subscription; cancel it in the device store when needed.',
    'سيتم تعطيل الإشعارات ووضع طلب حذف نهائي وآمن لكل بيانات الحساب. لا يمكن التراجع بعد تنفيذ الطلب. حذف حساب BIL لا يلغي اشتراك App Store أو Google Play؛ ألغِه من متجر الجهاز عند الحاجة.',
  );
  String get cancel => _t('Cancel', 'إلغاء');
  String get requestDeletion => _t('Request deletion', 'طلب الحذف');
  String get deletionQueued =>
      _t('Deletion request queued securely.', 'تم تسجيل طلب الحذف بأمان.');
  String get deletionFailed => _t(
    'Could not request account deletion. Try again.',
    'تعذر طلب حذف الحساب. حاول مجددًا.',
  );
  String get retry => _t('Retry', 'إعادة المحاولة');
  String get signInRequired => _t(
    'Sign in to manage your community profile.',
    'سجّل الدخول لإدارة ملف المجتمع.',
  );
  String visibilityLabel(CommunityProfileVisibility value) => switch (value) {
    CommunityProfileVisibility.public => _t('Public', 'عام'),
    CommunityProfileVisibility.friends => _t('Friends only', 'الأصدقاء فقط'),
    CommunityProfileVisibility.private => _t('Private', 'خاص'),
  };
  String messageLabel(CommunityMessagePermission value) => switch (value) {
    CommunityMessagePermission.friends => _t('Friends only', 'الأصدقاء فقط'),
    CommunityMessagePermission.nobody => _t('Nobody', 'لا أحد'),
  };
}
