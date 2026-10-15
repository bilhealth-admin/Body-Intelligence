import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/bil_pearl_alert_dialog.dart';

enum BilSpeechUse { coach, food, weight, community }

/// A foreground voice decision, separate from microphone and Remote AI consent.
/// Only an explicitly started Coach call can reuse a decision in memory. Its
/// owner/conversation scope and liveness are checked before every new capture.
class BilSystemSpeechDisclosure with WidgetsBindingObserver {
  Object? _liveScope;
  bool Function()? _liveStillCurrent;
  bool _promptOpen = false;
  bool _observing = false;
  int _generation = 0;

  Future<bool> authorize(
    BuildContext context, {
    required BilSpeechUse use,
    Object? liveScope,
    bool Function()? isLiveCurrent,
    bool Function()? isCurrent,
  }) async {
    if (!context.mounted || !_current(isCurrent)) return false;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    if (_promptOpen) return false;
    final live =
        use == BilSpeechUse.coach && liveScope != null && isLiveCurrent != null;
    if (_liveScope != null &&
        (!live || _liveScope != liveScope || !_current(_liveStillCurrent))) {
      resetLive();
    }
    if (live && _liveScope == liveScope && _current(isLiveCurrent)) return true;
    final generation = _generation;
    _promptOpen = true;
    _observe();
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final category = switch (use) {
      BilSpeechUse.coach => 'AI Coach',
      BilSpeechUse.food => arabic ? 'بحث الطعام' : 'food search',
      BilSpeechUse.weight => arabic ? 'إدخال الوزن' : 'weight entry',
      BilSpeechUse.community => arabic ? 'مسودة المجتمع' : 'a Community draft',
    };
    // AR/EN are authored here; other locales deliberately use this complete
    // English disclosure instead of an incomplete or automatic translation.
    final body = arabic
        ? 'لتحويل كلامك إلى نص من أجل $category، يستخدم BIL مزود التعرّف على الكلام المحدد في إعدادات جهاز Android لديك. قد يتضمن صوت الميكروفون معلومات شخصية أو صحية، وقد يعالجه ذلك المزود على خوادمه وفق سياسة خصوصيته. لا يرسل BIL تسجيلات الميكروفون الخام إلى خادمه أو إلى Google Gemini.\n\n'
              'هذه الموافقة لا تفعّل الذكاء الاصطناعي عن بُعد. يتطلب إرسال سؤال المدرب كنص إلى Google Gemini موافقته المنفصلة. يمكنك الرفض والكتابة بدلًا من الصوت، وتغيير إذن الميكروفون من إعدادات النظام.'
        : 'To turn your speech into text for $category, BIL uses the speech recognition provider selected in your Android device settings. Your microphone audio may include personal or health information, and that provider may process it on its servers under its own privacy policy. BIL does not send raw microphone recordings to its backend or to Google Gemini.\n\n'
              'This consent does not enable Remote AI. Sending a Coach question as text to Google Gemini requires its separate consent. You can decline and type instead, and change microphone access in system settings.';
    final duration = live
        ? (arabic
              ? '\n\nيستمر هذا الاختيار لهذه المكالمة حتى إيقافها مؤقتًا أو إنهائها. يطلب بدء مكالمة جديدة موافقتك مجددًا.'
              : '\n\nThis choice lasts for this live call until you pause or end it. Starting a new call asks again.')
        : '';
    try {
      final route = DialogRoute<bool>(
        context: context,
        barrierDismissible: true,
        themes: InheritedTheme.capture(
          from: context,
          to: Navigator.of(context, rootNavigator: true).context,
        ),
        builder: (dialogContext) => BilPearlAlertDialog(
          title: Text(
            arabic
                ? 'معالجة الصوت — $category'
                : 'Voice processing — $category',
          ),
          content: Text(
            '$body$duration',
            key: const Key('system-speech-disclosure-body'),
          ),
          actions: [
            TextButton(
              key: const Key('system-speech-disclosure-decline'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(arabic ? 'الكتابة بدلًا منه' : 'Type instead'),
            ),
            FilledButton(
              key: const Key('system-speech-disclosure-allow'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(arabic ? 'استخدام الصوت الآن' : 'Use voice now'),
            ),
          ],
        ),
      );
      final popped = Navigator.of(context, rootNavigator: true).push(route);
      final accepted = await Future.any<bool?>([
        popped,
        route.completed.then<bool?>((_) => null),
      ]);
      await route.completed;
      if (accepted != true ||
          generation != _generation ||
          !context.mounted ||
          !_current(isCurrent) ||
          (live && !_current(isLiveCurrent))) {
        return false;
      }
      if (live) {
        _liveScope = liveScope;
        _liveStillCurrent = isLiveCurrent;
      }
      return true;
    } on Object {
      return false;
    } finally {
      _promptOpen = false;
      if (_liveScope == null) _unobserve();
    }
  }

  bool _current(bool Function()? check) {
    try {
      return check?.call() ?? true;
    } on Object {
      return false;
    }
  }

  void _observe() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  void _unobserve() {
    if (!_observing) return;
    WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  /// Invalidates both the active call and any pending decision. No preferences,
  /// server entitlement, microphone permission or permanent consent are written.
  void resetLive() {
    _generation++;
    _liveScope = null;
    _liveStillCurrent = null;
    _unobserve();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      resetLive();
    }
  }
}
