import 'package:flutter/widgets.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy_extended.dart';

String communityText(BuildContext context, String en, String ar) =>
    communityTextForLanguage(
      BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      en,
      ar,
    );

String communityTextForLanguage(String languageCode, String en, String ar) {
  final code = languageCode.toLowerCase();
  if (code == 'ar') return ar;
  if (code == 'en') return en;
  return _communityCopy[code]?[en] ??
      ExtendedRuntimeCopy.values[en]?[languageCode] ??
      en;
}

const _communityCopy = <String, Map<String, String>>{
  'fr': {
    'Confirm review': 'Confirmer l’examen',
    'Cancel': 'Annuler',
    'Submit': 'Envoyer',
    'Moderator decision saved.': 'Décision du modérateur enregistrée.',
    'Product review': 'Examen des produits',
    'confidence': 'confiance',
    'Approve': 'Approuver',
    'Needs changes': 'Modifications requises',
    'Reject': 'Rejeter',
    'Safety and policy': 'Sécurité et politique',
    'Community profile': 'Profil communautaire',
    'Friends and requests': 'Amis et demandes',
    'Review foods': 'Examiner les aliments',
    'Find people': 'Trouver des personnes',
    'BIL Community': 'Communauté BIL',
    'Community': 'Communauté',
    'Friends': 'Amis',
    'Verified food': 'Aliment vérifié',
    'Sign in': 'Se connecter',
    'Privacy & safety': 'Confidentialité et sécurité',
    'Post deleted.': 'Publication supprimée.',
    'BIL member': 'Membre BIL',
    'Delete': 'Supprimer',
    'Report': 'Signaler',
    'Submit community food': 'Proposer un aliment communautaire',
    'Name': 'Nom',
    'Serving grams': 'Portion en grammes',
    'Calories': 'Calories',
    'Protein': 'Protéines',
    'Carbohydrate': 'Glucides',
    'Fat': 'Lipides',
    'Send for review': 'Envoyer pour examen',
    'Submit food': 'Proposer l’aliment',
    'Safety & community policy': 'Sécurité et règles de la communauté',
    'Consent could not be saved. Publishing remains locked.':
        'Le consentement n’a pas pu être enregistré. La publication reste verrouillée.',
    'A community built around privacy and dignity.':
        'Une communauté fondée sur la confidentialité et la dignité.',
    'Content policy': 'Règles de contenu',
    'Accepted': 'Acceptée',
    'Accept policy': 'Accepter les règles',
    'Health logs stay private': 'Les journaux de santé restent privés',
    'BIL never posts weight, meals, or measurements without an explicit share action.':
        'BIL ne publie jamais le poids, les repas ou les mesures sans une action de partage explicite.',
    'Report, block, and delete': 'Signaler, bloquer et supprimer',
    'You can report content, block a member, and delete your own content or messages.':
        'Vous pouvez signaler un contenu, bloquer un membre et supprimer votre contenu ou vos messages.',
    'Abuse prevention': 'Prévention des abus',
    'Rate limits, human moderation, and metadata-only audit trails protect the community.':
        'Les limites de débit, la modération humaine et les journaux limités aux métadonnées protègent la communauté.',
    'Community is unavailable in this build and remains hidden until secure cloud configuration is complete.':
        'La communauté est indisponible dans cette version et reste masquée jusqu’à la fin de la configuration sécurisée du cloud.',
    'Who can see my profile': 'Qui peut voir mon profil',
    'Allow friend requests': 'Autoriser les demandes d’amitié',
    'Allow follows': 'Autoriser les abonnements',
    'Who can message me': 'Qui peut m’envoyer un message',
    'Delete account and data': 'Supprimer le compte et les données',
    'Push is disabled immediately and a secure request is queued to permanently delete all account data. This cannot be undone after processing. Deleting BIL does not cancel an App Store or Google Play subscription; cancel it in the device store when needed.':
        'Les notifications sont désactivées immédiatement et une demande sécurisée de suppression définitive des données est mise en attente. Cette action est irréversible après traitement. La suppression de BIL n’annule pas un abonnement App Store ou Google Play ; annulez-le dans la boutique de l’appareil.',
    'Request deletion': 'Demander la suppression',
    'Deletion request queued securely.':
        'La demande de suppression a été enregistrée en toute sécurité.',
    'Sign in to manage your community profile.':
        'Connectez-vous pour gérer votre profil communautaire.',
    'Public': 'Public',
    'Friends only': 'Amis uniquement',
    'Private': 'Privé',
    'Nobody': 'Personne',
    'Sign-in required': 'Connexion requise',
    'Not now': 'Pas maintenant',
    'Submit product for review': 'Soumettre le produit à examen',
    'Product name': 'Nom du produit',
    'Enter the product name': 'Saisissez le nom du produit',
    'Barcode': 'Code-barres',
    'Product type': 'Type de produit',
    'Food': 'Aliment',
    'Beverage': 'Boisson',
    'Alcohol': 'Alcool',
    'Supplement': 'Complément',
    'Medicine': 'Médicament',
    'Tobacco': 'Tabac',
    'Personal care': 'Soins personnels',
    'Pet food': 'Alimentation animale',
    'Household': 'Produit ménager',
    'General product': 'Produit général',
    'Unknown': 'Inconnu',
    'Brand (optional)': 'Marque (facultatif)',
    'Country code (optional)': 'Code pays (facultatif)',
    'Use two letters, for example SA': 'Utilisez deux lettres, par exemple FR',
    'Evidence URL (optional)': 'URL de preuve (facultatif)',
    'Enter a valid URL': 'Saisissez une URL valide',
    'Note for reviewer (optional)': 'Note au réviseur (facultatif)',
    'Submit for review': 'Soumettre à examen',
    'Could not submit the product. Check the connection and try again.':
        'Impossible de soumettre le produit. Vérifiez la connexion et réessayez.',
    'Submitting a product for review requires an account. BIL will not upload or guess nutrition values, and the barcode stays on this device until you sign in.':
        'Un compte est requis pour soumettre un produit. BIL ne téléverse ni ne devine les valeurs nutritionnelles, et le code-barres reste sur cet appareil jusqu’à la connexion.',
    'This product will not become verified or searchable until a moderator reviews it. Do not submit estimated nutrition values.':
        'Ce produit ne sera ni vérifié ni consultable avant l’examen d’un modérateur. Ne soumettez pas de valeurs nutritionnelles estimées.',
    'Sign in to open community, friends, and messages.':
        'Connectez-vous pour accéder à la communauté, aux amis et aux messages.',
    'Health logs are never posted automatically. You choose every share.':
        'Les journaux de santé ne sont jamais publiés automatiquement. Vous choisissez chaque partage.',
    'Could not publish now. Your text is kept so you can retry.':
        'Publication impossible. Votre texte est conservé pour réessayer.',
    'Report sent for review.': 'Signalement envoyé pour examen.',
    'Could not complete that action safely. Try again.':
        'Impossible d’effectuer cette action en toute sécurité. Réessayez.',
    'Share an experience or win': 'Partager une expérience ou une réussite',
    'Do not share private health data you want to keep private.':
        'Ne partagez pas les données de santé que vous souhaitez garder privées.',
    'No posts yet. Start the first conversation.':
        'Aucune publication. Lancez la première conversation.',
    'No requests or friendships yet.':
        'Aucune demande ni amitié pour le moment.',
    'Complete all required values.': 'Renseignez toutes les valeurs requises.',
    'Food submitted for review. It will not appear as verified before validation.':
        'Aliment soumis à examen. Il ne sera pas marqué vérifié avant validation.',
    'Arabic and Gulf foods are reviewed before approval, and your contribution remains attributed to you.':
        'Les aliments arabes et du Golfe sont examinés avant approbation, et votre contribution vous reste attribuée.',
    'Community could not be loaded. No data was lost.':
        'Impossible de charger la communauté. Aucune donnée n’a été perdue.',
  },
  'es': {
    'Confirm review': 'Confirmar revisión',
    'Cancel': 'Cancelar',
    'Submit': 'Enviar',
    'Moderator decision saved.': 'Decisión del moderador guardada.',
    'Product review': 'Revisión de productos',
    'confidence': 'confianza',
    'Approve': 'Aprobar',
    'Needs changes': 'Necesita cambios',
    'Reject': 'Rechazar',
    'Safety and policy': 'Seguridad y política',
    'Community profile': 'Perfil de la comunidad',
    'Friends and requests': 'Amigos y solicitudes',
    'Review foods': 'Revisar alimentos',
    'Find people': 'Buscar personas',
    'BIL Community': 'Comunidad BIL',
    'Community': 'Comunidad',
    'Friends': 'Amigos',
    'Verified food': 'Alimento verificado',
    'Sign in': 'Iniciar sesión',
    'Privacy & safety': 'Privacidad y seguridad',
    'Post deleted.': 'Publicación eliminada.',
    'BIL member': 'Miembro de BIL',
    'Delete': 'Eliminar',
    'Report': 'Denunciar',
    'Submit community food': 'Enviar alimento comunitario',
    'Name': 'Nombre',
    'Serving grams': 'Porción en gramos',
    'Calories': 'Calorías',
    'Protein': 'Proteína',
    'Carbohydrate': 'Carbohidratos',
    'Fat': 'Grasa',
    'Send for review': 'Enviar para revisión',
    'Submit food': 'Enviar alimento',
    'Safety & community policy': 'Seguridad y normas de la comunidad',
    'Consent could not be saved. Publishing remains locked.':
        'No se pudo guardar el consentimiento. La publicación sigue bloqueada.',
    'A community built around privacy and dignity.':
        'Una comunidad basada en la privacidad y la dignidad.',
    'Content policy': 'Política de contenido',
    'Accepted': 'Aceptada',
    'Accept policy': 'Aceptar la política',
    'Health logs stay private': 'Los registros de salud son privados',
    'BIL never posts weight, meals, or measurements without an explicit share action.':
        'BIL nunca publica peso, comidas ni medidas sin una acción explícita para compartir.',
    'Report, block, and delete': 'Denunciar, bloquear y eliminar',
    'You can report content, block a member, and delete your own content or messages.':
        'Puedes denunciar contenido, bloquear a un miembro y eliminar tu contenido o tus mensajes.',
    'Abuse prevention': 'Prevención de abusos',
    'Rate limits, human moderation, and metadata-only audit trails protect the community.':
        'Los límites de uso, la moderación humana y los registros solo de metadatos protegen a la comunidad.',
    'Community is unavailable in this build and remains hidden until secure cloud configuration is complete.':
        'La comunidad no está disponible en esta versión y seguirá oculta hasta completar la configuración segura de la nube.',
    'Who can see my profile': 'Quién puede ver mi perfil',
    'Allow friend requests': 'Permitir solicitudes de amistad',
    'Allow follows': 'Permitir seguidores',
    'Who can message me': 'Quién puede enviarme mensajes',
    'Delete account and data': 'Eliminar cuenta y datos',
    'Push is disabled immediately and a secure request is queued to permanently delete all account data. This cannot be undone after processing. Deleting BIL does not cancel an App Store or Google Play subscription; cancel it in the device store when needed.':
        'Las notificaciones se desactivan de inmediato y se pone en cola una solicitud segura para eliminar todos los datos de la cuenta. No puede deshacerse después de procesarse. Eliminar BIL no cancela una suscripción de App Store o Google Play; cancélala en la tienda del dispositivo.',
    'Request deletion': 'Solicitar eliminación',
    'Deletion request queued securely.':
        'La solicitud de eliminación se registró de forma segura.',
    'Sign in to manage your community profile.':
        'Inicia sesión para gestionar tu perfil de comunidad.',
    'Public': 'Público',
    'Friends only': 'Solo amigos',
    'Private': 'Privado',
    'Nobody': 'Nadie',
    'Sign-in required': 'Inicio de sesión requerido',
    'Not now': 'Ahora no',
    'Submit product for review': 'Enviar producto para revisión',
    'Product name': 'Nombre del producto',
    'Enter the product name': 'Introduce el nombre del producto',
    'Barcode': 'Código de barras',
    'Product type': 'Tipo de producto',
    'Food': 'Alimento',
    'Beverage': 'Bebida',
    'Alcohol': 'Alcohol',
    'Supplement': 'Suplemento',
    'Medicine': 'Medicamento',
    'Tobacco': 'Tabaco',
    'Personal care': 'Cuidado personal',
    'Pet food': 'Alimento para mascotas',
    'Household': 'Producto doméstico',
    'General product': 'Producto general',
    'Unknown': 'Desconocido',
    'Brand (optional)': 'Marca (opcional)',
    'Country code (optional)': 'Código de país (opcional)',
    'Use two letters, for example SA': 'Usa dos letras, por ejemplo ES',
    'Evidence URL (optional)': 'URL de evidencia (opcional)',
    'Enter a valid URL': 'Introduce una URL válida',
    'Note for reviewer (optional)': 'Nota para el revisor (opcional)',
    'Submit for review': 'Enviar para revisión',
    'Could not submit the product. Check the connection and try again.':
        'No se pudo enviar el producto. Comprueba la conexión e inténtalo de nuevo.',
    'Submitting a product for review requires an account. BIL will not upload or guess nutrition values, and the barcode stays on this device until you sign in.':
        'Se necesita una cuenta para enviar un producto. BIL no subirá ni estimará valores nutricionales, y el código de barras permanecerá en este dispositivo hasta que inicies sesión.',
    'This product will not become verified or searchable until a moderator reviews it. Do not submit estimated nutrition values.':
        'El producto no será verificado ni aparecerá en búsquedas hasta que lo revise un moderador. No envíes valores nutricionales estimados.',
    'Sign in to open community, friends, and messages.':
        'Inicia sesión para acceder a la comunidad, los amigos y los mensajes.',
    'Health logs are never posted automatically. You choose every share.':
        'Los registros de salud nunca se publican automáticamente. Tú eliges cada publicación.',
    'Could not publish now. Your text is kept so you can retry.':
        'No se pudo publicar. Conservamos tu texto para que vuelvas a intentarlo.',
    'Report sent for review.': 'Denuncia enviada para revisión.',
    'Could not complete that action safely. Try again.':
        'No se pudo completar la acción de forma segura. Inténtalo de nuevo.',
    'Share an experience or win': 'Comparte una experiencia o logro',
    'Do not share private health data you want to keep private.':
        'No compartas datos de salud que quieras mantener privados.',
    'No posts yet. Start the first conversation.':
        'Aún no hay publicaciones. Inicia la primera conversación.',
    'No requests or friendships yet.': 'Aún no hay solicitudes ni amistades.',
    'Complete all required values.': 'Completa todos los valores obligatorios.',
    'Food submitted for review. It will not appear as verified before validation.':
        'Alimento enviado para revisión. No aparecerá como verificado antes de validarse.',
    'Arabic and Gulf foods are reviewed before approval, and your contribution remains attributed to you.':
        'Los alimentos árabes y del Golfo se revisan antes de aprobarse, y tu contribución permanece atribuida a ti.',
    'Community could not be loaded. No data was lost.':
        'No se pudo cargar la comunidad. No se perdió ningún dato.',
  },
  'tr': {
    'Confirm review': 'İncelemeyi onayla',
    'Cancel': 'İptal',
    'Submit': 'Gönder',
    'Moderator decision saved.': 'Moderatör kararı kaydedildi.',
    'Product review': 'Ürün inceleme',
    'confidence': 'güven',
    'Approve': 'Onayla',
    'Needs changes': 'Değişiklik gerekli',
    'Reject': 'Reddet',
    'Safety and policy': 'Güvenlik ve politika',
    'Community profile': 'Topluluk profili',
    'Friends and requests': 'Arkadaşlar ve istekler',
    'Review foods': 'Yiyecekleri incele',
    'Find people': 'Kişi bul',
    'BIL Community': 'BIL Topluluğu',
    'Community': 'Topluluk',
    'Friends': 'Arkadaşlar',
    'Verified food': 'Doğrulanmış yiyecek',
    'Sign in': 'Oturum aç',
    'Privacy & safety': 'Gizlilik ve güvenlik',
    'Post deleted.': 'Gönderi silindi.',
    'BIL member': 'BIL üyesi',
    'Delete': 'Sil',
    'Report': 'Bildir',
    'Submit community food': 'Topluluk yiyeceği gönder',
    'Name': 'Ad',
    'Serving grams': 'Porsiyon gramı',
    'Calories': 'Kalori',
    'Protein': 'Protein',
    'Carbohydrate': 'Karbonhidrat',
    'Fat': 'Yağ',
    'Send for review': 'İncelemeye gönder',
    'Submit food': 'Yiyecek gönder',
    'Safety & community policy': 'Güvenlik ve topluluk politikası',
    'Consent could not be saved. Publishing remains locked.':
        'Onay kaydedilemedi. Yayınlama kilitli kalır.',
    'A community built around privacy and dignity.':
        'Gizlilik ve saygı üzerine kurulu bir topluluk.',
    'Content policy': 'İçerik politikası',
    'Accepted': 'Kabul edildi',
    'Accept policy': 'Politikayı kabul et',
    'Health logs stay private': 'Sağlık kayıtları gizli kalır',
    'BIL never posts weight, meals, or measurements without an explicit share action.':
        'BIL açık bir paylaşma işlemi olmadan kilo, öğün veya ölçüm yayınlamaz.',
    'Report, block, and delete': 'Bildir, engelle ve sil',
    'You can report content, block a member, and delete your own content or messages.':
        'İçeriği bildirebilir, bir üyeyi engelleyebilir ve kendi içerik ya da mesajlarınızı silebilirsiniz.',
    'Abuse prevention': 'Kötüye kullanımı önleme',
    'Rate limits, human moderation, and metadata-only audit trails protect the community.':
        'İstek sınırları, insan moderasyonu ve yalnızca meta veri içeren denetim kayıtları topluluğu korur.',
    'Community is unavailable in this build and remains hidden until secure cloud configuration is complete.':
        'Topluluk bu sürümde kullanılamaz ve güvenli bulut yapılandırması tamamlanana kadar gizli kalır.',
    'Who can see my profile': 'Profilimi kim görebilir',
    'Allow friend requests': 'Arkadaşlık isteklerine izin ver',
    'Allow follows': 'Takiplere izin ver',
    'Who can message me': 'Bana kim mesaj gönderebilir',
    'Delete account and data': 'Hesabı ve verileri sil',
    'Push is disabled immediately and a secure request is queued to permanently delete all account data. This cannot be undone after processing. Deleting BIL does not cancel an App Store or Google Play subscription; cancel it in the device store when needed.':
        'Bildirimler hemen kapatılır ve tüm hesap verilerini kalıcı olarak silmek için güvenli bir talep sıraya alınır. İşlendikten sonra geri alınamaz. BIL hesabını silmek App Store veya Google Play aboneliğini iptal etmez; gerektiğinde cihaz mağazasından iptal edin.',
    'Request deletion': 'Silme talebi oluştur',
    'Deletion request queued securely.':
        'Silme talebi güvenli biçimde sıraya alındı.',
    'Sign in to manage your community profile.':
        'Topluluk profilinizi yönetmek için oturum açın.',
    'Public': 'Herkese açık',
    'Friends only': 'Yalnızca arkadaşlar',
    'Private': 'Özel',
    'Nobody': 'Hiç kimse',
    'Sign-in required': 'Oturum açmanız gerekiyor',
    'Not now': 'Şimdi değil',
    'Submit product for review': 'Ürünü incelemeye gönder',
    'Product name': 'Ürün adı',
    'Enter the product name': 'Ürün adını girin',
    'Barcode': 'Barkod',
    'Product type': 'Ürün türü',
    'Food': 'Yiyecek',
    'Beverage': 'İçecek',
    'Alcohol': 'Alkol',
    'Supplement': 'Takviye',
    'Medicine': 'İlaç',
    'Tobacco': 'Tütün',
    'Personal care': 'Kişisel bakım',
    'Pet food': 'Evcil hayvan maması',
    'Household': 'Ev ürünü',
    'General product': 'Genel ürün',
    'Unknown': 'Bilinmiyor',
    'Brand (optional)': 'Marka (isteğe bağlı)',
    'Country code (optional)': 'Ülke kodu (isteğe bağlı)',
    'Use two letters, for example SA': 'İki harf kullanın, örneğin TR',
    'Evidence URL (optional)': 'Kanıt bağlantısı (isteğe bağlı)',
    'Enter a valid URL': 'Geçerli bir bağlantı girin',
    'Note for reviewer (optional)': 'İnceleyene not (isteğe bağlı)',
    'Submit for review': 'İncelemeye gönder',
    'Could not submit the product. Check the connection and try again.':
        'Ürün gönderilemedi. Bağlantıyı kontrol edip tekrar deneyin.',
    'Submitting a product for review requires an account. BIL will not upload or guess nutrition values, and the barcode stays on this device until you sign in.':
        'Bir ürünü incelemeye göndermek için hesap gerekir. BIL besin değerlerini yüklemez veya tahmin etmez; barkod oturum açana kadar bu cihazda kalır.',
    'This product will not become verified or searchable until a moderator reviews it. Do not submit estimated nutrition values.':
        'Bu ürün bir moderatör inceleyene kadar doğrulanmış veya aranabilir olmaz. Tahmini besin değerleri göndermeyin.',
    'Sign in to open community, friends, and messages.':
        'Topluluğu, arkadaşları ve mesajları açmak için oturum açın.',
    'Health logs are never posted automatically. You choose every share.':
        'Sağlık kayıtları otomatik olarak yayınlanmaz. Her paylaşımı siz seçersiniz.',
    'Could not publish now. Your text is kept so you can retry.':
        'Şimdi yayınlanamadı. Yeniden denemeniz için metniniz korundu.',
    'Report sent for review.': 'Bildirim incelemeye gönderildi.',
    'Could not complete that action safely. Try again.':
        'İşlem güvenle tamamlanamadı. Tekrar deneyin.',
    'Share an experience or win': 'Bir deneyim veya başarı paylaşın',
    'Do not share private health data you want to keep private.':
        'Gizli tutmak istediğiniz sağlık verilerini paylaşmayın.',
    'No posts yet. Start the first conversation.':
        'Henüz gönderi yok. İlk konuşmayı başlatın.',
    'No requests or friendships yet.': 'Henüz istek veya arkadaşlık yok.',
    'Complete all required values.': 'Gerekli tüm değerleri tamamlayın.',
    'Food submitted for review. It will not appear as verified before validation.':
        'Yiyecek incelemeye gönderildi. Doğrulanmadan önce onaylı görünmez.',
    'Arabic and Gulf foods are reviewed before approval, and your contribution remains attributed to you.':
        'Arap ve Körfez yiyecekleri onaydan önce incelenir; katkınız size atfedilmeye devam eder.',
    'Community could not be loaded. No data was lost.':
        'Topluluk yüklenemedi. Veri kaybı olmadı.',
  },
};
