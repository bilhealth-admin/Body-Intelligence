import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations.dart';

String profileLocaleText(BuildContext context, String english, String arabic) {
  final code = Localizations.localeOf(context).languageCode;
  if (code == 'ar') return arabic;
  return _authored[english]?[code] ??
      AppLocalizations(Locale(code)).text(english);
}

String profileWeeklySessionsText(BuildContext context, int sessions) {
  return switch (Localizations.localeOf(context).languageCode) {
    'ar' => '$sessions مرات أسبوعيًا',
    'fr' => '$sessions fois par semaine',
    'es' => '$sessions veces por semana',
    'tr' => 'Haftada $sessions kez',
    _ => '$sessions per week',
  };
}

const _authored = <String, Map<String, String>>{
  'Personal details': {
    'fr': 'Informations personnelles',
    'es': 'Datos personales',
    'tr': 'Kişisel bilgiler',
  },
  'Date of birth': {
    'fr': 'Date de naissance',
    'es': 'Fecha de nacimiento',
    'tr': 'Doğum tarihi',
  },
  'Your height': {'fr': 'Votre taille', 'es': 'Tu estatura', 'tr': 'Boyunuz'},
  'Feet/Inches': {'fr': 'Pieds/pouces', 'es': 'Pies/pulgadas', 'tr': 'Fit/inç'},
  'Centimeters': {'fr': 'Centimètres', 'es': 'Centímetros', 'tr': 'Santimetre'},
  'Goals': {'fr': 'Objectifs', 'es': 'Objetivos', 'tr': 'Hedefler'},
  'Update weight, nutrition, and fitness goals': {
    'fr': 'Modifier les objectifs de poids, nutrition et forme',
    'es': 'Actualiza tus objetivos de peso, nutrición y forma física',
    'tr': 'Kilo, beslenme ve fitness hedeflerini güncelle',
  },
  'Linked to today’s measurement and kept on this device.': {
    'fr': 'Liée à la mesure du jour et conservée sur cet appareil.',
    'es': 'Vinculada a la medición de hoy y guardada en este dispositivo.',
    'tr': 'Bugünkü ölçüme bağlıdır ve bu cihazda saklanır.',
  },
  'After waking': {
    'fr': 'Après le réveil',
    'es': 'Al despertar',
    'tr': 'Uyandıktan sonra',
  },
  'After bathroom': {
    'fr': 'Après les toilettes',
    'es': 'Después de ir al baño',
    'tr': 'Tuvaletten sonra',
  },
  'Different time': {
    'fr': 'Heure différente',
    'es': 'Hora diferente',
    'tr': 'Farklı saat',
  },
  'Discard changes?': {
    'fr': 'Ignorer les modifications ?',
    'es': '¿Descartar los cambios?',
    'tr': 'Değişiklikler silinsin mi?',
  },
  'You have unsaved changes.': {
    'fr': 'Vous avez des modifications non enregistrées.',
    'es': 'Tienes cambios sin guardar.',
    'tr': 'Kaydedilmemiş değişiklikleriniz var.',
  },
  'Keep editing': {
    'fr': 'Continuer la modification',
    'es': 'Seguir editando',
    'tr': 'Düzenlemeye devam et',
  },
  'Discard': {'fr': 'Ignorer', 'es': 'Descartar', 'tr': 'Sil'},
  'Your profile and plan were saved.': {
    'fr': 'Votre profil et votre plan ont été enregistrés.',
    'es': 'Se guardaron tu perfil y tu plan.',
    'tr': 'Profiliniz ve planınız kaydedildi.',
  },
  'My profile & plan': {
    'fr': 'Mon profil et mon plan',
    'es': 'Mi perfil y plan',
    'tr': 'Profilim ve planım',
  },
  'Back to settings': {
    'fr': 'Retour aux paramètres',
    'es': 'Volver a ajustes',
    'tr': 'Ayarlara dön',
  },
  'Try again': {'fr': 'Réessayer', 'es': 'Reintentar', 'tr': 'Tekrar dene'},
  'No local profile.': {
    'fr': 'Aucun profil local.',
    'es': 'No hay perfil local.',
    'tr': 'Yerel profil yok.',
  },
  'Display name': {
    'fr': 'Nom affiché',
    'es': 'Nombre visible',
    'tr': 'Görünen ad',
  },
  'Maximum 60 characters': {
    'fr': '60 caractères maximum',
    'es': 'Máximo 60 caracteres',
    'tr': 'En fazla 60 karakter',
  },
  'Your profile photo can be changed from the account icon on Today.': {
    'fr':
        'Vous pouvez modifier votre photo depuis l’icône du compte sur Aujourd’hui.',
    'es': 'Puedes cambiar tu foto desde el icono de cuenta en Hoy.',
    'tr':
        'Profil fotoğrafınızı Bugün ekranındaki hesap simgesinden değiştirebilirsiniz.',
  },
  'Body profile': {
    'fr': 'Profil corporel',
    'es': 'Perfil corporal',
    'tr': 'Vücut profili',
  },
  'Sex': {'fr': 'Sexe', 'es': 'Sexo', 'tr': 'Cinsiyet'},
  'Male': {'fr': 'Homme', 'es': 'Hombre', 'tr': 'Erkek'},
  'Female': {'fr': 'Femme', 'es': 'Mujer', 'tr': 'Kadın'},
  'Age': {'fr': 'Âge', 'es': 'Edad', 'tr': 'Yaş'},
  'Height (cm)': {'fr': 'Taille (cm)', 'es': 'Altura (cm)', 'tr': 'Boy (cm)'},
  'Current weight (kg)': {
    'fr': 'Poids actuel (kg)',
    'es': 'Peso actual (kg)',
    'tr': 'Mevcut kilo (kg)',
  },
  'Goal & activity': {
    'fr': 'Objectif et activité',
    'es': 'Objetivo y actividad',
    'tr': 'Hedef ve aktivite',
  },
  'Target weight (kg)': {
    'fr': 'Poids cible (kg)',
    'es': 'Peso objetivo (kg)',
    'tr': 'Hedef kilo (kg)',
  },
  'Activity level': {
    'fr': 'Niveau d’activité',
    'es': 'Nivel de actividad',
    'tr': 'Aktivite düzeyi',
  },
  'Low movement': {
    'fr': 'Peu de mouvement',
    'es': 'Poco movimiento',
    'tr': 'Az hareket',
  },
  'Light activity': {
    'fr': 'Activité légère',
    'es': 'Actividad ligera',
    'tr': 'Hafif aktivite',
  },
  'Balanced activity': {
    'fr': 'Activité modérée',
    'es': 'Actividad moderada',
    'tr': 'Dengeli aktivite',
  },
  'High activity': {
    'fr': 'Activité élevée',
    'es': 'Actividad alta',
    'tr': 'Yüksek aktivite',
  },
  'Intense activity': {
    'fr': 'Activité intense',
    'es': 'Actividad intensa',
    'tr': 'Yoğun aktivite',
  },
  'I exercise': {
    'fr': 'Je fais de l’exercice',
    'es': 'Hago ejercicio',
    'tr': 'Egzersiz yapıyorum',
  },
  'Frequency and type improve context without claiming exact calorie burn.': {
    'fr':
        'La fréquence et le type enrichissent le contexte sans prétendre calculer exactement les calories brûlées.',
    'es':
        'La frecuencia y el tipo mejoran el contexto sin afirmar un gasto calórico exacto.',
    'tr':
        'Sıklık ve tür, kesin kalori yakımı iddiası olmadan bağlamı iyileştirir.',
  },
  'Exercise sessions per week': {
    'fr': 'Séances d’exercice par semaine',
    'es': 'Sesiones de ejercicio por semana',
    'tr': 'Haftalık egzersiz seansı',
  },
  'Primary exercise type': {
    'fr': 'Type d’exercice principal',
    'es': 'Tipo de ejercicio principal',
    'tr': 'Ana egzersiz türü',
  },
  'Walking': {'fr': 'Marche', 'es': 'Caminar', 'tr': 'Yürüyüş'},
  'Strength & gym': {
    'fr': 'Musculation et salle',
    'es': 'Fuerza y gimnasio',
    'tr': 'Kuvvet ve spor salonu',
  },
  'Cardio': {'fr': 'Cardio', 'es': 'Cardio', 'tr': 'Kardiyo'},
  'Swimming': {'fr': 'Natation', 'es': 'Natación', 'tr': 'Yüzme'},
  'Cycling': {'fr': 'Cyclisme', 'es': 'Ciclismo', 'tr': 'Bisiklet'},
  'Mixed training': {
    'fr': 'Entraînement mixte',
    'es': 'Entrenamiento mixto',
    'tr': 'Karma antrenman',
  },
  'Nutrition approach': {
    'fr': 'Approche nutritionnelle',
    'es': 'Enfoque nutricional',
    'tr': 'Beslenme yaklaşımı',
  },
  'My plan style': {
    'fr': 'Style de mon plan',
    'es': 'Estilo de mi plan',
    'tr': 'Plan tarzım',
  },
  'This guides presentation and preferences, not core scientific facts.': {
    'fr':
        'Cela guide la présentation et les préférences, sans modifier les principes scientifiques.',
    'es':
        'Esto orienta la presentación y las preferencias, no los principios científicos.',
    'tr':
        'Bu, temel bilimsel gerçekleri değil sunumu ve tercihleri yönlendirir.',
  },
  'Smart Balance': {
    'fr': 'Équilibre intelligent',
    'es': 'Equilibrio inteligente',
    'tr': 'Akıllı Denge',
  },
  'Protein Forward': {
    'fr': 'Priorité aux protéines',
    'es': 'Prioridad proteica',
    'tr': 'Protein Ağırlıklı',
  },
  'Lower Carb': {
    'fr': 'Moins de glucides',
    'es': 'Menos carbohidratos',
    'tr': 'Düşük Karbonhidrat',
  },
  'Keto': {'fr': 'Kéto', 'es': 'Keto', 'tr': 'Keto'},
  'Mediterranean': {
    'fr': 'Méditerranéen',
    'es': 'Mediterránea',
    'tr': 'Akdeniz',
  },
  'Plant Forward': {
    'fr': 'À dominante végétale',
    'es': 'Enfoque vegetal',
    'tr': 'Bitki Ağırlıklı',
  },
  'Save and return to settings': {
    'fr': 'Enregistrer et revenir aux paramètres',
    'es': 'Guardar y volver a ajustes',
    'tr': 'Kaydet ve ayarlara dön',
  },
  'Profile': {'fr': 'Profil', 'es': 'Perfil', 'tr': 'Profil'},
  'Choose an image smaller than 5 MB.': {
    'fr': 'Choisissez une image de moins de 5 Mo.',
    'es': 'Elige una imagen de menos de 5 MB.',
    'tr': '5 MB’den küçük bir görsel seçin.',
  },
  'Complete your profile first.': {
    'fr': 'Complétez d’abord votre profil.',
    'es': 'Completa primero tu perfil.',
    'tr': 'Önce profilinizi tamamlayın.',
  },
  'Personal identity': {
    'fr': 'Identité personnelle',
    'es': 'Identidad personal',
    'tr': 'Kişisel kimlik',
  },
  'Profile photo': {
    'fr': 'Photo de profil',
    'es': 'Foto de perfil',
    'tr': 'Profil fotoğrafı',
  },
  'Change photo': {
    'fr': 'Modifier la photo',
    'es': 'Cambiar foto',
    'tr': 'Fotoğrafı değiştir',
  },
  'Email address': {
    'fr': 'Adresse e-mail',
    'es': 'Correo electrónico',
    'tr': 'E-posta adresi',
  },
  'Not added': {'fr': 'Non ajouté', 'es': 'No añadido', 'tr': 'Eklenmedi'},
  'Body details': {
    'fr': 'Données corporelles',
    'es': 'Datos corporales',
    'tr': 'Vücut bilgileri',
  },
  'Height': {'fr': 'Taille', 'es': 'Altura', 'tr': 'Boy'},
  'Height in cm': {
    'fr': 'Taille en cm',
    'es': 'Altura en cm',
    'tr': 'Santimetre cinsinden boy',
  },
  'years': {'fr': 'ans', 'es': 'años', 'tr': 'yaş'},
  'Location & preferences': {
    'fr': 'Lieu et préférences',
    'es': 'Ubicación y preferencias',
    'tr': 'Konum ve tercihler',
  },
  'Location': {'fr': 'Lieu', 'es': 'Ubicación', 'tr': 'Konum'},
  'Country or city': {
    'fr': 'Pays ou ville',
    'es': 'País o ciudad',
    'tr': 'Ülke veya şehir',
  },
  'Postal code': {
    'fr': 'Code postal',
    'es': 'Código postal',
    'tr': 'Posta kodu',
  },
  'Time zone': {
    'fr': 'Fuseau horaire',
    'es': 'Zona horaria',
    'tr': 'Saat dilimi',
  },
  'Units': {'fr': 'Unités', 'es': 'Unidades', 'tr': 'Birimler'},
  'Unit system': {
    'fr': 'Système d’unités',
    'es': 'Sistema de unidades',
    'tr': 'Birim sistemi',
  },
  'Metric · kg, cm, ml': {
    'fr': 'Métrique · kg, cm, ml',
    'es': 'Métrico · kg, cm, ml',
    'tr': 'Metrik · kg, cm, ml',
  },
  'Imperial · lb, ft': {
    'fr': 'Impérial · lb, ft',
    'es': 'Imperial · lb, ft',
    'tr': 'İngiliz · lb, ft',
  },
  'Health goals': {
    'fr': 'Objectifs de santé',
    'es': 'Objetivos de salud',
    'tr': 'Sağlık hedefleri',
  },
  'Current weight': {
    'fr': 'Poids actuel',
    'es': 'Peso actual',
    'tr': 'Mevcut kilo',
  },
  'Goal weight': {
    'fr': 'Poids cible',
    'es': 'Peso objetivo',
    'tr': 'Hedef kilo',
  },
  'Sedentary': {'fr': 'Sédentaire', 'es': 'Sedentario', 'tr': 'Hareketsiz'},
  'Lightly active': {
    'fr': 'Légèrement actif',
    'es': 'Actividad ligera',
    'tr': 'Hafif aktif',
  },
  'Moderately active': {
    'fr': 'Modérément actif',
    'es': 'Actividad moderada',
    'tr': 'Orta aktif',
  },
  'Active': {'fr': 'Actif', 'es': 'Activo', 'tr': 'Aktif'},
  'Very active': {'fr': 'Très actif', 'es': 'Muy activo', 'tr': 'Çok aktif'},
  'Calories & macro plan': {
    'fr': 'Plan calories et macros',
    'es': 'Plan de calorías y macros',
    'tr': 'Kalori ve makro planı',
  },
  'Plan details & recommendations': {
    'fr': 'Détails et recommandations du plan',
    'es': 'Detalles y recomendaciones del plan',
    'tr': 'Plan ayrıntıları ve öneriler',
  },
  'Advanced body measurements': {
    'fr': 'Mesures corporelles avancées',
    'es': 'Medidas corporales avanzadas',
    'tr': 'Gelişmiş vücut ölçümleri',
  },
  'Save health profile': {
    'fr': 'Enregistrer le profil santé',
    'es': 'Guardar perfil de salud',
    'tr': 'Sağlık profilini kaydet',
  },
  'Not set': {'fr': 'Non défini', 'es': 'Sin definir', 'tr': 'Ayarlanmadı'},
  'Edit profile and photo': {
    'fr': 'Modifier le profil et la photo',
    'es': 'Editar perfil y foto',
    'tr': 'Profil ve fotoğrafı düzenle',
  },
  'Your health profile is updated.': {
    'fr': 'Votre profil santé est à jour.',
    'es': 'Tu perfil de salud está actualizado.',
    'tr': 'Sağlık profiliniz güncellendi.',
  },
  'Daily check-in': {
    'fr': 'Bilan quotidien',
    'es': 'Registro diario',
    'tr': 'Günlük kontrol',
  },
  'Cancel': {'fr': 'Annuler', 'es': 'Cancelar', 'tr': 'İptal'},
  'Not now': {'fr': 'Pas maintenant', 'es': 'Ahora no', 'tr': 'Şimdi değil'},
  'Enter a valid weight.': {
    'fr': 'Saisissez un poids valide.',
    'es': 'Introduce un peso válido.',
    'tr': 'Geçerli bir kilo girin.',
  },
  'Use the value shown on your scale.': {
    'fr': 'Utilisez la valeur affichée sur votre balance.',
    'es': 'Usa el valor que muestra tu báscula.',
    'tr': 'Tartınızda görünen değeri kullanın.',
  },
  'Camera is unavailable here. Choose a photo from the device.': {
    'fr':
        'La caméra n’est pas disponible ici. Choisissez une photo sur l’appareil.',
    'es': 'La cámara no está disponible aquí. Elige una foto del dispositivo.',
    'tr': 'Kamera burada kullanılamıyor. Cihazdan bir fotoğraf seçin.',
  },
  'Check-in saved. Consistent conditions make your trend clearer.': {
    'fr':
        'Bilan enregistré. Des conditions constantes rendent votre tendance plus claire.',
    'es':
        'Registro guardado. Mantener condiciones constantes aclara tu tendencia.',
    'tr': 'Kontrol kaydedildi. Tutarlı koşullar eğiliminizi netleştirir.',
  },
  "Delete today's weight?": {
    'fr': 'Supprimer le poids du jour ?',
    'es': '¿Eliminar el peso de hoy?',
    'tr': 'Bugünkü kilo silinsin mi?',
  },
  'This removes today’s check-in from trend calculations.': {
    'fr': 'Cela retire le bilan du jour des calculs de tendance.',
    'es': 'Esto elimina el registro de hoy de los cálculos de tendencia.',
    'tr': 'Bu işlem bugünkü kontrolü eğilim hesaplarından çıkarır.',
  },
  'The check-in could not be changed on this device. Try again.': {
    'fr': 'Le bilan n’a pas pu être modifié sur cet appareil. Réessayez.',
    'es':
        'No se pudo cambiar el registro en este dispositivo. Inténtalo de nuevo.',
    'tr': 'Kontrol bu cihazda değiştirilemedi. Tekrar deneyin.',
  },
  'A quick check-in for a clearer trend.': {
    'fr': 'Un bilan rapide pour une tendance plus claire.',
    'es': 'Un registro rápido para una tendencia más clara.',
    'tr': 'Daha net bir eğilim için hızlı kontrol.',
  },
  'Last measurement': {
    'fr': 'Dernière mesure',
    'es': 'Última medición',
    'tr': 'Son ölçüm',
  },
  'tap to enter': {
    'fr': 'toucher pour saisir',
    'es': 'toca para introducir',
    'tr': 'girmek için dokun',
  },
  'Record': {'fr': 'Enregistrer', 'es': 'Registrar', 'tr': 'Kaydet'},
  "Update today's weight": {
    'fr': 'Mettre à jour le poids du jour',
    'es': 'Actualizar el peso de hoy',
    'tr': 'Bugünkü kiloyu güncelle',
  },
  "Delete today's weight": {
    'fr': 'Supprimer le poids du jour',
    'es': 'Eliminar el peso de hoy',
    'tr': 'Bugünkü kiloyu sil',
  },
  'Progress photo': {
    'fr': 'Photo de progression',
    'es': 'Foto de progreso',
    'tr': 'İlerleme fotoğrafı',
  },
  'Take a private photo': {
    'fr': 'Prendre une photo privée',
    'es': 'Tomar una foto privada',
    'tr': 'Özel fotoğraf çek',
  },
  'Choose from device': {
    'fr': 'Choisir sur l’appareil',
    'es': 'Elegir del dispositivo',
    'tr': 'Cihazdan seç',
  },
  'Enter weight': {
    'fr': 'Saisir le poids',
    'es': 'Introducir peso',
    'tr': 'Kilo gir',
  },
  'Apply': {'fr': 'Appliquer', 'es': 'Aplicar', 'tr': 'Uygula'},
  'Delete': {'fr': 'Supprimer', 'es': 'Eliminar', 'tr': 'Sil'},
  'Later': {'fr': 'Plus tard', 'es': 'Más tarde', 'tr': 'Daha sonra'},
  'Good morning': {'fr': 'Bonjour', 'es': 'Buenos días', 'tr': 'Günaydın'},
  'Shall we log your weight?': {
    'fr': 'Enregistrons-nous votre poids ?',
    'es': '¿Registramos tu peso?',
    'tr': 'Kilonuzu kaydedelim mi?',
  },
  'Private progress photo': {
    'fr': 'Photo de progression privée',
    'es': 'Foto de progreso privada',
    'tr': 'Özel ilerleme fotoğrafı',
  },
  'Change': {'fr': 'Modifier', 'es': 'Cambiar', 'tr': 'Değiştir'},
  'Add photo': {
    'fr': 'Ajouter une photo',
    'es': 'Añadir foto',
    'tr': 'Fotoğraf ekle',
  },
  'Remove photo': {
    'fr': 'Supprimer la photo',
    'es': 'Eliminar foto',
    'tr': 'Fotoğrafı kaldır',
  },
  'Activity factor': {
    'fr': 'Facteur d’activité',
    'es': 'Factor de actividad',
    'tr': 'Aktivite katsayısı',
  },
  'Goal direction': {
    'fr': 'Orientation de l’objectif',
    'es': 'Dirección del objetivo',
    'tr': 'Hedef yönü',
  },
  'Mifflin–St Jeor BMR using the saved age, sex, height, and current weight': {
    'fr':
        'Métabolisme basal de Mifflin–St Jeor calculé avec l’âge, le sexe, la taille et le poids actuel enregistrés',
    'es':
        'TMB de Mifflin–St Jeor usando la edad, el sexo, la altura y el peso actual guardados',
    'tr':
        'Kaydedilen yaş, cinsiyet, boy ve mevcut kilo kullanılarak Mifflin–St Jeor BMH hesabı',
  },
  'Logged scale weight cannot distinguish fat from muscle': {
    'fr':
        'Le poids enregistré par la balance ne distingue pas la graisse du muscle',
    'es': 'El peso registrado por la báscula no distingue grasa de músculo',
    'tr': 'Kaydedilen tartı kilosu yağ ile kası ayırt edemez',
  },
  'Review draft only. Clinician review is required before activation.': {
    'fr':
        'Brouillon à examiner uniquement. L’avis d’un professionnel est requis avant activation.',
    'es':
        'Borrador solo para revisión. Se requiere revisión clínica antes de activarlo.',
    'tr':
        'Yalnızca inceleme taslağıdır. Etkinleştirmeden önce klinisyen incelemesi gerekir.',
  },
  'Selecting a pathway does not change your targets. No values apply until you save the plan.': {
    'fr':
        'Choisir un parcours ne modifie pas vos objectifs. Aucune valeur ne s’applique avant l’enregistrement du plan.',
    'es':
        'Seleccionar una ruta no cambia tus objetivos. Ningún valor se aplica hasta guardar el plan.',
    'tr':
        'Bir yol seçmek hedeflerinizi değiştirmez. Planı kaydedene kadar hiçbir değer uygulanmaz.',
  },
  'Body measurements': {
    'fr': 'Mensurations',
    'es': 'Medidas corporales',
    'tr': 'Vücut ölçümleri',
  },
  'Optional. Saving creates or updates today’s private measurement record.': {
    'fr':
        'Facultatif. L’enregistrement crée ou actualise les mensurations privées du jour.',
    'es':
        'Opcional. Al guardar se crea o actualiza el registro privado de hoy.',
    'tr':
        'İsteğe bağlıdır. Kaydetmek bugünün özel ölçüm kaydını oluşturur veya günceller.',
  },
  'Neck': {'fr': 'Cou', 'es': 'Cuello', 'tr': 'Boyun'},
  'Waist': {'fr': 'Tour de taille', 'es': 'Cintura', 'tr': 'Bel'},
  'Hips': {'fr': 'Hanches', 'es': 'Caderas', 'tr': 'Kalça'},
  'Chest': {'fr': 'Poitrine', 'es': 'Pecho', 'tr': 'Göğüs'},
  'Arm': {'fr': 'Bras', 'es': 'Brazo', 'tr': 'Kol'},
  'Thigh': {'fr': 'Cuisse', 'es': 'Muslo', 'tr': 'Uyluk'},
};
