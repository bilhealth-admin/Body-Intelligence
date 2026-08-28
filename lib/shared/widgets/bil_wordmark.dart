import 'package:flutter/material.dart';

/// Canonical body-free launch badge used across native and Flutter startup.
class BilLaunchBadge extends StatelessWidget {
  const BilLaunchBadge({super.key, this.diameter = 184});

  final double diameter;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'BIL, trademark',
    child: ExcludeSemantics(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: TextDirection.ltr,
          children: [
            Text(
              'BIL',
              style: TextStyle(
                color: Color(0xFF050505),
                fontSize: diameter * .30,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: diameter * .012,
              ),
            ),
            Text(
              '\u2122',
              style: TextStyle(
                color: Color(0xFF050505),
                fontSize: diameter * .10,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

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
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Body Intelligence Log, trademark',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: height * 8.8,
          height: height,
          child: Align(
            alignment: alignment,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _WordmarkLockup(
                height: height,
                color: color ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full product wordmark used on the dashboard and authentication surfaces.
class BilFullWordmark extends StatelessWidget {
  const BilFullWordmark({
    super.key,
    this.height = 32,
    this.alignment = Alignment.center,
  });

  final double height;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Body Intelligence Log, trademark',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Align(
            alignment: alignment,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _WordmarkLockup(
                height: height,
                color: Theme.of(context).colorScheme.onSurface,
              ),
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
            fontSize: height * .54,
            height: 1.08,
            fontWeight: FontWeight.w600,
            letterSpacing: height * .014,
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
              fontSize: height * .34,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
