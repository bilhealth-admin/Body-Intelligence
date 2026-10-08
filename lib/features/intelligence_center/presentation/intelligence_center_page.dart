import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/bil_semantic_icons.dart';
import '../../../app/environment/app_environment.dart';
import '../../../app/services/app_settings_provider.dart';
import '../../../app/services/app_settings_service.dart';
import '../../../app/services/runtime_permission_policy.dart';
import '../../../app/services/recoverable_image_picker.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy_meal_voice.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_scope.dart';
import '../../../data/repositories/daily_log_repository.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../../../shared/widgets/bil_premium_trust_surface.dart';
import '../../../shared/widgets/chat_history_viewport.dart';
import '../../../shared/widgets/bil_camera_capture_page.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../community/presentation/community_gold_balance_action.dart';
import '../../foods/providers/food_provider.dart';
import '../domain/intelligence_action.dart';
import '../domain/food_v2/coach_food_v2.dart';
import '../media_bridge/coach_media_attempt.dart';
import '../media_bridge/coach_media_food_bridge.dart';
import '../media_bridge/coach_media_catalog_entry.dart';
import '../media_bridge/coach_media_bridge_copy.dart';
import '../media_bridge/coach_voice_transcript_bridge.dart';
import '../domain/coach_action_permission.dart';
import '../domain/coach_action_admission.dart';
import '../domain/bil_navigation_registry.dart';
import '../domain/bil_action_receipt.dart';
import '../domain/coach_context_snapshot.dart';
import '../domain/intelligence_message.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../cloud_platform/presentation/cloud_auto_sync_coordinator.dart';
import '../../weight/providers/weight_provider.dart';
import '../services/intelligence_center_engine.dart';
import '../services/bil_text_to_speech.dart';
import '../services/bil_mic_sound.dart';
import '../services/coach_intent_normalizer.dart';
import '../services/coach_language_resolver.dart';
import '../services/coach_speech_policy.dart';
import '../services/coach_voice_turn_policy.dart';
import '../services/coach_daily_brief.dart';
import '../services/coach_memory_repository.dart';
import '../settings_commands/coach_unit_settings_command.dart';
import '../settings_commands/coach_reminder_command.dart';
import '../../notifications/domain/daily_reminder.dart';
import '../services/coach_native_command_repository.dart';
import '../services/coach_voice_transcript_normalizer.dart';
import '../services/intelligence_health_context_provider.dart';
import '../services/coach_context_provider.dart';
import '../services/local_coach_api.dart';
import '../services/remote_ai_consent_coordinator.dart';
import '../food_flow/coach_food_flow.dart';
import '../app_commands/coach_health_adapter.dart';
import '../app_commands/coach_health_copy.dart';
import '../app_commands/coach_health_parser.dart';
import '../app_commands/coach_health_read_guard.dart';
import '../app_commands/coach_health_brief_provider.dart';
import '../app_commands/coach_daily_commands.dart';
import '../app_commands/coach_life_context_commands.dart';
import '../app_commands/coach_fasting_commands.dart';
import '../app_commands/coach_activity_adapter.dart';
import '../app_commands/coach_plan_adapter.dart';
import '../app_commands/health_query_adapter.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../wellness/presentation/wellness_tools_pages.dart'
    show fastingNotificationServiceProvider;
import '../../nutrition_plans/data/diet_plan_repository.dart'
    show NutritionPathwayActivationException, NutritionPathwayActivationFailure;

import '../services/local_model_gateway.dart';
import '../services/coach_catalog_grounding.dart';
import '../services/coach_action_presentation_policy.dart';
import '../services/ai_coach_feedback_service.dart';
import '../../nutrition/domain/barcode_identity.dart';
import '../../nutrition/services/food_search_normalizer.dart';
import '../../nutrition/services/bil_speech_to_text.dart';
import '../../nutrition/services/meal_image_analysis_service.dart';
import '../../nutrition/presentation/meal_image_review_dialog.dart';
import '../../nutrition/presentation/meal_vision_ui_copy.dart';
import '../../nutrition/presentation/meal_vision_consent_gate.dart';
import '../intelligence_locale_copy.dart';
import '../ai_coach_chat_copy.dart';
import 'coach_message_text.dart';
import '../../../shared/widgets/bil_reference_bottom_bar.dart';
import '../../../app/router/bil_quick_add_presenter.dart';
import 'workspace/coach_reference_workspace.dart';
import 'workspace/coach_food_review_card.dart';
import 'workspace/coach_food_receipt_card.dart';
import 'coach_anchored_history.dart';

part 'intelligence_center_page_message.dart';
part 'intelligence_center_widgets.dart';
part 'intelligence_coach_menu.dart';
part 'intelligence_reference_workspace_flow.dart';
part 'intelligence_coach_reference_header.dart';
part 'intelligence_center_message_widgets.dart';
part 'intelligence_center_voice_widgets.dart';
part 'intelligence_conversation_persistence.dart';
part 'intelligence_conversation_history.dart';
part 'intelligence_conversation_viewport.dart';
part 'intelligence_reference_chat_body.dart';
part 'intelligence_conversation_voice.dart';
part 'intelligence_conversation_voice_transcript.dart';
part 'intelligence_vision_flow.dart';
part 'intelligence_media_confirmation.dart';
part 'intelligence_query_flow.dart';
part 'intelligence_query_decision.dart';
part 'intelligence_action_flow.dart';
part 'intelligence_meal_action_flow.dart';
part 'intelligence_meal_owner.dart';
part 'intelligence_native_owner.dart';
part 'intelligence_native_action_flow.dart';
part 'intelligence_native_recovery.dart';
part 'intelligence_settings_recovery.dart';
part 'intelligence_native_recovery_owner.dart';
part 'intelligence_meal_recovery.dart';
part 'intelligence_action_runtime.dart';
part 'intelligence_action_confirmation.dart';
part '../food_flow/intelligence_food_flow.dart';
part '../app_commands/coach_health_flow.dart';
part '../app_commands/coach_health_recovery.dart';

/// Single injectable wall clock for conversation copy and seeded messages.
///
/// Production still reads the device clock. Visual and widget tests override
/// this provider so a morning/evening boundary cannot change their output.
final intelligenceConversationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Injectable model boundary used by the Coach conversation.
///
/// Production keeps the platform-selected gateway. Focused behavior tests can
/// supply a deterministic gateway and exercise confirmation, repositories,
/// UI receipts, and conversation persistence without making a network call.
final intelligenceCenterModelGatewayProvider = Provider<LocalModelGateway>(
  (ref) => createLocalModelGateway(),
);

final coachActionPermissionModeProvider =
    StateProvider<CoachActionPermissionMode>(
      (ref) => CoachActionPermissionMode.askBeforeWrite,
    );

class IntelligenceCenterPage extends ConsumerStatefulWidget {
  const IntelligenceCenterPage({
    super.key,
    this.startWithVisionCapture = false,
    this.initialBarcode,
  });

  final bool startWithVisionCapture;
  final String? initialBarcode;

  @override
  ConsumerState<IntelligenceCenterPage> createState() =>
      _IntelligenceCenterPageState();
}

class _IntelligenceCenterPageState extends ConsumerState<IntelligenceCenterPage>
    with WidgetsBindingObserver {
  final question = TextEditingController();
  final conversationScroll = ScrollController();
  final speech = SpeechToText();
  final catalogGrounding = CoachCatalogGrounding();
  final messages = <IntelligenceMessage>[];
  final executingActionKeys = <String>{};
  final completedActionOperationIds = <String>{};
  final actionExecutionPhases = <String, _CoachActionExecutionPhase>{};
  String? lastClearWritingLanguageTag;
  Timer? voiceSilenceTimer;
  Timer? replyDelayTimer;
  Timer? entryWelcomeTimer;
  String? voiceLanguageHint;
  String pendingVoiceTranscript = '';
  _CoachVoiceMode voiceMode = _CoachVoiceMode.idle;
  _CoachReplyPhase replyPhase = _CoachReplyPhase.idle;
  bool liveCallPaused = false;
  int requestGeneration = 0;
  ({
    String text,
    String? detectedLanguageTag,
    bool autoSpeak,
    CoachInputChannel channel,
  })?
  failedRequest;
  bool sending = false;
  bool listening = false;
  bool voiceSubmitPending = false;
  bool voiceCaptureStarting = false;
  bool coachInBackground = false;
  int voiceCaptureGeneration = 0;
  int liveCallNoSpeechRestarts = 0;
  int voiceTransientRestarts = 0;
  bool analyzingFoodImage = false;
  bool foodImageFlowOpening = false;
  _CoachMediaPageRequest? foodMediaRequest;
  _CoachMediaPageRequest? voiceMediaRequest;
  String? queuedMediaBarcode;
  final voiceTranscriptBridge = CoachVoiceTranscriptBridge();
  bool consentPromptVisible = false;
  Future<_RemoteAiConsentChoice>? consentChoiceInFlight;
  IntelligenceMessage? sessionWelcomeMessage;
  bool introVisible = true;
  bool conversationReady = false;
  bool conversationLoadFailed = false;
  bool conversationHistoryOpening = false;
  bool coachMenuOpening = false;
  bool entryWelcomeVisible = true;
  String? activeConversationId;
  Future<void> conversationPersistenceTail = Future<void>.value();
  int conversationPersistenceEpoch = 0;
  ProviderSubscription<AppDatabase>? healthEffectOwnerSubscription;
  final healthEffectCancellers = <VoidCallback>{};
  int conversationLoadGeneration = 0;
  late final PreferencesRepository conversationPreferences;
  late final WeightRepository conversationWeightRepository;
  late final DailyLogRepository conversationDailyLogRepository;

  void _updateState(VoidCallback update) => setState(update);
  CoachServiceStatus lastServiceStatus = CoachServiceStatus.ready;
  CoachAnswerRuntime lastRuntime = CoachAnswerRuntime.onDevice;
  final messageRuntimes = <String, CoachAnswerRuntime>{};
  final messageFeedback = <String, bool>{};
  final reportedMessages = <String>{};
  final undoOperations = <String, _CoachUndoOperation>{};
  final preparedMealActions = <String, _PreparedCoachMealAction>{};
  final preparedNativeActions = <String, _PreparedCoachNativeAction>{};
  final recoveredMealOwners = <_CoachMealOwnerHandle>[];
  final recoveredNativeOwners = <_RecoveredCoachNativeOwner>[];
  // Only the latest failed turn owns a retry affordance. The failure remains
  // part of the transcript, while the transient progress row is not rendered
  // as a second error surface.
  final retryableErrorMessageIds = <String>{};
  // Keep the typing treatment limited to BIL replies created in this mounted
  // session. Previously saved messages remain immediate for browsing.
  final animatedResponseIds = <String>{};
  static const _speechPolicy = CoachSpeechPolicy();
  static const _voiceTurnPolicy = CoachVoiceTurnPolicy();

  bool get arabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  String tr(String english, String arabicText) =>
      intelligenceText(context, english, arabicText);

  @override
  void initState() {
    super.initState();
    entryWelcomeTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => entryWelcomeVisible = false);
    });
    // Riverpod refs are unavailable from dispose. Retain the stable,
    // database-backed repositories while this element is active so the last
    // conversation snapshot can still be queued during teardown.
    conversationPreferences = ref.read(preferencesRepositoryProvider);
    conversationWeightRepository = ref.read(weightRepositoryProvider);
    conversationDailyLogRepository = ref.read(dailyLogRepositoryProvider);
    WidgetsBinding.instance.addObserver(this);
    healthEffectOwnerSubscription = ref.listenManual(databaseProvider, (
      previous,
      next,
    ) {
      if (!identical(previous, next)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_resumeCoachFastingEffects());
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadConversation();
      if (!mounted) return;
      unawaited(_resumeCoachFastingEffects());
      unawaited(_syncCoachMemory());
      _applyInitialBarcode(widget.initialBarcode);
      if (widget.startWithVisionCapture) await _analyzeFoodImageInChat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep one stable, non-persistent introduction visible while local
    // storage is being read. The restored transcript replaces only the
    // session object after the read; it never merges a provisional turn into
    // the user-owned history.
    if (sessionWelcomeMessage != null) return;
    final now = ref.read(intelligenceConversationClockProvider)();
    sessionWelcomeMessage = IntelligenceMessage(
      id: 'welcome-loading-${now.microsecondsSinceEpoch}',
      role: IntelligenceMessageRole.bil,
      kind: IntelligenceMessageKind.coach,
      text: _sessionWelcome(null, at: now),
      createdAt: now,
      modality: IntelligenceMessageModality.system,
    );
  }

  Future<void> _syncCoachMemory() async {
    await CoachMemoryRepository(
      preferences: ref.read(preferencesRepositoryProvider),
    ).mergeFromCloud();
    if (mounted) ref.invalidate(coachContextSnapshotProvider);
  }

  @override
  void didUpdateWidget(covariant IntelligenceCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBarcode != widget.initialBarcode) {
      _applyInitialBarcode(widget.initialBarcode);
    }
    if (!oldWidget.startWithVisionCapture && widget.startWithVisionCapture) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _analyzeFoodImageInChat();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      coachInBackground = false;
      unawaited(_resumeCoachFastingEffects());
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      coachInBackground = true;
      voiceMediaRequest?.attempt.cancel();
      voiceTranscriptBridge.cancel();
      voiceCaptureGeneration++;
      if (voiceMode == _CoachVoiceMode.liveCall) liveCallPaused = true;
      unawaited(const BilTextToSpeech().stop());
    }
    if (conversationReady &&
        (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      // Snapshot before the operating system can suspend the process. The
      // save owns its repositories, so it can finish if this route is disposed
      // while the write is in flight.
      unawaited(_saveConversation());
    }
    // iOS emits `inactive` for its microphone/speech consent sheet and for
    // other transient system overlays. Do not cancel a live recognizer there;
    // only a true background transition should stop capture.
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive ||
        !listening) {
      return;
    }
    voiceSilenceTimer?.cancel();
    unawaited(speech.cancel());
    if (mounted) {
      setState(() {
        listening = false;
        if (voiceMode == _CoachVoiceMode.liveCall) liveCallPaused = true;
      });
    }
  }

  void _applyInitialBarcode(String? rawBarcode) {
    final barcode = rawBarcode?.trim();
    if (barcode == null || barcode.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && conversationReady) {
        unawaited(_reviewBarcodeInChat(barcode));
      }
    });
    final identity = BarcodeIdentity.parse(barcode);
    if (!identity.isValid) {
      final evidenceKey =
          'barcode-invalid:${identity.issue?.name ?? 'unknown'}';
      if (messages.any((message) => message.evidence.contains(evidenceKey))) {
        return;
      }
      setState(
        () => messages.add(
          IntelligenceMessage(
            id: 'barcode-invalid-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: tr('Invalid barcode', 'باركود غير صالح'),
            createdAt: DateTime.now(),
            evidence: <String>[evidenceKey],
            confidence: 1,
          ),
        ),
      );
      _scrollToLatest();
      return;
    }
    final canonicalBarcode = identity.digits;
    final evidenceKey = 'barcode:$canonicalBarcode';
    if (messages.any((message) => message.evidence.contains(evidenceKey))) {
      return;
    }
    setState(
      () => messages.add(
        IntelligenceMessage(
          id: 'barcode-label-${DateTime.now().microsecondsSinceEpoch}',
          role: IntelligenceMessageRole.user,
          kind: IntelligenceMessageKind.coach,
          text: tr(
            'Review product label for barcode $canonicalBarcode',
            'راجع ملصق المنتج للباركود $canonicalBarcode',
          ),
          createdAt: DateTime.now(),
          evidence: <String>[evidenceKey],
          confidence: 1,
        ),
      ),
    );
    _scrollToLatest();
  }

  @override
  void didChangeMetrics() {
    // Opening or closing the keyboard changes the conversation viewport after
    // the current frame. Only re-pin during an active turn; otherwise the
    // first metrics notification while opening a restored chat would move the
    // user away from the session introduction.
    if (!conversationReady || (!sending && !listening)) return;
    _scrollToLatest();
  }

  Future<void> _openCoachMenuSheet() async {
    if (!mounted ||
        !conversationReady ||
        coachMenuOpening ||
        foodImageFlowOpening) {
      return;
    }
    coachMenuOpening = true;
    try {
      await _showCoachMenuSheet();
    } finally {
      coachMenuOpening = false;
    }
  }

  @override
  void dispose() {
    _cancelCoachMediaRequests(notify: false);
    voiceTranscriptBridge.dispose();
    healthEffectOwnerSubscription?.close();
    for (final cancel in healthEffectCancellers.toList()) {
      cancel();
    }
    healthEffectCancellers.clear();
    _disposePreparedCoachMealActions();
    _disposePreparedCoachNativeActions();
    voiceCaptureGeneration++;
    if (conversationReady) unawaited(_saveConversation());
    WidgetsBinding.instance.removeObserver(this);
    voiceSilenceTimer?.cancel();
    replyDelayTimer?.cancel();
    entryWelcomeTimer?.cancel();
    unawaited(const BilTextToSpeech().stop());
    unawaited(speech.dispose());
    question.dispose();
    conversationScroll.dispose();
    super.dispose();
  }

  bool _referenceOverview = false;
  bool _referenceNavigating = false;

  @override
  Widget build(BuildContext context) => _buildReferencePresentation(context);
}
