import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/bil_semantic_icons.dart';
import '../../../app/services/app_settings_provider.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../data/database/database_provider.dart';
import '../../daily_log/providers/daily_log_provider.dart';
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
import '../services/intelligence_health_context_provider.dart';
import '../services/coach_context_provider.dart';
import '../services/local_coach_api.dart';
import '../services/local_model_gateway.dart';
import '../../nutrition/domain/barcode_identity.dart';
import '../../nutrition/services/bil_speech_to_text.dart';
import '../../nutrition/services/meal_image_analysis_service.dart';
import '../../nutrition/presentation/meal_image_review_dialog.dart';
import '../intelligence_locale_copy.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController tabs;
  final question = TextEditingController();
  final conversationScroll = ScrollController();
  final messages = <IntelligenceMessage>[];
  bool sending = false;
  bool listening = false;
  bool analyzingFoodImage = false;

  bool get arabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
  String tr(String english, String arabicText) =>
      intelligenceText(context, english, arabicText);

  Future<void> _analyzeFoodImageInChat() async {
    if (analyzingFoodImage || sending) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(tr('Take food photo', 'التقط صورة للطعام')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('Choose food photo', 'اختر صورة للطعام')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => analyzingFoodImage = true);
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
    // Conversation is the primary AI Coach surface. The overview remains
    // available, but opening AI Coach must always reveal a usable chat first.
    tabs = TabController(length: 2, initialIndex: 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadConversation();
      if (!mounted) return;
      _applyInitialBarcode(widget.initialBarcode);
      if (widget.startWithVisionCapture) await _analyzeFoodImageInChat();
    });
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

  Future<void> _loadConversation() async {
    final stored = await ref
        .read(preferencesRepositoryProvider)
        .get('intelligenceConversationV1');
    if (!mounted) return;
    final restored = <IntelligenceMessage>[];
    if (stored != null && stored.isNotEmpty) {
      try {
        final decoded = jsonDecode(stored) as List<Object?>;
        for (final value in decoded.whereType<Map>()) {
          restored.add(
            _presentationSafeMessage(
              IntelligenceMessage.fromJson(Map<String, Object?>.from(value)),
            ),
          );
        }
      } catch (_) {
        restored.clear();
      }
    }
    setState(() {
      messages
        ..clear()
        ..addAll(restored);
      if (messages.isEmpty) {
        messages.add(
          IntelligenceMessage(
            id: 'welcome',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: tr(
              'I am BIL. I explain what I know, expose what I do not know, and never execute an action without your approval.',
              'أنا BIL. أشرح ما أعرفه، أوضح ما لا أعرفه، ولا أنفذ إجراءً دون موافقتك.',
            ),
            createdAt: DateTime.now(),
            evidence: const <String>['local-intelligence-platform'],
            confidence: .8,
          ),
        );
      }
    });
    _scrollToLatest(jump: true);
  }

  void _scrollToLatest({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !conversationScroll.hasClients) return;
      final target = conversationScroll.position.maxScrollExtent;
      if (jump) {
        conversationScroll.jumpTo(target);
      } else {
        conversationScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _saveConversation() async {
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .set(
            'intelligenceConversationV1',
            jsonEncode(messages.map((item) => item.toJson()).toList()),
          );
    } on Object {
      // Conversation persistence is best-effort. A local storage failure must
      // not escape an unawaited save and terminate an otherwise valid reply.
    }
  }

  Future<void> _clearConversation() async {
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .remove('intelligenceConversationV1');
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'The local conversation could not be cleared. Your data was unchanged.',
              'تعذر مسح المحادثة المحلية. لم تتغير بياناتك.',
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      messages
        ..clear()
        ..add(
          IntelligenceMessage(
            id: 'welcome-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: tr(
              'I am BIL. I use your recorded data and explain the reason, confidence, and what is missing. I do not diagnose or make changes without your approval.',
              'أنا BIL. أفهم بياناتك المسجلة، وأشرح السبب والثقة وما ينقصني. لا أشخّص ولا أنفّذ أي تغيير دون موافقتك.',
            ),
            createdAt: DateTime.now(),
            evidence: const <String>['Body Twin', 'Truth Engine'],
            confidence: .8,
          ),
        );
    });
    unawaited(_saveConversation());
  }

  Future<void> _speakQuestion() async {
    if (listening || sending) return;
    final speech = SpeechToText();
    var transcript = '';
    var failed = false;
    StateSetter? refresh;
    setState(() => listening = true);
    try {
      final available = await speech.initialize(
        onError: (_) {
          failed = true;
          refresh?.call(() {});
        },
      );
      if (!available || !mounted) {
        if (mounted) _showVoiceUnavailable();
        return;
      }
      final interfaceLocale = BilLocalePolicy.canonicalTag(
        Localizations.localeOf(context),
      );
      final previousUserMessage = messages.reversed
          .where((message) => message.role == IntelligenceMessageRole.user)
          .map((message) => message.text.trim())
          .where((text) => text.isNotEmpty)
          .firstOrNull;
      final spokenLanguageHint = previousUserMessage == null
          ? interfaceLocale
          : const CoachLanguageResolver()
                .resolve(input: previousUserMessage, uiLocale: interfaceLocale)
                .languageTag;
      final requested = spokenLanguageHint
          .toLowerCase()
          .split(RegExp('[-_]'))
          .first;
      final locales = await speech.locales();
      final locale = locales
          .where((item) => item.localeId.toLowerCase().startsWith(requested))
          .map((item) => item.localeId)
          .firstOrNull;
      if (locale == null || !mounted) {
        if (mounted) _showVoiceUnavailable();
        return;
      }
      await speech.listen(
        onResult: (result) {
          transcript = result.recognizedWords;
          refresh?.call(() {});
        },
        listenOptions: SpeechListenOptions(
          localeId: locale,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 4),
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
          // Android 14+ can detect/switch spoken language independently from
          // the BIL interface language. The selected locale remains only the
          // recognizer's fallback on older devices.
          autoDetectLanguage: true,
          allowedLocaleIds: BilLocalePolicy.productionTags.toList(
            growable: false,
          ),
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            refresh = setDialogState;
            return AlertDialog(
              icon: Icon(
                failed ? Icons.mic_off_outlined : Icons.graphic_eq_rounded,
              ),
              title: Text(tr('Talk to AI Coach', 'تحدث إلى AI Coach')),
              content: Text(
                failed
                    ? tr(
                        'Speech recognition stopped. Close this dialog and type your question, or try another spoken language.',
                        'توقف التعرف على الكلام. أغلق هذه النافذة واكتب سؤالك، أو جرّب لغة كلام أخرى.',
                      )
                    : transcript.trim().isEmpty
                    ? tr('Listening…', 'أنا أستمع…')
                    : transcript,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    transcript = '';
                    Navigator.pop(dialogContext);
                  },
                  child: Text(tr('Cancel', 'إلغاء')),
                ),
                FilledButton(
                  onPressed: failed
                      ? () => Navigator.pop(dialogContext)
                      : transcript.trim().isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(
                    failed
                        ? tr('Close', 'إغلاق')
                        : tr('Use text', 'استخدام النص'),
                  ),
                ),
              ],
            );
          },
        ),
      );
      refresh = null;
      if (failed && transcript.trim().isEmpty && mounted) {
        _showVoiceUnavailable();
      }
      if (mounted && transcript.trim().isNotEmpty) {
        question.text = transcript.trim();
        await ask(inputChannel: CoachInputChannel.voice);
      }
    } on Object {
      if (mounted) _showVoiceUnavailable();
    } finally {
      try {
        await speech.stop();
      } on Object {
        // The plugin can report an unavailable recognizer while stopping.
        // The localized UI message above is the only user-facing failure.
      }
      if (mounted) setState(() => listening = false);
    }
  }

  void _showVoiceUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'Voice input is unavailable right now. You can type and send your question.',
            'تعذر تشغيل الإدخال الصوتي الآن. يمكنك كتابة سؤالك وإرساله.',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tabs.dispose();
    question.dispose();
    conversationScroll.dispose();
    super.dispose();
  }

  Future<void> ask({
    CoachInputChannel inputChannel = CoachInputChannel.text,
  }) async {
    final text = question.text.trim();
    if (text.isEmpty || sending) return;
    final localeCode = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    setState(() {
      sending = true;
      messages.add(
        IntelligenceMessage(
          id: 'user-${DateTime.now().microsecondsSinceEpoch}',
          role: IntelligenceMessageRole.user,
          kind: IntelligenceMessageKind.freeQuestion,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      question.clear();
    });
    _scrollToLatest();
    unawaited(_saveConversation());
    try {
      IntelligenceHealthContext? healthContext;
      try {
        healthContext = await ref.read(
          intelligenceHealthContextProvider.future,
        );
      } catch (_) {
        healthContext = null;
      }
      LocalCoachApi localApi = const DeterministicLocalCoachApi();
      late final CoachContextSnapshot coachContext;
      try {
        coachContext = await ref.read(coachContextSnapshotProvider.future);
      } on Object {
        // Missing or temporarily unavailable personal context is represented
        // explicitly as empty. It must not silently disable the signed-in AI
        // Coach or cause generic questions to bypass its usage ledger.
        coachContext = CoachContextSnapshot.empty();
      }
      localApi = ModelBackedLocalCoachApi(
        gateway: createLocalModelGateway(),
        context: coachContext,
      );
      final activeEngine = IntelligenceCenterEngine(localApi: localApi);
      final reply = await activeEngine.answer(
        question: text,
        arabic: arabic,
        localeCode: localeCode,
        healthContext: healthContext,
        coachContext: coachContext,
        inputChannel: inputChannel,
      );
      if (!mounted) return;
      setState(() => messages.add(_presentationSafeMessage(reply.message)));
      _scrollToLatest();
      unawaited(_saveConversation());
      final spokenReply = reply.spokenText?.trim();
      if (inputChannel == CoachInputChannel.voice &&
          spokenReply != null &&
          spokenReply.isNotEmpty) {
        final spokenLocale = const CoachLanguageResolver()
            .resolve(input: spokenReply, uiLocale: localeCode)
            .languageTag;
        try {
          await const BilTextToSpeech().speak(spokenReply, spokenLocale);
        } on Object {
          // The full written answer is already visible and authoritative.
          // A local TTS failure must not turn a successful AI reply into an
          // error or cause the metered request to be retried.
        }
      }
      if (reply.actions.isNotEmpty && mounted) {
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) =>
              _ActionSheet(actions: reply.actions, onAction: _executeAction),
        );
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        messages.add(
          IntelligenceMessage(
            id: 'coach-error-${DateTime.now().microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.safety,
            text: tr(
              'AI Coach could not prepare your context. Your data was not changed; try again.',
              'تعذر تجهيز سياق AI Coach الآن. لم تتغير بياناتك؛ أعد المحاولة.',
            ),
            createdAt: DateTime.now(),
            evidence: const ['local-coach-runtime'],
            confidence: 1,
          ),
        );
      });
      _scrollToLatest();
      unawaited(_saveConversation());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  IntelligenceMessage _presentationSafeMessage(IntelligenceMessage message) {
    if (message.role == IntelligenceMessageRole.user) return message;
    final normalized = message.text.toLowerCase();
    const technicalMarkers = <String>[
      'local-coach-runtime',
      'ai context is not accepted',
      'decision memory evidence',
      'safety boundary did not approve',
      'bil did not expose an action',
      'accepted ai context',
      'source summary is required',
      'one best action output',
    ];
    if (!technicalMarkers.any(normalized.contains)) return message;
    return IntelligenceMessage(
      id: message.id,
      role: message.role,
      kind: IntelligenceMessageKind.safety,
      text: tr(
        'AI Coach could not complete this reply. Your data was not changed; try again.',
        'تعذر إكمال هذا الرد الآن. لم تتغير بياناتك؛ أعد المحاولة.',
      ),
      createdAt: message.createdAt,
      confidence: 1,
    );
  }

  Future<void> _executeAction(IntelligenceAction action) async {
    try {
      if (action.requiresConfirmation && !await _confirmAction(action)) {
        return;
      }
      if (!mounted) return;
      switch (action.type) {
        case IntelligenceActionType.navigate:
          final target = action.payload['target']?.toString();
          final path = target == null
              ? null
              : const BilNavigationRegistry().resolve(target);
          if (path == null) return;
          context.go(path);
        case IntelligenceActionType.readNutritionRemaining:
          final snapshot = await ref.read(coachContextSnapshotProvider.future);
          final remaining = snapshot.nutritionRemainingFor(DateTime.now());
          if (remaining == null) return;
          if (mounted) {
            _showActionCompleted(
              tr(
                'Remaining today: ${remaining['caloriesKcal']!.round()} kcal, ${remaining['proteinG']!.round()} g protein, ${remaining['carbsG']!.round()} g carbs, ${remaining['fatG']!.round()} g fat.',
                'المتبقي اليوم: ${remaining['caloriesKcal']!.round()} سعرة، ${remaining['proteinG']!.round()} غ بروتين، ${remaining['carbsG']!.round()} غ كربوهيدرات، ${remaining['fatG']!.round()} غ دهون.',
              ),
            );
          }
        case IntelligenceActionType.readProfileIdentity:
          final snapshot = await ref.read(coachContextSnapshotProvider.future);
          final name = snapshot.minimalIdentity['displayName']?.toString();
          if (mounted) {
            _showActionCompleted(
              name == null
                  ? tr(
                      'No profile name is saved.',
                      'لا يوجد اسم محفوظ في الملف الشخصي.',
                    )
                  : tr('Profile name: $name', 'اسم الملف الشخصي: $name'),
            );
          }
        case IntelligenceActionType.openDailyLog:
          final requested = action.payload['action']?.toString();
          const supportedActions = {
            'barcode',
            'voice',
            'photo',
            'water',
            'notes',
            'exercise',
          };
          final safeAction = supportedActions.contains(requested)
              ? requested
              : null;
          context.go(
            Uri(
              path: '/daily-log',
              queryParameters: safeAction == null
                  ? null
                  : {'action': safeAction},
            ).toString(),
          );
        case IntelligenceActionType.addWater:
          final amount = action.payload['amountMl'];
          if (amount is! int) return;
          final entityId = await ref
              .read(waterRepositoryProvider)
              .add(occurredAt: DateTime.now(), amountMl: amount);
          final receipt = BilActionReceipt(
            actionId: action.id,
            committed: entityId > 0,
            completedAt: DateTime.now(),
            entityType: 'water_entry',
            entityId: entityId.toString(),
            refreshTargets: const {'dailyWater', 'dashboard', 'coachContext'},
          );
          if (mounted && receipt.verified) {
            _showActionCompleted(
              tr('Water logged locally.', 'تم تسجيل الماء محليًا.'),
            );
          }
        case IntelligenceActionType.addWeight:
          final value = action.payload['weightKg'];
          if (value is! num) {
            context.go('/daily-check-in');
            return;
          }
          final requestedDate = action.payload['date']?.toString();
          final occurredAt = requestedDate == null
              ? DateTime.now()
              : DateTime.tryParse(requestedDate);
          if (occurredAt == null) return;
          final entityId = await ref
              .read(weightRepositoryProvider)
              .addWeight(
                value.toDouble(),
                date: occurredAt,
                measurementContext: 'differentConditions',
              );
          final receipt = BilActionReceipt(
            actionId: action.id,
            committed: entityId > 0,
            completedAt: DateTime.now(),
            entityType: 'weight_entry',
            entityId: entityId.toString(),
            refreshTargets: const {
              'weightHistory',
              'progress',
              'dashboard',
              'coachContext',
            },
          );
          if (mounted && receipt.verified) {
            _showActionCompleted(
              tr('Weight logged locally.', 'تم تسجيل الوزن محليًا.'),
            );
          }
        case IntelligenceActionType.reviewMeal:
          final dayOffset = action.payload['dayOffset'];
          if (dayOffset is int && dayOffset != 0) {
            ref.read(selectedLogDateProvider.notifier).state = DateTime.now()
                .add(Duration(days: dayOffset));
          }
          context.go('/daily-log?focus=meal');
        case IntelligenceActionType.reviewWorkout:
          context.push('/wellness/workouts/log');
        case IntelligenceActionType.openPlan:
          context.go('/plan');
        case IntelligenceActionType.openReport:
          context.go('/analytics');
        case IntelligenceActionType.manageSubscription:
          context.push('/plans');
        case IntelligenceActionType.setThemeMode:
          final mode = action.payload['mode']?.toString();
          if (!const {'dark', 'light', 'system'}.contains(mode)) return;
          await ref.read(appSettingsProvider.notifier).setThemeMode(mode!);
          if (mounted) {
            _showActionCompleted(tr('Appearance updated.', 'تم تحديث المظهر.'));
          }
        case IntelligenceActionType.setLanguage:
          final locale = BilLocalePolicy.canonicalSupportedTag(
            action.payload['locale']?.toString(),
          );
          if (locale == null) return;
          await ref.read(appSettingsProvider.notifier).setLocale(locale);
          if (mounted) {
            _showActionCompleted(tr('Language updated.', 'تم تحديث اللغة.'));
          }
        case IntelligenceActionType.updateGoal:
          final target = action.payload['targetWeightKg'];
          if (target is! num) return;
          final profile = await ref.read(userProfileProvider.future);
          if (profile == null) return;
          final existing = await ref.read(activeGoalProvider.future);
          final targetDate = action.payload['targetDate'] == null
              ? null
              : DateTime.tryParse(action.payload['targetDate'].toString());
          final type = target < profile.currentWeight
              ? 'lose'
              : target > profile.currentWeight
              ? 'gain'
              : 'maintain';
          final entityId = await ref.read(databaseProvider).transaction(
            () async {
              await ref
                  .read(userProfileRepositoryProvider)
                  .save(
                    gender: profile.gender,
                    age: profile.age,
                    height: profile.height,
                    currentWeight: profile.currentWeight,
                    targetWeight: target.toDouble(),
                    activityLevel: profile.activityLevel,
                    exercises: profile.exercises,
                    medicalConditions: profile.medicalConditions,
                    waist: profile.waist,
                    neck: profile.neck,
                    chest: profile.chest,
                    arm: profile.arm,
                    thigh: profile.thigh,
                  );
              return ref
                  .read(goalRepositoryProvider)
                  .save(
                    uuid: existing?.uuid,
                    profileUuid: profile.uuid,
                    type: type,
                    targetWeight: target.toDouble(),
                    targetDate: targetDate,
                  );
            },
          );
          ref.invalidate(userProfileProvider);
          ref.invalidate(activeGoalProvider);
          if (mounted && entityId > 0) {
            _showActionCompleted(tr('Goal updated.', 'تم تحديث الهدف.'));
          }
        case IntelligenceActionType.saveMeasurements:
          double? measurement(String key) =>
              (action.payload[key] as num?)?.toDouble();
          final requestedDate = action.payload['date']?.toString();
          final date = requestedDate == null
              ? DateTime.now()
              : DateTime.tryParse(requestedDate);
          if (date == null) return;
          await ref
              .read(bodyMeasurementRepositoryProvider)
              .saveForDay(
                date: date,
                neckCm: measurement('neckCm'),
                waistCm: measurement('waistCm'),
                hipsCm: measurement('hipsCm'),
                chestCm: measurement('chestCm'),
                armCm: measurement('armCm'),
                thighCm: measurement('thighCm'),
              );
          ref.invalidate(bodyMeasurementHistoryProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted) {
            _showActionCompleted(
              tr('Measurements updated.', 'تم تحديث القياسات.'),
            );
          }
        case IntelligenceActionType.quickAddMacros:
          final date = action.payload['date'] == null
              ? DateTime.now()
              : DateTime.tryParse(action.payload['date'].toString());
          if (date == null) return;
          final entityId = await ref
              .read(mealRepositoryProvider)
              .addQuickMacroEntry(
                date: date,
                mealType: action.payload['mealType']!.toString(),
                calories: (action.payload['calories']! as num).toDouble(),
                protein: (action.payload['protein']! as num).toDouble(),
                carbohydrates: (action.payload['carbohydrates']! as num)
                    .toDouble(),
                fat: (action.payload['fat']! as num).toDouble(),
                caloriesKnown: true,
                proteinKnown: true,
                carbohydratesKnown: true,
                fatKnown: true,
              );
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted && entityId > 0) {
            _showActionCompleted(tr('Meal updated.', 'تم تحديث الوجبة.'));
          }
        case IntelligenceActionType.updateMealItem:
          await ref
              .read(mealRepositoryProvider)
              .updateMealItem(
                id: action.payload['itemId']! as int,
                quantity: (action.payload['quantityGrams']! as num).toDouble(),
              );
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted) {
            _showActionCompleted(
              tr('Meal item updated.', 'تم تحديث عنصر الوجبة.'),
            );
          }
        case IntelligenceActionType.deleteMealItem:
          await ref
              .read(mealRepositoryProvider)
              .deleteMealItem(action.payload['itemId']! as int);
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted) {
            _showActionCompleted(
              tr('Meal item deleted.', 'تم حذف عنصر الوجبة.'),
            );
          }
        case IntelligenceActionType.moveMealItem:
          await ref
              .read(mealRepositoryProvider)
              .moveMealItemToType(
                id: action.payload['itemId']! as int,
                mealType: action.payload['mealType']!.toString(),
              );
          ref.invalidate(dailyMealsProvider);
          ref.invalidate(coachContextSnapshotProvider);
          if (mounted) {
            _showActionCompleted(tr('Meal item moved.', 'تم نقل عنصر الوجبة.'));
          }
        case IntelligenceActionType.requestAccountDeletion:
          context.push('/community/profile');
        case IntelligenceActionType.saveMemory:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  'This action requires confirmation and a repository write before execution.',
                  'يتطلب هذا الإجراء تأكيدًا وربطًا بمخزن البيانات قبل التنفيذ.',
                ),
              ),
            ),
          );
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'The action was not completed. Your data stayed unchanged; review the value and try again.',
              'لم يُنفذ الإجراء. بقيت بياناتك دون تغيير؛ راجع القيمة وحاول مجددًا.',
            ),
          ),
        ),
      );
    }
  }

  Future<bool> _confirmAction(IntelligenceAction action) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          action.destructive
              ? BilSemanticIcons.deleteAccount
              : _iconForAction(action.type),
          color: action.destructive
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text(tr('Confirm action', 'تأكيد الإجراء')),
        content: Text(action.label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Continue', 'متابعة')),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
    if (!action.destructive || !mounted) return true;
    return _confirmDestructiveAction(action);
  }

  Future<bool> _confirmDestructiveAction(IntelligenceAction action) async {
    final controller = TextEditingController();
    try {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              icon: Icon(
                BilSemanticIcons.deleteAccount,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(tr('Final confirmation', 'التأكيد النهائي')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.label),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      'Type DELETE to continue. This confirmation cannot be supplied by AI Coach.',
                      'اكتب حذف للمتابعة. لا يستطيع المدرب الذكي تقديم هذا التأكيد نيابةً عنك.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: tr('Confirmation word', 'كلمة التأكيد'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(tr('Cancel', 'إلغاء')),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    Navigator.pop(
                      dialogContext,
                      value == 'DELETE' || value == 'حذف',
                    );
                  },
                  child: Text(tr('Confirm', 'تأكيد')),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      controller.dispose();
    }
  }

  void _showActionCompleted(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void usePrompt(String value) {
    tabs.animateTo(1);
    question.text = value;
    ask();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('BIL AI Coach', 'مدرب BIL الذكي')),
        actions: [
          IconButton(
            tooltip: tr('Clear local conversation', 'مسح المحادثة المحلية'),
            onPressed: messages.isEmpty ? null : _clearConversation,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
        bottom: TabBar(
          controller: tabs,
          tabs: [
            Tab(
              icon: const Icon(Icons.auto_awesome_rounded),
              text: tr('AI Coach', 'المدرب الذكي'),
            ),
            Tab(
              icon: const Icon(Icons.chat_bubble_outline),
              text: tr('Ask BIL', 'اسأل BIL'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabs,
        children: [
          _CoachOverview(onPrompt: usePrompt),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: conversationScroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: messages[index]),
                ),
              ),
              _QuickQuestions(onSelected: usePrompt),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('ai-coach-food-image-button'),
                        tooltip: tr('Analyze a food photo', 'حلّل صورة طعام'),
                        onPressed: analyzingFoodImage || sending
                            ? null
                            : _analyzeFoodImageInChat,
                        icon: analyzingFoodImage
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_a_photo_outlined),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          key: const Key('ai-coach-question-field'),
                          controller: question,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onTap: _scrollToLatest,
                          onSubmitted: (_) => ask(),
                          onChanged: (value) {
                            if (!sending && value.endsWith('\n')) {
                              question.value = TextEditingValue(
                                text: value.trimRight(),
                                selection: TextSelection.collapsed(
                                  offset: value.trimRight().length,
                                ),
                              );
                              unawaited(ask());
                            }
                          },
                          decoration: InputDecoration(
                            hintText: tr(
                              'Ask about your body, food, or progress...',
                              'اسأل عن جسمك أو غذائك أو تقدمك...',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        key: const Key('ai-coach-voice-button'),
                        tooltip: tr('Talk to AI Coach', 'تحدث إلى AI Coach'),
                        onPressed: listening || sending ? null : _speakQuestion,
                        icon: Icon(
                          listening
                              ? Icons.graphic_eq_rounded
                              : Icons.mic_rounded,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        key: const Key('ai-coach-send-button'),
                        onPressed: sending ? null : ask,
                        icon: sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
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
        ],
      ),
    );
  }
}

class _CoachOverview extends StatelessWidget {
  const _CoachOverview({required this.onPrompt});
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final prompts = <String>[
      intelligenceText(
        context,
        'Analyze my weight plateau',
        'حلل سبب ثبات وزني',
      ),
      intelligenceText(
        context,
        'Is my protein enough today?',
        'هل بروتيني كافٍ اليوم؟',
      ),
      intelligenceText(
        context,
        'What is my best action now?',
        'ما أفضل خطوة لي الآن؟',
      ),
      intelligenceText(context, 'Review my food day', 'راجع يومي الغذائي'),
      intelligenceText(context, 'What data is missing?', 'ماذا ينقص بياناتي؟'),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          intelligenceText(
            context,
            'How can AI Coach help?',
            'كيف يساعدك AI Coach؟',
          ),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          intelligenceText(
            context,
            'It surfaces observations from your data, explains why, and proposes an action for your approval.',
            'يعرض ملاحظات مبنية على بياناتك، يشرح السبب، ويقترح إجراءً بعد موافقتك.',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          intelligenceText(context, 'Try now', 'جرّب الآن'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (final prompt in prompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton.tonalIcon(
              onPressed: () => onPrompt(prompt),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(prompt),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              intelligenceText(
                context,
                'Important: full external conversation and body-context integration are not complete, so BIL will not present a personal plan before that connection is finished.',
                'مهم: الربط الكامل بالمحادثة الخارجية وبكل سياق جسمك ما زال غير مكتمل، لذلك لن يعرض BIL خطة شخصية قبل اكتمال هذا الربط.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickQuestions extends StatelessWidget {
  const _QuickQuestions({required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final prompts = <String>[
      intelligenceText(context, 'Ask about my body', 'اسأل عن جسمي'),
      intelligenceText(context, 'Why is my weight stable?', 'لماذا وزني ثابت؟'),
      intelligenceText(context, 'What should I eat now?', 'ماذا آكل الآن؟'),
      intelligenceText(context, 'Build me a plan', 'اعمل لي خطة'),
      intelligenceText(context, 'Review my day', 'راجع يومي'),
    ];

    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          label: Text(prompts[index]),
          onPressed: () => onSelected(prompts[index]),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final IntelligenceMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == IntelligenceMessageRole.user;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: user ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text),
            if (!user) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  key: Key('ai-coach-speak-${message.id}'),
                  visualDensity: VisualDensity.compact,
                  tooltip: intelligenceText(
                    context,
                    'Listen to response',
                    'استمع إلى الرد',
                  ),
                  onPressed: () async {
                    try {
                      final uiTag = Localizations.localeOf(
                        context,
                      ).toLanguageTag();
                      final spokenLocale = const CoachLanguageResolver()
                          .resolve(input: message.text, uiLocale: uiTag)
                          .languageTag;
                      await const BilTextToSpeech().speak(
                        _compactSpokenCoachReply(message.text),
                        spokenLocale,
                      );
                    } on Object {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            intelligenceText(
                              context,
                              'A voice for this language is unavailable on this device.',
                              'الصوت غير متاح لهذه اللغة على الجهاز.',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _compactSpokenCoachReply(String detailedReply) {
  final plain = detailedReply
      .replaceAll(RegExp(r'[`*_#>]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (plain.length <= 140) return plain;
  final sentenceEnd = RegExp(r'[.!?؟。]').firstMatch(plain);
  if (sentenceEnd != null && sentenceEnd.end >= 24 && sentenceEnd.end <= 140) {
    return plain.substring(0, sentenceEnd.end).trim();
  }
  return '${plain.substring(0, 137).trimRight()}…';
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.actions, required this.onAction});

  final List<IntelligenceAction> actions;
  final ValueChanged<IntelligenceAction> onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            intelligenceText(context, 'Suggested actions', 'إجراءات مقترحة'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final action in actions)
            ListTile(
              leading: Icon(_iconForAction(action.type)),
              title: Text(action.label),
              subtitle: Text(
                action.requiresConfirmation
                    ? intelligenceText(
                        context,
                        'Requires your confirmation',
                        'يتطلب تأكيدك',
                      )
                    : '',
              ),
              onTap: () {
                Navigator.pop(context);
                onAction(action);
              },
            ),
        ],
      ),
    );
  }
}

IconData _iconForAction(IntelligenceActionType type) => switch (type) {
  IntelligenceActionType.navigate => Icons.navigation_outlined,
  IntelligenceActionType.readNutritionRemaining => Icons.pie_chart_outline,
  IntelligenceActionType.readProfileIdentity => Icons.person_outline,
  IntelligenceActionType.openDailyLog => BilSemanticIcons.diary,
  IntelligenceActionType.addWater => BilSemanticIcons.water,
  IntelligenceActionType.addWeight => BilSemanticIcons.weight,
  IntelligenceActionType.reviewMeal => BilSemanticIcons.meal,
  IntelligenceActionType.reviewWorkout => BilSemanticIcons.workout,
  IntelligenceActionType.openPlan => Icons.route_outlined,
  IntelligenceActionType.openReport => BilSemanticIcons.insights,
  IntelligenceActionType.manageSubscription => BilSemanticIcons.subscription,
  IntelligenceActionType.setThemeMode => Icons.contrast_rounded,
  IntelligenceActionType.setLanguage => Icons.language_rounded,
  IntelligenceActionType.updateGoal => Icons.flag_outlined,
  IntelligenceActionType.saveMeasurements => Icons.straighten_outlined,
  IntelligenceActionType.quickAddMacros => BilSemanticIcons.meal,
  IntelligenceActionType.updateMealItem => Icons.edit_outlined,
  IntelligenceActionType.moveMealItem => Icons.drive_file_move_outline,
  IntelligenceActionType.deleteMealItem => Icons.delete_outline_rounded,
  IntelligenceActionType.requestAccountDeletion =>
    BilSemanticIcons.deleteAccount,
  IntelligenceActionType.saveMemory => Icons.bookmark_add_outlined,
};
