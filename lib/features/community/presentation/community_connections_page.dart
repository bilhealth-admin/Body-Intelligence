import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../../commerce/domain/commerce_entitlement.dart';
import '../../commerce/domain/subscription_state.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../data/community_repository.dart';

SupabaseClient? _initializedConnectionsClient() {
  if (!AppEnvironment.cloudConfigured) return null;
  try {
    final supabase = Supabase.instance;
    return supabase.isInitialized ? supabase.client : null;
  } on AssertionError {
    return null;
  } on StateError {
    return null;
  }
}

class CommunityConnectionsPage extends ConsumerStatefulWidget {
  const CommunityConnectionsPage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  ConsumerState<CommunityConnectionsPage> createState() =>
      _CommunityConnectionsPageState();
}

class _CommunityConnectionsPageState
    extends ConsumerState<CommunityConnectionsPage> {
  CommunityRepository? _repository;
  Future<List<Map<String, dynamic>>> _connections = Future.value(const []);
  int _tab = 0;
  final Set<String> _busyConnections = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository;
      _reload();
      return;
    }
    final client = _initializedConnectionsClient();
    if (client?.auth.currentUser == null) return;
    _repository = CommunityRepository(client!);
    _reload();
  }

  void _reload() {
    _connections = _repository!.loadFriendshipsWithProfiles();
  }

  Future<void> _respond(String id, {required bool accept}) async {
    if (!_busyConnections.add(id)) return;
    setState(() {});
    try {
      await _repository!.respondToFriendship(id, accept: accept);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _busyConnections.remove(id));
    }
  }

  Future<void> _remove(String id) async {
    if (!_busyConnections.add(id)) return;
    setState(() {});
    try {
      await _repository!.removeFriendship(id);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _busyConnections.remove(id));
    }
  }

  Future<void> _block(String operationId, String userId) async {
    if (!_busyConnections.add(operationId)) return;
    setState(() {});
    try {
      await _repository!.blockMember(userId);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _busyConnections.remove(operationId));
    }
  }

  Future<void> _reportUser(String operationId, String userId) async {
    if (!_busyConnections.add(operationId)) return;
    setState(() {});
    try {
      await _repository!.report(
        targetKind: 'profile',
        targetId: userId,
        reason: 'user_reported_from_connections',
      );
      if (mounted) {
        final copy = _ConnectionsCopy.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.reportSubmitted)));
      }
    } catch (_) {
      if (mounted) _showFailure();
    } finally {
      if (mounted) setState(() => _busyConnections.remove(operationId));
    }
  }

  void _showFailure() {
    final copy = _ConnectionsCopy.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copy.actionFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final copy = _ConnectionsCopy.of(context);
    final subscription = ref.watch(verifiedSubscriptionStateProvider).value;
    final friendsUnlocked =
        subscription?.authority == EntitlementAuthority.verifiedServer &&
        (subscription?.grants(CommerceEntitlement.communityFriends) ?? false);
    return Scaffold(
      appBar: AppBar(
        title: Text(copy.title),
        actions: [
          IconButton(
            tooltip: copy.findPeople,
            onPressed: _repository == null
                ? null
                : () => context.push('/community/people'),
            icon: const Icon(Icons.person_search_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: _ConnectionTab(
                  key: const Key('community-connections-all-tab'),
                  label: copy.all,
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
              ),
              Expanded(
                child: _ConnectionTab(
                  key: const Key('community-connections-requests-tab'),
                  label: copy.requests,
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _repository == null
          ? _ConnectionsUnavailable(copy: copy)
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _connections,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return _ConnectionsLoading(
                    label: context.strings.text('Loading...'),
                  );
                }
                if (snapshot.hasError) {
                  return _ConnectionsLoadError(
                    copy: copy,
                    onRetry: () => setState(_reload),
                  );
                }
                final rows = (snapshot.data ?? const <Map<String, dynamic>>[])
                    .map(_ConnectionRow.tryParse)
                    .whereType<_ConnectionRow>()
                    .toList(growable: false);
                final visibleRows = rows
                    .where((row) {
                      final status = row.status;
                      return _tab == 0
                          ? status == 'accepted'
                          : status == 'pending';
                    })
                    .toList(growable: false);
                if (visibleRows.isEmpty) {
                  return _EmptyConnections(copy: copy);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_reload);
                    await _connections;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleRows.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ConnectionsEducation(copy: copy);
                      }
                      final row = visibleRows[index - 1];
                      final otherId = row.otherUserId;
                      final status = row.status;
                      final incoming =
                          row.addresseeId == _repository!.currentUserId;
                      final name = row.displayName ?? copy.member;
                      final avatar = row.avatarUrl;
                      final busy = _busyConnections.contains(row.id);
                      return Card(
                        child: ListTile(
                          leading: BilAccountAvatar(
                            radius: 20,
                            networkUrl: avatar,
                          ),
                          title: Text(name),
                          subtitle: Text(
                            copy.status(status, incoming: incoming),
                          ),
                          trailing: status == 'pending' && incoming
                              ? Wrap(
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      tooltip: copy.decline,
                                      onPressed: busy
                                          ? null
                                          : () =>
                                                _respond(row.id, accept: false),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                    if (friendsUnlocked)
                                      IconButton.filled(
                                        tooltip: copy.accept,
                                        onPressed: busy
                                            ? null
                                            : () => _respond(
                                                row.id,
                                                accept: true,
                                              ),
                                        icon: Icon(
                                          Icons.check_rounded,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                      )
                                    else
                                      FilledButton.tonal(
                                        key: ValueKey(
                                          'community-premium-accept-${row.id}',
                                        ),
                                        onPressed: () => context.push(
                                          '/plans?focus=subscription',
                                        ),
                                        child: Text(
                                          context.strings.text('Premium'),
                                          style: const TextStyle(
                                            color: Color(0xFFC28A16),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : status == 'accepted'
                              ? Wrap(
                                  spacing: 2,
                                  children: [
                                    IconButton(
                                      tooltip: copy.message,
                                      onPressed: busy
                                          ? null
                                          : () => context.push(
                                              '/community/chat/$otherId',
                                              extra: name,
                                            ),
                                      icon: const Icon(
                                        Icons.chat_bubble_outline,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      enabled: !busy,
                                      tooltip: copy.manage,
                                      onSelected: (value) {
                                        if (value == 'remove') {
                                          _remove(row.id);
                                        }
                                        if (value == 'block') {
                                          _block(row.id, otherId);
                                        }
                                        if (value == 'report') {
                                          _reportUser(row.id, otherId);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'remove',
                                          child: Text(copy.remove),
                                        ),
                                        PopupMenuItem(
                                          value: 'report',
                                          child: Text(copy.report),
                                        ),
                                        PopupMenuItem(
                                          value: 'block',
                                          child: Text(copy.block),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _ConnectionRow {
  const _ConnectionRow({
    required this.id,
    required this.otherUserId,
    required this.addresseeId,
    required this.status,
    this.displayName,
    this.avatarUrl,
  });
  final String id, otherUserId, addresseeId, status;
  final String? displayName, avatarUrl;

  static _ConnectionRow? tryParse(Map<String, dynamic> row) {
    final id = row['id'];
    final other = row['other_user_id'];
    final addressee = row['addressee_id'];
    final status = row['status'];
    if (id is! String ||
        id.isEmpty ||
        other is! String ||
        other.isEmpty ||
        addressee is! String ||
        addressee.isEmpty ||
        status is! String ||
        !const {'pending', 'accepted'}.contains(status)) {
      return null;
    }
    final profile = row['profile'];
    if (profile != null && profile is! Map<String, dynamic>) return null;
    final name = profile is Map<String, dynamic>
        ? profile['display_name']
        : null;
    final avatar = profile is Map<String, dynamic>
        ? profile['avatar_url']
        : null;
    if (name != null && name is! String ||
        avatar != null && avatar is! String) {
      return null;
    }
    return _ConnectionRow(
      id: id,
      otherUserId: other,
      addresseeId: addressee,
      status: status,
      displayName: name as String?,
      avatarUrl: avatar as String?,
    );
  }
}

class _ConnectionTab extends StatelessWidget {
  const _ConnectionTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: selected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _ConnectionsEducation extends StatelessWidget {
  const _ConnectionsEducation({required this.copy});
  final _ConnectionsCopy copy;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      leading: const Icon(Icons.shield_outlined),
      title: Text(copy.educationTitle),
      subtitle: Text(copy.educationBody),
    ),
  );
}

class _ConnectionsUnavailable extends StatelessWidget {
  const _ConnectionsUnavailable({required this.copy});

  final _ConnectionsCopy copy;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_off_outlined, size: 52),
              const SizedBox(height: 16),
              Text(
                copy.signInRequired,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('community-connections-add-friends'),
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.login_rounded),
                label: Text(copy.signIn),
              ),
              const SizedBox(height: 18),
              _ConnectionsEducation(copy: copy),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ConnectionsLoadError extends StatelessWidget {
  const _ConnectionsLoadError({required this.copy, required this.onRetry});

  final _ConnectionsCopy copy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 52),
          const SizedBox(height: 12),
          Text(copy.loadFailed, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(copy.retry),
          ),
        ],
      ),
    ),
  );
}

class _ConnectionsLoading extends StatelessWidget {
  const _ConnectionsLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _EmptyConnections extends StatelessWidget {
  const _EmptyConnections({required this.copy});
  final _ConnectionsCopy copy;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded, size: 56),
          const SizedBox(height: 12),
          Text(copy.empty, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/community/people'),
            icon: const Icon(Icons.person_search_rounded),
            label: Text(copy.findPeople),
          ),
        ],
      ),
    ),
  );
}

class _ConnectionsCopy {
  const _ConnectionsCopy({
    required this.title,
    required this.findPeople,
    required this.loadFailed,
    required this.empty,
    required this.member,
    required this.accept,
    required this.decline,
    required this.message,
    required this.pendingIncoming,
    required this.pendingOutgoing,
    required this.accepted,
    required this.declined,
    required this.manage,
    required this.remove,
    required this.block,
    required this.report,
    required this.reportSubmitted,
    required this.actionFailed,
    required this.signInRequired,
    required this.signIn,
    required this.retry,
    required this.all,
    required this.requests,
    required this.educationTitle,
    required this.educationBody,
  });

  factory _ConnectionsCopy.of(
    BuildContext context,
  ) => switch (Localizations.localeOf(context).languageCode) {
    'ar' => const _ConnectionsCopy(
      title: 'الأصدقاء والطلبات',
      findPeople: 'البحث عن أشخاص',
      loadFailed: 'تعذر تحميل العلاقات بأمان.',
      empty: 'لا توجد طلبات أو صداقات بعد.',
      member: 'عضو BIL',
      accept: 'قبول',
      decline: 'رفض',
      message: 'مراسلة',
      pendingIncoming: 'طلب صداقة وارد',
      pendingOutgoing: 'طلب مرسل بانتظار الرد',
      accepted: 'صديق',
      declined: 'طلب مرفوض',
      manage: 'إدارة العلاقة',
      remove: 'إزالة الصداقة',
      block: 'حظر العضو',
      report: 'الإبلاغ عن العضو',
      reportSubmitted: 'تم إرسال البلاغ إلى فريق الإشراف.',
      actionFailed: 'تعذر تنفيذ الإجراء بأمان. حاول مجددًا.',
      signInRequired: 'سجّل الدخول لعرض الأصدقاء والطلبات.',
      signIn: 'تسجيل الدخول',
      retry: 'إعادة المحاولة',
      all: 'الكل',
      requests: 'الطلبات',
      educationTitle: 'أنت تتحكم في علاقاتك',
      educationBody: 'لا نشارك بياناتك الصحية. اقبل فقط الأشخاص الذين تعرفهم.',
    ),
    'fr' => const _ConnectionsCopy(
      title: 'Amis et demandes',
      findPeople: 'Trouver des personnes',
      loadFailed: 'Impossible de charger les relations.',
      empty: 'Aucune demande ou amitié.',
      member: 'Membre BIL',
      accept: 'Accepter',
      decline: 'Refuser',
      message: 'Message',
      pendingIncoming: 'Demande reçue',
      pendingOutgoing: 'Demande envoyée',
      accepted: 'Ami',
      declined: 'Demande refusée',
      manage: 'Gérer',
      remove: 'Retirer l’amitié',
      block: 'Bloquer',
      report: 'Signaler le membre',
      reportSubmitted: 'Signalement envoyé à la modération.',
      actionFailed: 'Action impossible. Réessayez.',
      signInRequired: 'Connectez-vous pour voir les amis et les demandes.',
      signIn: 'Se connecter',
      retry: 'Réessayer',
      all: 'Tous',
      requests: 'Demandes',
      educationTitle: 'Vous contrôlez vos relations',
      educationBody:
          'Vos données de santé restent privées. N’acceptez que les personnes que vous connaissez.',
    ),
    'es' => const _ConnectionsCopy(
      title: 'Amigos y solicitudes',
      findPeople: 'Buscar personas',
      loadFailed: 'No se pudieron cargar las relaciones.',
      empty: 'Aún no hay solicitudes ni amistades.',
      member: 'Miembro BIL',
      accept: 'Aceptar',
      decline: 'Rechazar',
      message: 'Mensaje',
      pendingIncoming: 'Solicitud recibida',
      pendingOutgoing: 'Solicitud enviada',
      accepted: 'Amigo',
      declined: 'Solicitud rechazada',
      manage: 'Gestionar',
      remove: 'Eliminar amistad',
      block: 'Bloquear',
      report: 'Denunciar miembro',
      reportSubmitted: 'Denuncia enviada a moderación.',
      actionFailed: 'No se pudo completar la acción.',
      signInRequired: 'Inicia sesión para ver amigos y solicitudes.',
      signIn: 'Iniciar sesión',
      retry: 'Reintentar',
      all: 'Todos',
      requests: 'Solicitudes',
      educationTitle: 'Tú controlas tus conexiones',
      educationBody:
          'Tus datos de salud son privados. Acepta solo a personas que conozcas.',
    ),
    'tr' => const _ConnectionsCopy(
      title: 'Arkadaşlar ve istekler',
      findPeople: 'Kişi bul',
      loadFailed: 'Bağlantılar yüklenemedi.',
      empty: 'Henüz istek veya arkadaş yok.',
      member: 'BIL üyesi',
      accept: 'Kabul et',
      decline: 'Reddet',
      message: 'Mesaj',
      pendingIncoming: 'Gelen arkadaşlık isteği',
      pendingOutgoing: 'Gönderilen istek',
      accepted: 'Arkadaş',
      declined: 'İstek reddedildi',
      manage: 'Yönet',
      remove: 'Arkadaşlığı kaldır',
      block: 'Engelle',
      report: 'Üyeyi bildir',
      reportSubmitted: 'Bildirim moderasyona gönderildi.',
      actionFailed: 'İşlem tamamlanamadı. Tekrar deneyin.',
      signInRequired: 'Arkadaşları ve istekleri görmek için oturum açın.',
      signIn: 'Oturum aç',
      retry: 'Tekrar dene',
      all: 'Tümü',
      requests: 'İstekler',
      educationTitle: 'Bağlantılarınızı siz kontrol edersiniz',
      educationBody:
          'Sağlık verileriniz gizli kalır. Yalnızca tanıdığınız kişileri kabul edin.',
    ),
    _ => _ConnectionsCopy.extended(context),
  };

  factory _ConnectionsCopy.extended(BuildContext context) {
    String t(String value) => AppLocalizations.of(context).text(value);
    return _ConnectionsCopy(
      title: t('Friends and requests'),
      findPeople: t('Find people'),
      loadFailed: t('Could not load connections safely.'),
      empty: t('No requests or friends yet.'),
      member: t('BIL member'),
      accept: t('Accept'),
      decline: t('Decline'),
      message: t('Message'),
      pendingIncoming: t('Incoming friend request'),
      pendingOutgoing: t('Request awaiting response'),
      accepted: t('Friend'),
      declined: t('Request declined'),
      manage: t('Manage connection'),
      remove: t('Remove friend'),
      block: t('Block member'),
      report: t('Report member'),
      reportSubmitted: t('Report sent to moderation.'),
      actionFailed: t('Could not complete that action safely. Try again.'),
      signInRequired: t('Sign in to view friends and requests.'),
      signIn: t('Sign in'),
      retry: t('Retry'),
      all: t('All'),
      requests: t('Requests'),
      educationTitle: t('You control your connections'),
      educationBody: t(
        'Your health data stays private. Only accept people you know.',
      ),
    );
  }

  final String title, findPeople, loadFailed, empty, member;
  final String accept, decline, message;
  final String pendingIncoming, pendingOutgoing, accepted, declined;
  final String manage, remove, block, report, reportSubmitted;
  final String actionFailed, signInRequired;
  final String signIn, retry;
  final String all, requests, educationTitle, educationBody;

  String status(String value, {required bool incoming}) => switch (value) {
    'accepted' => accepted,
    'declined' => declined,
    _ => incoming ? pendingIncoming : pendingOutgoing,
  };
}
