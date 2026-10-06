import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/community/data/community_repository.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/profile/services/profile_photo_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
final _photo = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10]);

String _session(String owner, {bool expired = false}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': owner, 'exp': expired ? 1600000000 : 4102444800}),
        ),
      )
      .replaceAll('=', '');
  return jsonEncode({
    'access_token': 'e30.$payload.synthetic',
    'refresh_token': 'synthetic-photo-refresh-$owner',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': owner,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'aud': 'authenticated',
      'created_at': '2026-10-06T00:00:00Z',
    },
  });
}

enum _Boundary { refresh, upload, profilePatch }

class _PhotoCloud {
  _PhotoCloud(this.boundary);
  final _Boundary? boundary;
  final entered = Completer<void>();
  final release = Completer<void>();
  int uploads = 0;
  int patches = 0;
  String? savedUrl;

  Future<void> _pause(_Boundary current) async {
    if (boundary != current) return;
    entered.complete();
    await release.future;
  }

  Future<http.Response> handle(http.Request request) async {
    expect(request.url.host, 'profile-photo-entry.invalid');
    Object? response;
    if (request.url.path == '/auth/v1/token') {
      expect(request.url.queryParameters['grant_type'], 'refresh_token');
      await _pause(_Boundary.refresh);
      response = jsonDecode(_session(_ownerA));
    } else if (request.url.path ==
        '/storage/v1/object/profile-avatars/$_ownerA/avatar') {
      expect(request.method, 'POST');
      expect(request.bodyBytes, _photo);
      uploads++;
      await _pause(_Boundary.upload);
      response = {'Key': 'profile-avatars/$_ownerA/avatar'};
    } else if (request.url.path == '/rest/v1/bil_public_profiles') {
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['user_id'], 'eq.$_ownerA');
      expect(request.url.queryParameters['select'], 'avatar_url');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      savedUrl = body['avatar_url'] as String;
      expect(
        savedUrl,
        startsWith(
          'https://profile-photo-entry.invalid/storage/v1/object/public/'
          'profile-avatars/$_ownerA/avatar?v=',
        ),
      );
      patches++;
      await _pause(_Boundary.profilePatch);
      response = {'avatar_url': savedUrl};
    } else {
      throw StateError('Unexpected photo fixture request: ${request.url.path}');
    }
    return http.Response(
      jsonEncode(response),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _PhotoTransport extends http.BaseClient {
  _PhotoTransport(this.cloud);
  final _PhotoCloud cloud;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final normalized = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    if (request is http.MultipartRequest) {
      // Inspect the actual Storage SDK file payload, not its multipart wire
      // envelope. The cloud fixture still asserts the exact original bytes.
      expect(request.files, hasLength(1));
      normalized.bodyBytes = await request.files.single.finalize().toBytes();
    } else {
      normalized.bodyBytes = await request.finalize().toBytes();
    }
    final response = await cloud.handle(normalized);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      request: request,
      headers: response.headers,
    );
  }
}

class _Visit {
  _Visit(this.client) {
    var lastOwner = client.auth.currentUser?.id;
    subscription = client.auth.onAuthStateChange.listen((event) {
      final owner = event.session?.user.id;
      if (owner != lastOwner) current = false;
      lastOwner = owner;
      if (owner == _ownerB && !deliveredB.isCompleted) deliveredB.complete();
      if (owner == _ownerA &&
          deliveredB.isCompleted &&
          !returnedA.isCompleted) {
        returnedA.complete();
      }
    });
  }
  final SupabaseClient client;
  late final StreamSubscription<AuthState> subscription;
  bool current = true;
  final deliveredB = Completer<void>();
  final returnedA = Completer<void>();

  Future<void> roundTrip() async {
    final second = client.auth.recoverSession(_session(_ownerB));
    final first = client.auth.recoverSession(_session(_ownerA));
    await Future.wait([second, first]);
    await Future.wait([
      deliveredB.future,
      returnedA.future,
    ]).timeout(const Duration(seconds: 3));
    expect(client.auth.currentUser?.id, _ownerA);
    expect(current, isFalse);
  }
}

class _DelayedCachePreferences extends PreferencesRepository {
  _DelayedCachePreferences(super.database);
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String?> get(String key) async {
    final value = await super.get(key);
    if (key == 'profilePhotoPublicUrl' && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return value;
  }
}

Future<SupabaseClient> _initialize(_PhotoCloud cloud) async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://profile-photo-entry.invalid',
    publishableKey: 'synthetic-photo-entry-key',
    httpClient: CommunityOwnerHttpClient(_PhotoTransport(cloud)),
    debug: false,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: false,
      detectSessionInUri: false,
      localStorage: EmptyLocalStorage(),
    ),
  );
  addTearDown(() => Supabase.instance.dispose());
  final client = Supabase.instance.client;
  await client.auth.recoverSession(_session(_ownerA));
  return client;
}

AppDatabase _database() {
  final database = AppDatabase.forTesting(
    NativeDatabase.memory(),
    localOwnerId: _ownerA,
  );
  addTearDown(database.close);
  return database;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final boundary in _Boundary.values) {
    test('real photo sync rejects A-B-A during ${boundary.name}', () async {
      final cloud = _PhotoCloud(boundary);
      final client = await _initialize(cloud);
      final visit = _Visit(client);
      addTearDown(visit.subscription.cancel);
      final preferences = PreferencesRepository(_database());
      await preferences.set('profilePhoto', base64Encode(_photo));
      if (boundary == _Boundary.refresh) {
        await client.auth.setInitialSession(_session(_ownerA, expired: true));
      }
      final service = ProfilePhotoService(preferences);
      final operation = CommunityRepository(client).runForCommunityOwner(
        () => service.syncStoredPhotoToCommunity(
          isCurrentOwner: () => visit.current,
        ),
        ownerId: _ownerA,
        isCurrentOwner: () => visit.current,
      );
      final rejected = expectLater(
        operation,
        throwsA(isA<ProfilePhotoIdentityChangedException>()),
      );
      await cloud.entered.future.timeout(const Duration(seconds: 3));
      await visit.roundTrip();
      cloud.release.complete();
      await rejected;
      expect(cloud.uploads, boundary == _Boundary.refresh ? 0 : 1);
      expect(cloud.patches, boundary == _Boundary.profilePatch ? 1 : 0);
      expect(await preferences.get('profilePhoto'), base64Encode(_photo));
      expect(await preferences.get('profilePhotoPublicUrl'), isNull);
    });
  }

  test(
    'same-owner refresh preserves real upload readback and cached retry',
    () async {
      final cloud = _PhotoCloud(_Boundary.profilePatch);
      final client = await _initialize(cloud);
      final visit = _Visit(client);
      addTearDown(visit.subscription.cancel);
      final preferences = PreferencesRepository(_database());
      await preferences.set('profilePhoto', base64Encode(_photo));
      final service = ProfilePhotoService(preferences);
      final operation = CommunityRepository(client).runForCommunityOwner(
        () => service.syncStoredPhotoToCommunity(
          isCurrentOwner: () => visit.current,
        ),
        ownerId: _ownerA,
        isCurrentOwner: () => visit.current,
      );
      await cloud.entered.future.timeout(const Duration(seconds: 3));
      await client.auth.refreshSession();
      expect(visit.current, isTrue);
      cloud.release.complete();
      final result = await operation;
      expect(result?.cloudSynced, isTrue);
      expect(result?.publicUrl, cloud.savedUrl);
      expect(await preferences.get('profilePhotoPublicUrl'), cloud.savedUrl);
      // Existing More callers omit the optional visit predicate. Reusing their
      // successful cache must not upload again or create a new versioned URL.
      final cached = await service.syncStoredPhotoToCommunity();
      expect(cached?.cloudSynced, isTrue);
      expect(cached?.publicUrl, cloud.savedUrl);
      expect(cloud.uploads, 1);
      expect(cloud.patches, 1);
      expect(await preferences.get('profilePhoto'), base64Encode(_photo));
    },
  );

  test(
    'A-B-A during cached URL read cannot report a prior visit synced',
    () async {
      final cloud = _PhotoCloud(null);
      final client = await _initialize(cloud);
      final visit = _Visit(client);
      addTearDown(visit.subscription.cancel);
      final preferences = _DelayedCachePreferences(_database());
      const url = 'https://profile-photo-entry.invalid/already-saved-avatar';
      await preferences.setMany({
        'profilePhoto': base64Encode(_photo),
        'profilePhotoPublicUrl': url,
      });
      final service = ProfilePhotoService(preferences);
      final operation = service.syncStoredPhotoToCommunity(
        isCurrentOwner: () => visit.current,
      );
      final rejected = expectLater(
        operation,
        throwsA(isA<ProfilePhotoIdentityChangedException>()),
      );
      await preferences.entered.future.timeout(const Duration(seconds: 3));
      await visit.roundTrip();
      preferences.release.complete();
      await rejected;
      expect(cloud.uploads, 0);
      expect(cloud.patches, 0);
      expect(await preferences.get('profilePhotoPublicUrl'), url);
      expect(await preferences.get('profilePhoto'), base64Encode(_photo));
    },
  );
}
