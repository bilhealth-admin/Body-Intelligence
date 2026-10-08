import 'package:flutter/material.dart';

/// Route activity uses the same ModalRoute dependency as the existing visible
/// read scope. It also gates the channel controller's presence heartbeat.
/// A covered or background route loses activity immediately; becoming active
/// waits until a rendered frame and rechecks the current visit.
class CommunityChannelActivity extends StatefulWidget {
  const CommunityChannelActivity({
    required this.enabled,
    required this.onChanged,
    required this.child,
    super.key,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  State<CommunityChannelActivity> createState() =>
      _CommunityChannelActivityState();
}

class _CommunityChannelActivityState extends State<CommunityChannelActivity>
    with WidgetsBindingObserver {
  AppLifecycleState? _lifecycle;
  bool _active = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  bool get _visible =>
      mounted &&
      widget.enabled &&
      (_lifecycle == null || _lifecycle == AppLifecycleState.resumed) &&
      ModalRoute.of(context)?.isCurrent != false;

  void _checkActivity() {
    final generation = ++_generation;
    if (!_visible) {
      if (_active) {
        _active = false;
        widget.onChanged(false);
      }
      return;
    }
    if (_active) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation || !_visible || _active) {
        return;
      }
      _active = true;
      widget.onChanged(true);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkActivity();
  }

  @override
  void didUpdateWidget(covariant CommunityChannelActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _checkActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _checkActivity();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    if (_active) widget.onChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
