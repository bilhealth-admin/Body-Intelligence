import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../commerce/domain/subscription_state.dart';
import '../../commerce/repositories/server_entitlement_repository.dart';
import '../domain/workout_release_catalog_item.dart';
import '../domain/wellness_content_access_policy.dart';
import '../domain/wellness_content_pack.dart';
import '../repositories/workout_discovery_catalog_repository.dart';
import '../repositories/workout_discovery_localizer.dart';
import '../repositories/workout_release_catalog_repository.dart';
import 'wellness_access_token.dart';
import 'wellness_media_cache.dart';
import 'workout_release_verifier.dart';

typedef WellnessEntitlementLoader = Future<SubscriptionState> Function();
typedef WorkoutReleaseCatalogLoader =
    Future<List<WorkoutReleaseCatalogItem>> Function();
typedef WorkoutDiscoveryCatalogLoader =
    Future<List<WellnessContentItem>> Function();
typedef WorkoutDiscoveryLocalizerLoader =
    Future<WorkoutDiscoveryLocalizer> Function(
      List<WellnessContentItem> discovery,
    );

class WellnessContentPackManager {
  WellnessContentPackManager({
    HttpClient? client,
    WellnessMediaCache? mediaCache,
    Directory? packsDirectory,
    WellnessEntitlementLoader? entitlementLoader,
    WorkoutReleaseCatalogLoader? workoutReleaseLoader,
    WorkoutDiscoveryCatalogLoader? workoutDiscoveryLoader,
    WorkoutDiscoveryLocalizerLoader? workoutDiscoveryLocalizerLoader,
    WellnessAccessTokenLoader? accessTokenLoader,
  }) : _client = client ?? HttpClient(),
       _mediaCache = mediaCache ?? WellnessMediaCache(),
       _injectedPacksDirectory = packsDirectory,
       _entitlementLoader =
           entitlementLoader ?? const ServerEntitlementRepository().current,
       _workoutReleaseLoader =
           workoutReleaseLoader ?? const WorkoutReleaseCatalogRepository().load,
       _injectedWorkoutDiscoveryLoader = workoutDiscoveryLoader,
       _injectedWorkoutDiscoveryLocalizerLoader =
           workoutDiscoveryLocalizerLoader,
       _accessTokenLoader = accessTokenLoader ?? loadCurrentWellnessAccessToken;
  static const manifestUrl = String.fromEnvironment(
    'BIL_WELLNESS_MANIFEST_URL',
  );
  static const _maximumManifestBytes = 2 * 1024 * 1024;
  final HttpClient _client;
  final WellnessMediaCache _mediaCache;
  final Directory? _injectedPacksDirectory;
  final WellnessEntitlementLoader _entitlementLoader;
  final WorkoutReleaseCatalogLoader _workoutReleaseLoader;
  final WorkoutDiscoveryCatalogLoader? _injectedWorkoutDiscoveryLoader;
  final WorkoutDiscoveryLocalizerLoader?
  _injectedWorkoutDiscoveryLocalizerLoader;
  final WellnessAccessTokenLoader _accessTokenLoader;
  Future<List<WellnessContentItem>>? _workoutDiscoveryCache;
  Future<WorkoutDiscoveryLocalizer>? _workoutDiscoveryLocalizerCache;

  WorkoutReleaseVerifier get _workoutReleaseVerifier =>
      WorkoutReleaseVerifier(_workoutReleaseLoader);

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
    final request = await _client.getUrl(pack.downloadUrl);
    request.followRedirects = false;
    applyWellnessBearer(request, _accessTokenLoader, pack.downloadUrl);
    final response = await request.close();
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
    await _workoutReleaseVerifier.validatePayload(temporary, pack);
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
    final approvedWorkoutBundles = type == WellnessContentType.workouts
        ? await _workoutReleaseVerifier.approvedRelease()
        : null;
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
          decoded['pack_id'] != installed.id ||
          decoded['version'] != installed.version ||
          decoded['type'] != type.name ||
          decoded['items'] is! List) {
        continue;
      }
      final schemaVersion = (decoded['schema_version'] as num?)?.toInt() ?? 1;
      if (type == WellnessContentType.workouts &&
          (decoded['schema_version'] is! int ||
              decoded['schema_version'] != 2)) {
        continue;
      }
      final approvedWorkouts = approvedWorkoutBundles?[installed.id];
      for (final raw in decoded['items'] as List) {
        if (raw is! Map<String, dynamic>) continue;
        if (type == WellnessContentType.workouts) {
          if (schemaVersion != 2) continue;
          final approval = approvedWorkouts?[raw['id']];
          if (approval == null ||
              !WorkoutReleaseVerifier.rawWorkoutMatchesApproval(
                raw,
                approval,
              )) {
            continue;
          }
        }
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
          '_pack_id': installed.id,
          '_pack_version': installed.version,
          '_pack_schema_version': schemaVersion,
          '_pack_minimum_access': installed.minimumAccess.name,
          if (type == WellnessContentType.workouts) ...{
            '_release_bundle_id': approvedWorkouts![raw['id']]!.bundleId,
            '_release_key': approvedWorkouts[raw['id']]!.releaseKey,
            '_primary_plan_group_id':
                approvedWorkouts[raw['id']]!.primaryGroupId,
            '_plan_group_ids': approvedWorkouts[raw['id']]!.planGroupIds,
          },
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

  /// Returns all 302 redacted discovery cards before any paid pack is
  /// installed, then substitutes only locally verified version-1 pack records
  /// with the same bundle-scoped stable identity.
  ///
  /// Loading this list is metadata-only: it never requests an MP4 and it does
  /// not bypass [install]'s server-verified PRO entitlement boundary.
  Future<List<WellnessContentItem>> loadWorkoutLibraryItems({
    String? locale,
  }) async {
    final discovery = await _loadWorkoutDiscovery();
    if (discovery.length != WorkoutDiscoveryCatalogRepository.itemCount) {
      throw const FormatException('Workout discovery catalog is incomplete.');
    }

    final allStableIds = <String>{};
    final merged = <String, WellnessContentItem>{};
    for (final item in discovery) {
      if (item.type != WellnessContentType.workouts ||
          item.releaseKey == null ||
          item.minimumAccess != WellnessContentAccess.pro ||
          item.instructions.isNotEmpty ||
          item.steps.isNotEmpty ||
          item.segments.isNotEmpty ||
          !allStableIds.add(item.stableId)) {
        throw const FormatException('Workout discovery item is invalid.');
      }
      if (_matchesWorkoutLocale(item.locale, locale)) {
        merged[item.stableId] = item;
      }
    }

    final installedByPack = <String, List<Map<String, dynamic>>>{};
    for (final raw in await loadInstalledItems(WellnessContentType.workouts)) {
      final packId = raw['_pack_id'];
      final packVersion = raw['_pack_version'];
      if (packId is! String ||
          packVersion is! int ||
          WorkoutDiscoveryCatalogRepository.releasePackVersions[packId] !=
              packVersion ||
          raw['_pack_minimum_access'] != WellnessContentAccess.pro.name) {
        continue;
      }
      installedByPack.putIfAbsent(packId, () => []).add(raw);
    }

    final installedStableIds = <String>{};
    for (final entry in installedByPack.entries) {
      final packId = entry.key;
      final expectedCount =
          WorkoutDiscoveryCatalogRepository.releasePackItemCounts[packId];
      final expectedBundle =
          WorkoutDiscoveryCatalogRepository.releaseBundleIds[packId];
      if (expectedCount == null ||
          expectedBundle == null ||
          entry.value.length != expectedCount) {
        continue;
      }
      final installedItems = <String, WellnessContentItem>{};
      var validPack = true;
      for (final raw in entry.value) {
        try {
          final item = WellnessContentItem.fromJson(
            raw,
            expectedType: WellnessContentType.workouts,
            schemaVersion: 2,
          );
          if (item.releaseBundleId != expectedBundle ||
              installedItems[item.stableId] != null) {
            validPack = false;
            break;
          }
          installedItems[item.stableId] = item;
        } on FormatException {
          validPack = false;
          break;
        }
      }
      final expectedStableIds = discovery
          .where((item) => item.releaseBundleId == expectedBundle)
          .map((item) => item.stableId)
          .toSet();
      if (!validPack ||
          installedItems.length != expectedCount ||
          expectedStableIds.length != expectedCount ||
          !installedItems.keys.toSet().containsAll(expectedStableIds)) {
        continue;
      }
      for (final item in installedItems.values) {
        if (!_matchesWorkoutLocale(item.locale, locale)) continue;
        if (!merged.containsKey(item.stableId) ||
            !installedStableIds.add(item.stableId)) {
          throw const FormatException(
            'Installed workout discovery override is invalid.',
          );
        }
        merged[item.stableId] = item;
      }
    }
    final items = List<WellnessContentItem>.unmodifiable(merged.values);
    final localeTag = locale == null
        ? 'en'
        : BilLocalePolicy.canonicalSupportedTag(locale);
    if (localeTag == null) {
      throw FormatException('Unsupported workout discovery locale: $locale.');
    }
    if (localeTag == 'en') return items;
    final localizer = await _loadWorkoutDiscoveryLocalizer(discovery);
    return List.unmodifiable(
      items.map((item) => localizer.localize(item, localeTag)),
    );
  }

  Future<List<WellnessContentItem>> _loadWorkoutDiscovery() {
    final cached = _workoutDiscoveryCache;
    if (cached != null) return cached;
    final future = _loadWorkoutDiscoveryOnce();
    _workoutDiscoveryCache = future;
    future.catchError((Object _) {
      if (identical(_workoutDiscoveryCache, future)) {
        _workoutDiscoveryCache = null;
      }
      return <WellnessContentItem>[];
    });
    return future;
  }

  Future<List<WellnessContentItem>> _loadWorkoutDiscoveryOnce() async {
    final injected = _injectedWorkoutDiscoveryLoader;
    if (injected != null) return injected();
    final source = await rootBundle.loadString(
      WorkoutDiscoveryCatalogRepository.assetPath,
    );
    final approvedRelease = await _workoutReleaseLoader();
    return const WorkoutDiscoveryCatalogRepository().parse(
      source,
      approvedRelease,
    );
  }

  Future<WorkoutDiscoveryLocalizer> _loadWorkoutDiscoveryLocalizer(
    List<WellnessContentItem> discovery,
  ) {
    final cached = _workoutDiscoveryLocalizerCache;
    if (cached != null) return cached;
    final future = _loadWorkoutDiscoveryLocalizerOnce(discovery);
    _workoutDiscoveryLocalizerCache = future;
    future.catchError((Object error) {
      if (identical(_workoutDiscoveryLocalizerCache, future)) {
        _workoutDiscoveryLocalizerCache = null;
      }
      throw error;
    });
    return future;
  }

  Future<WorkoutDiscoveryLocalizer> _loadWorkoutDiscoveryLocalizerOnce(
    List<WellnessContentItem> discovery,
  ) async {
    final injected = _injectedWorkoutDiscoveryLocalizerLoader;
    if (injected != null) return injected(discovery);
    return WorkoutDiscoveryLocalizer.fromDiscovery(discovery);
  }

  static bool _matchesWorkoutLocale(String itemLocale, String? requested) =>
      requested == null ||
      itemLocale == requested ||
      itemLocale == 'all' ||
      itemLocale == 'en';

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
