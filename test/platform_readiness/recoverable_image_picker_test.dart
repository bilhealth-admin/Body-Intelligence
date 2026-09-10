import 'dart:io';
import 'dart:typed_data';

import 'package:body_intelligence_log/app/services/recoverable_image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Coach photo recovery cannot leak into meals or another journey',
    () async {
      final now = DateTime.utc(2026, 9, 9, 12);
      const ownerScope = 'account:coach-member';
      final directory = await Directory.systemTemp.createTemp(
        'bil-coach-picker-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/coach.jpg');
      await file.writeAsBytes(const [0xff, 0xd8, 0xff, 0xd9]);
      final xFile = XFile(file.path);
      SharedPreferences.setMockInitialValues({
        BilRecoverableImagePicker.pendingPurposePreferenceKey:
            BilRecoverableImagePicker.pendingMarkerForTesting(
              purpose: BilImagePickerPurpose.coachFoodPhoto,
              ownerScope: ownerScope,
              launchedAt: now,
            ),
      });
      final plugin = _FakeImagePicker(
        lost: LostDataResponse(
          file: xFile,
          files: [xFile],
          type: RetrieveType.image,
        ),
      );
      final picker = BilRecoverableImagePicker(
        picker: plugin,
        isAndroid: true,
        ownerScope: () => ownerScope,
        clock: () => now,
      );
      await picker.recoverAtStartup();
      expect(
        await picker.takeRecoveredImage(BilImagePickerPurpose.mealPhoto),
        isNull,
      );
      expect(
        await picker.takeRecoveredImage(BilImagePickerPurpose.profilePhoto),
        isNull,
      );
      expect(
        BilImagePickerResumePolicy.locationFor(
          BilImagePickerPurpose.coachFoodPhoto,
          hasMealPhotoEntitlement: true,
        ),
        isNull,
      );
      expect(
        (await picker.pickImage(
          purpose: BilImagePickerPurpose.coachFoodPhoto,
          source: ImageSource.gallery,
        ))?.path,
        file.path,
      );
      expect(plugin.pickCalls, 0);
      expect(
        await picker.takeRecoveredImage(BilImagePickerPurpose.coachFoodPhoto),
        isNull,
      );
    },
  );

  test(
    'startup recovery is returned only to the originating image journey',
    () async {
      final now = DateTime.utc(2026, 9, 4, 12);
      const ownerScope = 'account:member-a';
      final directory = await Directory.systemTemp.createTemp(
        'bil-picker-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final recoveredFile = File('${directory.path}/recovered.jpg');
      await recoveredFile.writeAsBytes(const [0xff, 0xd8, 0xff, 0xd9]);
      final xFile = XFile(recoveredFile.path);
      SharedPreferences.setMockInitialValues({
        BilRecoverableImagePicker.pendingPurposePreferenceKey:
            BilRecoverableImagePicker.pendingMarkerForTesting(
              purpose: BilImagePickerPurpose.communityPost,
              ownerScope: ownerScope,
              launchedAt: now,
            ),
      });
      final plugin = _FakeImagePicker(
        lost: LostDataResponse(
          file: xFile,
          files: [xFile],
          type: RetrieveType.image,
        ),
      );
      final picker = BilRecoverableImagePicker(
        picker: plugin,
        isAndroid: true,
        ownerScope: () => ownerScope,
        clock: () => now,
      );

      await picker.recoverAtStartup();
      final unrelated = await picker.pickImage(
        purpose: BilImagePickerPurpose.barcodeGallery,
        source: ImageSource.gallery,
      );
      final recovered = await picker.pickImage(
        purpose: BilImagePickerPurpose.communityPost,
        source: ImageSource.gallery,
      );

      expect(plugin.retrieveCalls, 1);
      expect(plugin.pickCalls, 1);
      expect(unrelated, isNull);
      expect(recovered?.path, recoveredFile.path);
      expect(
        (await SharedPreferences.getInstance()).getString(
          BilRecoverableImagePicker.pendingPurposePreferenceKey,
        ),
        isNull,
      );
    },
  );

  test('a recovered file is discarded across account scopes', () async {
    final now = DateTime.utc(2026, 9, 4, 12);
    final directory = await Directory.systemTemp.createTemp('bil-picker-test-');
    addTearDown(() => directory.delete(recursive: true));
    final recoveredFile = File('${directory.path}/private.jpg');
    await recoveredFile.writeAsBytes(const [0xff, 0xd8, 0xff, 0xd9]);
    final xFile = XFile(recoveredFile.path);
    SharedPreferences.setMockInitialValues({
      BilRecoverableImagePicker.pendingPurposePreferenceKey:
          BilRecoverableImagePicker.pendingMarkerForTesting(
            purpose: BilImagePickerPurpose.profilePhoto,
            ownerScope: 'account:member-a',
            launchedAt: now,
          ),
    });
    final picker = BilRecoverableImagePicker(
      picker: _FakeImagePicker(
        lost: LostDataResponse(
          file: xFile,
          files: [xFile],
          type: RetrieveType.image,
        ),
      ),
      isAndroid: true,
      ownerScope: () => 'account:member-b',
      clock: () => now,
    );

    expect(await picker.pendingRecoveryForOwner('account:member-b'), isNull);
    expect(
      await picker.takeRecoveredImage(BilImagePickerPurpose.profilePhoto),
      isNull,
    );
  });

  test('startup resume claim and recovered file are both one-shot', () async {
    final now = DateTime.utc(2026, 9, 4, 12);
    const ownerScope = 'account:member-a';
    final directory = await Directory.systemTemp.createTemp('bil-picker-test-');
    addTearDown(() => directory.delete(recursive: true));
    final recoveredFile = File('${directory.path}/meal.jpg');
    await recoveredFile.writeAsBytes(const [0xff, 0xd8, 0xff, 0xd9]);
    final xFile = XFile(recoveredFile.path);
    SharedPreferences.setMockInitialValues({
      BilRecoverableImagePicker.pendingPurposePreferenceKey:
          BilRecoverableImagePicker.pendingMarkerForTesting(
            purpose: BilImagePickerPurpose.mealPhoto,
            ownerScope: ownerScope,
            launchedAt: now,
          ),
    });
    final picker = BilRecoverableImagePicker(
      picker: _FakeImagePicker(
        lost: LostDataResponse(
          file: xFile,
          files: [xFile],
          type: RetrieveType.image,
        ),
      ),
      isAndroid: true,
      ownerScope: () => ownerScope,
      clock: () => now,
    );

    final intent = await picker.pendingRecoveryForOwner(ownerScope);
    expect(intent?.purpose, BilImagePickerPurpose.mealPhoto);
    expect(
      await picker.claimResume(intent: intent!, ownerScope: ownerScope),
      isTrue,
    );
    expect(
      await picker.claimResume(intent: intent, ownerScope: ownerScope),
      isFalse,
    );
    expect(
      (await picker.takeRecoveredImage(BilImagePickerPurpose.mealPhoto))?.path,
      recoveredFile.path,
    );
    expect(
      await picker.takeRecoveredImage(BilImagePickerPurpose.mealPhoto),
      isNull,
    );
  });

  test('unbound legacy and stale markers fail closed', () async {
    final now = DateTime.utc(2026, 9, 4, 12);
    final file = XFile('unused.jpg', bytes: Uint8List.fromList(const [1]));
    for (final marker in <String>[
      BilImagePickerPurpose.profilePhoto.name,
      BilRecoverableImagePicker.pendingMarkerForTesting(
        purpose: BilImagePickerPurpose.profilePhoto,
        ownerScope: 'account:member-a',
        launchedAt: now.subtract(const Duration(days: 2)),
      ),
    ]) {
      SharedPreferences.setMockInitialValues({
        BilRecoverableImagePicker.pendingPurposePreferenceKey: marker,
      });
      final picker = BilRecoverableImagePicker(
        picker: _FakeImagePicker(
          lost: LostDataResponse(
            file: file,
            files: [file],
            type: RetrieveType.image,
          ),
        ),
        isAndroid: true,
        ownerScope: () => 'account:member-a',
        clock: () => now,
      );

      expect(await picker.pendingRecoveryForOwner('account:member-a'), isNull);
    }
  });

  test(
    'a normally completed or cancelled picker clears its purpose marker',
    () async {
      final plugin = _FakeImagePicker(lost: LostDataResponse.empty());
      final picker = BilRecoverableImagePicker(picker: plugin, isAndroid: true);

      expect(
        await picker.pickImage(
          purpose: BilImagePickerPurpose.profilePhoto,
          source: ImageSource.gallery,
        ),
        isNull,
      );

      expect(plugin.retrieveCalls, 1);
      expect(plugin.pickCalls, 1);
      expect(
        (await SharedPreferences.getInstance()).getString(
          BilRecoverableImagePicker.pendingPurposePreferenceKey,
        ),
        isNull,
      );
    },
  );

  test('resume policy waits for paid Vision and rejects unsafe drafts', () {
    expect(
      BilImagePickerResumePolicy.locationFor(
        BilImagePickerPurpose.profilePhoto,
        hasMealPhotoEntitlement: false,
      ),
      '/profile-settings?resume=android-image-picker',
    );
    expect(
      BilImagePickerResumePolicy.locationFor(
        BilImagePickerPurpose.mealPhoto,
        hasMealPhotoEntitlement: false,
      ),
      isNull,
    );
    expect(
      BilImagePickerResumePolicy.locationFor(
        BilImagePickerPurpose.mealPhoto,
        hasMealPhotoEntitlement: true,
      ),
      '/daily-log?action=recovered-photo&from=%2Fdashboard',
    );
    expect(
      BilImagePickerResumePolicy.locationFor(
        BilImagePickerPurpose.communityPost,
        hasMealPhotoEntitlement: true,
      ),
      isNull,
    );
    expect(
      BilImagePickerResumePolicy.locationFor(
        BilImagePickerPurpose.barcodeGallery,
        hasMealPhotoEntitlement: true,
      ),
      isNull,
    );
  });

  test(
    'non-Android picking does not touch Android lost-data storage',
    () async {
      final direct = XFile('direct.jpg');
      final plugin = _FakeImagePicker(
        lost: LostDataResponse.empty(),
        picked: direct,
      );
      final picker = BilRecoverableImagePicker(
        picker: plugin,
        isAndroid: false,
      );

      final selected = await picker.pickImage(
        purpose: BilImagePickerPurpose.mealPhoto,
        source: ImageSource.gallery,
      );

      expect(selected, same(direct));
      expect(plugin.retrieveCalls, 0);
      expect(plugin.pickCalls, 1);
    },
  );

  test('all external image journeys use startup-safe recovery', () {
    final main = File('lib/main.dart').readAsStringSync();
    final profile = File(
      'lib/features/profile/services/profile_photo_service.dart',
    ).readAsStringSync();
    final community = File(
      'lib/features/community/services/community_post_image_picker.dart',
    ).readAsStringSync();
    final dailyLog = File(
      'lib/features/daily_log/daily_log_capture_actions.dart',
    ).readAsStringSync();
    final barcode = File(
      'lib/features/nutrition/presentation/food_barcode_scanner_page.dart',
    ).readAsStringSync();
    final startup = File(
      'lib/features/startup/startup_page.dart',
    ).readAsStringSync();
    final profilePage = File(
      'lib/features/profile/premium_profile_page.dart',
    ).readAsStringSync();
    final profileActions = File(
      'lib/features/profile/premium_profile_actions.dart',
    ).readAsStringSync();
    final dailyNavigation = File(
      'lib/features/daily_log/daily_log_navigation_actions.dart',
    ).readAsStringSync();
    final coachVision = File(
      'lib/features/intelligence_center/presentation/intelligence_vision_flow.dart',
    ).readAsStringSync();

    expect(main, contains('recoverAtStartup()'));
    expect(profile, contains('BilImagePickerPurpose.profilePhoto'));
    expect(community, contains('BilImagePickerPurpose.communityPost'));
    expect(dailyLog, contains('BilImagePickerPurpose.mealPhoto'));
    expect(barcode, contains('BilImagePickerPurpose.barcodeGallery'));
    expect(startup, contains('pendingRecoveryForOwner(ownerScope)'));
    expect(startup, contains('aiBoostVisionAccessProvider.future'));
    expect(startup, contains('claimResume('));
    expect(startup, contains('intent: intent'));
    expect(profilePage, contains('resumeRecoveredPhoto'));
    expect(profileActions, contains('recoveredOnly: recoveredOnly'));
    expect(dailyNavigation, contains("case 'recovered-photo':"));
    expect(dailyLog, contains('takeRecoveredImage('));
    // Camera stays in-app; the gallery uses a separate, owner-scoped recovery
    // purpose so it cannot deliver a Coach photo to an unrelated journey.
    expect(coachVision, contains('BilCameraCapturePage('));
    expect(coachVision, contains('BilRecoverableImagePicker.instance'));
    expect(coachVision, contains('BilImagePickerPurpose.coachFoodPhoto'));
  });
}

final class _FakeImagePicker extends ImagePicker {
  _FakeImagePicker({required this.lost, this.picked});

  final LostDataResponse lost;
  final XFile? picked;
  int retrieveCalls = 0;
  int pickCalls = 0;

  @override
  Future<LostDataResponse> retrieveLostData() async {
    retrieveCalls += 1;
    return lost;
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickCalls += 1;
    return picked;
  }
}
