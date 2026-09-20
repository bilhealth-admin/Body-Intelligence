import 'package:flutter/material.dart';

/// Canonical BIL product wordmark for every identity-bearing surface.
/// BIL uses the trademark symbol (™), never the registered symbol (®).
class BilWordmark extends StatelessWidget {
  const BilWordmark({
    super.key,
    this.height = 54,
    this.alignment = Alignment.center,
    this.color,
  });

  final double height;
  final AlignmentGeometry alignment;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      BilFullWordmark(height: height, alignment: alignment, color: color);
}

/// Full product wordmark used on the dashboard and authentication surfaces.
class BilFullWordmark extends StatelessWidget {
  const BilFullWordmark({
    super.key,
    this.height = 32,
    this.alignment = Alignment.center,
    this.color,
  });

  final double height;
  final AlignmentGeometry alignment;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFF7FAFC)
            : const Color(0xFF050505));
    return Semantics(
      label: 'Body Intelligence Log',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Align(
            alignment: alignment,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _WordmarkLockup(height: height, color: resolvedColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _WordmarkLockup extends StatelessWidget {
  const _WordmarkLockup({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BODY INTELLIGENCE LOG',
          textDirection: TextDirection.ltr,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontFamily: 'BILDisplay',
            fontSize: height * .48,
            height: 1.06,
            fontWeight: FontWeight.w800,
            letterSpacing: height * .008,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: height * .065, top: height * .005),
          child: Text(
            '™',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: color,
              // The former 0.22 lockup made the trademark disappear on phone
              // dashboards and the launch frame. Keep it subordinate to the
              // wordmark, but large enough to survive rasterisation and common
              // Android display scaling.
              fontFamily: 'BILDisplay',
              fontSize: height * .30,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
