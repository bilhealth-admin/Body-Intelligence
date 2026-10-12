import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../domain/coach_context_preferences.dart';

typedef CoachSettingsContext = ({
  PreferencesRepository repository,
  CoachContextPreferences preferences,
});

/// Local settings do not depend on a balance or third-party consent request.
final coachSettingsContextProvider =
    StreamProvider.autoDispose<CoachSettingsContext>((ref) {
      final repository = ref.watch(preferencesRepositoryProvider);
      return repository
          .watch(CoachContextPreferences.storageKey)
          .map(
            (raw) => (
              repository: repository,
              preferences: CoachContextPreferences.decode(raw),
            ),
          );
    });
