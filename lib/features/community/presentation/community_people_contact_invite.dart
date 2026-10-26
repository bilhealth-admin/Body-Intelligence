part of 'community_people_page.dart';

// Own the one-contact system picker and invitation sheet separately from
// people search and relationship state. No address-book permission is added.
mixin _CommunityPeopleContactInvite on State<CommunityPeoplePage> {
  CommunityRepository? get _repository;
  bool _pickingContact = false;

  Future<void> _pickContact() async {
    if (_pickingContact) return;
    setState(() => _pickingContact = true);
    try {
      final contact = await const ContactPickerService().pick();
      if (!mounted || contact == null) return;
      await _showContactInvite(contact);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'تعذر فتح منتقي جهات الاتصال الآمن.',
              'The secure contact picker could not be opened.',
              'Impossible d’ouvrir le sélecteur de contacts sécurisé.',
              'No se pudo abrir el selector seguro de contactos.',
              'Güvenli kişi seçici açılamadı.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingContact = false);
    }
  }

  Future<void> _showContactInvite(PickedBilContact contact) async {
    final localeTag = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    String? trackedInviteUrl;
    final repository = _repository;
    if (repository != null) {
      try {
        final invite = await repository.createCommunityInvite();
        if (invite.active) {
          trackedInviteUrl = invite.url?.toString();
        }
      } on Object {
        // Referral attribution is fail-closed. The existing generic BIL
        // download invite remains available when tracked links are disabled
        // or the cloud is temporarily unavailable.
      }
    }
    if (!mounted) return;
    final message = bilCommunityInviteMessage(
      localeTag,
      name: contact.name,
      url: trackedInviteUrl,
    );
    final privacy = bilCommunityContactPrivacy(localeTag);
    // The native system picker grants one-contact access only.
    // No permission was requested. BIL cannot read or retain the address book.
    await showBilPearlBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StoreMark(
                  icon: Icons.play_arrow_rounded,
                  label: 'Google Play',
                ),
                SizedBox(width: 10),
                _StoreMark(icon: Icons.apple_rounded, label: 'App Store'),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              contact.name.trim().isEmpty ? contact.phone : contact.name,
              textAlign: TextAlign.center,
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Container(
              key: const Key('community-contact-invite-preview'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Text(message, style: const TextStyle(height: 1.45)),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.privacy_tip_outlined,
                  size: 18,
                  color: Color(0xFF475467),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    privacy,
                    style: const TextStyle(
                      color: Color(0xFF475467),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('community-send-contact-sms'),
              onPressed: () async {
                final uri = Uri(
                  scheme: 'sms',
                  path: contact.phone,
                  queryParameters: {'body': message},
                );
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && sheetContext.mounted) {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _copy(
                            context,
                            'تم نسخ الدعوة. افتح تطبيق الرسائل وأرسلها.',
                            'Invitation copied. Open Messages to send it.',
                            'Invitation copiée. Ouvrez Messages pour l’envoyer.',
                            'Invitación copiada. Abre Mensajes para enviarla.',
                            'Davet kopyalandı. Göndermek için Mesajlar’ı açın.',
                          ),
                        ),
                      ),
                    );
                  }
                  return;
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              icon: const Icon(Icons.sms_rounded),
              label: Text(
                _copy(
                  sheetContext,
                  'إرسال الدعوة',
                  'Send invitation',
                  'Envoyer l’invitation',
                  'Enviar invitación',
                  'Daveti gönder',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
