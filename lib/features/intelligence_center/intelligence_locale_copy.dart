import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';

String intelligenceText(BuildContext context, String english, String arabic) =>
    intelligenceTextFor(
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      english,
      arabic,
    );

String intelligenceTextFor(String localeTag, String english, String arabic) {
  final normalized = localeTag.replaceAll('_', '-');
  final code = normalized.toLowerCase().split('-').first;
  if (code == 'ar') return arabic;
  final authored =
      _authored[english]?[code] ?? _serviceAuthored[english]?[code];
  if (authored != null) return authored;
  final exact = RuntimeCopy.resolve(english, normalized);
  if (exact != null) return exact;
  return AppLocalizations(
    BilLocalePolicy.localeFromTag(normalized),
  ).text(english);
}

const _serviceAuthored = <String, Map<String, String>>{
  'Take action': {'fr': 'Agir', 'es': 'Realizar la acción', 'tr': 'İşlemi yap'},
  'Enter your question first.': {
    'fr': 'Saisissez d’abord votre question.',
    'es': 'Escribe primero tu pregunta.',
    'tr': 'Önce sorunuzu yazın.',
  },
  'Review account and data deletion': {
    'fr': 'Vérifier la suppression du compte et des données',
    'es': 'Revisar la eliminación de la cuenta y los datos',
    'tr': 'Hesap ve veri silme işlemini incele',
  },
  'Open official subscription management': {
    'fr': 'Ouvrir la gestion officielle de l’abonnement',
    'es': 'Abrir la gestión oficial de la suscripción',
    'tr': 'Resmî abonelik yönetimini aç',
  },
  'Review water log': {
    'fr': 'Vérifier le journal d’eau',
    'es': 'Revisar el registro de agua',
    'tr': 'Su kaydını incele',
  },
  'Open weight check-in': {
    'fr': 'Ouvrir la saisie du poids',
    'es': 'Abrir el registro de peso',
    'tr': 'Kilo kaydını aç',
  },
  'Review meal before logging': {
    'fr': 'Vérifier le repas avant de l’enregistrer',
    'es': 'Revisar la comida antes de registrarla',
    'tr': 'Kaydetmeden önce öğünü incele',
  },
  'Review workout before logging': {
    'fr': 'Vérifier l’entraînement avant de l’enregistrer',
    'es': 'Revisar el entrenamiento antes de registrarlo',
    'tr': 'Kaydetmeden önce antrenmanı incele',
  },
  'Open weight log': {
    'fr': 'Ouvrir le journal du poids',
    'es': 'Abrir el registro de peso',
    'tr': 'Kilo günlüğünü aç',
  },
  'Open meal log': {
    'fr': 'Ouvrir le journal des repas',
    'es': 'Abrir el registro de comidas',
    'tr': 'Öğün günlüğünü aç',
  },
  "Show yesterday's meals": {
    'fr': 'Afficher les repas d’hier',
    'es': 'Mostrar las comidas de ayer',
    'tr': 'Dünkü öğünleri göster',
  },
  'Open workouts': {
    'fr': 'Ouvrir les entraînements',
    'es': 'Abrir entrenamientos',
    'tr': 'Antrenmanları aç',
  },
  'Open plan': {
    'fr': 'Ouvrir le programme',
    'es': 'Abrir el plan',
    'tr': 'Planı aç',
  },
  'Open report': {
    'fr': 'Ouvrir le rapport',
    'es': 'Abrir el informe',
    'tr': 'Raporu aç',
  },
  'Manage subscription': {
    'fr': 'Gérer l’abonnement',
    'es': 'Gestionar la suscripción',
    'tr': 'Aboneliği yönet',
  },
  'Review account deletion': {
    'fr': 'Vérifier la suppression du compte',
    'es': 'Revisar la eliminación de la cuenta',
    'tr': 'Hesap silme işlemini incele',
  },
  'Confirm water log': {
    'fr': 'Confirmer l’enregistrement de l’eau',
    'es': 'Confirmar el registro de agua',
    'tr': 'Su kaydını onayla',
  },
  'Confirm weight log': {
    'fr': 'Confirmer l’enregistrement du poids',
    'es': 'Confirmar el registro de peso',
    'tr': 'Kilo kaydını onayla',
  },
  'Diagnosis requires qualified clinical evaluation.': {
    'fr': 'Un diagnostic nécessite une évaluation clinique qualifiée.',
    'es': 'El diagnóstico requiere una evaluación clínica cualificada.',
    'tr': 'Tanı, yetkin bir klinik değerlendirme gerektirir.',
  },
  'Open daily log': {
    'fr': 'Ouvrir le journal du jour',
    'es': 'Abrir el registro diario',
    'tr': 'Günlük kaydı aç',
  },
  'Remember this about me': {
    'fr': 'Mémoriser cette information sur moi',
    'es': 'Recordar esta información sobre mí',
    'tr': 'Hakkımdaki bu bilgiyi hatırla',
  },
  'Review suggested action': {
    'fr': 'Vérifier l’action suggérée',
    'es': 'Revisar la acción sugerida',
    'tr': 'Önerilen işlemi incele',
  },
  'Open plan settings': {
    'fr': 'Ouvrir les paramètres du programme',
    'es': 'Abrir la configuración del plan',
    'tr': 'Plan ayarlarını aç',
  },
};

const _authored = <String, Map<String, String>>{
  'I am BIL. I explain what I know, expose what I do not know, and never execute an action without your approval.': {
    'fr': 'Je suis BIL. J’explique ce que je sais, indique ce que j’ignore et n’exécute jamais une action sans votre accord.',
    'es': 'Soy BIL. Explico lo que sé, indico lo que no sé y nunca ejecuto una acción sin tu aprobación.',
    'tr': 'Ben BIL. Bildiklerimi açıklar, bilmediklerimi belirtir ve onayınız olmadan hiçbir işlemi gerçekleştirmem.',
  },
  'Analyze a food photo': {
    'fr': 'Analyser une photo de repas',
    'es': 'Analizar una foto de comida',
    'tr': 'Yemek fotoğrafını analiz et',
  },
  'Take food photo': {
    'fr': 'Prendre une photo du repas',
    'es': 'Tomar una foto de la comida',
    'tr': 'Yemek fotoğrafı çek',
  },
  'Choose food photo': {
    'fr': 'Choisir une photo du repas',
    'es': 'Elegir una foto de la comida',
    'tr': 'Yemek fotoğrafı seç',
  },
  'BIL AI Coach': {
    'fr': 'Coach IA BIL',
    'es': 'Coach de IA BIL',
    'tr': 'BIL Yapay Zekâ Koçu',
  },
  'Talk to AI Coach': {
    'fr': 'Parler au coach IA',
    'es': 'Hablar con el coach de IA',
    'tr': 'Yapay zekâ koçuyla konuş',
  },
  'Listening…': {'fr': 'Écoute…', 'es': 'Escuchando…', 'tr': 'Dinliyor…'},
  'Cancel': {'fr': 'Annuler', 'es': 'Cancelar', 'tr': 'İptal'},
  'Use text': {
    'fr': 'Utiliser le texte',
    'es': 'Usar texto',
    'tr': 'Metni kullan',
  },
  'Confirm action': {
    'fr': 'Confirmer l’action',
    'es': 'Confirmar acción',
    'tr': 'İşlemi onayla',
  },
  'Continue': {'fr': 'Continuer', 'es': 'Continuar', 'tr': 'Devam et'},
  'AI Coach': {'fr': 'Coach IA', 'es': 'Coach de IA', 'tr': 'Yapay Zekâ Koçu'},
  'Ask BIL': {
    'fr': 'Demander à BIL',
    'es': 'Preguntar a BIL',
    'tr': 'BIL’e sor',
  },
  'How can AI Coach help?': {
    'fr': 'Comment le coach IA peut-il aider ?',
    'es': '¿Cómo puede ayudarte el coach de IA?',
    'tr': 'Yapay zekâ koçu nasıl yardımcı olabilir?',
  },
  'Try now': {
    'fr': 'Essayer maintenant',
    'es': 'Probar ahora',
    'tr': 'Şimdi dene',
  },
  'Listen to response': {
    'fr': 'Écouter la réponse',
    'es': 'Escuchar respuesta',
    'tr': 'Yanıtı dinle',
  },
  'Suggested actions': {
    'fr': 'Actions suggérées',
    'es': 'Acciones sugeridas',
    'tr': 'Önerilen işlemler',
  },
  'Requires your confirmation': {
    'fr': 'Nécessite votre confirmation',
    'es': 'Requiere tu confirmación',
    'tr': 'Onayınız gerekiyor',
  },
  'Water logged locally.': {
    'fr': 'Eau enregistrée localement.',
    'es': 'Agua registrada localmente.',
    'tr': 'Su yerel olarak kaydedildi.',
  },
  'Weight logged locally.': {
    'fr': 'Poids enregistré localement.',
    'es': 'Peso registrado localmente.',
    'tr': 'Kilo yerel olarak kaydedildi.',
  },
  'Clear local conversation': {
    'fr': 'Effacer la conversation locale',
    'es': 'Borrar conversación local',
    'tr': 'Yerel konuşmayı temizle',
  },
  'Ask about your body, food, or progress...': {
    'fr':
        'Posez une question sur votre corps, votre alimentation ou vos progrès…',
    'es': 'Pregunta sobre tu cuerpo, comida o progreso…',
    'tr': 'Vücudunuz, beslenmeniz veya ilerlemeniz hakkında sorun…',
  },
  'Voice input is unavailable right now. You can type and send your question.': {
    'fr':
        'La saisie vocale est indisponible. Vous pouvez écrire et envoyer votre question.',
    'es':
        'La entrada de voz no está disponible. Puedes escribir y enviar tu pregunta.',
    'tr':
        'Sesli giriş şu anda kullanılamıyor. Sorunuzu yazıp gönderebilirsiniz.',
  },
  'Analyze my weight plateau': {
    'fr': 'Analyser la stagnation de mon poids',
    'es': 'Analiza mi estancamiento de peso',
    'tr': 'Kilo duraklamamı analiz et',
  },
  'Is my protein enough today?': {
    'fr': 'Ai-je assez de protéines aujourd’hui ?',
    'es': '¿Mi proteína es suficiente hoy?',
    'tr': 'Bugünkü proteinim yeterli mi?',
  },
  'What is my best action now?': {
    'fr': 'Quelle est ma meilleure action maintenant ?',
    'es': '¿Cuál es mi mejor acción ahora?',
    'tr': 'Şimdi en iyi adımım ne?',
  },
  'Review my food day': {
    'fr': 'Examiner ma journée alimentaire',
    'es': 'Revisa mi día de alimentación',
    'tr': 'Beslenme günümü incele',
  },
  'What data is missing?': {
    'fr': 'Quelles données manquent ?',
    'es': '¿Qué datos faltan?',
    'tr': 'Hangi veriler eksik?',
  },
  'Ask about my body': {
    'fr': 'Question sur mon corps',
    'es': 'Pregunta sobre mi cuerpo',
    'tr': 'Vücudum hakkında sor',
  },
  'Why is my weight stable?': {
    'fr': 'Pourquoi mon poids est-il stable ?',
    'es': '¿Por qué mi peso está estable?',
    'tr': 'Kilom neden sabit?',
  },
  'What should I eat now?': {
    'fr': 'Que devrais-je manger maintenant ?',
    'es': '¿Qué debería comer ahora?',
    'tr': 'Şimdi ne yemeliyim?',
  },
  'Build me a plan': {
    'fr': 'Créer un plan pour moi',
    'es': 'Crea un plan para mí',
    'tr': 'Bana bir plan oluştur',
  },
  'Review my day': {
    'fr': 'Examiner ma journée',
    'es': 'Revisa mi día',
    'tr': 'Günümü incele',
  },
  'A voice for this language is unavailable on this device.': {
    'fr': 'Aucune voix pour cette langue n’est disponible sur cet appareil.',
    'es': 'No hay una voz disponible para este idioma en el dispositivo.',
    'tr': 'Bu dil için cihazda kullanılabilir bir ses yok.',
  },
  'It surfaces observations from your data, explains why, and proposes an action for your approval.': {
    'fr':
        'Il présente des observations issues de vos données, explique pourquoi et propose une action soumise à votre approbation.',
    'es':
        'Muestra observaciones de tus datos, explica el motivo y propone una acción para tu aprobación.',
    'tr':
        'Verilerinizden gözlemler sunar, nedenini açıklar ve onayınız için bir işlem önerir.',
  },
  'The local conversation could not be cleared. Your data was unchanged.': {
    'fr':
        'La conversation locale n’a pas pu être effacée. Vos données n’ont pas changé.',
    'es': 'No se pudo borrar la conversación local. Tus datos no cambiaron.',
    'tr': 'Yerel konuşma temizlenemedi. Verileriniz değişmedi.',
  },
  'AI Coach could not prepare your context. Your data was not changed; try again.': {
    'fr':
        'Le coach IA n’a pas pu préparer votre contexte. Vos données n’ont pas changé ; réessayez.',
    'es':
        'El coach de IA no pudo preparar tu contexto. Tus datos no cambiaron; inténtalo de nuevo.',
    'tr':
        'Yapay zekâ koçu bağlamınızı hazırlayamadı. Verileriniz değişmedi; tekrar deneyin.',
  },
  'AI Coach could not complete this reply. Your data was not changed; try again.': {
    'fr':
        'Le coach IA n’a pas pu terminer cette réponse. Vos données n’ont pas changé ; réessayez.',
    'es':
        'El coach de IA no pudo completar esta respuesta. Tus datos no cambiaron; inténtalo de nuevo.',
    'tr':
        'Yapay zekâ koçu bu yanıtı tamamlayamadı. Verileriniz değişmedi; tekrar deneyin.',
  },
  'This action requires confirmation and a repository write before execution.': {
    'fr':
        'Cette action nécessite une confirmation et une écriture dans le stockage avant son exécution.',
    'es':
        'Esta acción requiere confirmación y escritura en el repositorio antes de ejecutarse.',
    'tr': 'Bu işlem yürütülmeden önce onay ve veri deposuna yazma gerektirir.',
  },
  'The action was not completed. Your data stayed unchanged; review the value and try again.': {
    'fr':
        'L’action n’a pas été effectuée. Vos données sont restées inchangées ; vérifiez la valeur et réessayez.',
    'es':
        'La acción no se completó. Tus datos no cambiaron; revisa el valor e inténtalo de nuevo.',
    'tr':
        'İşlem tamamlanmadı. Verileriniz değişmedi; değeri kontrol edip tekrar deneyin.',
  },
};
