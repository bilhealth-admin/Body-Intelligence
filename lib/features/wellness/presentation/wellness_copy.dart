import 'package:flutter/widgets.dart';

import '../../../app/localization/app_localizations.dart';

abstract final class WellnessCopyCatalog {
  static const supportedLanguageCodes = {'ar', 'en', 'fr', 'es', 'tr'};
  static const secondaryLanguageCodes = {'fr', 'es', 'tr'};

  static bool get catalogsBalanced => _wellnessSecondary.values.every(
    (translations) =>
        translations.keys.toSet().containsAll(secondaryLanguageCodes) &&
        secondaryLanguageCodes.containsAll(translations.keys),
  );
}

String wellnessCopy(BuildContext context, String english, String arabic) {
  final code = Localizations.localeOf(context).languageCode.toLowerCase();
  if (code == 'ar') return arabic;
  if (code == 'en') return english;

  final recipeCount = RegExp(r'^(\d+) of (\d+) recipes$').firstMatch(english);
  if (recipeCount != null) {
    return context.strings
        .text('{visible} of {total} recipes')
        .replaceFirst('{visible}', recipeCount.group(1)!)
        .replaceFirst('{total}', recipeCount.group(2)!);
  }
  final minutesOnly = RegExp(r'^(\d+) min$').firstMatch(english);
  if (minutesOnly != null) {
    return context.strings
        .text('{count} min')
        .replaceFirst('{count}', minutesOnly.group(1)!);
  }
  final originalLanguage = RegExp(
    r'^Original · ([A-Z-]+)$',
  ).firstMatch(english);
  if (originalLanguage != null) {
    return context.strings
        .text('Original · {language}')
        .replaceFirst('{language}', originalLanguage.group(1)!);
  }

  String dynamicCopy(String prefix, String suffix) => switch (code) {
    'fr' => '$prefix$suffix',
    'es' => '$prefix$suffix',
    'tr' => '$prefix$suffix',
    _ => english,
  };

  if (english.startsWith('Recorded today: ')) {
    final value = english.substring('Recorded today: '.length);
    return dynamicCopy(switch (code) {
      'fr' => "Enregistré aujourd’hui : ",
      'es' => 'Registrado hoy: ',
      'tr' => 'Bugün kaydedilen: ',
      _ => '',
    }, value);
  }
  if (english.startsWith('Duration: ')) {
    final value = english.substring('Duration: '.length);
    return dynamicCopy(switch (code) {
      'fr' => 'Durée : ',
      'es' => 'Duración: ',
      'tr' => 'Süre: ',
      _ => '',
    }, value);
  }
  if (english.startsWith('of ') && english.endsWith(' hours')) {
    final value = english.substring(3, english.length - 6);
    return switch (code) {
      'fr' => 'sur $value heures',
      'es' => 'de $value horas',
      'tr' => '$value saatin',
      _ => english,
    };
  }
  if (english.contains(' recorded nights · ') &&
      english.endsWith(' h average')) {
    final parts = english.split(' recorded nights · ');
    final average = parts[1].replaceFirst(' h average', '');
    return switch (code) {
      'fr' => '${parts[0]} nuits enregistrées · moyenne $average h',
      'es' => '${parts[0]} noches registradas · media de $average h',
      'tr' => '${parts[0]} kayıtlı gece · ortalama $average sa',
      _ => english,
    };
  }
  final recipeSummary = RegExp(
    r'^(\d+) min • (\d+) ingredients$',
  ).firstMatch(english);
  if (recipeSummary != null) {
    final minutes = recipeSummary.group(1);
    final count = recipeSummary.group(2);
    return switch (code) {
      'fr' => '$minutes min • $count ingrédients',
      'es' => '$minutes min • $count ingredientes',
      'tr' => '$minutes dk • $count malzeme',
      _ => english,
    };
  }
  final guidance = RegExp(
    r'^(\d+) minutes • guidance quantities$',
  ).firstMatch(english);
  if (guidance != null) {
    final minutes = guidance.group(1);
    return switch (code) {
      'fr' => '$minutes minutes • quantités indicatives',
      'es' => '$minutes minutos • cantidades orientativas',
      'tr' => '$minutes dakika • rehber miktarlar',
      _ => english,
    };
  }

  return _wellnessSecondary[english]?[code] ?? context.strings.text(english);
}

const _wellnessSecondary = <String, Map<String, String>>{
  'Display options': {
    'fr': "Options d’affichage",
    'es': 'Opciones de visualización',
    'tr': 'Görüntüleme seçenekleri',
  },
  'Exercise sort order': {
    'fr': 'Ordre de tri des exercices',
    'es': 'Orden de los ejercicios',
    'tr': 'Egzersiz sıralaması',
  },
  'A to Z': {'fr': 'De A à Z', 'es': 'De A a Z', 'tr': "A'dan Z'ye"},
  'Z to A': {'fr': 'De Z à A', 'es': 'De Z a A', 'tr': "Z'den A'ya"},
  'Create exercise': {
    'fr': 'Créer un exercice',
    'es': 'Crear ejercicio',
    'tr': 'Egzersiz oluştur',
  },
  'Exercise name': {
    'fr': "Nom de l’exercice",
    'es': 'Nombre del ejercicio',
    'tr': 'Egzersiz adı',
  },
  'Category': {'fr': 'Catégorie', 'es': 'Categoría', 'tr': 'Kategori'},
  'Could not save exercise. Review and retry.': {
    'fr': "Impossible d’enregistrer l’exercice. Vérifiez puis réessayez.",
    'es': 'No se pudo guardar el ejercicio. Revísalo e inténtalo de nuevo.',
    'tr': 'Egzersiz kaydedilemedi. Kontrol edip yeniden deneyin.',
  },
  'Delete exercise?': {
    'fr': "Supprimer l’exercice ?",
    'es': '¿Eliminar ejercicio?',
    'tr': 'Egzersiz silinsin mi?',
  },
  'This removes the custom exercise from My Exercises.': {
    'fr': "Cela supprime l’exercice personnalisé de Mes exercices.",
    'es': 'Esto elimina el ejercicio personalizado de Mis ejercicios.',
    'tr': 'Bu işlem özel egzersizi Egzersizlerimden kaldırır.',
  },
  'Could not delete exercise.': {
    'fr': "Impossible de supprimer l’exercice.",
    'es': 'No se pudo eliminar el ejercicio.',
    'tr': 'Egzersiz silinemedi.',
  },
  'Could not save display options.': {
    'fr': "Impossible d’enregistrer les options d’affichage.",
    'es': 'No se pudieron guardar las opciones de visualización.',
    'tr': 'Görüntüleme seçenekleri kaydedilemedi.',
  },
  'Add beaten eggs and cook gently.': {
    'fr': 'Ajoutez les œufs battus et cuisez doucement.',
    'es': 'Añade los huevos batidos y cocina suavemente.',
    'tr': 'Çırpılmış yumurtayı ekleyip kısık ateşte pişirin.',
  },
  'Add eggs and cover until just set.': {
    'fr': 'Ajoutez les œufs et couvrez jusqu’à cuisson.',
    'es': 'Añade los huevos y tapa hasta que cuajen.',
    'tr': 'Yumurtaları ekleyip pişene kadar kapağı kapatın.',
  },
  'Add spinach near the end.': {
    'fr': 'Ajoutez les épinards vers la fin.',
    'es': 'Añade las espinacas al final.',
    'tr': 'Ispanağı sona doğru ekleyin.',
  },
  'Arrange on a tray.': {
    'fr': 'Disposez sur une plaque.',
    'es': 'Coloca en una bandeja.',
    'tr': 'Tepsiye yerleştirin.',
  },
  'Arrange with grain and vegetables.': {
    'fr': 'Disposez avec les céréales et les légumes.',
    'es': 'Sirve con cereal y verduras.',
    'tr': 'Tahıl ve sebzelerle düzenleyin.',
  },
  'Arrange with grains and vegetables.': {
    'fr': 'Disposez avec les céréales et les légumes.',
    'es': 'Sirve con cereales y verduras.',
    'tr': 'Tahıllar ve sebzelerle düzenleyin.',
  },
  'Arrange with rice and vegetables.': {
    'fr': 'Disposez avec le riz et les légumes.',
    'es': 'Sirve con arroz y verduras.',
    'tr': 'Pirinç ve sebzelerle düzenleyin.',
  },
  'Bake falafel and serve with salad.': {
    'fr': 'Cuisez les falafels au four et servez avec la salade.',
    'es': 'Hornea el falafel y sirve con ensalada.',
    'tr': 'Falafeli fırınlayıp salatayla servis edin.',
  },
  'Blend the hummus.': {
    'fr': 'Mixez le houmous.',
    'es': 'Tritura el hummus.',
    'tr': 'Humusu blenderdan geçirin.',
  },
  'Blend to the preferred texture and season after tasting.': {
    'fr': 'Mixez à la texture souhaitée et assaisonnez après avoir goûté.',
    'es': 'Tritura hasta la textura deseada y sazona tras probar.',
    'tr': 'İstenen kıvama kadar karıştırıp tattıktan sonra baharatlayın.',
  },
  'Brown the tofu.': {
    'fr': 'Faites dorer le tofu.',
    'es': 'Dora el tofu.',
    'tr': 'Tofuyu kızartın.',
  },
  'Build the bowl with vegetables.': {
    'fr': 'Composez le bol avec les légumes.',
    'es': 'Monta el bol con verduras.',
    'tr': 'Kaseyi sebzelerle hazırlayın.',
  },
  'Chill overnight and add figs.': {
    'fr': 'Réfrigérez toute la nuit et ajoutez les figues.',
    'es': 'Refrigera durante la noche y añade higos.',
    'tr': 'Gece boyunca soğutup incir ekleyin.',
  },
  'Chop the vegetables and parsley.': {
    'fr': 'Coupez les légumes et le persil.',
    'es': 'Pica las verduras y el perejil.',
    'tr': 'Sebzeleri ve maydanozu doğrayın.',
  },
  'Combine and dress with lemon just before serving.': {
    'fr': 'Mélangez et assaisonnez au citron avant de servir.',
    'es': 'Mezcla y aliña con limón antes de servir.',
    'tr': 'Karıştırıp servisten hemen önce limon ekleyin.',
  },
  'Combine everything and dress with lime.': {
    'fr': 'Mélangez le tout et assaisonnez au citron vert.',
    'es': 'Mezcla todo y aliña con lima.',
    'tr': 'Hepsini karıştırıp misket limonuyla tatlandırın.',
  },
  'Combine oats and liquid.': {
    'fr': 'Mélangez l’avoine et le liquide.',
    'es': 'Mezcla la avena y el líquido.',
    'tr': 'Yulaf ve sıvıyı karıştırın.',
  },
  'Combine with chopped vegetables and lemon.': {
    'fr': 'Mélangez avec les légumes coupés et le citron.',
    'es': 'Mezcla con verduras picadas y limón.',
    'tr': 'Doğranmış sebzeler ve limonla karıştırın.',
  },
  'Combine yogurt and oats.': {
    'fr': 'Mélangez le yaourt et l’avoine.',
    'es': 'Mezcla yogur y avena.',
    'tr': 'Yoğurt ve yulafı karıştırın.',
  },
  'Cook salmon safely.': {
    'fr': 'Cuisez le saumon à cœur.',
    'es': 'Cocina el salmón de forma segura.',
    'tr': 'Somonu güvenli biçimde pişirin.',
  },
  'Cook shrimp until opaque.': {
    'fr': 'Cuisez les crevettes jusqu’à opacité.',
    'es': 'Cocina los camarones hasta que estén opacos.',
    'tr': 'Karidesleri rengi opaklaşana kadar pişirin.',
  },
  'Cook the chicken.': {
    'fr': 'Cuisez le poulet.',
    'es': 'Cocina el pollo.',
    'tr': 'Tavuğu pişirin.',
  },
  'Cook the seasoned chicken.': {
    'fr': 'Cuisez le poulet assaisonné.',
    'es': 'Cocina el pollo sazonado.',
    'tr': 'Baharatlı tavuğu pişirin.',
  },
  'Cook the tomato base.': {
    'fr': 'Cuisez la base de tomate.',
    'es': 'Cocina la base de tomate.',
    'tr': 'Domates tabanını pişirin.',
  },
  'Cool the quinoa.': {
    'fr': 'Laissez refroidir le quinoa.',
    'es': 'Enfría la quinoa.',
    'tr': 'Kinoayı soğutun.',
  },
  'Drain and rinse the chickpeas.': {
    'fr': 'Égouttez et rincez les pois chiches.',
    'es': 'Escurre y enjuaga los garbanzos.',
    'tr': 'Nohutları süzüp yıkayın.',
  },
  'Grill until safely cooked.': {
    'fr': 'Grillez jusqu’à cuisson complète.',
    'es': 'Asa hasta una cocción segura.',
    'tr': 'Güvenli biçimde pişene kadar ızgara yapın.',
  },
  'Rinse beans.': {
    'fr': 'Rincez les haricots.',
    'es': 'Enjuaga los frijoles.',
    'tr': 'Fasulyeleri yıkayın.',
  },
  'Rinse the lentils.': {
    'fr': 'Rincez les lentilles.',
    'es': 'Enjuaga las lentejas.',
    'tr': 'Mercimeği yıkayın.',
  },
  'Roast the vegetables.': {
    'fr': 'Faites rôtir les légumes.',
    'es': 'Asa las verduras.',
    'tr': 'Sebzeleri fırınlayın.',
  },
  'Roast until the chicken is safely cooked.': {
    'fr': 'Rôtissez jusqu’à cuisson complète du poulet.',
    'es': 'Asa hasta que el pollo esté bien cocido.',
    'tr': 'Tavuk güvenli biçimde pişene kadar fırınlayın.',
  },
  'Season the fish and vegetables.': {
    'fr': 'Assaisonnez le poisson et les légumes.',
    'es': 'Sazona el pescado y las verduras.',
    'tr': 'Balık ve sebzeleri baharatlayın.',
  },
  'Serve over quinoa with lemon.': {
    'fr': 'Servez sur le quinoa avec du citron.',
    'es': 'Sirve sobre quinoa con limón.',
    'tr': 'Kinoa üzerinde limonla servis edin.',
  },
  'Simmer all ingredients until tender.': {
    'fr': 'Laissez mijoter jusqu’à tendreté.',
    'es': 'Cuece a fuego lento hasta que esté tierno.',
    'tr': 'Tüm malzemeleri yumuşayana kadar pişirin.',
  },
  'Simmer lentils and vegetables.': {
    'fr': 'Laissez mijoter lentilles et légumes.',
    'es': 'Cuece a fuego lento lentejas y verduras.',
    'tr': 'Mercimek ve sebzeleri kısık ateşte pişirin.',
  },
  'Stir-fry vegetables and combine.': {
    'fr': 'Faites sauter les légumes puis mélangez.',
    'es': 'Saltea las verduras y mezcla.',
    'tr': 'Sebzeleri soteleyip birleştirin.',
  },
  'Top with fruit and optional nuts or seeds.': {
    'fr': 'Ajoutez les fruits et, au choix, noix ou graines.',
    'es': 'Añade fruta y frutos secos o semillas opcionales.',
    'tr': 'Üzerine meyve ve isteğe bağlı kuruyemiş veya tohum ekleyin.',
  },
  'Wilt the spinach.': {
    'fr': 'Faites tomber les épinards.',
    'es': 'Saltea ligeramente las espinacas.',
    'tr': 'Ispanağı hafifçe soldurun.',
  },
  '1 carrot': {'fr': '1 carotte', 'es': '1 zanahoria', 'tr': '1 havuç'},
  '1 cup red lentils': {
    'fr': '1 tasse de lentilles rouges',
    'es': '1 taza de lentejas rojas',
    'tr': '1 su bardağı kırmızı mercimek',
  },
  '1 onion': {'fr': '1 oignon', 'es': '1 cebolla', 'tr': '1 soğan'},
  'Avocado': {'fr': 'Avocat', 'es': 'Aguacate', 'tr': 'Avokado'},
  'Bell pepper': {'fr': 'Poivron', 'es': 'Pimiento', 'tr': 'Dolmalık biber'},
  'Black beans': {
    'fr': 'Haricots noirs',
    'es': 'Frijoles negros',
    'tr': 'Siyah fasulye',
  },
  'Black pepper': {
    'fr': 'Poivre noir',
    'es': 'Pimienta negra',
    'tr': 'Karabiber',
  },
  'Broccoli': {'fr': 'Brocoli', 'es': 'Brócoli', 'tr': 'Brokoli'},
  'Brown lentils': {
    'fr': 'Lentilles brunes',
    'es': 'Lentejas pardas',
    'tr': 'Yeşil mercimek',
  },
  'Cabbage': {'fr': 'Chou', 'es': 'Repollo', 'tr': 'Lahana'},
  'Carrot': {'fr': 'Carotte', 'es': 'Zanahoria', 'tr': 'Havuç'},
  'Chia seeds': {
    'fr': 'Graines de chia',
    'es': 'Semillas de chía',
    'tr': 'Chia tohumu',
  },
  'Chicken': {'fr': 'Poulet', 'es': 'Pollo', 'tr': 'Tavuk'},
  'Chicken breast': {
    'fr': 'Blanc de poulet',
    'es': 'Pechuga de pollo',
    'tr': 'Tavuk göğsü',
  },
  'Chickpeas': {'fr': 'Pois chiches', 'es': 'Garbanzos', 'tr': 'Nohut'},
  'Cooked chickpeas': {
    'fr': 'Pois chiches cuits',
    'es': 'Garbanzos cocidos',
    'tr': 'Pişmiş nohut',
  },
  'Cooked grain': {
    'fr': 'Céréales cuites',
    'es': 'Cereal cocido',
    'tr': 'Pişmiş tahıl',
  },
  'Cooked quinoa': {
    'fr': 'Quinoa cuit',
    'es': 'Quinoa cocida',
    'tr': 'Pişmiş kinoa',
  },
  'Cooked rice': {
    'fr': 'Riz cuit',
    'es': 'Arroz cocido',
    'tr': 'Pişmiş pirinç',
  },
  'Corn': {'fr': 'Maïs', 'es': 'Maíz', 'tr': 'Mısır'},
  'Cucumber': {'fr': 'Concombre', 'es': 'Pepino', 'tr': 'Salatalık'},
  'Cumin': {'fr': 'Cumin', 'es': 'Comino', 'tr': 'Kimyon'},
  'Edamame': {'fr': 'Edamame', 'es': 'Edamame', 'tr': 'Edamame'},
  'Eggs': {'fr': 'Œufs', 'es': 'Huevos', 'tr': 'Yumurta'},
  'Figs': {'fr': 'Figues', 'es': 'Higos', 'tr': 'İncir'},
  'Firm tofu': {'fr': 'Tofu ferme', 'es': 'Tofu firme', 'tr': 'Sert tofu'},
  'Fish fillet': {
    'fr': 'Filet de poisson',
    'es': 'Filete de pescado',
    'tr': 'Balık fileto',
  },
  'Flatbread': {'fr': 'Pain plat', 'es': 'Pan plano', 'tr': 'Lavaş'},
  'Fresh fruit': {
    'fr': 'Fruits frais',
    'es': 'Fruta fresca',
    'tr': 'Taze meyve',
  },
  'Green beans': {
    'fr': 'Haricots verts',
    'es': 'Judías verdes',
    'tr': 'Taze fasulye',
  },
  'Herbs': {'fr': 'Herbes', 'es': 'Hierbas', 'tr': 'Otlar'},
  'Lemon': {'fr': 'Citron', 'es': 'Limón', 'tr': 'Limon'},
  'Lemon juice': {
    'fr': 'Jus de citron',
    'es': 'Zumo de limón',
    'tr': 'Limon suyu',
  },
  'Lime': {'fr': 'Citron vert', 'es': 'Lima', 'tr': 'Misket limonu'},
  'Milk or yogurt': {
    'fr': 'Lait ou yaourt',
    'es': 'Leche o yogur',
    'tr': 'Süt veya yoğurt',
  },
  'Onion': {'fr': 'Oignon', 'es': 'Cebolla', 'tr': 'Soğan'},
  'Optional nuts or seeds': {
    'fr': 'Noix ou graines facultatives',
    'es': 'Frutos secos o semillas opcionales',
    'tr': 'İsteğe bağlı kuruyemiş veya tohum',
  },
  'Parsley': {'fr': 'Persil', 'es': 'Perejil', 'tr': 'Maydanoz'},
  'Plain yogurt': {
    'fr': 'Yaourt nature',
    'es': 'Yogur natural',
    'tr': 'Sade yoğurt',
  },
  'Red onion': {
    'fr': 'Oignon rouge',
    'es': 'Cebolla roja',
    'tr': 'Kırmızı soğan',
  },
  'Rolled oats': {
    'fr': 'Flocons d’avoine',
    'es': 'Copos de avena',
    'tr': 'Yulaf ezmesi',
  },
  'Salmon': {'fr': 'Saumon', 'es': 'Salmón', 'tr': 'Somon'},
  'Seasonal vegetables': {
    'fr': 'Légumes de saison',
    'es': 'Verduras de temporada',
    'tr': 'Mevsim sebzeleri',
  },
  'Shrimp': {'fr': 'Crevettes', 'es': 'Camarones', 'tr': 'Karides'},
  'Snap peas': {
    'fr': 'Pois mange-tout',
    'es': 'Tirabeques',
    'tr': 'Şeker bezelye',
  },
  'Spinach': {'fr': 'Épinards', 'es': 'Espinacas', 'tr': 'Ispanak'},
  'Sweet potato': {'fr': 'Patate douce', 'es': 'Batata', 'tr': 'Tatlı patates'},
  'Tahini': {'fr': 'Tahini', 'es': 'Tahini', 'tr': 'Tahin'},
  'Tomato': {'fr': 'Tomate', 'es': 'Tomate', 'tr': 'Domates'},
  'Tomatoes': {'fr': 'Tomates', 'es': 'Tomates', 'tr': 'Domates'},
  'Water or unsalted stock': {
    'fr': 'Eau ou bouillon sans sel',
    'es': 'Agua o caldo sin sal',
    'tr': 'Su veya tuzsuz et suyu',
  },
  'Yogurt': {'fr': 'Yaourt', 'es': 'Yogur', 'tr': 'Yoğurt'},
  'Zucchini': {'fr': 'Courgette', 'es': 'Calabacín', 'tr': 'Kabak'},
  'Featured workouts': {
    'fr': 'Entraînements à la une',
    'es': 'Entrenamientos destacados',
    'tr': 'Öne çıkan antrenmanlar',
  },
  'Full-body strength': {
    'fr': 'Renforcement complet',
    'es': 'Fuerza de cuerpo completo',
    'tr': 'Tüm vücut kuvvet',
  },
  '20 min • Full body': {
    'fr': '20 min • Corps entier',
    'es': '20 min • Cuerpo completo',
    'tr': '20 dk • Tüm vücut',
  },
  'Mobility flow': {
    'fr': 'Enchaînement mobilité',
    'es': 'Flujo de movilidad',
    'tr': 'Mobilite akışı',
  },
  '15 min • Recovery': {
    'fr': '15 min • Récupération',
    'es': '15 min • Recuperación',
    'tr': '15 dk • Toparlanma',
  },
  'History': {'fr': 'Historique', 'es': 'Historial', 'tr': 'Geçmiş'},
  'My Exercises': {
    'fr': 'Mes exercices',
    'es': 'Mis ejercicios',
    'tr': 'Egzersizlerim',
  },
  'All Exercises': {
    'fr': 'Tous les exercices',
    'es': 'Todos los ejercicios',
    'tr': 'Tüm egzersizler',
  },
  'Brisk walk': {
    'fr': 'Marche rapide',
    'es': 'Caminata rápida',
    'tr': 'Tempolu yürüyüş',
  },
  'Easy run': {
    'fr': 'Course légère',
    'es': 'Carrera suave',
    'tr': 'Hafif koşu',
  },
  'Cycling': {'fr': 'Vélo', 'es': 'Ciclismo', 'tr': 'Bisiklet'},
  'Upper-body strength': {
    'fr': 'Renforcement du haut du corps',
    'es': 'Fuerza del tren superior',
    'tr': 'Üst vücut kuvvet',
  },
  'Lower-body strength': {
    'fr': 'Renforcement du bas du corps',
    'es': 'Fuerza del tren inferior',
    'tr': 'Alt vücut kuvvet',
  },
  'Gentle stretching': {
    'fr': 'Étirements doux',
    'es': 'Estiramiento suave',
    'tr': 'Hafif esneme',
  },
  'Swimming': {'fr': 'Natation', 'es': 'Natación', 'tr': 'Yüzme'},
  'Hiking': {'fr': 'Randonnée', 'es': 'Senderismo', 'tr': 'Doğa yürüyüşü'},
  'Stair climbing': {
    'fr': 'Montée d’escaliers',
    'es': 'Subir escaleras',
    'tr': 'Merdiven çıkma',
  },
  'Rowing': {'fr': 'Aviron', 'es': 'Remo', 'tr': 'Kürek'},
  'Dance fitness': {
    'fr': 'Fitness dansé',
    'es': 'Fitness de baile',
    'tr': 'Dans fitness',
  },
  'Core strength': {
    'fr': 'Renforcement du tronc',
    'es': 'Fuerza del core',
    'tr': 'Merkez bölge kuvvet',
  },
  'Strength circuit': {
    'fr': 'Circuit de renforcement',
    'es': 'Circuito de fuerza',
    'tr': 'Kuvvet devresi',
  },
  'Yoga': {'fr': 'Yoga', 'es': 'Yoga', 'tr': 'Yoga'},
  'Pilates': {'fr': 'Pilates', 'es': 'Pilates', 'tr': 'Pilates'},
  'Breathing recovery': {
    'fr': 'Respiration de récupération',
    'es': 'Respiración de recuperación',
    'tr': 'Toparlanma nefesi',
  },
  'Saved recipes': {
    'fr': 'Recettes enregistrées',
    'es': 'Recetas guardadas',
    'tr': 'Kaydedilen tarifler',
  },
  'Search recipes or ingredients': {
    'fr': 'Rechercher une recette ou un ingrédient',
    'es': 'Buscar recetas o ingredientes',
    'tr': 'Tarif veya malzeme ara',
  },
  'Regional': {'fr': 'Régional', 'es': 'Regional', 'tr': 'Bölgesel'},
  'Quick': {'fr': 'Rapide', 'es': 'Rápido', 'tr': 'Hızlı'},
  'Plant-forward': {
    'fr': 'À dominante végétale',
    'es': 'Más vegetal',
    'tr': 'Bitki ağırlıklı',
  },
  'Saved': {'fr': 'Enregistrées', 'es': 'Guardadas', 'tr': 'Kaydedilenler'},
  'Quantities are guidance. BIL shows nutrition only after ingredients are linked to verified food records.': {
    'fr':
        'Les quantités sont indicatives. BIL affiche la nutrition uniquement après liaison à des aliments vérifiés.',
    'es':
        'Las cantidades son orientativas. BIL muestra nutrición solo tras vincular ingredientes a alimentos verificados.',
    'tr':
        'Miktarlar rehberdir. BIL besin değerlerini yalnızca malzemeler doğrulanmış gıda kayıtlarına bağlandığında gösterir.',
  },
  'No matching recipes.': {
    'fr': 'Aucune recette correspondante.',
    'es': 'No hay recetas coincidentes.',
    'tr': 'Eşleşen tarif yok.',
  },
  'Regional favorites': {
    'fr': 'Favoris régionaux',
    'es': 'Favoritos regionales',
    'tr': 'Bölgesel favoriler',
  },
  'Quick & easy': {
    'fr': 'Rapide et facile',
    'es': 'Rápido y fácil',
    'tr': 'Hızlı ve kolay',
  },
  'View more': {'fr': 'Voir plus', 'es': 'Ver más', 'tr': 'Daha fazla'},
  'Save recipe': {
    'fr': 'Enregistrer la recette',
    'es': 'Guardar receta',
    'tr': 'Tarifi kaydet',
  },
  'Ingredients': {
    'fr': 'Ingrédients',
    'es': 'Ingredientes',
    'tr': 'Malzemeler',
  },
  'Method': {'fr': 'Préparation', 'es': 'Preparación', 'tr': 'Hazırlama'},
  'Nutrition is added only from verified food records.': {
    'fr': 'La nutrition provient uniquement de fiches alimentaires vérifiées.',
    'es':
        'La nutrición se añade solo desde registros de alimentos verificados.',
    'tr': 'Besin değerleri yalnızca doğrulanmış gıda kayıtlarından eklenir.',
  },
  'Red lentil soup': {
    'fr': 'Soupe de lentilles rouges',
    'es': 'Sopa de lentejas rojas',
    'tr': 'Kırmızı mercimek çorbası',
  },
  'Yogurt oat bowl': {
    'fr': 'Bol yaourt et avoine',
    'es': 'Bol de yogur y avena',
    'tr': 'Yoğurtlu yulaf kasesi',
  },
  'Chickpea herb salad': {
    'fr': 'Salade de pois chiches aux herbes',
    'es': 'Ensalada de garbanzos y hierbas',
    'tr': 'Otlu nohut salatası',
  },
  'Herbed shakshuka': {
    'fr': 'Chakchouka aux herbes',
    'es': 'Shakshuka con hierbas',
    'tr': 'Otlu şakşuka',
  },
  'Grilled fish & vegetables': {
    'fr': 'Poisson grillé et légumes',
    'es': 'Pescado y verduras a la parrilla',
    'tr': 'Izgara balık ve sebzeler',
  },
  'Chicken shawarma grain bowl': {
    'fr': 'Bol de céréales au chawarma de poulet',
    'es': 'Bol de cereal con shawarma de pollo',
    'tr': 'Tavuk şavarmalı tahıl kasesi',
  },
  'Vegetable lentil stew': {
    'fr': 'Ragoût de lentilles et légumes',
    'es': 'Guiso de lentejas y verduras',
    'tr': 'Sebzeli mercimek yemeği',
  },
  'Hummus & baked falafel plate': {
    'fr': 'Assiette houmous et falafels au four',
    'es': 'Plato de hummus y falafel al horno',
    'tr': 'Humus ve fırın falafel tabağı',
  },
  'Quinoa tabbouleh': {
    'fr': 'Taboulé de quinoa',
    'es': 'Tabulé de quinoa',
    'tr': 'Kinoalı tabule',
  },
  'Overnight oats with figs': {
    'fr': 'Avoine de nuit aux figues',
    'es': 'Avena nocturna con higos',
    'tr': 'İncirli geceden yulaf',
  },
  'Spinach omelet': {
    'fr': 'Omelette aux épinards',
    'es': 'Tortilla de espinacas',
    'tr': 'Ispanaklı omlet',
  },
  'Shrimp rice bowl': {
    'fr': 'Bol de riz aux crevettes',
    'es': 'Bol de arroz con camarones',
    'tr': 'Karidesli pirinç kasesi',
  },
  'Tofu vegetable stir-fry': {
    'fr': 'Tofu sauté aux légumes',
    'es': 'Salteado de tofu y verduras',
    'tr': 'Sebzeli tofu sote',
  },
  'Bean & corn salad': {
    'fr': 'Salade de haricots et maïs',
    'es': 'Ensalada de frijoles y maíz',
    'tr': 'Fasulye ve mısır salatası',
  },
  'Chicken & sweet potato tray': {
    'fr': 'Plaque de poulet et patate douce',
    'es': 'Bandeja de pollo y batata',
    'tr': 'Tavuk ve tatlı patates tepsisi',
  },
  'Mediterranean chicken bowl': {
    'fr': 'Bol de poulet méditerranéen',
    'es': 'Bol mediterráneo de pollo',
    'tr': 'Akdeniz usulü tavuk kasesi',
  },
  'Roasted vegetable quinoa bowl': {
    'fr': 'Bol de quinoa aux légumes rôtis',
    'es': 'Bol de quinoa con verduras asadas',
    'tr': 'Fırın sebzeli kinoa kasesi',
  },
  'Salmon avocado bowl': {
    'fr': 'Bol saumon avocat',
    'es': 'Bol de salmón y aguacate',
    'tr': 'Somonlu avokado kasesi',
  },
  'Spotlight': {'fr': 'À la une', 'es': 'Destacado', 'tr': 'Öne çıkan'},
  'Topics': {'fr': 'Thèmes', 'es': 'Temas', 'tr': 'Konular'},
  'Nutrition': {'fr': 'Nutrition', 'es': 'Nutrición', 'tr': 'Beslenme'},
  'Movement': {'fr': 'Mouvement', 'es': 'Movimiento', 'tr': 'Hareket'},
  'Privacy': {'fr': 'Confidentialité', 'es': 'Privacidad', 'tr': 'Gizlilik'},
  'BIL education is general information, not diagnosis or treatment. Sources and limits are shown in every article.': {
    'fr':
        'Les contenus BIL sont informatifs, sans diagnostic ni traitement. Les sources et limites figurent dans chaque article.',
    'es':
        'El contenido educativo de BIL es información general, no diagnóstico ni tratamiento. Cada artículo muestra fuentes y límites.',
    'tr':
        'BIL eğitimi genel bilgidir; tanı veya tedavi değildir. Her makalede kaynaklar ve sınırlar gösterilir.',
  },
  'How to read your food log without judgment': {
    'fr': 'Lire votre journal alimentaire sans jugement',
    'es': 'Cómo leer tu registro de comida sin juzgar',
    'tr': 'Yemek kaydınızı yargılamadan okumak',
  },
  'Look for a pattern across several days instead of judging one meal. Compare energy, protein, and fiber only when logs are complete and nutrition sources are documented.': {
    'fr':
        'Recherchez une tendance sur plusieurs jours plutôt que de juger un repas. Comparez énergie, protéines et fibres uniquement avec des journaux complets et des sources documentées.',
    'es':
        'Busca un patrón durante varios días en vez de juzgar una comida. Compara energía, proteína y fibra solo con registros completos y fuentes documentadas.',
    'tr':
        'Tek öğünü yargılamak yerine birkaç günlük örüntü arayın. Enerji, protein ve lifi yalnızca kayıtlar tam ve kaynaklar belgeli olduğunda karşılaştırın.',
  },
  'BIL editorial review • General education': {
    'fr': 'Revue éditoriale BIL • Information générale',
    'es': 'Revisión editorial BIL • Educación general',
    'tr': 'BIL editoryal inceleme • Genel eğitim',
  },
  'Consistency matters more than a perfect day': {
    'fr': 'La régularité compte plus qu’une journée parfaite',
    'es': 'La constancia importa más que un día perfecto',
    'tr': 'Tutarlılık kusursuz bir günden önemlidir',
  },
  'Start with a duration that matches your current capacity, then progress gradually. Stop and seek professional assessment for sharp pain, dizziness, or unusual breathlessness.': {
    'fr':
        'Commencez par une durée adaptée à votre capacité, puis progressez graduellement. Arrêtez et consultez en cas de douleur vive, vertiges ou essoufflement inhabituel.',
    'es':
        'Empieza con una duración acorde a tu capacidad y progresa gradualmente. Detente y busca evaluación ante dolor agudo, mareo o falta de aire inusual.',
    'tr':
        'Mevcut kapasitenize uygun süreyle başlayın ve kademeli ilerleyin. Keskin ağrı, baş dönmesi veya olağandışı nefes darlığında durup değerlendirme alın.',
  },
  'BIL safety guidance • Not a treatment prescription': {
    'fr': 'Consignes de sécurité BIL • Pas une prescription',
    'es': 'Guía de seguridad BIL • No es una prescripción',
    'tr': 'BIL güvenlik rehberi • Tedavi reçetesi değildir',
  },
  'Why one night cannot explain your sleep': {
    'fr': 'Pourquoi une nuit ne suffit pas à comprendre votre sommeil',
    'es': 'Por qué una noche no explica tu sueño',
    'tr': 'Tek gece uykunuzu neden açıklayamaz',
  },
  'BIL shows a trend only when enough recorded days exist and marks missing days instead of estimating them. Record sleep, wake time, and context honestly.': {
    'fr':
        'BIL affiche une tendance seulement avec assez de jours enregistrés et signale les jours manquants sans les estimer. Notez honnêtement sommeil, réveil et contexte.',
    'es':
        'BIL muestra una tendencia solo con suficientes días registrados y marca los faltantes sin estimarlos. Registra sueño, despertar y contexto con honestidad.',
    'tr':
        'BIL yalnızca yeterli kayıtlı gün olduğunda eğilim gösterir ve eksik günleri tahmin etmek yerine işaretler. Uyku, uyanma ve bağlamı dürüstçe kaydedin.',
  },
  'BIL evidence and confidence method': {
    'fr': 'Méthode BIL de preuve et confiance',
    'es': 'Método BIL de evidencia y confianza',
    'tr': 'BIL kanıt ve güven yöntemi',
  },
  'Your health data stays under your control': {
    'fr': 'Vos données de santé restent sous votre contrôle',
    'es': 'Tus datos de salud permanecen bajo tu control',
    'tr': 'Sağlık verileriniz sizin kontrolünüzde kalır',
  },
  'The log works locally without an account. Sync, sharing, and health connections start only with explicit consent and can be revoked with data deletion.': {
    'fr':
        'Le journal fonctionne localement sans compte. Synchronisation, partage et connexions santé exigent un consentement explicite, révocable avec suppression des données.',
    'es':
        'El registro funciona localmente sin cuenta. Sincronización, uso compartido y conexiones de salud requieren consentimiento explícito y pueden revocarse borrando datos.',
    'tr':
        'Kayıt hesap olmadan yerel çalışır. Eşitleme, paylaşım ve sağlık bağlantıları yalnızca açık onayla başlar; onay geri çekilip veriler silinebilir.',
  },
  'BIL privacy principles': {
    'fr': 'Principes de confidentialité BIL',
    'es': 'Principios de privacidad BIL',
    'tr': 'BIL gizlilik ilkeleri',
  },
  'BIL content packs': {
    'fr': 'Packs de contenu BIL',
    'es': 'Paquetes de contenido BIL',
    'tr': 'BIL içerik paketleri',
  },
  'Catalog unavailable': {
    'fr': 'Catalogue indisponible',
    'es': 'Catálogo no disponible',
    'tr': 'Katalog kullanılamıyor',
  },
  'Retry': {'fr': 'Réessayer', 'es': 'Reintentar', 'tr': 'Tekrar dene'},
  'No packs published yet': {
    'fr': 'Aucun pack publié',
    'es': 'Aún no hay paquetes publicados',
    'tr': 'Henüz paket yayımlanmadı',
  },
  'The app stays small. Verified recipe, workout, sleep and fasting packs will appear here after publishing the BIL catalog.': {
    'fr':
        'L’application reste légère. Les packs vérifiés de recettes, d’entraînement, de sommeil et de jeûne apparaîtront ici après publication du catalogue BIL.',
    'es':
        'La aplicación sigue siendo ligera. Los paquetes verificados de recetas, entrenamiento, sueño y ayuno aparecerán aquí al publicarse el catálogo BIL.',
    'tr':
        'Uygulama küçük kalır. Doğrulanmış tarif, antrenman, uyku ve oruç paketleri BIL kataloğu yayımlandıktan sonra burada görünür.',
  },
  'items': {'fr': 'éléments', 'es': 'elementos', 'tr': 'öğe'},
  'This installs the verified routine catalog only. Workout media downloads on demand when first opened, after size and checksum verification; installing the catalog does not download every video.': {
    'fr':
        'Seul le catalogue vérifié est installé. Les médias sont téléchargés à la demande après vérification de la taille et de l’empreinte ; tous les fichiers ne sont pas téléchargés.',
    'es':
        'Solo se instala el catálogo verificado. Los medios se descargan bajo demanda tras verificar tamaño y suma; no se descargan todos los vídeos.',
    'tr':
        'Yalnızca doğrulanmış rutin kataloğu kurulur. Medya, boyut ve sağlama doğrulamasından sonra gerektiğinde indirilir; tüm videolar indirilmez.',
  },
  'Routine details are available offline. A video becomes available offline only after its first verified download. Removing the pack also clears its cached workout media.': {
    'fr':
        'Les détails sont disponibles hors ligne. Une vidéo ne le devient qu’après son premier téléchargement vérifié. Supprimer le pack efface aussi ses médias en cache.',
    'es':
        'Los detalles están disponibles sin conexión. Cada vídeo lo estará tras su primera descarga verificada. Quitar el paquete borra también sus medios en caché.',
    'tr':
        'Rutin ayrıntıları çevrimdışıdır. Bir video ilk doğrulanmış indirmeden sonra çevrimdışı olur. Paketi kaldırmak önbelleği de temizler.',
  },
  'Install verified catalog': {
    'fr': 'Installer le catalogue vérifié',
    'es': 'Instalar catálogo verificado',
    'tr': 'Doğrulanmış kataloğu kur',
  },
  'Remove pack and cached media': {
    'fr': 'Supprimer le pack et les médias',
    'es': 'Quitar paquete y medios',
    'tr': 'Paketi ve önbelleği kaldır',
  },
  'BIL wellness library': {
    'fr': 'Bibliothèque bien-être BIL',
    'es': 'Biblioteca de bienestar BIL',
    'tr': 'BIL sağlık kitaplığı',
  },
  'Manage content packs': {
    'fr': 'Gérer les packs de contenu',
    'es': 'Gestionar paquetes de contenido',
    'tr': 'İçerik paketlerini yönet',
  },
  'Practical tools grounded in your real logs and connections—never invented measurements.': {
    'fr':
        'Des outils pratiques fondés sur vos journaux et connexions réels, sans mesures inventées.',
    'es':
        'Herramientas prácticas basadas en tus registros y conexiones reales, sin mediciones inventadas.',
    'tr':
        'Gerçek kayıtlarınıza ve bağlantılarınıza dayalı araçlar; uydurma ölçüm yok.',
  },
  'BIL recipes': {
    'fr': 'Recettes BIL',
    'es': 'Recetas BIL',
    'tr': 'BIL tarifleri',
  },
  'Searchable, saveable recipes without invented nutrition values.': {
    'fr':
        'Des recettes consultables et enregistrables, sans valeurs nutritionnelles inventées.',
    'es':
        'Recetas que puedes buscar y guardar, sin valores nutricionales inventados.',
    'tr': 'Uydurma besin değeri olmadan aranabilen ve kaydedilebilen tarifler.',
  },
  'Nutrition appears only when ingredients resolve to trusted sources.': {
    'fr':
        'Les données nutritionnelles apparaissent uniquement si les ingrédients proviennent de sources fiables.',
    'es':
        'La nutrición solo aparece cuando los ingredientes se vinculan a fuentes fiables.',
    'tr':
        'Besin değerleri yalnızca malzemeler güvenilir kaynaklarla eşleştiğinde görünür.',
  },
  'Explore recipes': {
    'fr': 'Explorer les recettes',
    'es': 'Explorar recetas',
    'tr': 'Tarifleri keşfet',
  },
  'Understand how sleep relates to energy, meals, and recovery.': {
    'fr': 'Comprenez le lien entre sommeil, énergie, repas et récupération.',
    'es':
        'Comprende cómo se relaciona el sueño con la energía, las comidas y la recuperación.',
    'tr': 'Uykunun enerji, öğünler ve toparlanmayla ilişkisini anlayın.',
  },
  'Trends appear after a sleep log or a supported health connection.': {
    'fr':
        'Les tendances apparaissent après un journal de sommeil ou une connexion santé compatible.',
    'es':
        'Las tendencias aparecen tras registrar el sueño o conectar una fuente de salud compatible.',
    'tr':
        'Eğilimler uyku kaydı veya desteklenen bir sağlık bağlantısından sonra görünür.',
  },
  'Log your sleep': {
    'fr': 'Enregistrer votre sommeil',
    'es': 'Registrar tu sueño',
    'tr': 'Uykunu kaydet',
  },
  'Movement & recovery': {
    'fr': 'Mouvement et récupération',
    'es': 'Movimiento y recuperación',
    'tr': 'Hareket ve toparlanma',
  },
  'Plan movement around your current capacity, not a generic template.': {
    'fr':
        'Planifiez le mouvement selon votre capacité actuelle, pas un modèle générique.',
    'es':
        'Planifica el movimiento según tu capacidad actual, no con una plantilla genérica.',
    'tr':
        'Hareketi genel bir şablona göre değil, mevcut kapasitenize göre planlayın.',
  },
  'BIL does not count workouts or burn without a log or trusted source.': {
    'fr':
        'BIL ne comptabilise ni séance ni dépense sans journal ou source fiable.',
    'es':
        'BIL no cuenta entrenamientos ni gasto sin un registro o fuente fiable.',
    'tr':
        'BIL kayıt veya güvenilir kaynak olmadan antrenman ya da yakım saymaz.',
  },
  'Add today’s workout': {
    'fr': 'Ajouter la séance du jour',
    'es': 'Añadir el entrenamiento de hoy',
    'tr': 'Bugünkü antrenmanı ekle',
  },
  'Rhythm & fasting': {
    'fr': 'Rythme et jeûne',
    'es': 'Ritmo y ayuno',
    'tr': 'Ritim ve oruç',
  },
  'Track your window and its context with clear health guardrails.': {
    'fr':
        'Suivez votre fenêtre et son contexte avec des garde-fous de santé clairs.',
    'es': 'Registra tu ventana y contexto con límites de salud claros.',
    'tr': 'Aralığınızı ve bağlamını açık sağlık sınırlarıyla takip edin.',
  },
  'Fasting is optional, not medical advice. Consult a clinician when relevant.': {
    'fr':
        'Le jeûne est facultatif et ne constitue pas un avis médical. Consultez si nécessaire.',
    'es':
        'El ayuno es opcional y no es consejo médico. Consulta a un profesional cuando corresponda.',
    'tr':
        'Oruç isteğe bağlıdır, tıbbi tavsiye değildir. Gerektiğinde bir klinisyene danışın.',
  },
  'Open fasting timer': {
    'fr': 'Ouvrir le minuteur de jeûne',
    'es': 'Abrir temporizador de ayuno',
    'tr': 'Oruç zamanlayıcısını aç',
  },
  'Your weekly review': {
    'fr': 'Votre bilan hebdomadaire',
    'es': 'Tu revisión semanal',
    'tr': 'Haftalık değerlendirmeniz',
  },
  'Bring weight, nutrition, water, and context into one explainable review.': {
    'fr':
        'Regroupez poids, nutrition, eau et contexte dans un bilan explicable.',
    'es': 'Reúne peso, nutrición, agua y contexto en una revisión explicable.',
    'tr':
        'Kilo, beslenme, su ve bağlamı açıklanabilir tek değerlendirmede birleştirin.',
  },
  'BIL shows record sufficiency and confidence limits; weight alone never proves fat or muscle change.': {
    'fr':
        'BIL indique la suffisance des données et les limites de confiance ; le poids seul ne prouve jamais un changement de graisse ou de muscle.',
    'es':
        'BIL muestra la suficiencia de registros y los límites de confianza; el peso por sí solo no demuestra cambios de grasa o músculo.',
    'tr':
        'BIL kayıt yeterliliğini ve güven sınırlarını gösterir; kilo tek başına yağ veya kas değişimini kanıtlamaz.',
  },
  'Open weekly review': {
    'fr': 'Ouvrir le bilan',
    'es': 'Abrir revisión',
    'tr': 'Haftalık değerlendirmeyi aç',
  },
  '0 h': {'fr': '0 h', 'es': '0 h', 'tr': '0 sa'},
  '14 h': {'fr': '14 h', 'es': '14 h', 'tr': '14 sa'},
  'hours': {'fr': 'heures', 'es': 'horas', 'tr': 'saat'},
  'All': {'fr': 'Tout', 'es': 'Todo', 'tr': 'Tümü'},
  'Cardio': {'fr': 'Cardio', 'es': 'Cardio', 'tr': 'Kardiyo'},
  'Strength': {'fr': 'Force', 'es': 'Fuerza', 'tr': 'Kuvvet'},
  'Recovery': {'fr': 'Récupération', 'es': 'Recuperación', 'tr': 'Toparlanma'},
  'Exercise': {'fr': 'Exercices', 'es': 'Ejercicios', 'tr': 'Egzersiz'},
  'Search for an exercise': {
    'fr': 'Rechercher un exercice',
    'es': 'Buscar un ejercicio',
    'tr': 'Egzersiz ara',
  },
  'Log workout': {
    'fr': 'Enregistrer la séance',
    'es': 'Registrar entrenamiento',
    'tr': 'Antrenmanı kaydet',
  },
  'New exercise': {
    'fr': 'Nouvel exercice',
    'es': 'Nuevo ejercicio',
    'tr': 'Yeni egzersiz',
  },
  'Multi-add': {
    'fr': 'Ajout multiple',
    'es': 'Añadir varios',
    'tr': 'Çoklu ekle',
  },
  'No exercise history yet': {
    'fr': 'Aucun historique d’exercice',
    'es': 'Aún no hay historial de ejercicios',
    'tr': 'Henüz egzersiz geçmişi yok',
  },
  'No custom exercises yet': {
    'fr': 'Aucun exercice personnalisé',
    'es': 'Aún no hay ejercicios personalizados',
    'tr': 'Henüz özel egzersiz yok',
  },
  'Exercises you log will appear here for quick reuse.': {
    'fr': 'Les exercices enregistrés apparaîtront ici pour être réutilisés.',
    'es': 'Los ejercicios registrados aparecerán aquí para reutilizarlos.',
    'tr': 'Kaydettiğiniz egzersizler yeniden kullanım için burada görünür.',
  },
  'Create exercises that match your own training plan.': {
    'fr': 'Créez des exercices adaptés à votre programme.',
    'es': 'Crea ejercicios que se adapten a tu plan.',
    'tr': 'Kendi antrenman planınıza uygun egzersizler oluşturun.',
  },
  'Only the activity and duration you confirm are saved. BIL does not invent calorie burn.': {
    'fr':
        'Seules l’activité et la durée confirmées sont enregistrées. BIL n’invente pas les calories brûlées.',
    'es':
        'Solo se guardan la actividad y la duración confirmadas. BIL no inventa calorías quemadas.',
    'tr':
        'Yalnızca onayladığınız etkinlik ve süre kaydedilir. BIL yakılan kaloriyi tahmin etmez.',
  },
  'Workout added to today’s health record.': {
    'fr': 'Séance ajoutée au journal de santé du jour.',
    'es': 'Entrenamiento añadido al registro de salud de hoy.',
    'tr': 'Antrenman bugünkü sağlık kaydına eklendi.',
  },
  'Sleep': {'fr': 'Sommeil', 'es': 'Sueño', 'tr': 'Uyku'},
  'Sleep intelligence': {
    'fr': 'Intelligence du sommeil',
    'es': 'Inteligencia del sueño',
    'tr': 'Uyku zekâsı',
  },
  'Log': {'fr': 'Journal', 'es': 'Registro', 'tr': 'Kayıt'},
  'Insights': {'fr': 'Analyses', 'es': 'Perspectivas', 'tr': 'İçgörüler'},
  'Learn': {'fr': 'Apprendre', 'es': 'Aprender', 'tr': 'Öğren'},
  'Illustration only': {
    'fr': 'Illustration uniquement',
    'es': 'Solo ilustración',
    'tr': 'Yalnızca görsel',
  },
  'Review meals alongside sleep': {
    'fr': 'Examiner les repas en parallèle du sommeil',
    'es': 'Revisar las comidas junto con el sueño',
    'tr': 'Yemekleri uykuyla birlikte inceleyin',
  },
  'Record last night': {
    'fr': 'Enregistrer la nuit dernière',
    'es': 'Registrar la noche anterior',
    'tr': 'Dün geceyi kaydet',
  },
  'Save sleep': {
    'fr': 'Enregistrer le sommeil',
    'es': 'Guardar sueño',
    'tr': 'Uykuyu kaydet',
  },
  'Saving…': {
    'fr': 'Enregistrement…',
    'es': 'Guardando…',
    'tr': 'Kaydediliyor…',
  },
  'Sleep saved to today’s health record.': {
    'fr': 'Sommeil enregistré dans le journal de santé du jour.',
    'es': 'Sueño guardado en el registro de salud de hoy.',
    'tr': 'Uyku bugünkü sağlık kaydına kaydedildi.',
  },
  'Sleep history unavailable': {
    'fr': 'Historique du sommeil indisponible',
    'es': 'Historial de sueño no disponible',
    'tr': 'Uyku geçmişi kullanılamıyor',
  },
  'Open Daily Log to review meal timing alongside saved sleep. This does not establish causation.': {
    'fr':
        'Ouvrez le journal quotidien pour examiner les horaires des repas avec le sommeil enregistré. Cela n’établit pas de causalité.',
    'es':
        'Abre el registro diario para revisar el horario de las comidas junto con el sueño guardado. Esto no establece causalidad.',
    'tr':
        'Öğün zamanlamasını kayıtlı uykuyla birlikte incelemek için Günlük Kaydı açın. Bu, nedensellik göstermez.',
  },
  'No sleep trend yet': {
    'fr': 'Aucune tendance de sommeil',
    'es': 'Aún no hay tendencia de sueño',
    'tr': 'Henüz uyku eğilimi yok',
  },
  'Your recorded sleep': {
    'fr': 'Votre sommeil enregistré',
    'es': 'Tu sueño registrado',
    'tr': 'Kaydedilen uykunuz',
  },
  'How does food affect your sleep?': {
    'fr': 'Comment l’alimentation influence-t-elle votre sommeil ?',
    'es': '¿Cómo afecta la comida a tu sueño?',
    'tr': 'Yemek uykunuzu nasıl etkiler?',
  },
  'Spot trends, adjust your routine, and sleep well with BIL.': {
    'fr':
        'Repérez les tendances, adaptez votre routine et dormez mieux avec BIL.',
    'es': 'Detecta patrones, ajusta tu rutina y duerme mejor con BIL.',
    'tr': 'Eğilimleri görün, rutininizi ayarlayın ve BIL ile daha iyi uyuyun.',
  },
  "Find out what's keeping you awake": {
    'fr': 'Découvrez ce qui vous tient éveillé',
    'es': 'Descubre qué te mantiene despierto',
    'tr': 'Sizi neyin uyanık tuttuğunu keşfedin',
  },
  'Your eating and fitness habits might be making it hard to fall asleep and stay asleep.': {
    'fr':
        'Vos habitudes alimentaires et sportives peuvent compliquer l’endormissement et le maintien du sommeil.',
    'es':
        'Tus hábitos de alimentación y ejercicio pueden dificultar conciliar y mantener el sueño.',
    'tr':
        'Beslenme ve egzersiz alışkanlıklarınız uykuya dalmayı ve uykuda kalmayı zorlaştırabilir.',
  },
  'Time your meals for the best rest': {
    'fr': 'Planifiez vos repas pour mieux dormir',
    'es': 'Programa tus comidas para descansar mejor',
    'tr': 'En iyi dinlenme için öğünlerinizi zamanlayın',
  },
  'When you eat can be as important as what you eat, especially later in the day.': {
    'fr':
        'L’heure des repas peut compter autant que leur contenu, surtout en fin de journée.',
    'es':
        'Cuándo comes puede ser tan importante como qué comes, especialmente al final del día.',
    'tr':
        'Ne zaman yediğiniz, özellikle günün ilerleyen saatlerinde ne yediğiniz kadar önemli olabilir.',
  },
  'See my data': {
    'fr': 'Voir mes données',
    'es': 'Ver mis datos',
    'tr': 'Verilerimi gör',
  },
  'Sleep factors': {
    'fr': 'Facteurs du sommeil',
    'es': 'Factores del sueño',
    'tr': 'Uyku faktörleri',
  },
  'Foods logged': {
    'fr': 'Aliments enregistrés',
    'es': 'Alimentos registrados',
    'tr': 'Kaydedilen yiyecekler',
  },
  'Understand your sleep': {
    'fr': 'Comprendre votre sommeil',
    'es': 'Comprende tu sueño',
    'tr': 'Uykunuzu anlayın',
  },
  'Food and sleep': {
    'fr': 'Alimentation et sommeil',
    'es': 'Alimentación y sueño',
    'tr': 'Beslenme ve uyku',
  },
  'Morning context': {
    'fr': 'Contexte du matin',
    'es': 'Contexto matutino',
    'tr': 'Sabah bağlamı',
  },
  'Look for repeated patterns': {
    'fr': 'Recherchez des tendances répétées',
    'es': 'Busca patrones repetidos',
    'tr': 'Tekrarlanan örüntüleri arayın',
  },
  'Record sleep to build a recorded trend. Missing days stay missing.': {
    'fr':
        'Enregistrez votre sommeil pour construire une tendance enregistrée. Les jours manquants restent manquants.',
    'es':
        'Registra el sueño para crear una tendencia registrada. Los días faltantes siguen faltando.',
    'tr': 'Kayıtlı bir eğilim için uykuyu kaydedin. Eksik günler eksik kalır.',
  },
  'One night is not a trend. Use several recorded nights and keep missing days visible.': {
    'fr':
        'Une nuit ne constitue pas une tendance. Utilisez plusieurs nuits enregistrées et gardez les jours manquants visibles.',
    'es':
        'Una noche no es una tendencia. Usa varias noches registradas y mantén visibles los días faltantes.',
    'tr':
        'Tek gece bir eğilim değildir. Birkaç kayıtlı gece kullanın ve eksik günleri görünür tutun.',
  },
  'Only saved nights are shown. BIL does not estimate missing nights or diagnose sleep conditions.': {
    'fr':
        'Seules les nuits enregistrées sont affichées. BIL n’estime pas les nuits manquantes et ne diagnostique pas.',
    'es':
        'Solo se muestran las noches guardadas. BIL no estima noches faltantes ni diagnostica trastornos.',
    'tr':
        'Yalnızca kaydedilen geceler gösterilir. BIL eksik geceleri tahmin etmez veya tanı koymaz.',
  },
  'Sleep duration alone does not explain energy. Activity, stress, illness, and schedule can matter.': {
    'fr':
        'La durée du sommeil seule n’explique pas l’énergie. Activité, stress, maladie et horaires peuvent compter.',
    'es':
        'La duración del sueño por sí sola no explica la energía. Actividad, estrés, enfermedad y horarios importan.',
    'tr':
        'Uyku süresi tek başına enerjiyi açıklamaz. Aktivite, stres, hastalık ve program etkili olabilir.',
  },
  'Sleep duration is a personal log, not a medical measurement or diagnosis.': {
    'fr':
        'La durée du sommeil est un journal personnel, pas une mesure ni un diagnostic médical.',
    'es':
        'La duración del sueño es un registro personal, no una medición ni diagnóstico médico.',
    'tr': 'Uyku süresi kişisel bir kayıttır; tıbbi ölçüm veya tanı değildir.',
  },
  'Your real sleep record can inform recovery guidance and Body Twin confidence.': {
    'fr':
        'Votre sommeil réel peut éclairer les conseils de récupération et la confiance de Body Twin.',
    'es':
        'Tu registro real de sueño puede orientar la recuperación y la confianza de Body Twin.',
    'tr':
        'Gerçek uyku kaydınız toparlanma rehberini ve Body Twin güvenini destekleyebilir.',
  },
  'Use recorded patterns as context—not as a diagnosis.': {
    'fr':
        'Utilisez les tendances enregistrées comme contexte, pas comme diagnostic.',
    'es': 'Usa los patrones registrados como contexto, no como diagnóstico.',
    'tr': 'Kaydedilen örüntüleri tanı değil, bağlam olarak kullanın.',
  },
  'Large late meals may affect comfort for some people. Record timing and compare your own repeated observations.': {
    'fr':
        'Les repas copieux tardifs peuvent gêner certaines personnes. Notez l’heure et comparez vos observations répétées.',
    'es':
        'Las comidas copiosas tardías pueden afectar a algunas personas. Registra la hora y compara tus observaciones.',
    'tr':
        'Geç saatte büyük öğünler bazı kişileri etkileyebilir. Zamanı kaydedin ve tekrar eden gözlemlerinizi karşılaştırın.',
  },
  'Seek qualified medical care for persistent sleep problems, breathing concerns, or severe daytime sleepiness.': {
    'fr':
        'Consultez un professionnel qualifié en cas de troubles persistants, de problèmes respiratoires ou de somnolence sévère.',
    'es':
        'Busca atención médica cualificada ante problemas persistentes, respiración preocupante o somnolencia intensa.',
    'tr':
        'Sürekli uyku sorunları, solunum endişeleri veya şiddetli gündüz uykululuğu için nitelikli tıbbi yardım alın.',
  },
  'Your saved data was not changed. Try again.': {
    'fr': 'Vos données enregistrées n’ont pas été modifiées. Réessayez.',
    'es': 'Tus datos guardados no cambiaron. Inténtalo de nuevo.',
    'tr': 'Kayıtlı verileriniz değişmedi. Tekrar deneyin.',
  },
  'Intermittent fasting with BIL': {
    'fr': 'Jeûne intermittent avec BIL',
    'es': 'Ayuno intermitente con BIL',
    'tr': 'BIL ile aralıklı oruç',
  },
  'Three popular fasting options to get started': {
    'fr': 'Trois options de jeûne populaires pour commencer',
    'es': 'Tres opciones de ayuno populares para empezar',
    'tr': 'Başlamak için üç popüler oruç seçeneği',
  },
  'Easy stop and start timer for flexibility and accuracy': {
    'fr':
        'Minuteur facile à démarrer et arrêter, pour plus de souplesse et de précision',
    'es':
        'Temporizador fácil de iniciar y detener para mayor flexibilidad y precisión',
    'tr': 'Esneklik ve doğruluk için kolayca başlatılıp durdurulan zamanlayıcı',
  },
  'Track fasts and meals in one place': {
    'fr': 'Suivez vos jeûnes et vos repas au même endroit',
    'es': 'Registra ayunos y comidas en un solo lugar',
    'tr': 'Oruçları ve öğünleri tek yerde takip edin',
  },
  'What is intermittent fasting, and is it right for you?': {
    'fr': 'Qu’est-ce que le jeûne intermittent et vous convient-il ?',
    'es': '¿Qué es el ayuno intermitente y es adecuado para ti?',
    'tr': 'Aralıklı oruç nedir ve size uygun mu?',
  },
  'Check with your clinician before significant dietary changes.': {
    'fr':
        'Consultez votre professionnel de santé avant tout changement alimentaire important.',
    'es':
        'Consulta a tu profesional sanitario antes de hacer cambios importantes en la dieta.',
    'tr': 'Önemli beslenme değişikliklerinden önce sağlık uzmanınıza danışın.',
  },
  'Fasting rhythm': {
    'fr': 'Rythme de jeûne',
    'es': 'Ritmo de ayuno',
    'tr': 'Oruç ritmi',
  },
  'Intermittent fasting': {
    'fr': 'Jeûne intermittent',
    'es': 'Ayuno intermitente',
    'tr': 'Aralıklı oruç',
  },
  'Intermittent fast in progress': {
    'fr': 'Jeûne intermittent en cours',
    'es': 'Ayuno intermitente en curso',
    'tr': 'Aralıklı oruç sürüyor',
  },
  'Intermittent fasting history': {
    'fr': 'Historique du jeûne intermittent',
    'es': 'Historial de ayuno intermitente',
    'tr': 'Aralıklı oruç geçmişi',
  },
  'Start intermittent fast': {
    'fr': 'Commencer le jeûne intermittent',
    'es': 'Iniciar ayuno intermitente',
    'tr': 'Aralıklı orucu başlat',
  },
  'End intermittent fast': {
    'fr': 'Terminer le jeûne intermittent',
    'es': 'Finalizar ayuno intermitente',
    'tr': 'Aralıklı orucu bitir',
  },
  'Fast in progress': {
    'fr': 'Jeûne en cours',
    'es': 'Ayuno en curso',
    'tr': 'Oruç sürüyor',
  },
  'Choose your window': {
    'fr': 'Choisissez votre fenêtre',
    'es': 'Elige tu ventana',
    'tr': 'Aralığınızı seçin',
  },
  'Start fast': {
    'fr': 'Commencer',
    'es': 'Iniciar ayuno',
    'tr': 'Orucu başlat',
  },
  'End fast': {'fr': 'Terminer', 'es': 'Finalizar ayuno', 'tr': 'Orucu bitir'},
  'Last fast': {'fr': 'Dernier jeûne', 'es': 'Último ayuno', 'tr': 'Son oruç'},
  'A simple local timer. You remain in control.': {
    'fr': 'Un minuteur local simple. Vous gardez le contrôle.',
    'es': 'Un temporizador local sencillo. Tú mantienes el control.',
    'tr': 'Basit bir yerel zamanlayıcı. Kontrol sizde kalır.',
  },
  'Fasting is optional and is not medical advice. Do not fast if it conflicts with pregnancy, medication, an eating-disorder history, diabetes care, or clinician guidance.': {
    'fr':
        'Le jeûne est facultatif et ne constitue pas un avis médical. Ne jeûnez pas en cas de grossesse, traitement, antécédents de troubles alimentaires, diabète ou avis médical contraire.',
    'es':
        'El ayuno es opcional y no es consejo médico. No ayunes si entra en conflicto con embarazo, medicación, trastornos alimentarios, diabetes o indicación clínica.',
    'tr':
        'Oruç isteğe bağlıdır ve tıbbi tavsiye değildir. Hamilelik, ilaç, yeme bozukluğu öyküsü, diyabet bakımı veya klinisyen önerisiyle çelişiyorsa oruç tutmayın.',
  },
};
