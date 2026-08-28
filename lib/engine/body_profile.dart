class BodyProfile {
  final int age;

  final String gender;

  final double height;

  final double weight;

  final double targetWeight;

  final String activityLevel;

  final bool exercises;

  final String goalType;

  /// Optional circumference measurements in centimetres. They are kept on
  /// the same immutable profile passed to every calculation consumer so a
  /// plan, progress surface, and body-composition estimate cannot silently
  /// use different body inputs.
  final double? waistCm;
  final double? neckCm;
  final double? hipCm;

  const BodyProfile({
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.targetWeight,
    required this.activityLevel,
    required this.exercises,
    this.goalType = 'maintain',
    this.waistCm,
    this.neckCm,
    this.hipCm,
  });
}
