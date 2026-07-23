import '../domain/food_image.dart';

class FoodImageSelection {
  final FoodImageReference? primary;
  final List<FoodImageReference> images;
  final List<String> rejectedIds;

  const FoodImageSelection({
    required this.primary,
    required this.images,
    required this.rejectedIds,
  });
}

class FoodImagePipeline {
  const FoodImagePipeline();

  FoodImageSelection resolve(
    Iterable<FoodImageReference> candidates, {
    String? preferredLocale,
    int limit = 8,
  }) {
    if (limit <= 0) {
      return const FoodImageSelection(
        primary: null,
        images: <FoodImageReference>[],
        rejectedIds: <String>[],
      );
    }

    final accepted = <FoodImageReference>[];
    final rejected = <String>[];
    final seen = <String>{};

    for (final candidate in candidates) {
      final canonical = _canonical(candidate);
      if (canonical == null) {
        rejected.add(candidate.id);
        continue;
      }
      final identity = canonical.uri.toString().toLowerCase();
      if (!seen.add(identity)) continue;
      accepted.add(canonical);
    }

    accepted.sort((left, right) {
      final primaryOrder = _boolRank(
        right.isPrimary,
      ).compareTo(_boolRank(left.isPrimary));
      if (primaryOrder != 0) return primaryOrder;
      final localeOrder = _localeScore(
        right,
        preferredLocale,
      ).compareTo(_localeScore(left, preferredLocale));
      if (localeOrder != 0) return localeOrder;
      final roleOrder = _roleRank(left.role).compareTo(_roleRank(right.role));
      if (roleOrder != 0) return roleOrder;
      final securityOrder = _boolRank(
        right.isSecureRemote,
      ).compareTo(_boolRank(left.isSecureRemote));
      if (securityOrder != 0) return securityOrder;
      final resolutionOrder = _pixels(right).compareTo(_pixels(left));
      if (resolutionOrder != 0) return resolutionOrder;
      return left.id.compareTo(right.id);
    });

    final selected = List<FoodImageReference>.unmodifiable(
      accepted.take(limit),
    );
    return FoodImageSelection(
      primary: selected.isEmpty ? null : selected.first,
      images: selected,
      rejectedIds: List<String>.unmodifiable(rejected),
    );
  }

  FoodImageReference? _canonical(FoodImageReference image) {
    final scheme = image.uri.scheme.toLowerCase();
    if (scheme != 'https' &&
        scheme != 'http' &&
        scheme != 'file' &&
        scheme != 'asset') {
      return null;
    }
    if ((scheme == 'https' || scheme == 'http') && image.uri.host.isEmpty) {
      return null;
    }
    if (image.id.trim().isEmpty) return null;
    if (image.width != null && image.width! <= 0) return null;
    if (image.height != null && image.height! <= 0) return null;

    return FoodImageReference(
      id: image.id.trim(),
      uri: image.uri.replace(fragment: ''),
      role: image.role,
      source: image.source,
      locale: _nullableTrim(image.locale)?.toLowerCase(),
      width: image.width,
      height: image.height,
      attribution: _nullableTrim(image.attribution),
      isPrimary: image.isPrimary,
    );
  }

  int _localeScore(FoodImageReference image, String? preferredLocale) {
    final preferred = _nullableTrim(preferredLocale)?.toLowerCase();
    if (preferred == null || image.locale == null) return 0;
    if (image.locale == preferred) return 2;
    final preferredLanguage = preferred.split(RegExp('[-_]')).first;
    final imageLanguage = image.locale!.split(RegExp('[-_]')).first;
    return preferredLanguage == imageLanguage ? 1 : 0;
  }

  int _roleRank(FoodImageRole role) => switch (role) {
    FoodImageRole.front => 0,
    FoodImageRole.nutrition => 1,
    FoodImageRole.ingredients => 2,
    FoodImageRole.other => 3,
  };

  int _boolRank(bool value) => value ? 1 : 0;

  int _pixels(FoodImageReference image) =>
      (image.width ?? 0) * (image.height ?? 0);

  String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
