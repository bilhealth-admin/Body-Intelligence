enum FoodImageRole { front, nutrition, ingredients, other }

enum FoodImageSource { openFoodFacts, remote, local, generated }

class FoodImageReference {
  final String id;
  final Uri uri;
  final FoodImageRole role;
  final FoodImageSource source;
  final String? locale;
  final int? width;
  final int? height;
  final String? attribution;
  final bool isPrimary;

  const FoodImageReference({
    required this.id,
    required this.uri,
    required this.role,
    required this.source,
    this.locale,
    this.width,
    this.height,
    this.attribution,
    this.isPrimary = false,
  });

  bool get isRemote => uri.scheme == 'https' || uri.scheme == 'http';
  bool get isSecureRemote => uri.scheme == 'https';
}
