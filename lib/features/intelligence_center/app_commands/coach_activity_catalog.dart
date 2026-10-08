/// The app-owned exercise identities from WorkoutLibraryPage.workouts at the
/// shared BASE. Only these exact identities are accepted by Coach; model text
/// cannot introduce a workout, MET value, or measured energy signal.
///
/// The original widget's catalog is private. Keep this projection aligned when
/// that catalog changes, or extract the common catalog in the integration layer.
typedef CoachActivityCatalogEntry = ({
  String id,
  String name,
  String nameAr,
  String category,
});

const coachActivityCatalog = <CoachActivityCatalogEntry>[
  (id: 'walk', name: 'Brisk walk', nameAr: 'مشي سريع', category: 'Cardio'),
  (id: 'run', name: 'Easy run', nameAr: 'جري خفيف', category: 'Cardio'),
  (id: 'cycle', name: 'Cycling', nameAr: 'دراجة', category: 'Cardio'),
  (
    id: 'strength',
    name: 'Full-body strength',
    nameAr: 'مقاومة لكامل الجسم',
    category: 'Strength',
  ),
  (
    id: 'upper',
    name: 'Upper-body strength',
    nameAr: 'مقاومة للجزء العلوي',
    category: 'Strength',
  ),
  (
    id: 'lower',
    name: 'Lower-body strength',
    nameAr: 'مقاومة للجزء السفلي',
    category: 'Strength',
  ),
  (
    id: 'mobility',
    name: 'Mobility flow',
    nameAr: 'تمارين مرونة وحركة',
    category: 'Recovery',
  ),
  (
    id: 'stretch',
    name: 'Gentle stretching',
    nameAr: 'إطالة خفيفة',
    category: 'Recovery',
  ),
  (id: 'swim', name: 'Swimming', nameAr: 'سباحة', category: 'Cardio'),
  (id: 'hike', name: 'Hiking', nameAr: 'المشي الجبلي', category: 'Cardio'),
  (
    id: 'stairs',
    name: 'Stair climbing',
    nameAr: 'صعود الدرج',
    category: 'Cardio',
  ),
  (id: 'row', name: 'Rowing', nameAr: 'التجديف', category: 'Cardio'),
  (
    id: 'dance',
    name: 'Dance fitness',
    nameAr: 'لياقة الرقص',
    category: 'Cardio',
  ),
  (
    id: 'core',
    name: 'Core strength',
    nameAr: 'تقوية الجذع',
    category: 'Strength',
  ),
  (
    id: 'circuit',
    name: 'Strength circuit',
    nameAr: 'دائرة تمارين المقاومة',
    category: 'Strength',
  ),
  (id: 'yoga', name: 'Yoga', nameAr: 'يوغا', category: 'Recovery'),
  (id: 'pilates', name: 'Pilates', nameAr: 'بيلاتس', category: 'Recovery'),
  (
    id: 'breathing',
    name: 'Breathing recovery',
    nameAr: 'تنفس للتعافي',
    category: 'Recovery',
  ),
];

CoachActivityCatalogEntry? coachActivityForExactId(Object? id) {
  if (id is! String) return null;
  for (final entry in coachActivityCatalog) {
    if (entry.id == id) return entry;
  }
  return null;
}
