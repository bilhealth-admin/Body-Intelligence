import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';

typedef AccountEmailUpdater = Future<void> Function(String email);

class AccountEmailPage extends StatefulWidget {
  const AccountEmailPage({super.key, this.initialEmail, this.emailUpdater});

  final String? initialEmail;
  final AccountEmailUpdater? emailUpdater;

  @override
  State<AccountEmailPage> createState() => _AccountEmailPageState();
}

class _AccountEmailPageState extends State<AccountEmailPage> {
  final _email = TextEditingController();
  bool _saving = false;

  String _text(String en, String ar, String fr, String es, String tr) =>
      switch (Localizations.localeOf(context).languageCode) {
        'ar' => ar,
        'fr' => fr,
        'es' => es,
        'tr' => tr,
        'en' => en,
        _ => context.strings.text(en),
      };

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _email.text = widget.initialEmail!;
    } else if (AppEnvironment.cloudConfigured &&
        Supabase.instance.isInitialized) {
      _email.text = Supabase.instance.client.auth.currentUser?.email ?? '';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final value = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      _message(
        _text(
          'Enter a valid email address.',
          'أدخل بريدًا إلكترونيًا صالحًا.',
          'Saisissez une adresse e-mail valide.',
          'Introduce un correo válido.',
          'Geçerli bir e-posta adresi girin.',
        ),
      );
      return;
    }
    if (widget.emailUpdater == null &&
        (!AppEnvironment.cloudConfigured ||
            !Supabase.instance.isInitialized ||
            Supabase.instance.client.auth.currentUser == null)) {
      _message(
        _text(
          'Sign in to change your account email.',
          'سجّل الدخول لتغيير بريد الحساب.',
          'Connectez-vous pour modifier l’e-mail du compte.',
          'Inicia sesión para cambiar el correo de la cuenta.',
          'Hesap e-postasını değiştirmek için giriş yapın.',
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.emailUpdater case final updater?) {
        await updater(value);
      } else {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(email: value),
        );
      }
      if (!mounted) return;
      _message(
        _text(
          'Check both email addresses to confirm the change.',
          'تحقق من بريديك الإلكترونيين لتأكيد التغيير.',
          'Consultez les deux adresses pour confirmer le changement.',
          'Revisa ambas direcciones para confirmar el cambio.',
          'Değişikliği onaylamak için iki e-posta adresini de kontrol edin.',
        ),
      );
    } on AuthException {
      if (mounted) {
        _message(
          _text(
            'Email could not be changed. Try again.',
            'تعذّر تغيير البريد. حاول مرة أخرى.',
            'Impossible de modifier l’e-mail. Réessayez.',
            'No se pudo cambiar el correo. Inténtalo de nuevo.',
            'E-posta değiştirilemedi. Yeniden deneyin.',
          ),
        );
      }
    } on Object {
      if (mounted) {
        _message(
          _text(
            'Email could not be changed. Try again.',
            'تعذّر تغيير البريد. حاول مرة أخرى.',
            'Impossible de modifier l’e-mail. Réessayez.',
            'No se pudo cambiar el correo. Inténtalo de nuevo.',
            'E-posta değiştirilemedi. Yeniden deneyin.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _text(
            'Account email',
            'بريد الحساب',
            'E-mail du compte',
            'Correo de la cuenta',
            'Hesap e-postası',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _text(
              'This changes the address used to sign in. Supabase may require confirmation from both the old and new address.',
              'يغيّر هذا العنوان المستخدم لتسجيل الدخول. قد يطلب Supabase التأكيد من العنوان القديم والجديد.',
              'Cela modifie l’adresse de connexion. Supabase peut demander une confirmation aux deux adresses.',
              'Esto cambia la dirección de acceso. Supabase puede pedir confirmación en ambas direcciones.',
              'Bu, giriş adresini değiştirir. Supabase iki adresten de onay isteyebilir.',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('account-email-field'),
            controller: _email,
            enabled: !_saving,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: _text(
                'Email address',
                'البريد الإلكتروني',
                'Adresse e-mail',
                'Correo electrónico',
                'E-posta adresi',
              ),
              prefixIcon: const Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('save-account-email'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _text(
                      'Update email',
                      'تحديث البريد',
                      'Mettre à jour',
                      'Actualizar correo',
                      'E-postayı güncelle',
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
