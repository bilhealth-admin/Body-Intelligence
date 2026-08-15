enum CatalogPackAccess { free, plus, pro, coach, clinic, enterprise }

class CatalogPack {
  const CatalogPack({
    required this.id,
    required this.version,
    required this.title,
    required this.downloadUri,
    required this.sha256,
    required this.sizeBytes,
    required this.access,
    this.compression,
    this.installedSizeBytes,
    this.databaseSha256,
    this.localeCodes = const <String>[],
    this.countryCodes = const <String>[],
  });

  final String id;
  final String version;
  final String title;
  final Uri downloadUri;
  final String sha256;
  final int sizeBytes;
  final CatalogPackAccess access;
  final String? compression;
  final int? installedSizeBytes;
  final String? databaseSha256;
  final List<String> localeCodes;
  final List<String> countryCodes;

  factory CatalogPack.fromJson(Map<String, dynamic> json) => CatalogPack(
    id: json['id'] as String,
    version: json['version'] as String,
    title: json['title'] as String,
    downloadUri: Uri.parse(json['download_url'] as String),
    sha256: (json['sha256'] as String).toLowerCase(),
    sizeBytes: json['size_bytes'] as int,
    access: CatalogPackAccess.values.byName(
      (json['access'] as String?) ?? 'pro',
    ),
    compression: json['compression'] as String?,
    installedSizeBytes: json['installed_size_bytes'] as int?,
    databaseSha256: (json['database_sha256'] as String?)?.toLowerCase(),
    localeCodes: List<String>.from(json['locale_codes'] as List? ?? const []),
    countryCodes: List<String>.from(json['country_codes'] as List? ?? const []),
  );
}

class InstalledCatalogPack {
  const InstalledCatalogPack({
    required this.id,
    required this.version,
    required this.path,
    required this.sizeBytes,
    required this.installedAt,
  });

  final String id;
  final String version;
  final String path;
  final int sizeBytes;
  final DateTime installedAt;
}
