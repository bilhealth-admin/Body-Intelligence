import 'runtime_copy_primary.dart';
import 'runtime_copy_secondary.dart';
import 'runtime_copy_workouts.dart';
import 'runtime_copy_small_features.dart';
import 'runtime_copy_extended.dart';

/// Reviewed runtime copy used by legacy call-sites that still pass an English
/// sentence instead of a typed key. Every entry is complete in the five
/// production languages; missing entries fail debug and release audits.
abstract final class RuntimeCopy {
  static const supported = <String>{
    'ar',
    'en',
    'fr',
    'es',
    'tr',
    ...ExtendedRuntimeCopy.supported,
  };

  static const values = <String, Map<String, String>>{
    ...RuntimeCopyPrimary.values,
    ...RuntimeCopySecondary.values,
    ...RuntimeCopyWorkouts.values,
    ...RuntimeCopySmallFeatures.values,
  };

  static String? resolve(String english, String localeTag) {
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    for (final tag in ExtendedRuntimeCopy.supported) {
      if (tag.toLowerCase() == normalized) {
        return ExtendedRuntimeCopy.values[english]?[tag];
      }
    }
    final language = normalized.split('-').first;
    final base = values[english]?[language];
    if (base != null) return base;
    final matches = ExtendedRuntimeCopy.supported
        .where(
          (tag) =>
              tag.toLowerCase() == language ||
              tag.toLowerCase().startsWith('$language-'),
        )
        .toList(growable: false);
    if (matches.length == 1) {
      return ExtendedRuntimeCopy.values[english]?[matches.single];
    }
    return null;
  }

  static bool get balanced {
    const base = <String>{'ar', 'en', 'fr', 'es', 'tr'};
    return values.values.every(
          (translations) =>
              translations.keys.toSet().containsAll(base) &&
              base.containsAll(translations.keys),
        ) &&
        values.keys.every(ExtendedRuntimeCopy.values.containsKey) &&
        ExtendedRuntimeCopy.values.values.every(
          (translations) =>
              translations.keys.toSet().containsAll(
                ExtendedRuntimeCopy.supported,
              ) &&
              ExtendedRuntimeCopy.supported.containsAll(translations.keys),
        );
  }
}
