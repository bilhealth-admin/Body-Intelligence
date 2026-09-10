part of 'premium_profile_page.dart';

extension _PremiumProfileActions on _PremiumProfilePageState {
  Future<void> hydrate(
    UserProfileData profile,
    double effectiveCurrentWeight,
    ProfileAuthIdentity authIdentity,
  ) async {
    final requestedKey = authIdentity.hydrationKey(profile.uuid);
    if ((loaded && hydrationIdentityKey == requestedKey) || hydrating) {
      return;
    }
    _updateState(() {
      hydrating = true;
      hydrateError = null;
    });
    try {
      final repo = ref.read(preferencesRepositoryProvider);
      if (repo.localOwnerId != authIdentity.ownerId) {
        throw StateError('Profile storage owner does not match auth owner.');
      }
      final values = await Future.wait([
        repo.get('displayName'),
        repo.get('profileLocation'),
        repo.get('profilePostalCode'),
        repo.get('profileTimeZone'),
        repo.get('profileEmail'),
        repo.get('units'),
        repo.get('profileDateOfBirth'),
        repo.get('countryRegion'),
        repo.get('cityName'),
        repo.get('timezoneName'),
        repo.get('units.height'),
      ]);
      if (!mounted) return;
      final currentIdentity = ref.read(profileAuthIdentityProvider).value;
      final liveOwner = AppEnvironment.supabaseRuntimeReady
          ? Supabase.instance.client.auth.currentUser?.id.trim()
          : null;
      if (currentIdentity?.ownerId != authIdentity.ownerId ||
          repo.localOwnerId != authIdentity.ownerId ||
          (AppEnvironment.supabaseRuntimeReady &&
              liveOwner != authIdentity.ownerId)) {
        return;
      }
      _updateState(() {
        name = values[0]?.trim().isNotEmpty == true ? values[0]!.trim() : 'BIL';
        final canonicalLocation = [values[8], values[7]]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join(', ');
        location = canonicalLocation.isNotEmpty
            ? canonicalLocation
            : values[1] ?? '';
        postalCode = values[2] ?? '';
        timeZone = values[9]?.trim().isNotEmpty == true
            ? values[9]!
            : values[3]?.trim().isNotEmpty == true
            ? values[3]!
            : DateTime.now().timeZoneName;
        final storedEmail = values[4];
        // A live authenticated session is the identity authority. A cached
        // email can only support local/offline mode and must never cover a
        // different signed-in account.
        email = resolveAuthoritativeProfileEmail(
          authIdentity: authIdentity,
          cachedEmail: storedEmail,
        );
        units = values[10] == 'Feet/Inches' || values[5] == 'imperial'
            ? 'imperial'
            : 'metric';
        dateOfBirth = DateTime.tryParse(values[6] ?? '');
        gender = profile.gender;
        activity = profile.activityLevel;
        age = profile.age;
        height = profile.height;
        weight = effectiveCurrentWeight;
        target = profile.targetWeight;
        exercises = profile.exercises;
        hydrationIdentityKey = requestedKey;
        loaded = true;
      });
    } catch (error) {
      if (mounted) _updateState(() => hydrateError = error);
    } finally {
      if (mounted) _updateState(() => hydrating = false);
    }
  }

  Future<void> pickPhoto({bool recoveredOnly = false}) async {
    try {
      final service = ref.read(profilePhotoServiceProvider);
      ProfilePhotoSaveResult? result;
      if (recoveredOnly) {
        result = await service.chooseAndSave(recoveredOnly: recoveredOnly);
      } else {
        final source = await showModalBottomSheet<_ProfilePhotoSource>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('profile-photo-camera-action'),
                  leading: const BilSemanticIconBadge(
                    kind: BilSemanticIconKind.profile,
                    iconOverride: Icons.photo_camera_outlined,
                    appleIconOverride: CupertinoIcons.camera,
                  ),
                  title: Text(tr('Take a photo', 'التقاط صورة')),
                  onTap: () =>
                      Navigator.pop(sheetContext, _ProfilePhotoSource.camera),
                ),
                ListTile(
                  key: const Key('profile-photo-library-action'),
                  leading: const BilSemanticIconBadge(
                    kind: BilSemanticIconKind.profile,
                    iconOverride: Icons.photo_library_outlined,
                    appleIconOverride: CupertinoIcons.photo_on_rectangle,
                  ),
                  title: Text(tr('Choose from device', 'اختيار من الجهاز')),
                  onTap: () =>
                      Navigator.pop(sheetContext, _ProfilePhotoSource.library),
                ),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: Text(tr('Cancel', 'إلغاء')),
                  onTap: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        );
        if (source == null || !mounted) return;
        if (source == _ProfilePhotoSource.camera) {
          if (!await _ensureProfileCameraPermission() || !mounted) return;
          final image = await ref.read(profileCameraLauncherProvider)(
            context,
            title: tr('Take a photo', 'التقاط صورة'),
            captureLabel: tr('Take a photo', 'التقاط صورة'),
          );
          if (image == null || !mounted) return;
          result = await service.save(
            await image.readAsBytes(),
            contentType: 'image/jpeg',
          );
        } else {
          result = await service.chooseAndSave();
        }
      }
      if (!mounted || result == null) return;
      if (!result.cloudSynced && AppEnvironment.supabaseRuntimeReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Your photo is saved on this device. Community sync will retry when the cloud is available.',
                'تم حفظ صورتك على هذا الجهاز. ستتم إعادة مزامنتها مع المجتمع عند توفر السحابة.',
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
            tr(
              'Choose an image smaller than 5 MB.',
              'اختر صورة أصغر من 5 ميجابايت.',
            ),
          ),
        ),
      );
    } on ProfilePhotoIdentityChangedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Your account changed. Open your profile and choose the photo again.',
              'تغيّر حسابك. افتح ملفك واختر الصورة مجددًا.',
            ),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'The photo picker could not open or read that image. Check Photos access and try again.',
              'تعذر فتح منتقي الصور أو قراءة هذه الصورة. تحقق من إذن الصور وحاول مجددًا.',
            ),
          ),
        ),
      );
    }
  }

  Future<bool> _ensureProfileCameraPermission() async {
    final policy = ref.read(profileRuntimePermissionPolicyProvider);
    final current = await policy.status(BilRuntimeCapability.camera);
    if (current == BilRuntimePermissionState.granted) return true;
    if (!mounted) return false;
    final blocked =
        current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: Text(
          tr(
            blocked ? 'Camera access is off' : 'Allow camera for this action?',
            blocked
                ? 'الوصول إلى الكاميرا متوقف'
                : 'السماح بالكاميرا لهذا الإجراء؟',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Not now', 'ليس الآن')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              tr(
                blocked ? 'Open system settings' : 'Continue',
                blocked ? 'فتح إعدادات النظام' : 'متابعة',
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

  Future<String?> edit(
    String title,
    String value, {
    bool number = false,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: InputDecoration(labelText: title),
              onSubmitted: (value) => Navigator.pop(sheetContext, value.trim()),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(sheetContext, controller.text.trim()),
              child: Text(tr('Apply', 'اعتماد')),
            ),
          ],
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    return result;
  }

  Future<T?> choose<T>(String title, Map<T, String> options) =>
      showModalBottomSheet<T>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final option in options.entries)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(
                  option.value,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, option.key),
              ),
            const SizedBox(height: 12),
          ],
        ),
      );

  Future<void> showHealthGoalDetails(GoalTimelineEstimate estimate) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: GoalTimelineCard(estimate: estimate),
        ),
      );

  Future<bool> save(
    UserProfileData profile,
    Goal? activeGoal, {
    bool showSuccess = true,
  }) async {
    if (saving) return false;
    final authIdentity = ref.read(profileAuthIdentityProvider).value;
    final database = ref.read(databaseProvider);
    if (authIdentity == null ||
        database.localOwnerId != authIdentity.ownerId ||
        hydrationIdentityKey != authIdentity.hydrationKey(profile.uuid)) {
      return false;
    }
    final snapshot = (
      name: name,
      gender: gender,
      activity: activity,
      location: location,
      postalCode: postalCode,
      timeZone: timeZone,
      email: email,
      units: units,
      dateOfBirth: dateOfBirth,
      age: age,
      height: height,
      weight: weight,
      target: target,
      exercises: exercises,
    );
    _updateState(() => saving = true);
    try {
      final authoritativeCurrent =
          ref.read(effectiveCurrentWeightProvider) ?? profile.currentWeight;
      final currentChanged =
          (snapshot.weight - authoritativeCurrent).abs() >= 0.0001;
      final goalType = goalTypeForUpdate(
        currentWeightKg: snapshot.weight,
        targetWeightKg: snapshot.target,
        storedGoalType: activeGoal?.type,
        storedTargetWeightKg: activeGoal?.targetWeight,
      );
      await database.transaction(() async {
        await ref
            .read(userProfileRepositoryProvider)
            .save(
              gender: snapshot.gender,
              age: snapshot.age,
              height: snapshot.height,
              currentWeight: snapshot.weight,
              targetWeight: snapshot.target,
              activityLevel: snapshot.activity,
              exercises: snapshot.exercises,
              medicalConditions: profile.medicalConditions,
              waist: profile.waist,
              neck: profile.neck,
              chest: profile.chest,
              arm: profile.arm,
              thigh: profile.thigh,
            );
        if (currentChanged) {
          await ref
              .read(weightRepositoryProvider)
              .addWeight(
                snapshot.weight,
                date: DateTime.now(),
                measurementContext: 'unspecified',
              );
        }
        await ref
            .read(goalRepositoryProvider)
            .save(
              uuid: activeGoal?.uuid,
              profileUuid: profile.uuid,
              type: goalType,
              targetWeight: snapshot.target,
              targetDate: activeGoal?.targetDate,
            );
        await ref
            .read(preferencesRepositoryProvider)
            .setManyInCurrentTransaction({
              ...DisplayNameSync.localEdit(snapshot.name),
              'profileLocation': snapshot.location,
              'profilePostalCode': snapshot.postalCode,
              'profileTimeZone': snapshot.timeZone,
              'profileEmail': snapshot.email,
              'units': snapshot.units,
              'profileDateOfBirth':
                  snapshot.dateOfBirth?.toIso8601String() ?? '',
            });
      });
      unawaited(ref.read(displayNameSyncProvider).synchronize());
      ref.invalidate(userProfileProvider);
      ref.invalidate(activeGoalProvider);
      ref.invalidate(latestWeightProvider);
      ref.invalidate(todayWeightProvider);
      ref.invalidate(weightHistoryProvider);
      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Your health profile is updated.',
                'تم تحديث ملفك الصحي بأمان.',
              ),
            ),
          ),
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Your health profile could not be saved. Try again.',
                'تعذّر حفظ ملفك الصحي. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        _updateState(() => saving = false);
      }
    }
  }
}

enum _ProfilePhotoSource { camera, library }
