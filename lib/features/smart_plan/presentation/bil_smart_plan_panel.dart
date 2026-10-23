import 'package:flutter/material.dart';
import '../../../app/theme/bil_pearl_finish.dart';

/// The Coach Overview's panel finish, clipping and transparent ink surface.
/// Scoped to Smart Plan; never installs a theme on unrelated app routes.
class BilSmartPlanPanel extends StatelessWidget {
  const BilSmartPlanPanel({super.key, required this.child, this.margin});
  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    clipBehavior: Clip.antiAlias,
    decoration: BilPearlFinish.panel(context),
    child: Material(type: MaterialType.transparency, child: child),
  );
}
