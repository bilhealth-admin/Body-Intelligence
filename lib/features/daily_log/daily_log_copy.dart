part of 'daily_log_page.dart';

const _dailyLogCopy = <String, Map<String, String>>{
  'Quick Add macros': {
    'fr': 'Ajout rapide des macros',
    'es': 'Añadir macros rápidamente',
    'tr': 'Makroları hızlı ekle',
  },
  'Calories': {'fr': 'Calories', 'es': 'Calorías', 'tr': 'Kalori'},
  'Protein (g)': {
    'fr': 'Protéines (g)',
    'es': 'Proteínas (g)',
    'tr': 'Protein (g)',
  },
  'Carbohydrates (g)': {
    'fr': 'Glucides (g)',
    'es': 'Carbohidratos (g)',
    'tr': 'Karbonhidrat (g)',
  },
  'Fat (g)': {'fr': 'Lipides (g)', 'es': 'Grasas (g)', 'tr': 'Yağ (g)'},
  'Time': {'fr': 'Heure', 'es': 'Hora', 'tr': 'Saat'},
  'Add': {'fr': 'Ajouter', 'es': 'Añadir', 'tr': 'Ekle'},
  'Enter at least one valid calorie or macro value.': {
    'fr': 'Saisissez au moins une valeur valide de calories ou de macros.',
    'es': 'Introduce al menos un valor válido de calorías o macros.',
    'tr': 'En az bir geçerli kalori veya makro değeri girin.',
  },
  'Quick Add saved locally.': {
    'fr': 'Ajout rapide enregistré localement.',
    'es': 'La adición rápida se guardó localmente.',
    'tr': 'Hızlı ekleme yerel olarak kaydedildi.',
  },
  'Copy to multiple days': {
    'fr': 'Copier vers plusieurs jours',
    'es': 'Copiar a varios días',
    'tr': 'Birden fazla güne kopyala',
  },
  'Choose how many upcoming empty days receive this diary. Existing days are never replaced.': {
    'fr':
        'Choisissez le nombre de jours vides à venir qui recevront ce journal. Les jours existants ne sont jamais remplacés.',
    'es':
        'Elige cuántos días vacíos próximos recibirán este diario. Los días existentes nunca se reemplazan.',
    'tr':
        'Bu günlüğün kopyalanacağı boş gelecek gün sayısını seçin. Mevcut günler asla değiştirilmez.',
  },
  'One of the selected days already has meals. Nothing was copied.': {
    'fr':
        'Un des jours sélectionnés contient déjà des repas. Rien n’a été copié.',
    'es':
        'Uno de los días seleccionados ya contiene comidas. No se copió nada.',
    'tr': 'Seçilen günlerden birinde zaten öğün var. Hiçbir şey kopyalanmadı.',
  },
  'Diary copied to {count} days.': {
    'fr': 'Journal copié vers {count} jours.',
    'es': 'Diario copiado a {count} días.',
    'tr': 'Günlük {count} güne kopyalandı.',
  },
  'Copy previous day meals': {
    'fr': 'Copier les repas de la veille',
    'es': 'Copiar las comidas del día anterior',
    'tr': 'Önceki günün öğünlerini kopyala',
  },
  'Record your day': {
    'fr': 'Consignez votre journée',
    'es': 'Registra tu día',
    'tr': 'Gününüzü kaydedin',
  },
  'Body context': {
    'fr': 'Contexte du corps',
    'es': 'Contexto corporal',
    'tr': 'Beden bağlamı',
  },
  'Add sleep, travel, stress, hydration, and other context on a focused page.': {
    'fr':
        'Ajoutez le sommeil, les voyages, le stress, l’hydratation et d’autres éléments sur une page dédiée.',
    'es':
        'Añade sueño, viajes, estrés, hidratación y otros datos en una página específica.',
    'tr':
        'Uyku, seyahat, stres, sıvı alımı ve diğer bağlamları özel bir sayfada ekleyin.',
  },
  'Copy yesterday’s meals?': {
    'fr': 'Copier les repas d’hier ?',
    'es': '¿Copiar las comidas de ayer?',
    'tr': 'Dünün öğünleri kopyalansın mı?',
  },
  'Cancel': {'fr': 'Annuler', 'es': 'Cancelar', 'tr': 'İptal'},
  'Copy': {'fr': 'Copier', 'es': 'Copiar', 'tr': 'Kopyala'},
  'Edit quantity': {
    'fr': 'Modifier la quantité',
    'es': 'Editar cantidad',
    'tr': 'Miktarı düzenle',
  },
  'Duplicate item': {
    'fr': 'Dupliquer l’élément',
    'es': 'Duplicar elemento',
    'tr': 'Öğeyi çoğalt',
  },
  'Copies the same quantity and saved nutrition snapshot.': {
    'fr': 'Copie la même quantité et l’instantané nutritionnel enregistré.',
    'es': 'Copia la misma cantidad y la instantánea nutricional guardada.',
    'tr': 'Aynı miktarı ve kaydedilmiş besin anlık görüntüsünü kopyalar.',
  },
  'Remove favorite': {
    'fr': 'Retirer des favoris',
    'es': 'Quitar de favoritos',
    'tr': 'Favorilerden kaldır',
  },
  'Add favorite': {
    'fr': 'Ajouter aux favoris',
    'es': 'Añadir a favoritos',
    'tr': 'Favorilere ekle',
  },
  'Delete from meal': {
    'fr': 'Supprimer du repas',
    'es': 'Eliminar de la comida',
    'tr': 'Öğünden sil',
  },
  'Submit for review': {
    'fr': 'Envoyer pour vérification',
    'es': 'Enviar para revisión',
    'tr': 'İncelemeye gönder',
  },
  'Image analysis unavailable': {
    'fr': 'Analyse d’image indisponible',
    'es': 'El análisis de imágenes no está disponible',
    'tr': 'Görüntü analizi kullanılamıyor',
  },
  'OK': {'fr': 'OK', 'es': 'Aceptar', 'tr': 'Tamam'},
  'Take a photo': {
    'fr': 'Prendre une photo',
    'es': 'Hacer una foto',
    'tr': 'Fotoğraf çek',
  },
  'Choose from device': {
    'fr': 'Choisir sur l’appareil',
    'es': 'Elegir del dispositivo',
    'tr': 'Cihazdan seç',
  },
  'Review image suggestions': {
    'fr': 'Vérifier les suggestions de l’image',
    'es': 'Revisar las sugerencias de la imagen',
    'tr': 'Görüntü önerilerini incele',
  },
};
double? dailyLogAmountInGrams({required double amount, required String unit}) {
  if (!amount.isFinite || amount <= 0) return null;
  return switch (unit.trim().toLowerCase()) {
    'kg' || 'kgs' || 'kilogram' || 'kilograms' => amount * 1000,
    'oz' || 'ozs' || 'ounce' || 'ounces' => amount * 28.349523125,
    'lb' || 'lbs' || 'pound' || 'pounds' => amount * 453.59237,
    'mg' || 'mgs' || 'milligram' || 'milligrams' => amount / 1000,
    _ => amount,
  };
}

double dailyLogAmountFromGrams({required double grams, required String unit}) {
  return switch (unit.trim().toLowerCase()) {
    'kg' || 'kgs' || 'kilogram' || 'kilograms' => grams / 1000,
    'oz' || 'ozs' || 'ounce' || 'ounces' => grams / 28.349523125,
    'lb' || 'lbs' || 'pound' || 'pounds' => grams / 453.59237,
    'mg' || 'mgs' || 'milligram' || 'milligrams' => grams * 1000,
    _ => grams,
  };
}
