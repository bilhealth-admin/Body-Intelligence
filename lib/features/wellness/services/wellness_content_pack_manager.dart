import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../commerce/domain/subscription_state.dart';
import '../../commerce/repositories/server_entitlement_repository.dart';
import '../domain/wellness_content_access_policy.dart';
import '../domain/wellness_content_pack.dart';
import 'wellness_media_cache.dart';

typedef WellnessEntitlementLoader = Future<SubscriptionState> Function();

class WellnessContentPackManager {
  WellnessContentPackManager({
    HttpClient? client,
    WellnessMediaCache? mediaCache,
    Directory? packsDirectory,
    WellnessEntitlementLoader? entitlementLoader,
  }) : _client = client ?? HttpClient(),
       _mediaCache = mediaCache ?? WellnessMediaCache(),
       _injectedPacksDirectory = packsDirectory,
       _entitlementLoader =
           entitlementLoader ?? const ServerEntitlementRepository().current;
  static const manifestUrl = String.fromEnvironment(
    'BIL_WELLNESS_MANIFEST_URL',
  );
  static const _maximumManifestBytes = 2 * 1024 * 1024;
  final HttpClient _client;
  final WellnessMediaCache _mediaCache;
  final Directory? _injectedPacksDirectory;
  final WellnessEntitlementLoader _entitlementLoader;

  Future<List<WellnessContentPack>> fetchCatalog() async {
    if (manifestUrl.trim().isEmpty) return const [];
    final manifestUri = Uri.tryParse(manifestUrl.trim());
    if (manifestUri == null ||
        manifestUri.scheme != 'https' ||
        manifestUri.host.isEmpty) {
      throw const FormatException('Wellness catalog URL must use HTTPS.');
    }
    final response = await (await _client.getUrl(manifestUri)).close();
    _requireHttpsRedirects(response);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Catalog returned ${response.statusCode}.');
    }
    final data = jsonDecode(
      await _readUtf8Response(response, maximumBytes: _maximumManifestBytes),
    );
    if (data is! Map<String, dynamic> ||
        (data['schema_version'] != 1 && data['schema_version'] != 2) ||
        data['packs'] is! List) {
      throw const FormatException('Unsupported wellness catalog.');
    }
    final catalogSchema = (data['schema_version'] as num).toInt();
    return (data['packs'] as List).map((e) {
      if (e is! Map<String, dynamic>) {
        throw const FormatException('Invalid wellness catalog entry.');
      }
      return WellnessContentPack.fromJson({
        'schema_version': catalogSchema,
        ...e,
      });
    }).toList();
  }

  Future<List<InstalledWellnessContentPack>> installedPacks() async {
    final file = await _registryFile();
    if (!await file.exists()) return const [];
    final data = jsonDecode(await file.readAsString());
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(InstalledWellnessContentPack.fromJson)
        .toList();
  }

  Future<InstalledWellnessContentPack> install(WellnessContentPack pack) async {
    await _requireAccess(pack.minimumAccess);
    final directory = await _packsDirectory();
    final target = File(
      p.join(directory.path, '${pack.id}-${pack.version}.json'),
    );
    final temporary = File('${target.path}.download');
    if (await temporary.exists()) await temporary.delete();
    final response = await (await _client.getUrl(pack.downloadUrl)).close();
    _requireHttpsRedirects(response);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Pack returned ${response.statusCode}.');
    }
    if (response.contentLength > pack.sizeBytes) {
      throw const FormatException('Wellness pack exceeds declared size.');
    }
    try {
      await _writeExactResponse(response, temporary, pack.sizeBytes);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    if (await temporary.length() != pack.sizeBytes ||
        (await sha256.bind(temporary.openRead()).first).toString() !=
            pack.sha256) {
      await temporary.delete();
      throw const FormatException(
        'Wellness pack integrity verification failed.',
      );
    }
    await _validatePayload(temporary, pack);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
    final installed = InstalledWellnessContentPack(
      id: pack.id,
      version: pack.version,
      path: target.path,
      installedAt: DateTime.now(),
      minimumAccess: pack.minimumAccess,
    );
    final registry = await installedPacks();
    await _writeRegistry([
      ...registry.where((e) => e.id != pack.id),
      installed,
    ]);
    return installed;
  }

  Future<void> _requireAccess(WellnessContentAccess required) async {
    if (required == WellnessContentAccess.free) return;
    SubscriptionState? subscription;
    try {
      subscription = await _entitlementLoader();
    } on Object {
      // Installation is a paid-content boundary. Network/configuration errors
      // fail closed and cannot be converted into local access.
    }
    if (!wellnessContentAccessGranted(required, subscription)) {
      throw StateError('${required.name.toUpperCase()} access is required.');
    }
  }

  Future<void> remove(String id) async {
    final registry = await installedPacks();
    final packsDirectory = await _packsDirectory();
    for (final item in registry.where((e) => e.id == id)) {
      final file = _safeInstalledPackFile(packsDirectory, item);
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const FormatException(
          'Installed wellness pack cannot be a link.',
        );
      }
      if (type == FileSystemEntityType.file) {
        await _removeCachedMedia(file);
        await file.delete();
      }
    }
    await _writeRegistry(registry.where((e) => e.id != id).toList());
  }

  static File _safeInstalledPackFile(
    Directory packsDirectory,
    InstalledWellnessContentPack installed,
  ) {
    final expected = File(
      p.join(
        packsDirectory.absolute.path,
        '${installed.id}-${installed.version}.json',
      ),
    );
    final registered = File(installed.path);
    if (p.normalize(expected.absolute.path) !=
        p.normalize(registered.absolute.path)) {
      throw const FormatException('Unsafe installed wellness pack path.');
    }
    return expected;
  }

  Future<void> _removeCachedMedia(File packFile) async {
    final decoded = jsonDecode(await packFile.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid installed wellness pack.');
    }
    final schemaVersion = (decoded['schema_version'] as num?)?.toInt();
    final typeName = decoded['type'];
    final rawItems = decoded['items'];
    if ((schemaVersion != 1 && schemaVersion != 2) ||
        typeName is! String ||
        rawItems is! List) {
      throw const FormatException('Invalid installed wellness pack.');
    }
    WellnessContentType? type;
    for (final value in WellnessContentType.values) {
      if (value.name == typeName) {
        type = value;
        break;
      }
    }
    if (type == null) {
      throw const FormatException('Invalid installed wellness content type.');
    }
    if (type != WellnessContentType.workouts) return;

    final assets = <String, WellnessMediaAsset>{};
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid installed wellness item.');
      }
      final item = WellnessContentItem.fromJson(
        raw,
        expectedType: type,
        schemaVersion: schemaVersion!,
      );
      final mainImage = item.imageMedia;
      if (mainImage != null) {
        assets['${mainImage.sha256}:${mainImage.mimeType}'] = mainImage;
      }
      final mainVideo = item.videoMedia;
      if (mainVideo != null) {
        assets['${mainVideo.sha256}:${mainVideo.mimeType}'] = mainVideo;
      }
      for (final segment in item.segments) {
        final image = segment.imageMedia;
        assets['${image.sha256}:${image.mimeType}'] = image;
        final video = segment.videoMedia;
        assets['${video.sha256}:${video.mimeType}'] = video;
      }
    }
    for (final asset in assets.values) {
      await _mediaCache.remove(asset);
    }
  }

  /// Reads already verified local packs. No content is streamed silently and
  /// malformed items are ignored instead of being presented as trusted.
  Future<List<Map<String, dynamic>>> loadInstalledItems(
    WellnessContentType type, {
    String? locale,
  }) async {
    final result = <Map<String, dynamic>>[];
    final packsDirectory = await _packsDirectory();
    for (final installed in await installedPacks()) {
      final file = _safeInstalledPackFile(packsDirectory, installed);
      final entityType = await FileSystemEntity.type(
        file.path,
        followLinks: false,
      );
      if (entityType == FileSystemEntityType.notFound) continue;
      if (entityType != FileSystemEntityType.file) {
        throw const FormatException('Installed wellness pack is unsafe.');
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != type.name ||
          decoded['items'] is! List) {
        continue;
      }
      final schemaVersion = (decoded['schema_version'] as num?)?.toInt() ?? 1;
      for (final raw in decoded['items'] as List) {
        if (raw is! Map<String, dynamic>) continue;
        final itemLocale = raw['locale'] as String? ?? 'en';
        if (locale != null && itemLocale != locale && itemLocale != 'all') {
          continue;
        }
        if ((raw['id'] as String? ?? '').trim().isEmpty ||
            (raw['title'] as String? ?? '').trim().isEmpty) {
          continue;
        }
        result.add({
          ...raw,
          '_pack_schema_version': schemaVersion,
          '_pack_minimum_access': installed.minimumAccess.name,
        });
      }
    }
    return result;
  }

  /// Returns only typed, verified, attributable items from installed packs.
  /// Invalid entries fail closed at the item boundary and are never rendered.
  Future<List<WellnessContentItem>> loadTrustedInstalledItems(
    WellnessContentType type, {
    String? locale,
  }) async {
    final trusted = <WellnessContentItem>[];
    for (final raw in await loadInstalledItems(type, locale: locale)) {
      try {
        trusted.add(
          WellnessContentItem.fromJson(
            raw,
            expectedType: type,
            schemaVersion: (raw['_pack_schema_version'] as num?)?.toInt() ?? 1,
          ),
        );
      } on FormatException {
        // A bad item cannot downgrade trust for the rest of a verified pack.
      }
    }
    return trusted;
  }

  Future<void> _validatePayload(File file, WellnessContentPack pack) async {
    final data = jsonDecode(await file.readAsString());
    final schemaVersion = data is Map<String, dynamic>
        ? (data['schema_version'] as num?)?.toInt()
        : null;
    if (data is! Map<String, dynamic> ||
        (schemaVersion != 1 && schemaVersion != 2) ||
        schemaVersion != pack.schemaVersion ||
        data['pack_id'] != pack.id ||
        data['version'] != pack.version ||
        data['type'] != pack.type.name ||
        data['items'] is! List) {
      throw const FormatException('Invalid wellness pack payload.');
    }
    final items = data['items'] as List;
    if (items.length != pack.itemCount) {
      throw const FormatException('Wellness pack item count mismatch.');
    }
    final declaredCategories = <String>{};
    if (schemaVersion == 2 && pack.type == WellnessContentType.workouts) {
      final rawCategories = data['categories'];
      if (rawCategories is! List) {
        throw const FormatException('Workout categories must be declared.');
      }
      declaredCategories.addAll(
        rawCategories
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
      if (declaredCategories.isEmpty ||
          declaredCategories.length != rawCategories.length) {
        throw const FormatException('Workout categories are invalid.');
      }
      if (declaredCategories.length !=
          WorkoutReleaseMediaContract.categoryCount) {
        throw const FormatException(
          'The release workout pack must declare exactly 10 categories.',
        );
      }
      if (items.length != WorkoutReleaseMediaContract.movementVideoCount) {
        throw const FormatException(
          'The release workout pack must contain exactly 200 movement videos.',
        );
      }
    }
    final categoryCounts = <String, int>{};
    final categoryDescriptions = <String, String>{};
    final categoryOrders = <String, int>{};
    final itemIds = <String>{};
    final videoUrls = <Uri>{};
    final videoDigests = <String>{};
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid wellness content item.');
      }
      final item = WellnessContentItem.fromJson(
        raw,
        expectedType: pack.type,
        schemaVersion: schemaVersion!,
      );
      if (schemaVersion == 2 && pack.type == WellnessContentType.workouts) {
        if (!itemIds.add(item.id)) {
          throw const FormatException('Duplicate workout movement id.');
        }
        if (!WorkoutReleaseMediaContract.canonicalMovementId.hasMatch(
              item.id,
            ) ||
            item.durationSeconds !=
                WorkoutReleaseMediaContract.movementDurationSeconds ||
            !WorkoutReleaseMediaContract.hasCanonicalVideoPath(
              item.videoMedia!.url,
              item.id,
            )) {
          throw const FormatException(
            'Workout movement id, duration, or video filename violates the release contract.',
          );
        }
        final category = item.category!;
        if (!declaredCategories.contains(category)) {
          throw const FormatException('Workout uses an undeclared category.');
        }
        categoryCounts.update(
          category,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        final description = item.categoryDescription!;
        final order = item.categoryOrder!;
        final existingDescription = categoryDescriptions[category];
        final existingOrder = categoryOrders[category];
        if ((existingDescription != null &&
                existingDescription != description) ||
            (existingOrder != null && existingOrder != order)) {
          throw const FormatException(
            'Workout category metadata must be consistent.',
          );
        }
        categoryDescriptions[category] = description;
        categoryOrders[category] = order;
        final video = item.videoMedia!;
        if (!videoUrls.add(video.url) || !videoDigests.add(video.sha256)) {
          throw const FormatException('Duplicate workout video media.');
        }
        for (final segment in item.segments) {
          if (!videoUrls.add(segment.videoMedia.url) ||
              !videoDigests.add(segment.videoMedia.sha256)) {
            throw const FormatException('Duplicate workout video media.');
          }
        }
        if (pack.minimumAccess != WellnessContentAccess.free &&
            item.rights?.paid != true) {
          throw const FormatException(
            'Paid workout packs require paid distribution rights.',
          );
        }
      }
    }
    if (declaredCategories.any(
      (category) =>
          (categoryCounts[category] ?? 0) !=
          WorkoutReleaseMediaContract.movementsPerCategory,
    )) {
      throw const FormatException(
        'Every release workout category requires exactly 20 movement videos.',
      );
    }
  }

  Future<Directory> _packsDirectory() async {
    final directory =
        _injectedPacksDirectory ??
        Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'wellness_packs',
          ),
        );
    return directory..createSync(recursive: true);
  }

  Future<File> _registryFile() async =>
      File(p.join((await _packsDirectory()).path, 'installed.json'));
  Future<void> _writeRegistry(List<InstalledWellnessContentPack> packs) async {
    final file = await _registryFile(), temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(packs.map((e) => e.toJson()).toList()),
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  static Future<String> _readUtf8Response(
    HttpClientResponse response, {
    required int maximumBytes,
  }) async {
    if (response.contentLength > maximumBytes) {
      throw const FormatException('Wellness catalog is too large.');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > maximumBytes) {
        throw const FormatException('Wellness catalog is too large.');
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: false);
  }

  static void _requireHttpsRedirects(HttpClientResponse response) {
    for (final redirect in response.redirects) {
      if (redirect.location.scheme != 'https') {
        throw const FormatException(
          'Wellness content redirect must preserve HTTPS.',
        );
      }
    }
  }

  static Future<void> _writeExactResponse(
    HttpClientResponse response,
    File target,
    int expectedBytes,
  ) async {
    final sink = target.openWrite(mode: FileMode.writeOnly);
    var received = 0;
    try {
      await for (final chunk in response) {
        received += chunk.length;
        if (received > expectedBytes) {
          throw const FormatException('Wellness pack exceeds declared size.');
        }
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (received != expectedBytes) {
      if (await target.exists()) await target.delete();
      throw const FormatException('Wellness pack size does not match catalog.');
    }
  }
}
