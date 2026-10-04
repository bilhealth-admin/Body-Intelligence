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

  static const maximumDownloadBytes = 256 * 1024 * 1024;
  static const maximumInstalledBytes = 512 * 1024 * 1024;

  static bool isSafeComponent(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(value) &&
      !value.contains('..');

  static bool isSecureUri(Uri uri, {bool allowLoopbackHttp = false}) =>
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      (uri.scheme == 'https' ||
          (allowLoopbackHttp &&
              uri.scheme == 'http' &&
              const {'127.0.0.1', '::1'}.contains(uri.host)));

  void validate({bool allowLoopbackHttp = false}) {
    final hash = RegExp(r'^[a-fA-F0-9]{64}$');
    if (!isSafeComponent(id) ||
        !isSafeComponent(version) ||
        title.trim().isEmpty ||
        title.length > 200 ||
        !isSecureUri(downloadUri, allowLoopbackHttp: allowLoopbackHttp) ||
        !hash.hasMatch(sha256) ||
        sizeBytes <= 0 ||
        sizeBytes > maximumDownloadBytes ||
        !const {null, 'gzip'}.contains(compression) ||
        (installedSizeBytes != null &&
            (installedSizeBytes! <= 0 ||
                installedSizeBytes! > maximumInstalledBytes)) ||
        (databaseSha256 != null && !hash.hasMatch(databaseSha256!)) ||
        (compression == 'gzip' &&
            (installedSizeBytes == null || databaseSha256 == null)) ||
        localeCodes.length > 100 ||
        countryCodes.length > 250) {
      throw const FormatException('Invalid or unsafe catalog pack');
    }
  }

  factory CatalogPack.fromJson(Map<String, dynamic> json) {
    final pack = CatalogPack(
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
      countryCodes: List<String>.from(
        json['country_codes'] as List? ?? const [],
      ),
    );
    pack.validate();
    return pack;
  }
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
