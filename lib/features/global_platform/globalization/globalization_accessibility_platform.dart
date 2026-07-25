import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class GlobalLocaleCatalog {
  const GlobalLocaleCatalog(this.locale, this.messages);
  final String locale;
  final Map<String, String> messages;
}

final class ArbCatalogLoader {
  const ArbCatalogLoader();
  Future<GlobalLocaleCatalog> load(String assetPath, String locale) async {
    final raw =
        jsonDecode(await rootBundle.loadString(assetPath))
            as Map<String, Object?>;
    return GlobalLocaleCatalog(locale, <String, String>{
      for (final entry in raw.entries.where((e) => !e.key.startsWith('@')))
        entry.key: entry.value! as String,
    });
  }
}

final class GlobalizationRuntime {
  GlobalizationRuntime({required this.catalogs, required this.requiredKeys});
  final List<GlobalLocaleCatalog> catalogs;
  final Set<String> requiredKeys;
  List<String> validate() => [
    for (final catalog in catalogs)
      for (final key in requiredKeys)
        if ((catalog.messages[key] ?? '').trim().isEmpty)
          '${catalog.locale}:$key',
  ];
  String text(String locale, String key) =>
      catalogs
          .where((catalog) => catalog.locale == locale)
          .map((catalog) => catalog.messages[key])
          .whereType<String>()
          .firstOrNull ??
      catalogs
          .where((catalog) => catalog.locale == 'en')
          .map((catalog) => catalog.messages[key])
          .whereType<String>()
          .firstOrNull ??
      key;
  double kgToDisplay(double kg, {required bool imperial}) =>
      imperial ? kg * 2.2046226218 : kg;
  double displayToKg(double value, {required bool imperial}) =>
      imperial ? value / 2.2046226218 : value;
  TextDirection direction(String locale) =>
      <String>{'ar', 'fa', 'he', 'ur'}.contains(locale.split('-').first)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

final class AccessibilityPolicy {
  const AccessibilityPolicy({
    this.minimumTouchTarget = 44,
    this.supportsReducedMotion = true,
    this.colorIndependentStatus = true,
    this.maximumTextScale = 2,
  });
  final double minimumTouchTarget, maximumTextScale;
  final bool supportsReducedMotion, colorIndependentStatus;
  bool validate({required double touchTarget, required double textScale}) =>
      touchTarget >= minimumTouchTarget && textScale <= maximumTextScale;
}

final class AccessibleGlobalStatus extends StatelessWidget {
  const AccessibleGlobalStatus({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    excludeSemantics: true,
    label: label,
    value: value,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Center(child: Text('$label: $value')),
        ),
      ),
    ),
  );
}
