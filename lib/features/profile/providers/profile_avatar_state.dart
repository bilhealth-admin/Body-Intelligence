import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import '../../commerce/providers/commerce_providers.dart';
import '../../../app/environment/app_environment.dart';
import 'user_profile_provider.dart';

/// Loading is not deletion. Only an authoritative data event clears a photo.
/// One holder is shared by all account surfaces; changing owners retires it.
class ProfileAvatarState {
  const ProfileAvatarState(this.owner, this.bytes, this.url);
  final String? owner;
  final Uint8List? bytes;
  final String? url;
}

final profileAvatarStateProvider =
    NotifierProvider<ProfileAvatarStateNotifier, ProfileAvatarState>(
      ProfileAvatarStateNotifier.new,
    );

class ProfileAvatarStateNotifier extends Notifier<ProfileAvatarState> {
  ProfileAvatarState _last = const ProfileAvatarState(null, null, null);
  AppLifecycleListener? _lifecycle;
  @override
  ProfileAvatarState build() {
    _lifecycle ??= AppLifecycleListener(
      onResume: () {
        if (ref.mounted) ref.invalidate(profilePhotoPublicUrlProvider);
      },
    );
    ref.onDispose(() {
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    final preferences = ref.watch(preferencesRepositoryProvider);
    final owner = AppEnvironment.supabaseRuntimeReady
        ? ref.watch(verifiedEntitlementOwnerIdProvider)
        : preferences.localOwnerId;
    final local = ref.watch(profilePhotoProvider);
    final remote = ref.watch(profilePhotoPublicUrlProvider);
    final metadata = ref.watch(profilePhotoMetadataProvider);
    if (owner != _last.owner || preferences.localOwnerId != owner) {
      _last = ProfileAvatarState(owner, null, null);
    }
    if (preferences.localOwnerId != owner) return _last;
    if (metadata.value?['profilePhotoDeleted'] == 'true') {
      return _last = ProfileAvatarState(owner, null, null);
    }
    final bytes = !local.isLoading && local.hasValue
        ? local.value
        : _last.bytes;
    final url = !remote.isLoading && remote.hasValue ? remote.value : _last.url;
    return _last = ProfileAvatarState(owner, bytes, url);
  }
}
