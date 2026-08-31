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

  Future<void> pickPhoto() async {
    try {
      final result = await ref
          .read(profilePhotoServiceProvider)
          .chooseAndSave();
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
    }
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
                title: Text(option.value),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, option.key),
              ),
            const SizedBox(height: 12),
          ],
        ),
      );

  Future<void> save(UserProfileData profile, Goal? activeGoal) async {
    if (saving) return;
    final authIdentity = ref.read(profileAuthIdentityProvider).value;
    final database = ref.read(databaseProvider);
    if (authIdentity == null ||
        database.localOwnerId != authIdentity.ownerId ||
        hydrationIdentityKey != authIdentity.hydrationKey(profile.uuid)) {
      return;
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
              'displayName': snapshot.name,
              'profileLocation': snapshot.location,
              'profilePostalCode': snapshot.postalCode,
              'profileTimeZone': snapshot.timeZone,
              'profileEmail': snapshot.email,
              'units': snapshot.units,
              'profileDateOfBirth':
                  snapshot.dateOfBirth?.toIso8601String() ?? '',
            });
      });
      ref.invalidate(userProfileProvider);
      ref.invalidate(activeGoalProvider);
      ref.invalidate(latestWeightProvider);
      ref.invalidate(todayWeightProvider);
      ref.invalidate(weightHistoryProvider);
      if (mounted) {
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
    } finally {
      if (mounted) {
        _updateState(() => saving = false);
      }
    }
  }
}
