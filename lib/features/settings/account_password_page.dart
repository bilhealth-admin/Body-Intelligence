import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/app_localizations.dart';

typedef AccountPasswordUpdater = Future<void> Function(String password);

class AccountPasswordPage extends StatefulWidget {
  const AccountPasswordPage({super.key, this.passwordUpdater});

  final AccountPasswordUpdater? passwordUpdater;

  @override
  State<AccountPasswordPage> createState() => _AccountPasswordPageState();
}

class _AccountPasswordPageState extends State<AccountPasswordPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  bool get _canSubmit =>
      !_saving &&
      _password.text.length >= 8 &&
      _password.text == _confirmation.text;

  String _t(String en, String ar, String fr, String es, String tr) =>
      switch (Localizations.localeOf(context).languageCode) {
        'ar' => ar,
        'fr' => fr,
        'es' => es,
        'tr' => tr,
        'en' => en,
        _ => context.strings.text(en),
      };

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _save() async {
    if (_saving) return;
    final password = _password.text;
    if (password.length < 8) {
      _message(
        _t(
          'Use at least 8 characters.',
          'استخدم 8 أحرف على الأقل.',
          'Utilisez au moins 8 caractères.',
          'Usa al menos 8 caracteres.',
          'En az 8 karakter kullanın.',
        ),
      );
      return;
    }
    if (password != _confirmation.text) {
      _message(
        _t(
          'The passwords do not match.',
          'كلمتا المرور غير متطابقتين.',
          'Les mots de passe ne correspondent pas.',
          'Las contraseñas no coinciden.',
          'Parolalar eşleşmiyor.',
        ),
      );
      return;
    }
    if (widget.passwordUpdater == null &&
        (!AppEnvironment.cloudConfigured ||
            !AppEnvironment.supabaseRuntimeReady ||
            Supabase.instance.client.auth.currentUser == null)) {
      _message(
        _t(
          'Sign in before changing your password.',
          'سجّل الدخول قبل تغيير كلمة المرور.',
          'Connectez-vous avant de modifier votre mot de passe.',
          'Inicia sesión antes de cambiar la contraseña.',
          'Parolanızı değiştirmeden önce giriş yapın.',
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.passwordUpdater case final updater?) {
        await updater(password);
      } else {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: password),
        );
      }
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      _message(
        _t(
          'Password updated securely.',
          'تم تحديث كلمة المرور بأمان.',
          'Mot de passe mis à jour en toute sécurité.',
          'Contraseña actualizada de forma segura.',
          'Parola güvenli biçimde güncellendi.',
        ),
      );
    } on AuthException {
      if (mounted) {
        _message(
          _t(
            'Password could not be updated. Try again.',
            'تعذّر تحديث كلمة المرور. حاول مرة أخرى.',
            'Impossible de mettre à jour le mot de passe. Réessayez.',
            'No se pudo actualizar la contraseña. Inténtalo de nuevo.',
            'Parola güncellenemedi. Yeniden deneyin.',
          ),
        );
      }
    } on Object {
      if (mounted) {
        _message(
          _t(
            'Password could not be updated. Try again.',
            'تعذّر تحديث كلمة المرور. حاول مرة أخرى.',
            'Impossible de mettre à jour le mot de passe. Réessayez.',
            'No se pudo actualizar la contraseña. Inténtalo de nuevo.',
            'Parola güncellenemedi. Yeniden deneyin.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _t(
            'Change password',
            'تغيير كلمة المرور',
            'Modifier le mot de passe',
            'Cambiar contraseña',
            'Parolayı değiştir',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _t(
              'Choose a unique password for your BIL account.',
              'اختر كلمة مرور فريدة لحساب BIL الخاص بك.',
              'Choisissez un mot de passe unique pour votre compte BIL.',
              'Elige una contraseña única para tu cuenta BIL.',
              'BIL hesabınız için benzersiz bir parola seçin.',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          TextField(
            key: const Key('new-account-password'),
            controller: _password,
            enabled: !_saving,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _t(
                'New password',
                'كلمة المرور الجديدة',
                'Nouveau mot de passe',
                'Nueva contraseña',
                'Yeni parola',
              ),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: _saving
                    ? null
                    : () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('confirm-account-password'),
            controller: _confirmation,
            enabled: !_saving,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_canSubmit) _save();
            },
            decoration: InputDecoration(
              labelText: _t(
                'Confirm password',
                'تأكيد كلمة المرور',
                'Confirmer le mot de passe',
                'Confirmar contraseña',
                'Parolayı doğrula',
              ),
              prefixIcon: const Icon(Icons.verified_user_outlined),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('save-account-password'),
            onPressed: _canSubmit ? _save : null,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shield_outlined),
            label: Text(
              _t(
                'Update password',
                'تحديث كلمة المرور',
                'Mettre à jour',
                'Actualizar contraseña',
                'Parolayı güncelle',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
