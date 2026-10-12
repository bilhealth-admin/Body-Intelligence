import 'dart:async';
import 'package:flutter/widgets.dart';
import '../services/meal_voice_session.dart';

class BilMealVoiceSessionPanel extends StatefulWidget {
  const BilMealVoiceSessionPanel({
    super.key,
    required this.session,
    required this.builder,
  });
  final MealVoiceSession session;
  final WidgetBuilder builder;
  @override
  State<BilMealVoiceSessionPanel> createState() =>
      _BilMealVoiceSessionPanelState();
}

class _BilMealVoiceSessionPanelState extends State<BilMealVoiceSessionPanel>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_changed);
    unawaited(widget.session.start());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.session.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_changed);
    unawaited(widget.session.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
