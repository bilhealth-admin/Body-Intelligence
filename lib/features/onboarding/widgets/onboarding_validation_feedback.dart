import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps a validation message beside the actions. Large accessibility text
/// remains scrollable in its own visible panel without moving the form/focus.
class OnboardingValidationFeedback extends StatefulWidget {
  const OnboardingValidationFeedback({super.key, required this.child});

  final Widget child;

  @override
  State<OnboardingValidationFeedback> createState() =>
      _OnboardingValidationFeedbackState();
}

class _OnboardingValidationFeedbackState
    extends State<OnboardingValidationFeedback> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(
            48,
            (media.size.height -
                    media.viewInsets.bottom -
                    media.viewPadding.vertical) *
                .35,
          ),
        ),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            key: const Key('onboarding-validation-feedback'),
            primary: false,
            controller: _scrollController,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
