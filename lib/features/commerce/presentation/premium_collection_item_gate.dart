import 'package:flutter/material.dart';

import 'premium_label_badge.dart';

/// Keeps paid collection content visible as a real preview while preventing
/// every interaction with it until the verified subscription is active.
class PremiumCollectionItemGate extends StatelessWidget {
  const PremiumCollectionItemGate({
    required this.locked,
    required this.tier,
    required this.onUpgrade,
    required this.child,
    super.key,
  });

  final bool locked;
  final String tier;
  final VoidCallback onUpgrade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(absorbing: true, child: ExcludeSemantics(child: child)),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xB8DBA936), width: 1.2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x08000000), Color(0x52000000)],
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('premium-collection-upgrade'),
            onTap: onUpgrade,
            borderRadius: BorderRadius.circular(18),
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: PremiumLabelBadge(semanticLabel: tier),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
