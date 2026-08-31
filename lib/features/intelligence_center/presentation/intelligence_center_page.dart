import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme/bil_semantic_icons.dart';
import '../../../app/services/app_settings_provider.dart';
import '../../../app/services/runtime_permission_policy.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../data/database/database_provider.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../foods/providers/food_provider.dart';
import '../domain/intelligence_action.dart';
import '../domain/bil_navigation_registry.dart';
import '../domain/bil_action_receipt.dart';
import '../domain/coach_context_snapshot.dart';
import '../domain/intelligence_message.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../services/intelligence_center_engine.dart';
import '../services/bil_text_to_speech.dart';
import '../services/coach_intent_normalizer.dart';
import '../services/coach_language_resolver.dart';
import '../services/coach_speech_policy.dart';
import '../services/coach_voice_turn_policy.dart';
import '../services/coach_daily_brief.dart';
import '../services/coach_memory_repository.dart';
import '../services/intelligence_health_context_provider.dart';
import '../services/coach_context_provider.dart';
import '../services/local_coach_api.dart';
import '../services/local_model_gateway.dart';
import '../services/coach_catalog_grounding.dart';
import '../services/ai_coach_feedback_service.dart';
import '../../nutrition/domain/barcode_identity.dart';
import '../../nutrition/services/bil_speech_to_text.dart';
import '../../nutrition/services/meal_image_analysis_service.dart';
import '../../nutrition/presentation/meal_image_review_dialog.dart';
import '../intelligence_locale_copy.dart';

part 'intelligence_center_widgets.dart';
part 'intelligence_center_message_widgets.dart';
part 'intelligence_center_voice_widgets.dart';
part 'intelligence_conversation_voice.dart';
part 'intelligence_query_flow.dart';
part 'intelligence_action_flow.dart';

/// Single injectable wall clock for conversation copy and seeded messages.
///
/// Production still reads the device clock. Visual and widget tests override
/// this provider so a morning/evening boundary cannot change their output.
final intelligenceConversationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

enum _CoachVoiceMode { idle, dictation, liveCall }

enum _CoachReplyPhase { idle, preparing, searching, failed }

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
  Timer? voiceSilenceTimer;
  Timer? replyDelayTimer;
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
  bool analyzingFoodImage = false;
  bool consentPromptVisible = false;
  bool welcomeSeeded = false;
  bool introVisible = true;

  void _updateState(VoidCallback update) => setState(update);
  CoachServiceStatus lastServiceStatus = CoachServiceStatus.ready;
  CoachAnswerRuntime lastRuntime = CoachAnswerRuntime.onDevice;
  final messageRuntimes = <String, CoachAnswerRuntime>{};
  final messageFeedback = <String, bool>{};
  static const _speechPolicy = CoachSpeechPolicy();
  static const _voiceTurnPolicy = CoachVoiceTurnPolicy();

  bool get arabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  String tr(String english, String arabicText) =>
      intelligenceText(context, english, arabicText);

  Future<void> _analyzeFoodImageInChat() async {
    if (analyzingFoodImage || sending) return;
    if (!await _ensureCoachRuntimePermission(BilRuntimeCapability.camera) ||
        !mounted) {
      return;
    }
    // This affordance is deliberately unambiguous: camera means camera.
    const source = ImageSource.camera;
    setState(() {
      analyzingFoodImage = true;
      introVisible = false;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (image == null || !mounted) return;
      final analysis = await MealImageAnalysisService(
        requestedLocale: BilLocalePolicy.canonicalTag(
          Localizations.localeOf(context),
        ),
      ).analyze(image);
      if (!mounted) return;
      final reviewed = await showMealImageReviewDialog(
        context,
        analysis: analysis,
      );
      if (reviewed == null || !mounted) return;
      final summary = reviewed.isEmpty
          ? tr(
              'No food was confirmed. Nothing was logged.',
              'لم يتم تأكيد أي طعام. لم يُسجّل شيء.',
            )
          : reviewed
                .map((item) {
                  final confidence = (item.candidate.confidence * 100).round();
                  return '${item.candidate.name}: ${item.amount} ${item.unit} ($confidence%)';
                })
                .join('\n');
      setState(
        () => messages.add(
          IntelligenceMessage(
            id: 'vision-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text:
                '$summary\n${tr('Review and confirm a verified BIL food match before logging.', 'راجع وأكد مطابقة طعام موثقة في BIL قبل التسجيل.')}',
            createdAt: DateTime.now(),
            confidence: 1,
            modality: IntelligenceMessageModality.image,
          ),
        ),
      );
      _scrollToLatest();
      unawaited(_saveConversation());
    } on MealImageAnalysisException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message(
              arabic: arabic,
              languageCode: BilLocalePolicy.canonicalTag(
                Localizations.localeOf(context),
              ),
            ),
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Food image analysis failed. Nothing was logged.',
              'فشل تحليل صورة الطعام. لم يُسجّل شيء.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => analyzingFoodImage = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadConversation();
      if (!mounted) return;
      unawaited(_syncCoachMemory());
      _applyInitialBarcode(widget.initialBarcode);
      if (widget.startWithVisionCapture) await _analyzeFoodImageInChat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (welcomeSeeded) return;
    welcomeSeeded = true;
    final now = ref.read(intelligenceConversationClockProvider)();
    messages.add(
      IntelligenceMessage(
        id: 'welcome-immediate-${now.microsecondsSinceEpoch}',
        role: IntelligenceMessageRole.bil,
        kind: IntelligenceMessageKind.coach,
        text: _sessionWelcome(null, at: now),
        createdAt: now,
        modality: IntelligenceMessageModality.system,
      ),
    );
  }

  Future<void> _syncCoachMemory() async {
    await CoachMemoryRepository(
      preferences: ref.read(preferencesRepositoryProvider),
    ).mergeFromCloud();
    ref.invalidate(coachContextSnapshotProvider);
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
    if (state == AppLifecycleState.resumed || !listening) return;
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
    // the current frame. Re-pin the chat to its newest message once that new
    // viewport has been laid out.
    _scrollToLatest();
  }

  Future<void> _openCoachMenuSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => const _CoachMenuSheet(),
    );
    if (!mounted || action == null) return;
    if (action == 'memory') {
      await context.push('/decision-memory');
    } else if (action == 'settings') {
      await _openAiCoachSettings();
    } else if (action == 'clear') {
      await _clearConversation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    voiceSilenceTimer?.cancel();
    replyDelayTimer?.cancel();
    unawaited(const BilTextToSpeech().stop());
    unawaited(speech.dispose());
    question.dispose();
    conversationScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coachContext = ref.watch(coachContextSnapshotProvider);
    final snapshot = coachContext.asData?.value;
    final dailyBrief = snapshot == null
        ? null
        : const CoachDailyBriefEngine().build(
            context: snapshot,
            now: DateTime.now(),
            locale: BilLocalePolicy.canonicalTag(
              Localizations.localeOf(context),
            ),
          );
    final visibleMessages = messages.toList(growable: false);
    final showLiveVoiceDraft =
        listening && pendingVoiceTranscript.trim().isNotEmpty;
    final showReplyProgress =
        replyPhase == _CoachReplyPhase.searching ||
        replyPhase == _CoachReplyPhase.failed;
    final showIntroBrief = introVisible && dailyBrief != null;
    final coachStatus = voiceMode == _CoachVoiceMode.liveCall && liveCallPaused
        ? tr('Live call paused', 'المكالمة المباشرة متوقفة مؤقتًا')
        : listening
        ? tr(
            'Listening live · pause to send',
            'أكتب كلامك مباشرة · اسكت للإرسال',
          )
        : sending
        ? tr('Thinking with your BIL data', 'أفكر باستخدام بيانات BIL')
        : tr('Ready', 'جاهز');
    const coachNavy = Color(0xFF071923);
    return Scaffold(
      backgroundColor: coachNavy,
      body: ColoredBox(
        color: coachNavy,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 6),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 760),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF1D4A60),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .3),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _CoachHero(
                      key: const ValueKey('ai-coach-hero'),
                      onStart: _toggleLiveCall,
                      onStop: _stopLiveCall,
                      liveCallActive: voiceMode == _CoachVoiceMode.liveCall,
                      liveCallPaused: liveCallPaused,
                      active: listening || sending,
                      status: coachStatus,
                      onBack: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/dashboard');
                        }
                      },
                      onMenu: () => unawaited(_openCoachMenuSheet()),
                    ),
                    Expanded(
                      child: visibleMessages.isEmpty
                          ? _CoachEmptyState(
                              onVoice: _toggleLiveCall,
                              onCamera: _analyzeFoodImageInChat,
                            )
                          : ListView.builder(
                              controller: conversationScroll,
                              reverse: true,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                18,
                                16,
                                12,
                              ),
                              itemCount:
                                  visibleMessages.length +
                                  (showLiveVoiceDraft ? 1 : 0) +
                                  (showReplyProgress ? 1 : 0) +
                                  (showIntroBrief ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (showReplyProgress && index == 0) {
                                  return _CoachReplyProgress(
                                    phase: replyPhase,
                                    onCancel: _cancelCurrentCoachRequest,
                                    onRetry: failedRequest == null
                                        ? null
                                        : _retryFailedCoachRequest,
                                  );
                                }
                                final progressOffset = showReplyProgress
                                    ? 1
                                    : 0;
                                if (showLiveVoiceDraft &&
                                    index == progressOffset) {
                                  return _LiveVoiceTranscript(
                                    text: pendingVoiceTranscript.trim(),
                                    liveCall:
                                        voiceMode == _CoachVoiceMode.liveCall,
                                  );
                                }
                                var cursor =
                                    index -
                                    progressOffset -
                                    (showLiveVoiceDraft ? 1 : 0);
                                if (cursor == 0 && visibleMessages.isNotEmpty) {
                                  return _buildMessage(
                                    visibleMessages.last,
                                    messageFeedback,
                                  );
                                }
                                cursor -= 1;
                                if (showIntroBrief && cursor == 0) {
                                  return _InlineCoachDecision(
                                    brief: dailyBrief,
                                    onAction: () {
                                      if (dailyBrief.kind ==
                                          CoachDailyBriefKind.experiment) {
                                        context.push('/experiments');
                                      } else {
                                        usePrompt(dailyBrief.suggestedPrompt);
                                      }
                                    },
                                  );
                                }
                                if (showIntroBrief) cursor -= 1;
                                final messageIndex =
                                    visibleMessages.length - 2 - cursor;
                                final message = visibleMessages[messageIndex];
                                return _buildMessage(message, messageFeedback);
                              },
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.fromLTRB(12, 5, 12, 12),
                        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: listening
                                ? scheme.primary.withValues(alpha: .62)
                                : scheme.outlineVariant.withValues(alpha: .55),
                            width: listening ? 1.5 : .8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: .07),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              key: const Key('ai-coach-food-image-button'),
                              tooltip: tr('Open camera', 'افتح الكاميرا'),
                              onPressed: analyzingFoodImage || sending
                                  ? null
                                  : _analyzeFoodImageInChat,
                              icon: analyzingFoodImage
                                  ? const SizedBox.square(
                                      dimension: 19,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 21,
                                    ),
                            ),
                            Expanded(
                              child: listening
                                  ? _ListeningComposerLabel(
                                      label: tr(
                                        'Listening — pause when you’re done',
                                        'أستمع — اسكت عندما تنتهي',
                                      ),
                                      transcript: pendingVoiceTranscript,
                                    )
                                  : TextField(
                                      key: const Key('ai-coach-question-field'),
                                      controller: question,
                                      minLines: 1,
                                      maxLines: 4,
                                      textInputAction: TextInputAction.send,
                                      onTap: _scrollToLatest,
                                      onSubmitted: (_) => ask(),
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        hintText: tr(
                                          'Ask BIL anything about your day…',
                                          'اسأل BIL أي شيء عن يومك…',
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 10,
                                            ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 4),
                            if (question.text.trim().isEmpty || listening)
                              IconButton.filled(
                                key: const Key('ai-coach-voice-button'),
                                tooltip: listening
                                    ? tr('Stop listening', 'إيقاف الاستماع')
                                    : tr('Talk to BIL', 'تحدث مع BIL'),
                                onPressed: sending ? null : _toggleDictation,
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF12394E),
                                  foregroundColor: const Color(0xFFC8F3FF),
                                  minimumSize: const Size.square(46),
                                ),
                                icon: listening
                                    ? const _VoiceListeningWave(
                                        color: Color(0xFFC8F3FF),
                                        compact: true,
                                      )
                                    : const Icon(Icons.graphic_eq_rounded),
                              )
                            else
                              IconButton.filled(
                                key: const Key('ai-coach-send-button'),
                                tooltip: tr('Send', 'إرسال'),
                                onPressed: sending ? null : ask,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size.square(46),
                                ),
                                icon: sending
                                    ? const SizedBox.square(
                                        dimension: 19,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_upward_rounded),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(
    IntelligenceMessage message,
    Map<String, bool> feedback,
  ) {
    final canRate =
        message.role == IntelligenceMessageRole.bil &&
        !message.id.startsWith('welcome') &&
        !message.id.startsWith('tool-');
    return _MessageBubble(
      message: message,
      feedbackValue: feedback[message.id],
      onSpeak:
          message.role == IntelligenceMessageRole.bil &&
              message.modality == IntelligenceMessageModality.voice
          ? () {
              final language = const CoachLanguageResolver()
                  .resolve(
                    input: message.text,
                    uiLocale: Localizations.localeOf(context).toLanguageTag(),
                  )
                  .languageTag;
              unawaited(
                _speakCoachText(message.text, language, showFailure: true),
              );
            }
          : null,
      onFeedback: canRate
          ? (helpful) => _recordFeedback(message, helpful)
          : null,
      onReport: canRate
          ? (reason) => _recordFeedback(message, false, reason: reason)
          : null,
    );
  }
}
