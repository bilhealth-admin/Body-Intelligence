import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/app/services/scoped_media_file_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ScopedMediaFileCache cache;
  late HttpClient client;
  Uri photo({String token = '', bool private = false}) => Uri.parse(
    '${AppEnvironment.supabaseUrl}/storage/v1/object/${private ? 'sign/community-post-images' : 'public/profile-avatars'}/a/photo.png',
  ).replace(queryParameters: token.isEmpty ? null : {'token': token});
  String token(int epochSeconds) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': epochSeconds}))).replaceAll('=', '')}.signature';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bil-cache-test-');
    client = HttpClient();
    cache = ScopedMediaFileCache(directory: directory, client: client);
    cache.bindViewer('A');
  });
  tearDown(() async {
    await cache.clear();
    cache.dispose();
    client.close(force: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  });
  Future<File> seed(Uri uri, {String viewer = 'A'}) async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final digest = sha256.convert(bytes).toString();
    final key = ScopedMediaFileCache.identity(uri, viewer);
    final file = File('${directory.path}/${key}_$digest.img');
    await file.writeAsBytes(bytes);
    await File('${directory.path}/$key.json').writeAsString(
      jsonEncode({
        'digest': digest,
        'length': bytes.length,
        'saved': DateTime.now().millisecondsSinceEpoch,
        'path': uri.path,
      }),
    );
    return file;
  }

  test(
    'signed token rotation does not change content identity; owner does',
    () {
      final a = photo(token: 'first', private: true),
          b = photo(token: 'second', private: true);
      expect(
        ScopedMediaFileCache.identity(a, 'A'),
        ScopedMediaFileCache.identity(b, 'A'),
      );
      expect(
        ScopedMediaFileCache.identity(a, 'A'),
        isNot(ScopedMediaFileCache.identity(a, 'B')),
      );
      expect(
        ScopedMediaFileCache.identity(
          a.replace(queryParameters: {'token': 'first', 'width': '320'}),
          'A',
        ),
        isNot(ScopedMediaFileCache.identity(a, 'A')),
      );
    },
  );
  test('wrong host, credential URL and cleartext are never cached', () {
    expect(
      ScopedMediaFileCache.supports(photo().replace(host: 'attacker.invalid')),
      isFalse,
    );
    expect(
      ScopedMediaFileCache.supports(photo().replace(userInfo: 'u:p')),
      isFalse,
    );
    expect(
      ScopedMediaFileCache.supports(photo().replace(scheme: 'http')),
      isFalse,
    );
  });
  test(
    'cached fresh bytes survive cache recreation without starting HTTP',
    () async {
      final uri = photo();
      final expected = await seed(uri);
      final second = ScopedMediaFileCache(directory: directory, client: client)
        ..bindViewer('A');
      expect((await second.peek(uri, 'A'))?.path, expected.path);
      expect(
        (await second.resolve(uri, 'A', current: () => true)).path,
        expected.path,
      );
      second.dispose();
    },
  );
  test('corrupt bytes and another viewer never satisfy a local read', () async {
    final uri = photo();
    final file = await seed(uri);
    expect(await cache.peek(uri, 'B'), isNull);
    await file.writeAsBytes([4, 3, 2, 1]);
    expect(await cache.peek(uri, 'A'), isNull);
  });
  test('private cache requires an unexpired capability and a viewer', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final valid = photo(private: true, token: token(now + 60));
    await seed(valid);
    expect(await cache.peek(valid, 'A'), isNotNull);
    expect(
      await cache.peek(photo(private: true, token: token(now - 60)), 'A'),
      isNull,
    );
    expect(await cache.peek(valid, null), isNull);
  });
  test('account retirement purges previous photos', () async {
    final uri = photo();
    await seed(uri);
    cache.bindViewer('B');
    await cache.clear();
    cache.bindViewer('A');
    await cache.clear();
    expect(await cache.peek(uri, 'A'), isNull);
  });
}
