/// Canonical local artwork slots for workout categories and locked fallbacks.
///
/// These are promotional stills, never movement instructions or video
/// posters. Keeping the six filenames centralized lets artwork be replaced in
/// place without changing workout identities, media manifests, or routes.
abstract final class StaticWorkoutArtwork {
  static const strength =
      'assets/images/workouts/workout_strength_cover_v1.png';
  static const cardio = 'assets/images/workouts/workout_cardio_cover_v1.png';
  static const mobility =
      'assets/images/workouts/workout_mobility_cover_v1.png';
  static const hiit = 'assets/images/workouts/workout_hiit_cover_v1.png';
  static const kettlebell =
      'assets/images/workouts/workout_kettlebell_cover_v1.png';
  static const recovery =
      'assets/images/workouts/workout_recovery_cover_v1.png';

  static const all = <String>{
    strength,
    cardio,
    mobility,
    hiit,
    kettlebell,
    recovery,
  };
}
