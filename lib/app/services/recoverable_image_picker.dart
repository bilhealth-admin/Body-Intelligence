import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../environment/app_environment.dart';

enum BilImagePickerPurpose {
  profilePhoto,
  communityPost,
  mealPhoto,
  coachFoodPhoto,
  barcodeGallery,
}

@immutable
class BilRecoveredImageIntent {
  const BilRecoveredImageIntent({
    required this.purpose,
    required this.ownerScope,
    required this.source,
    required this.recoveryToken,
  });

  final BilImagePickerPurpose purpose;
  final String ownerScope;
  final ImageSource source;
  final String recoveryToken;
}

/// Only journeys that can safely re-enter without synthesizing user intent
/// receive an automatic post-startup destination.
///
/// Coach photos, community composition and barcode-gallery scanning return
/// null: their surrounding draft/scanner state cannot be reconstructed from a
/// bare image. Their recovered file remains quarantined for the same explicit
/// journey instead of being delivered to an unrelated screen.
class BilImagePickerResumePolicy {
  const BilImagePickerResumePolicy._();

  static String? locationFor(
    BilImagePickerPurpose purpose, {
    required bool hasMealPhotoEntitlement,
  }) => switch (purpose) {
    BilImagePickerPurpose.profilePhoto =>
      '/profile-settings?resume=android-image-picker',
    BilImagePickerPurpose.mealPhoto when hasMealPhotoEntitlement =>
      '/daily-log?action=recovered-photo&from=%2Fdashboard',
    BilImagePickerPurpose.mealPhoto ||
    BilImagePickerPurpose.coachFoodPhoto ||
    BilImagePickerPurpose.communityPost ||
    BilImagePickerPurpose.barcodeGallery => null,
  };
}

/// Preserves the result of Android's external photo picker when Android
/// destroys and recreates the Flutter activity under memory pressure.
///
/// Only a small purpose marker is persisted. The recovered [XFile] remains in
/// memory and can be consumed only by the journey that launched the picker, so
/// a profile photo can never be handed to a community or meal flow.
class BilRecoverableImagePicker {
  BilRecoverableImagePicker({
    ImagePicker? picker,
    Future<SharedPreferences> Function()? preferences,
    String Function()? ownerScope,
    DateTime Function()? clock,
    bool? isAndroid,
  }) : _picker = picker ?? ImagePicker(),
       _preferences = preferences ?? SharedPreferences.getInstance,
       _ownerScope = ownerScope ?? currentOwnerScope,
       _clock = clock ?? DateTime.now,
       _isAndroidOverride = isAndroid;

  static final instance = BilRecoverableImagePicker();

  @visibleForTesting
  static const pendingPurposePreferenceKey =
      'bil.pending_android_image_picker_purpose';

  static const _markerVersion = 2;
  static const _maximumRecoveryAge = Duration(hours: 24);
  static const _maximumFutureClockSkew = Duration(minutes: 5);
  static const _localOwnerScope = 'local-device';

  final ImagePicker _picker;
  final Future<SharedPreferences> Function() _preferences;
  final String Function() _ownerScope;
  final DateTime Function() _clock;
  final bool? _isAndroidOverride;
  _RecoveredImage? _recovered;
  Future<void>? _startupRecovery;

  bool get _usesAndroidRecovery =>
      _isAndroidOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static String ownerScopeForUserId(String? userId) {
    final normalized = userId?.trim() ?? '';
    return normalized.isEmpty ? _localOwnerScope : 'account:$normalized';
  }

  static String currentOwnerScope() {
    if (!AppEnvironment.supabaseRuntimeReady) {
      return _localOwnerScope;
    }
    try {
      return ownerScopeForUserId(Supabase.instance.client.auth.currentUser?.id);
    } on Object {
      // Startup may be between plugin registration and cloud initialization.
      // A page cannot launch the picker until startup settles, but this
      // fallback keeps tests and local-only builds deterministic.
      return _localOwnerScope;
    }
  }

  @visibleForTesting
  static String pendingMarkerForTesting({
    required BilImagePickerPurpose purpose,
    required String ownerScope,
    ImageSource source = ImageSource.gallery,
    String recoveryToken = 'test-recovery-token',
    DateTime? launchedAt,
  }) => _PendingImagePickerMarker(
    purpose: purpose,
    ownerScope: ownerScope,
    source: source,
    recoveryToken: recoveryToken,
    launchedAt: launchedAt ?? DateTime.now(),
  ).encode();

  /// Must be invoked during startup, after Flutter plugins are registered.
  Future<void> recoverAtStartup() {
    if (!_usesAndroidRecovery) return Future<void>.value();
    return _startupRecovery ??= _recoverLostDataSafely();
  }

  /// Returns the pending Android result only when it belongs to [ownerScope].
  /// Looking does not consume the file; startup uses this to settle access
  /// before claiming a one-shot resume route.
  Future<BilRecoveredImageIntent?> pendingRecoveryForOwner(
    String ownerScope,
  ) async {
    if (!_usesAndroidRecovery) return null;
    await recoverAtStartup();
    final recovered = _recovered;
    if (recovered == null) return null;
    if (recovered.intent.ownerScope != ownerScope) {
      // Never retain another account's selected media in a newly active
      // account scope. The Android temporary file is not owned by BIL, so only
      // the in-memory reference is discarded.
      _recovered = null;
      return null;
    }
    return recovered.intent;
  }

  /// Claims automatic navigation exactly once while leaving the file for the
  /// destination page to consume. Rebuilding StartupPage cannot replay it.
  Future<bool> claimResume({
    required BilRecoveredImageIntent intent,
    required String ownerScope,
  }) async {
    final recovered = _recovered;
    if (recovered == null ||
        recovered.resumeClaimed ||
        recovered.intent.recoveryToken != intent.recoveryToken ||
        recovered.intent.purpose != intent.purpose ||
        recovered.intent.ownerScope != ownerScope) {
      return false;
    }
    recovered.resumeClaimed = true;
    return true;
  }

  /// Consumes a recovered image without ever opening a new system picker.
  /// Resume routes must use this method so stale URLs cannot launch a picker or
  /// create a route loop after the recovered result has already been handled.
  Future<XFile?> takeRecoveredImage(BilImagePickerPurpose purpose) async {
    if (!_usesAndroidRecovery) return null;
    await recoverAtStartup();
    return _takeRecoveredImage(purpose, _ownerScope());
  }

  Future<XFile?> pickImage({
    required BilImagePickerPurpose purpose,
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (_usesAndroidRecovery) {
      await recoverAtStartup();
      final ownerScope = _ownerScope();
      final recovered = _takeRecoveredImage(purpose, ownerScope);
      if (recovered != null) {
        return recovered;
      }

      SharedPreferences? preferences;
      final recoveryToken =
          '${_clock().toUtc().microsecondsSinceEpoch}-${purpose.name}';
      try {
        preferences = await _preferences();
        await preferences.setString(
          pendingPurposePreferenceKey,
          _PendingImagePickerMarker(
            purpose: purpose,
            ownerScope: ownerScope,
            source: source,
            recoveryToken: recoveryToken,
            launchedAt: _clock(),
          ).encode(),
        );
      } on Object {
        // Preference failure must not make the photo picker unusable. This
        // invocation simply cannot be recovered if Android kills the activity.
      }

      try {
        return await _picker.pickImage(
          source: source,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: imageQuality,
          preferredCameraDevice: preferredCameraDevice,
          requestFullMetadata: requestFullMetadata,
        );
      } finally {
        try {
          final pending = preferences?.getString(pendingPurposePreferenceKey);
          if (_PendingImagePickerMarker.tryDecode(pending)?.recoveryToken ==
              recoveryToken) {
            await preferences?.remove(pendingPurposePreferenceKey);
          }
        } on Object {
          // A stale marker is harmless and is cleared by the next startup
          // recovery attempt.
        }
      }
    }

    return _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      preferredCameraDevice: preferredCameraDevice,
      requestFullMetadata: requestFullMetadata,
    );
  }

  Future<void> _recoverLostDataSafely() async {
    try {
      final preferences = await _preferences();
      final pending = _PendingImagePickerMarker.tryDecode(
        preferences.getString(pendingPurposePreferenceKey),
      );
      final response = await _picker.retrieveLostData();
      await preferences.remove(pendingPurposePreferenceKey);
      if (pending == null ||
          !_isFresh(pending.launchedAt) ||
          response.isEmpty ||
          response.exception != null ||
          response.type != RetrieveType.image) {
        return;
      }

      final files = response.files;
      final recovered = files != null && files.isNotEmpty
          ? files.last
          : response.file;
      if (recovered == null || !await _isReadable(recovered)) return;
      _recovered = _RecoveredImage(
        file: recovered,
        intent: BilRecoveredImageIntent(
          purpose: pending.purpose,
          ownerScope: pending.ownerScope,
          source: pending.source,
          recoveryToken: pending.recoveryToken,
        ),
      );
    } on Object {
      // Recovery is best-effort. Keep the purpose marker so another process
      // restart can retry, while normal picking remains available now.
    }
  }

  XFile? _takeRecoveredImage(BilImagePickerPurpose purpose, String ownerScope) {
    final recovered = _recovered;
    if (recovered == null) return null;
    if (recovered.intent.ownerScope != ownerScope) {
      _recovered = null;
      return null;
    }
    if (recovered.intent.purpose != purpose) return null;
    // Remove before returning so every result is single-consumption even if
    // validation/analysis on the destination page later throws.
    _recovered = null;
    return recovered.file;
  }

  bool _isFresh(DateTime launchedAt) {
    final age = _clock().toUtc().difference(launchedAt.toUtc());
    return age.inMicroseconds >= -_maximumFutureClockSkew.inMicroseconds &&
        age <= _maximumRecoveryAge;
  }

  Future<bool> _isReadable(XFile file) async {
    try {
      return await file.length() > 0;
    } on Object {
      return false;
    }
  }
}

final class _RecoveredImage {
  _RecoveredImage({required this.file, required this.intent});

  final XFile file;
  final BilRecoveredImageIntent intent;
  bool resumeClaimed = false;
}

final class _PendingImagePickerMarker {
  const _PendingImagePickerMarker({
    required this.purpose,
    required this.ownerScope,
    required this.source,
    required this.recoveryToken,
    required this.launchedAt,
  });

  final BilImagePickerPurpose purpose;
  final String ownerScope;
  final ImageSource source;
  final String recoveryToken;
  final DateTime launchedAt;

  String encode() => jsonEncode(<String, Object>{
    'version': BilRecoverableImagePicker._markerVersion,
    'purpose': purpose.name,
    'ownerScope': ownerScope,
    'source': source.name,
    'recoveryToken': recoveryToken,
    'launchedAt': launchedAt.toUtc().toIso8601String(),
  });

  static _PendingImagePickerMarker? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['version'] != BilRecoverableImagePicker._markerVersion) {
        // Version-one markers contained only a purpose and therefore cannot
        // be bound to an account. Fail closed instead of guessing ownership.
        return null;
      }
      final purpose = BilImagePickerPurpose.values
          .where((candidate) => candidate.name == decoded['purpose'])
          .firstOrNull;
      final source = ImageSource.values
          .where((candidate) => candidate.name == decoded['source'])
          .firstOrNull;
      final ownerScope = decoded['ownerScope'];
      final recoveryToken = decoded['recoveryToken'];
      final launchedAt = DateTime.tryParse(
        decoded['launchedAt'] as String? ?? '',
      );
      if (purpose == null ||
          source == null ||
          ownerScope is! String ||
          ownerScope.trim().isEmpty ||
          recoveryToken is! String ||
          recoveryToken.trim().isEmpty ||
          launchedAt == null) {
        return null;
      }
      return _PendingImagePickerMarker(
        purpose: purpose,
        ownerScope: ownerScope,
        source: source,
        recoveryToken: recoveryToken,
        launchedAt: launchedAt,
      );
    } on Object {
      return null;
    }
  }
}
