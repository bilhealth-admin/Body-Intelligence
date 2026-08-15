import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/runtime_copy.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final _confirmation = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final copy = _AccountDeletionCopy.of(context);
    final supabase = Supabase.instance;
    if (!AppEnvironment.cloudConfigured ||
        !supabase.isInitialized ||
        supabase.client.auth.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.signInRequired)));
      return;
    }
    final client = supabase.client;
    if (_confirmation.text.trim().toUpperCase() != 'DELETE') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.confirmationRequired)));
      return;
    }
    setState(() => _submitting = true);
    try {
      final response = await client.rpc(
        'bil_request_account_deletion',
        params: {'p_reason': 'user_requested_in_help_center'},
      );
      if (response is! Map) throw const FormatException('invalid response');
      final requestId = response['request_id'];
      final status = response['status'];
      if (requestId is! String ||
          requestId.isEmpty ||
          status is! String ||
          (status != 'pending' && status != 'processing')) {
        throw const FormatException('invalid deletion request receipt');
      }
      if (!mounted) return;
      _confirmation.clear();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(copy.requestReceived),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.requestReceivedBody),
              const SizedBox(height: 16),
              Text('${copy.statusLabel}: ${copy.statusFor(status)}'),
              const SizedBox(height: 4),
              Text(copy.referenceLabel),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(requestId),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(copy.close),
            ),
          ],
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.failed)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _AccountDeletionCopy.of(context);
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: Text(copy.title)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.person_remove_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              copy.heading,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(copy.body),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmation,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: copy.confirmationLabel,
                hintText: 'DELETE',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: Text(copy.submit),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDeletionCopy {
  const _AccountDeletionCopy(this.values);
  final Map<String, String> values;
  String get title => values['title']!;
  String get heading => values['heading']!;
  String get body => values['body']!;
  String get confirmationLabel => values['confirmationLabel']!;
  String get submit => values['submit']!;
  String get signInRequired => values['signInRequired']!;
  String get confirmationRequired => values['confirmationRequired']!;
  String get requestReceived => values['requestReceived']!;
  String get requestReceivedBody => values['requestReceivedBody']!;
  String get failed => values['failed']!;
  String get close => values['close']!;
  String get statusLabel => values['statusLabel']!;
  String get referenceLabel => values['referenceLabel']!;
  String statusFor(String status) => switch (status) {
    'pending' => values['statusPending']!,
    'processing' => values['statusProcessing']!,
    _ => throw StateError('Unsupported account deletion status: $status'),
  };

  static _AccountDeletionCopy of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final authored = _catalog[code];
    if (authored != null) return _AccountDeletionCopy(authored);
    final english = _catalog['en']!;
    return _AccountDeletionCopy({
      for (final entry in english.entries)
        entry.key:
            _statusCatalog[code]?[entry.key] ??
            RuntimeCopy.resolve(entry.value, code) ??
            (throw StateError(
              'Missing account-deletion copy for $code: ${entry.value}',
            )),
    });
  }

  static const _statusCatalog = <String, Map<String, String>>{
    'de': {
      'statusLabel': 'Status',
      'referenceLabel': 'Anfragereferenz',
      'statusPending': 'Ausstehend',
      'statusProcessing': 'In Bearbeitung',
    },
    'it': {
      'statusLabel': 'Stato',
      'referenceLabel': 'Riferimento richiesta',
      'statusPending': 'In attesa',
      'statusProcessing': 'In elaborazione',
    },
    'pt-BR': {
      'statusLabel': 'Status',
      'referenceLabel': 'Referência da solicitação',
      'statusPending': 'Pendente',
      'statusProcessing': 'Em processamento',
    },
    'pt-PT': {
      'statusLabel': 'Estado',
      'referenceLabel': 'Referência do pedido',
      'statusPending': 'Pendente',
      'statusProcessing': 'Em processamento',
    },
    'ur': {
      'statusLabel': 'حالت',
      'referenceLabel': 'درخواست کا حوالہ',
      'statusPending': 'زیر التوا',
      'statusProcessing': 'زیر عمل',
    },
    'fa': {
      'statusLabel': 'وضعیت',
      'referenceLabel': 'مرجع درخواست',
      'statusPending': 'در انتظار',
      'statusProcessing': 'در حال پردازش',
    },
    'hi': {
      'statusLabel': 'स्थिति',
      'referenceLabel': 'अनुरोध संदर्भ',
      'statusPending': 'लंबित',
      'statusProcessing': 'प्रक्रियाधीन',
    },
    'id': {
      'statusLabel': 'Status',
      'referenceLabel': 'Referensi permintaan',
      'statusPending': 'Menunggu',
      'statusProcessing': 'Sedang diproses',
    },
    'ms': {
      'statusLabel': 'Status',
      'referenceLabel': 'Rujukan permintaan',
      'statusPending': 'Belum selesai',
      'statusProcessing': 'Sedang diproses',
    },
    'ja': {
      'statusLabel': '状態',
      'referenceLabel': 'リクエスト参照',
      'statusPending': '保留中',
      'statusProcessing': '処理中',
    },
    'ko': {
      'statusLabel': '상태',
      'referenceLabel': '요청 참조',
      'statusPending': '대기 중',
      'statusProcessing': '처리 중',
    },
    'zh-Hans': {
      'statusLabel': '状态',
      'referenceLabel': '请求编号',
      'statusPending': '待处理',
      'statusProcessing': '处理中',
    },
    'zh-Hant': {
      'statusLabel': '狀態',
      'referenceLabel': '請求編號',
      'statusPending': '待處理',
      'statusProcessing': '處理中',
    },
    'ru': {
      'statusLabel': 'Статус',
      'referenceLabel': 'Номер запроса',
      'statusPending': 'Ожидает',
      'statusProcessing': 'Обрабатывается',
    },
    'bn': {
      'statusLabel': 'স্থিতি',
      'referenceLabel': 'অনুরোধ রেফারেন্স',
      'statusPending': 'অপেক্ষমাণ',
      'statusProcessing': 'প্রক্রিয়াধীন',
    },
    'vi': {
      'statusLabel': 'Trạng thái',
      'referenceLabel': 'Mã yêu cầu',
      'statusPending': 'Đang chờ',
      'statusProcessing': 'Đang xử lý',
    },
    'th': {
      'statusLabel': 'สถานะ',
      'referenceLabel': 'หมายเลขคำขอ',
      'statusPending': 'รอดำเนินการ',
      'statusProcessing': 'กำลังดำเนินการ',
    },
    'pl': {
      'statusLabel': 'Status',
      'referenceLabel': 'Numer zgłoszenia',
      'statusPending': 'Oczekuje',
      'statusProcessing': 'W trakcie',
    },
    'nl': {
      'statusLabel': 'Status',
      'referenceLabel': 'Aanvraagreferentie',
      'statusPending': 'In afwachting',
      'statusProcessing': 'In behandeling',
    },
    'uk': {
      'statusLabel': 'Статус',
      'referenceLabel': 'Номер запиту',
      'statusPending': 'Очікує',
      'statusProcessing': 'Обробляється',
    },
  };

  static const _catalog = <String, Map<String, String>>{
    'en': {
      'title': 'Delete account',
      'heading': 'Request account and cloud-data deletion',
      'body':
          'This records a request to delete your cloud account and associated cloud data. A recorded request remains pending until deletion is completed; recording it does not confirm deletion. Local data on this device is managed separately in Settings.',
      'confirmationLabel': 'Type DELETE to confirm',
      'submit': 'Request deletion',
      'signInRequired':
          'Sign in to the account you want to delete, then try again.',
      'confirmationRequired': 'Type DELETE exactly to continue.',
      'requestReceived': 'Deletion request received',
      'requestReceivedBody':
          'Your request was recorded. Your account and cloud data have not been confirmed deleted yet. Keep the status and reference below for enquiries.',
      'failed':
          'The deletion request could not be sent. Nothing was deleted. Try again later.',
      'close': 'Close',
      'statusLabel': 'Status',
      'referenceLabel': 'Request reference',
      'statusPending': 'Pending',
      'statusProcessing': 'Processing',
    },
    'ar': {
      'title': 'حذف الحساب',
      'heading': 'طلب حذف الحساب والبيانات السحابية',
      'body':
          'يسجّل هذا طلبًا لحذف حسابك السحابي وبياناته المرتبطة. يبقى الطلب معلّقًا حتى اكتمال الحذف، وتسجيله لا يؤكد أن الحذف تم. تُدار البيانات المحلية على هذا الجهاز بشكل منفصل من الإعدادات.',
      'confirmationLabel': 'اكتب DELETE للتأكيد',
      'submit': 'طلب الحذف',
      'signInRequired': 'سجّل الدخول إلى الحساب الذي تريد حذفه ثم حاول مجددًا.',
      'confirmationRequired': 'اكتب DELETE تمامًا للمتابعة.',
      'requestReceived': 'تم استلام طلب الحذف',
      'requestReceivedBody':
          'تم تسجيل طلبك. لم يتم تأكيد حذف الحساب والبيانات السحابية بعد. احتفظ بالحالة والمرجع أدناه للاستفسار.',
      'failed': 'تعذر إرسال طلب الحذف. لم يُحذف شيء. حاول لاحقًا.',
      'close': 'إغلاق',
      'statusLabel': 'الحالة',
      'referenceLabel': 'مرجع الطلب',
      'statusPending': 'قيد الانتظار',
      'statusProcessing': 'قيد المعالجة',
    },
    'fr': {
      'title': 'Supprimer le compte',
      'heading': 'Demander la suppression du compte et des données cloud',
      'body':
          'Cette action enregistre une demande de suppression du compte cloud et des données associées. La demande reste en attente jusqu’à la fin de la suppression ; son enregistrement ne confirme pas la suppression. Les données locales sont gérées séparément.',
      'confirmationLabel': 'Saisissez DELETE pour confirmer',
      'submit': 'Demander la suppression',
      'signInRequired': 'Connectez-vous au compte à supprimer, puis réessayez.',
      'confirmationRequired': 'Saisissez exactement DELETE pour continuer.',
      'requestReceived': 'Demande de suppression reçue',
      'requestReceivedBody':
          'Votre demande a été enregistrée. La suppression du compte et des données cloud n’est pas encore confirmée. Conservez le statut et la référence ci-dessous pour le suivi.',
      'failed':
          'La demande n’a pas pu être envoyée. Rien n’a été supprimé. Réessayez plus tard.',
      'close': 'Fermer',
      'statusLabel': 'Statut',
      'referenceLabel': 'Référence de la demande',
      'statusPending': 'En attente',
      'statusProcessing': 'En cours de traitement',
    },
    'es': {
      'title': 'Eliminar cuenta',
      'heading': 'Solicitar la eliminación de la cuenta y los datos en la nube',
      'body':
          'Esta acción registra una solicitud para eliminar la cuenta en la nube y sus datos asociados. La solicitud queda pendiente hasta completar la eliminación; registrarla no confirma que se haya eliminado. Los datos locales se administran por separado.',
      'confirmationLabel': 'Escribe DELETE para confirmar',
      'submit': 'Solicitar eliminación',
      'signInRequired':
          'Inicia sesión en la cuenta que quieres eliminar e inténtalo de nuevo.',
      'confirmationRequired': 'Escribe DELETE exactamente para continuar.',
      'requestReceived': 'Solicitud de eliminación recibida',
      'requestReceivedBody':
          'Tu solicitud se registró. La eliminación de la cuenta y los datos en la nube aún no está confirmada. Conserva el estado y la referencia siguientes para consultas.',
      'failed':
          'No se pudo enviar la solicitud. No se eliminó nada. Inténtalo más tarde.',
      'close': 'Cerrar',
      'statusLabel': 'Estado',
      'referenceLabel': 'Referencia de la solicitud',
      'statusPending': 'Pendiente',
      'statusProcessing': 'En proceso',
    },
    'tr': {
      'title': 'Hesabı sil',
      'heading': 'Hesap ve bulut verilerinin silinmesini iste',
      'body':
          'Bu işlem bulut hesabınızı ve ilişkili verileri silme isteğini kaydeder. Silme tamamlanana kadar istek beklemede kalır; kaydedilmesi silmenin gerçekleştiğini doğrulamaz. Yerel veriler Ayarlar bölümünde ayrı yönetilir.',
      'confirmationLabel': 'Onaylamak için DELETE yazın',
      'submit': 'Silme isteği gönder',
      'signInRequired':
          'Silmek istediğiniz hesapta oturum açıp yeniden deneyin.',
      'confirmationRequired': 'Devam etmek için tam olarak DELETE yazın.',
      'requestReceived': 'Silme isteği alındı',
      'requestReceivedBody':
          'İsteğiniz kaydedildi. Hesabın ve bulut verilerinin silindiği henüz doğrulanmadı. Sorgular için aşağıdaki durum ve referansı saklayın.',
      'failed':
          'Silme isteği gönderilemedi. Hiçbir şey silinmedi. Daha sonra yeniden deneyin.',
      'close': 'Kapat',
      'statusLabel': 'Durum',
      'referenceLabel': 'İstek referansı',
      'statusPending': 'Beklemede',
      'statusProcessing': 'İşleniyor',
    },
  };
}
