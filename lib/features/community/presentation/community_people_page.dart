import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../../commerce/domain/commerce_entitlement.dart';
import '../../commerce/domain/subscription_state.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import '../domain/community_text_policy.dart';
import '../services/contact_picker_service.dart';
import 'community_invite_copy.dart';

part 'community_chat_page.dart';

class CommunityPeoplePage extends ConsumerStatefulWidget {
  const CommunityPeoplePage({this.repository, super.key});
  final CommunityRepository? repository;
  @override
  ConsumerState<CommunityPeoplePage> createState() =>
      _CommunityPeoplePageState();
}

class _CommunityPeoplePageState extends ConsumerState<CommunityPeoplePage> {
  CommunityRepository? _repository;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Future<List<Map<String, dynamic>>> _results = Future.value(const []);
  final Set<String> _pendingRequests = <String>{};
  final Set<String> _sendingRequests = <String>{};
  bool _pickingContact = false;
  String _lastQuery = '';

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
    final message = bilCommunityInviteMessage(localeTag, name: contact.name);
    final privacy = bilCommunityContactPrivacy(localeTag);
    // The native system picker grants one-contact access only.
    // No permission was requested. BIL cannot read or retain the address book.
    await showModalBottomSheet<void>(
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

  void _searchPeople(String value) {
    final repository = _repository;
    if (repository == null) return;
    _lastQuery = value;
    final results = repository.searchProfiles(value);
    setState(() {
      _results = results;
    });
  }

  Future<void> _requestFriend(String userId) async {
    final repository = _repository;
    if (repository == null) return;
    if (_pendingRequests.contains(userId) ||
        _sendingRequests.contains(userId)) {
      return;
    }
    setState(() => _sendingRequests.add(userId));
    try {
      await repository.requestFriend(userId);
      if (!mounted) return;
      setState(() => _pendingRequests.add(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'تم إرسال الطلب.',
              'Request sent.',
              'Demande envoyée.',
              'Solicitud enviada.',
              'İstek gönderildi.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              'تعذر إرسال الطلب بأمان. حاول مجددًا.',
              'Could not send the request safely. Try again.',
              'Impossible d’envoyer la demande. Réessayez.',
              'No se pudo enviar la solicitud. Inténtalo de nuevo.',
              'İstek gönderilemedi. Tekrar deneyin.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingRequests.remove(userId));
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository;
      _results = _repository!.searchProfiles('');
      return;
    }
    if (!AppEnvironment.cloudConfigured) return;
    try {
      final supabase = Supabase.instance;
      if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
        return;
      }
      _repository = CommunityRepository(supabase.client);
      _results = _repository!.searchProfiles('');
    } on AssertionError {
      return;
    } on StateError {
      return;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(verifiedSubscriptionStateProvider).value;
    final friendsUnlocked =
        subscription?.authority == EntitlementAuthority.verifiedServer &&
        (subscription?.grants(CommerceEntitlement.communityFriends) ?? false);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _copy(
            context,
            'البحث عن أصدقاء',
            'Find people',
            'Trouver des amis',
            'Buscar personas',
            'Kişileri bul',
          ),
        ),
      ),
      body: _repository == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('community-add-from-contacts'),
                            onPressed: null,
                            icon: const Icon(Icons.contacts_outlined),
                            label: Text(
                              _copy(
                                context,
                                'جهات الاتصال',
                                'Contacts',
                                'Contacts',
                                'Contactos',
                                'Kişiler',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('community-add-by-bil-name'),
                            onPressed: null,
                            icon: const Icon(Icons.alternate_email_rounded),
                            label: Text(
                              _copy(
                                context,
                                'اسم BIL',
                                'BIL name',
                                'Nom BIL',
                                'Nombre BIL',
                                'BIL adı',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _copy(
                        context,
                        'سجّل الدخول وفعّل السحابة للبحث عن الأصدقاء.',
                        'Sign in and enable cloud access to find people.',
                        'Connectez-vous et activez le cloud pour trouver des amis.',
                        'Inicia sesión y activa la nube para buscar personas.',
                        'Kişileri bulmak için oturum açın ve bulutu etkinleştirin.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('community-add-from-contacts'),
                          onPressed: _pickingContact ? null : _pickContact,
                          icon: _pickingContact
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.contacts_outlined),
                          label: Text(
                            _copy(
                              context,
                              'جهات الاتصال',
                              'Contacts',
                              'Contacts',
                              'Contactos',
                              'Kişiler',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('community-add-by-bil-name'),
                          onPressed: () => _searchFocus.requestFocus(),
                          icon: const Icon(Icons.alternate_email_rounded),
                          label: Text(
                            _copy(
                              context,
                              'اسم BIL',
                              'BIL name',
                              'Nom BIL',
                              'Nombre BIL',
                              'BIL adı',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    key: const Key('community-people-search'),
                    focusNode: _searchFocus,
                    controller: _search,
                    onChanged: _searchPeople,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: _copy(
                        context,
                        'الاسم',
                        'Display name',
                        'Nom',
                        'Nombre',
                        'Ad',
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _results,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _copy(
                                  context,
                                  'تعذر البحث الآن. حاول مجددًا.',
                                  'Search is unavailable right now. Try again.',
                                  'La recherche est indisponible. Réessayez.',
                                  'La búsqueda no está disponible. Inténtalo de nuevo.',
                                  'Arama şu anda kullanılamıyor. Tekrar deneyin.',
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => _searchPeople(_lastQuery),
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(
                                  _copy(
                                    context,
                                    'إعادة المحاولة',
                                    'Retry',
                                    'Réessayer',
                                    'Reintentar',
                                    'Tekrar dene',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final rows = snapshot.data ?? const [];
                      if (rows.isEmpty) {
                        return Center(
                          child: Text(
                            _copy(
                              context,
                              'لا توجد نتائج.',
                              'No people found.',
                              'Aucun résultat.',
                              'Sin resultados.',
                              'Sonuç yok.',
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return ListTile(
                            leading: BilAccountAvatar(
                              radius: 20,
                              networkUrl: row['avatar_url'] as String?,
                            ),
                            title: Text(row['display_name'] as String),
                            subtitle: row['bio'] == null
                                ? null
                                : Text(
                                    row['bio'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: friendsUnlocked
                                ? IconButton.filledTonal(
                                    tooltip:
                                        _pendingRequests.contains(
                                          row['user_id'],
                                        )
                                        ? _copy(
                                            context,
                                            'قيد الانتظار',
                                            'Pending',
                                            'En attente',
                                            'Pendiente',
                                            'Beklemede',
                                          )
                                        : _copy(
                                            context,
                                            'إرسال طلب',
                                            'Send request',
                                            'Envoyer',
                                            'Enviar',
                                            'İstek gönder',
                                          ),
                                    icon:
                                        _pendingRequests.contains(
                                          row['user_id'],
                                        )
                                        ? const Icon(Icons.schedule_rounded)
                                        : _sendingRequests.contains(
                                            row['user_id'],
                                          )
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person_add_alt_1_rounded,
                                          ),
                                    onPressed:
                                        _pendingRequests.contains(
                                              row['user_id'],
                                            ) ||
                                            _sendingRequests.contains(
                                              row['user_id'],
                                            )
                                        ? null
                                        : () => _requestFriend(
                                            row['user_id'] as String,
                                          ),
                                  )
                                : FilledButton.tonal(
                                    key: ValueKey(
                                      'community-premium-add-${row['user_id']}',
                                    ),
                                    onPressed: () => context.push(
                                      '/plans?focus=subscription',
                                    ),
                                    child: Text(
                                      _copy(
                                        context,
                                        'عرض خطط العضوية',
                                        'View membership plans',
                                        'Voir les offres d’abonnement',
                                        'Ver planes de membresía',
                                        'Üyelik planlarını gör',
                                      ),
                                    ),
                                  ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _StoreMark extends StatelessWidget {
  const _StoreMark({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFF101828),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 7),
        Text(
          label,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
