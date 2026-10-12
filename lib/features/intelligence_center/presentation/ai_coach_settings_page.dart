import '../../../shared/widgets/bil_striped_progress.dart';
import '../../../shared/widgets/bil_glass_press_feedback.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/bil_pearl_finish.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../app/theme/bil_flat_icon.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../../../shared/widgets/bil_clinical_note.dart';
import '../../commerce/presentation/ai_boost_coach_artwork.dart';
import '../../commerce/presentation/bil_store_copy.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../commerce/providers/app_purchase_providers.dart';
import '../../onboarding/onboarding_runtime_copy.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../domain/coach_context_preferences.dart';
import '../services/ai_boost_purchase_service.dart';
import '../services/coach_settings_context_provider.dart';
import '../services/coach_context_provider.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../services/remote_ai_consent_coordinator.dart';

part 'ai_coach_settings_components.dart';
part 'ai_coach_settings_usage_widgets.dart';
part 'ai_coach_settings_body.dart';

const _globalResetGiftCopy =
    'A gift from BIL 🎁 Your current-period AI Coach usage was reset, and 2,500 non-expiring AI Boost tokens were added.';

@visibleForTesting
Set<CoachContextFocus> coachContextFocusesFromUsage(Object? raw) {
  if (raw is! List) return const CoachContextPreferences().focuses;
  final names = raw
      .map((value) => value?.toString())
      .whereType<String>()
      .toSet();
  return Set.unmodifiable(
    CoachContextFocus.values.where((focus) => names.contains(focus.name)),
  );
}

class AiCoachSettingsPage extends ConsumerStatefulWidget {
  const AiCoachSettingsPage({super.key});

  @override
  ConsumerState<AiCoachSettingsPage> createState() =>
      _AiCoachSettingsPageState();
}

class _AiCoachSettingsPageState extends ConsumerState<AiCoachSettingsPage>
    with WidgetsBindingObserver {
  late final AiBoostPurchaseService boost;
  Future<Map<String, Object?>>? usage;
  bool changingConsent = false;
  bool changingContextFocus = false;
  Set<CoachContextFocus>? contextFocuses;
  int _usageLoadVersion = 0;
  String? _verifiedUsageOwnerId;
  Map<String, Object?>? _lastVerifiedUsage;
  PreferencesRepository? _contextRepository;
  CoachContextPreferences? _lastLocalContext;
  int _ownerEpoch = 0;
  String? _sessionOwner;
  StreamSubscription<AuthState>? _ownerSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    boost = ref.read(appBoostPurchaseProvider)..addListener(_boostChanged);
    _sessionOwner = Supabase.instance.client.auth.currentUser?.id;
    _ownerSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        if (state.session == null && state.event != AuthChangeEvent.signedOut) {
          return;
        }
        final next = state.session?.user.id;
        if (next == _sessionOwner || !mounted) return;
        _sessionOwner = next;
        _ownerEpoch++;
        setState(() {
          _lastVerifiedUsage = null;
          _verifiedUsageOwnerId = null;
          contextFocuses = null;
          _lastLocalContext = null;
          changingContextFocus = false;
          changingConsent = false;
          usage = _startUsageLoad();
        });
      },
    );
    usage = _startUsageLoad();
    boost.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    boost.initialize();
    setState(() {
      usage = _startUsageLoad();
    });
  }

  void _boostChanged() {
    if (!mounted) return;
    // The app-owned receipt listener refreshes all readers once, even after
    // leaving this page. The existing usage signal updates this local view.
    setState(() {});
  }

  Future<Map<String, Object?>> _startUsageLoad() {
    final pending = _loadUsage();
    // A fast I/O failure can precede the next frame's FutureBuilder listener.
    // Observe it immediately, while returning the original failed future to
    // the builder so the error/retry and last verified data stay visible.
    unawaited(pending.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    return pending;
  }

  Future<Map<String, Object?>> _loadUsage() async {
    final loadVersion = ++_usageLoadVersion;
    final epoch = _ownerEpoch;
    final preferences = ref.read(preferencesRepositoryProvider);
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw StateError('authentication_required');
    }
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('authentication_required');
    final value = await client.rpc('bil_get_ai_usage_status');
    final result = Map<String, Object?>.from(value as Map);
    final storedContext = await preferences.get(
      CoachContextPreferences.storageKey,
    );
    result['context_focuses'] = CoachContextPreferences.decode(
      storedContext,
    ).focuses.map((focus) => focus.name).toList(growable: false);
    try {
      final granted = await sharedRemoteAiConsentCoordinator(
        client,
      ).isGranted(forceServerRead: true);
      result['remote_ai_consent'] = granted;
      result['cloud_voice_consent'] = granted;
      result['consent_status_available'] = true;
    } on Object {
      result['remote_ai_consent'] = false;
      result['cloud_voice_consent'] = false;
      result['consent_status_available'] = false;
    }
    try {
      final notice = await client
          .from('bil_ai_coach_reset_notices')
          .select('reset_id,created_at,message')
          .eq('owner_id', ownerId)
          .isFilter('seen_at', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (notice != null) {
        result['reset_notice'] = Map<String, Object?>.from(notice);
      }
    } on Object {
      // Older backends can still show usage while the additive notice
      // migration is rolling out.
    }
    // An older request may complete after sign-out, sign-in or a newer
    // refresh. Never publish its private credit and consent data to the
    // current owner's UI.
    if (client.auth.currentUser?.id != ownerId ||
        epoch != _ownerEpoch ||
        !mounted ||
        !identical(ref.read(preferencesRepositoryProvider), preferences)) {
      throw StateError('authentication_required');
    }
    result['_qualityOwnerId'] = ownerId;
    if (mounted && loadVersion == _usageLoadVersion) {
      _verifiedUsageOwnerId = ownerId;
      _lastVerifiedUsage = Map<String, Object?>.unmodifiable(result);
    }
    return result;
  }

  Future<void> _setRemoteAiConsent(bool granted) async {
    if (changingConsent) return;
    setState(() => changingConsent = true);
    try {
      final coordinator = sharedRemoteAiConsentCoordinator();
      final verified = await (granted
          ? coordinator.grantAndVerify()
          : coordinator.revokeAndVerify());
      if (!verified) throw StateError('consent_readback_failed');
      if (mounted) {
        setState(() {
          usage = _startUsageLoad();
        });
      }
    } on Object {
      if (!mounted) return;
      if (!granted) {
        setState(() {
          usage = _startUsageLoad();
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Could not update AI privacy consent. Nothing was sent.',
              'تعذّر تحديث موافقة الخصوصية. لم يتم إرسال أي شيء.',
              'Impossible de mettre à jour le consentement. Aucun envoi.',
              'No se pudo actualizar el consentimiento. No se envió nada.',
              'Gizlilik izni güncellenemedi. Hiçbir şey gönderilmedi.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => changingConsent = false);
    }
  }

  Future<void> _setContextFocus(
    CoachContextFocus focus,
    bool included,
    Set<CoachContextFocus> current,
  ) async {
    if (changingContextFocus) return;
    final preferences = ref.read(preferencesRepositoryProvider);
    final epoch = _ownerEpoch;
    final owner = _sessionOwner;
    bool currentOwner() =>
        mounted &&
        epoch == _ownerEpoch &&
        owner == _sessionOwner &&
        identical(ref.read(preferencesRepositoryProvider), preferences);
    if (!currentOwner()) return;
    final next = <CoachContextFocus>{...current};
    included ? next.add(focus) : next.remove(focus);
    // The switch follows the requested value immediately, but the
    // repository remains authoritative: a failed save rolls this back.
    setState(() {
      changingContextFocus = true;
      contextFocuses = Set.unmodifiable(next);
    });
    try {
      await preferences.update(CoachContextPreferences.storageKey, (raw) {
        final latest = {...CoachContextPreferences.decode(raw).focuses};
        included ? latest.add(focus) : latest.remove(focus);
        return CoachContextPreferences(
          focuses: Set.unmodifiable(latest),
        ).encode();
      }, isCurrent: currentOwner);
      if (currentOwner()) ref.invalidate(coachContextSnapshotProvider);
      // The verified preference stream will adopt the same value after
      // the next usage read. Keep the choice stable in the interim.
    } on Object {
      if (!mounted || !currentOwner()) return;
      setState(() => contextFocuses = Set.unmodifiable(current));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Could not update Coach context categories. Nothing changed.',
              'تعذر تحديث فئات سياق المدرب. لم يتغير شيء.',
              'Impossible de modifier les catégories de contexte. Aucun changement.',
              'No se pudieron actualizar las categorías de contexto. No cambió nada.',
              'Koç bağlam kategorileri güncellenemedi. Hiçbir şey değişmedi.',
            ),
          ),
        ),
      );
    } finally {
      if (currentOwner()) setState(() => changingContextFocus = false);
    }
  }

  String t(String en, String ar, String fr, String es, String tr) {
    final locale = Localizations.localeOf(context);
    return switch (locale.languageCode) {
      'ar' => ar,
      'en' => en,
      'fr' => fr,
      'es' => es,
      'tr' => tr,
      _ =>
        RuntimeCopy.resolve(en, BilLocalePolicy.canonicalTag(locale)) ??
            OnboardingRuntimeCopy.resolve(en, locale),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(aiCoachUsageRefreshProvider, (previous, next) {
      if (previous == next || !mounted) return;
      setState(() {
        usage = _startUsageLoad();
      });
    });
    final localRepository = ref.watch(preferencesRepositoryProvider);
    if (!identical(localRepository, _contextRepository)) {
      final replacingOwner = _contextRepository != null;
      _contextRepository = localRepository;
      _lastLocalContext = null;
      contextFocuses = null;
      changingContextFocus = false;
      if (replacingOwner) {
        _usageLoadVersion++;
        _lastVerifiedUsage = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              identical(
                ref.read(preferencesRepositoryProvider),
                localRepository,
              )) {
            setState(() {
              usage = _startUsageLoad();
            });
          }
        });
      }
    }
    final local = ref.watch(coachSettingsContextProvider);
    final localData = local.asData?.value;
    if (localData != null && identical(localData.repository, localRepository)) {
      _lastLocalContext = localData.preferences;
      if (contextFocuses != null &&
          setEquals(contextFocuses!, localData.preferences.focuses)) {
        contextFocuses = null;
      }
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        title: Text(
          t(
            'Coach settings',
            'إعدادات المدرب',
            'Réglages du Coach',
            'Ajustes del Coach',
            'Koç ayarları',
          ),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: BilPearlBackdrop(
        child: FutureBuilder<Map<String, Object?>>(
          future: usage,
          builder: (context, snapshot) {
            final currentOwner = Supabase.instance.client.auth.currentUser?.id;
            final received = snapshot.data;
            final currentData = received?['_qualityOwnerId'] == currentOwner
                ? received
                : null;
            // A refresh or transient network error may retain the last
            // server-verified data, but never data from a different account.
            final cached =
                currentOwner != null && _verifiedUsageOwnerId == currentOwner
                ? _lastVerifiedUsage
                : null;
            final data = currentData ?? cached;
            if (data == null) {
              return _settingsBody(
                null,
                usageError: snapshot.error,
                usageLoading:
                    snapshot.connectionState == ConnectionState.waiting,
                contextError: local.error,
              );
            }
            final refreshing =
                snapshot.connectionState == ConnectionState.waiting;
            return Column(
              children: [
                SizedBox(
                  height: 3,
                  child: refreshing
                      ? const LinearProgressIndicator()
                      : const SizedBox.shrink(),
                ),
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListTile(
                      key: const Key('ai-coach-settings-stale-notice'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.info_outline_rounded, size: 20),
                      title: Text(
                        t(
                          'Refresh failed. Showing last verified settings.',
                          'تعذّر التحديث. تظهر آخر إعدادات مؤكدة.',
                          'Actualisation impossible. Derniers réglages vérifiés.',
                          'No se pudo actualizar. Se muestra la última versión verificada.',
                          'Yenileme başarısız. Son doğrulanmış ayarlar gösteriliyor.',
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: t(
                          'Retry',
                          'إعادة المحاولة',
                          'Réessayer',
                          'Reintentar',
                          'Yeniden dene',
                        ),
                        onPressed: () => setState(() {
                          usage = _startUsageLoad();
                        }),
                        icon: const BilGlassPressFeedback(
                          child: Icon(Icons.refresh_rounded),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final fresh = _startUsageLoad();
                      setState(() {
                        usage = fresh;
                      });
                      try {
                        await fresh;
                      } on Object {
                        // Keep the verified snapshot; the inline notice and
                        // explicit Retry expose the failed refresh.
                      }
                    },
                    child: _settingsBody(data, contextError: local.error),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _errorState(Object? error) {
    final authenticationRequired = error.toString().contains(
      'authentication_required',
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              authenticationRequired
                  ? Icons.person_outline_rounded
                  : Icons.cloud_off_rounded,
              size: 46,
              color: const Color(0xFF536873),
            ),
            const SizedBox(height: 12),
            Text(
              authenticationRequired
                  ? context.strings.text(
                      'Sign in and try again to manage AI Coach access.',
                    )
                  : t(
                      'Could not load your Coach balance. Check your account and try again.',
                      'تعذّر تحميل رصيد المدرب. تحقق من حسابك وحاول مجددًا.',
                      'Impossible de charger le solde. Réessayez.',
                      'No se pudo cargar el saldo. Inténtalo de nuevo.',
                      'Koç bakiyesi yüklenemedi. Tekrar deneyin.',
                    ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: authenticationRequired
                  ? () => context.push('/login')
                  : () => setState(() {
                      usage = _startUsageLoad();
                    }),
              icon: BilGlassPressFeedback(
                child: Icon(
                  authenticationRequired
                      ? Icons.login_rounded
                      : Icons.refresh_rounded,
                ),
              ),
              label: Text(
                authenticationRequired
                    ? context.strings.text('Sign in')
                    : t(
                        'Try again',
                        'حاول مجددًا',
                        'Réessayer',
                        'Reintentar',
                        'Tekrar dene',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _int(Object? value) => value is num ? value.toInt() : 0;

  Future<void> _dismissResetNotice(String resetId) async {
    final client = Supabase.instance.client;
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) return;
    try {
      final changed = await client.rpc(
        'bil_dismiss_ai_coach_reset_notice',
        params: <String, Object?>{'p_owner_id': ownerId, 'p_reset_id': resetId},
      );
      if (changed != true) return;
      if (mounted) {
        setState(() {
          usage = _startUsageLoad();
        });
      }
    } on Object {
      // Keep the notice visible when acknowledgement did not persist.
    }
  }

  Future<void> _manageSubscription() async {
    final uri = defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_ownerSubscription?.cancel());
    boost.removeListener(_boostChanged);
    super.dispose();
  }
}
