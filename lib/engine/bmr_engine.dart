import 'body_profile.dart';

class BMREngine {
  static double calculate(BodyProfile profile) {
    if (profile.gender.toLowerCase() == 'male') {
      return 10 * profile.weight +
          6.25 * profile.height -
          5 * profile.age +
          5;
    }

    return 10 * profile.weight +
        6.25 * profile.height -
        5 * profile.age -
        161;
  }
}