import 'package:flutter/material.dart';

final class BilAccessibleStatus extends StatelessWidget {
  const BilAccessibleStatus({
    super.key,
    required this.label,
    required this.detail,
    required this.status,
    required this.onActivate,
  });
  final String label, detail, status;
  final VoidCallback onActivate;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      button: true,
      label: '$label. $detail. $status',
      onTap: onActivate,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onActivate,
            child: AnimatedContainer(
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(status),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class GlobalAccessibilityGate {
  const GlobalAccessibilityGate();
  bool supportsScale(double factor) => factor >= 1 && factor <= 2.5;
  bool touchTarget(Size size) => size.width >= 48 && size.height >= 48;
  bool colorIndependent({required String label, required IconData? icon}) =>
      label.trim().isNotEmpty || icon != null;
  TextDirection directionFor(String locale) =>
      locale.startsWith('ar') ? TextDirection.rtl : TextDirection.ltr;
}
