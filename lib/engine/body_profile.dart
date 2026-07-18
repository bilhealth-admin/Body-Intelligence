class BodyProfile {
  final int age;

  final String gender;

  final double height;

  final double weight;

  final double targetWeight;

  final String activityLevel;

  final bool exercises;

  final String goalType;

  const BodyProfile({
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.targetWeight,
    required this.activityLevel,
    required this.exercises,
    this.goalType = 'maintain',
  });
}
