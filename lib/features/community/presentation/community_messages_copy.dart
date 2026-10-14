part of 'community_messages_page.dart';

class _MessagesCopy {
  const _MessagesCopy(this.v);
  final Map<String, String> v;
  String get messages => v['messages']!;
  String get inbox => v['inbox']!;
  String get sent => v['sent']!;
  String get noMessages => v['noMessages']!;
  String get noSentMessages => v['noSentMessages']!;
  String get sendMessage => v['sendMessage']!;
  String get newMessage => v['newMessage']!;
  String get to => v['to']!;
  String get subject => v['subject']!;
  String get message => v['message']!;
  String get send => v['send']!;
  String get loadFailed => v['loadFailed']!;
  String get sendFailed => v['sendFailed']!;
  String get completeFields => v['completeFields']!;
  String get unknownMember => v['unknownMember']!;
  String get signInRequired => v['signInRequired']!;
  String get signIn => v['signIn']!;
  String get retry => v['retry']!;
  String get olderMessages => v['olderMessages']!;
  String get deliveryRemoved => v['deliveryRemoved']!;
  String get replacementBody => v['replacementBody']!;
  String get sendNewMessage => v['sendNewMessage']!;
  static _MessagesCopy of(BuildContext context) => _MessagesCopy(
    _catalog[Localizations.localeOf(context).languageCode] ??
        _extended(context),
  );

  static Map<String, String> _extended(BuildContext context) {
    String t(String value) => AppLocalizations.of(context).text(value);
    return {
      for (final entry in _catalog['en']!.entries) entry.key: t(entry.value),
    };
  }

  static const _catalog = <String, Map<String, String>>{
    'en': {
      'deliveryRemoved':
          'This message was previously delivered and then removed. Your text is kept; no new message was sent.',
      'replacementBody':
          'The previous request was delivered and then removed. Sending again creates a new message.',
      'sendNewMessage': 'Send new message',
      'olderMessages': 'Load older messages',
      'messages': 'Messages',
      'inbox': 'Inbox',
      'sent': 'Sent',
      'noMessages': 'No messages',
      'noSentMessages': 'No sent messages',
      'sendMessage': 'Send a message',
      'newMessage': 'New message',
      'to': 'To: user name',
      'subject': 'Subject',
      'message': 'Message',
      'send': 'Send',
      'loadFailed': 'Messages could not be loaded safely.',
      'sendFailed': 'Message could not be sent.',
      'completeFields': 'Choose a recipient and enter a message.',
      'unknownMember': 'BIL member',
      'signInRequired': 'Sign in to view and send messages.',
      'signIn': 'Sign in',
      'retry': 'Retry',
    },
    'ar': {
      'deliveryRemoved':
          'أُرسلت هذه الرسالة سابقًا ثم أُزيلت. النص محفوظ؛ لم نرسل رسالة أخرى.',
      'replacementBody':
          'أُرسلت الرسالة السابقة ثم أُزيلت. الإرسال مرة أخرى ينشئ رسالة جديدة.',
      'sendNewMessage': 'إرسال رسالة جديدة',
      'olderMessages': 'تحميل الرسائل الأقدم',
      'messages': 'الرسائل',
      'inbox': 'الوارد',
      'sent': 'المرسلة',
      'noMessages': 'لا توجد رسائل',
      'noSentMessages': 'لا توجد رسائل مرسلة',
      'sendMessage': 'إرسال رسالة',
      'newMessage': 'رسالة جديدة',
      'to': 'إلى: اسم المستخدم',
      'subject': 'الموضوع',
      'message': 'الرسالة',
      'send': 'إرسال',
      'loadFailed': 'تعذر تحميل الرسائل بأمان.',
      'sendFailed': 'تعذر إرسال الرسالة.',
      'completeFields': 'اختر مستلمًا واكتب رسالة.',
      'unknownMember': 'عضو BIL',
      'signInRequired': 'سجّل الدخول لعرض الرسائل وإرسالها.',
      'signIn': 'تسجيل الدخول',
      'retry': 'إعادة المحاولة',
    },
    'fr': {
      'deliveryRemoved':
          'Ce message a été envoyé puis supprimé. Votre texte est conservé ; aucun nouveau message n’a été envoyé.',
      'replacementBody':
          'La demande précédente a été transmise puis supprimée. Un nouvel envoi crée un nouveau message.',
      'sendNewMessage': 'Envoyer un nouveau message',
      'olderMessages': 'Charger les messages précédents',
      'messages': 'Messages',
      'inbox': 'Boîte de réception',
      'sent': 'Envoyés',
      'noMessages': 'Aucun message',
      'noSentMessages': 'Aucun message envoyé',
      'sendMessage': 'Envoyer un message',
      'newMessage': 'Nouveau message',
      'to': 'À : nom d’utilisateur',
      'subject': 'Objet',
      'message': 'Message',
      'send': 'Envoyer',
      'loadFailed': 'Impossible de charger les messages en toute sécurité.',
      'sendFailed': 'Le message n’a pas pu être envoyé.',
      'completeFields': 'Choisissez un destinataire et saisissez un message.',
      'unknownMember': 'Membre BIL',
      'signInRequired': 'Connectez-vous pour voir et envoyer des messages.',
      'signIn': 'Se connecter',
      'retry': 'Réessayer',
    },
    'es': {
      'deliveryRemoved':
          'Este mensaje se envió y luego se eliminó. Conservamos tu texto; no se envió otro mensaje.',
      'replacementBody':
          'La solicitud anterior se entregó y luego se eliminó. Enviar de nuevo crea un mensaje nuevo.',
      'sendNewMessage': 'Enviar un nuevo mensaje',
      'olderMessages': 'Cargar mensajes anteriores',
      'messages': 'Mensajes',
      'inbox': 'Recibidos',
      'sent': 'Enviados',
      'noMessages': 'No hay mensajes',
      'noSentMessages': 'No hay mensajes enviados',
      'sendMessage': 'Enviar un mensaje',
      'newMessage': 'Nuevo mensaje',
      'to': 'Para: nombre de usuario',
      'subject': 'Asunto',
      'message': 'Mensaje',
      'send': 'Enviar',
      'loadFailed': 'No se pudieron cargar los mensajes de forma segura.',
      'sendFailed': 'No se pudo enviar el mensaje.',
      'completeFields': 'Elige un destinatario y escribe un mensaje.',
      'unknownMember': 'Miembro de BIL',
      'signInRequired': 'Inicia sesión para ver y enviar mensajes.',
      'signIn': 'Iniciar sesión',
      'retry': 'Reintentar',
    },
    'tr': {
      'deliveryRemoved':
          'Bu mesaj daha önce iletildi ve ardından kaldırıldı. Metniniz korundu; yeni mesaj gönderilmedi.',
      'replacementBody':
          'Önceki istek iletildi ve ardından kaldırıldı. Yeniden göndermek yeni bir mesaj oluşturur.',
      'sendNewMessage': 'Yeni mesaj gönder',
      'olderMessages': 'Eski mesajları yükle',
      'messages': 'Mesajlar',
      'inbox': 'Gelen kutusu',
      'sent': 'Gönderilenler',
      'noMessages': 'Mesaj yok',
      'noSentMessages': 'Gönderilmiş mesaj yok',
      'sendMessage': 'Mesaj gönder',
      'newMessage': 'Yeni mesaj',
      'to': 'Kime: kullanıcı adı',
      'subject': 'Konu',
      'message': 'Mesaj',
      'send': 'Gönder',
      'loadFailed': 'Mesajlar güvenle yüklenemedi.',
      'sendFailed': 'Mesaj gönderilemedi.',
      'completeFields': 'Bir alıcı seçin ve mesaj yazın.',
      'unknownMember': 'BIL üyesi',
      'signInRequired': 'Mesajları görmek ve göndermek için oturum açın.',
      'signIn': 'Oturum aç',
      'retry': 'Tekrar dene',
    },
  };
}
