import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/services/wellness_content_pack_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'paid pack install fails closed before download without verified access',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bil-wellness-access-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final manager = WellnessContentPackManager(
        packsDirectory: directory,
        entitlementLoader: () async => FreePlan.createState(),
      );

      await expectLater(
        manager.install(_paidPack),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('PRO access is required'),
          ),
        ),
      );
      expect(directory.listSync(), isEmpty);
    },
  );

  test('paid pack request carries the current Supabase bearer', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bil-wellness-bearer-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final client = _RecordingHttpClient();
    final manager = WellnessContentPackManager(
      client: client,
      packsDirectory: directory,
      entitlementLoader: () async => SubscriptionState(
        plan: CommercePlan.premium,
        entitlements: const {},
        authority: EntitlementAuthority.verifiedServer,
        currentPeriodEndsAt: DateTime.now().toUtc().add(
          const Duration(days: 1),
        ),
        isPurchasable: true,
        canRestorePurchases: true,
      ),
      accessTokenLoader: () => ' signed-session-token ',
    );

    await expectLater(
      manager.install(_paidPack),
      throwsA(isA<HttpException>()),
    );

    expect(client.requests, 1);
    expect(client.authorization, 'Bearer signed-session-token');
    expect(client.followRedirects, isFalse);
  });
}

final _paidPack = WellnessContentPack(
  id: 'bil-workouts-pro-v2',
  version: 1,
  type: WellnessContentType.workouts,
  title: 'Verified Pro workouts',
  description: 'Server-controlled licensed workout catalog.',
  locale: 'en',
  downloadUrl: Uri.parse(
    'https://workouts.bilhealth.com/v2/objects/workouts/v2/packs/pro-v2.json',
  ),
  sizeBytes: 128,
  sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  itemCount: 100,
  minimumAccess: WellnessContentAccess.pro,
  schemaVersion: 2,
  publisher: 'BIL Health',
  sourceUrl: Uri.parse('https://bilhealth.com/workouts'),
  licenseName: 'BIL licensed content',
  licenseUrl: Uri.parse('https://bilhealth.com/licenses/workouts'),
);

class _RecordingHttpClient implements HttpClient {
  int requests = 0;
  _RecordingHttpHeaders? lastRequestHeaders;
  _RecordingHttpClientRequest? lastRequest;

  String? get authorization =>
      lastRequestHeaders?.value(HttpHeaders.authorizationHeader);
  bool? get followRedirects => lastRequest?.followRedirects;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests += 1;
    final headers = _RecordingHttpHeaders();
    lastRequestHeaders = headers;
    final request = _RecordingHttpClientRequest(headers);
    lastRequest = request;
    return request;
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingHttpClientRequest implements HttpClientRequest {
  _RecordingHttpClientRequest(this.headers);

  @override
  final HttpHeaders headers;

  @override
  bool followRedirects = true;

  @override
  Future<HttpClientResponse> close() async =>
      const _NotFoundHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NotFoundHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  const _NotFoundHttpClientResponse();

  @override
  int get statusCode => HttpStatus.notFound;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<List<int>>.empty().listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingHttpHeaders implements HttpHeaders {
  final Map<String, String> _values = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = value.toString();
  }

  @override
  String? value(String name) => _values[name.toLowerCase()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
