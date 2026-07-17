import 'body_profile.dart';

class HydrationEngine {
  static int calculate(BodyProfile profile) {
    int water = (profile.weight * 35).round();

    if (profile.exercises) {
      water += 750;
    }

    return water;
  }
}