import 'dart:io';
import 'dart:typed_data';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/barcode_identity.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/food_barcode_scanner_page.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real product photograph by SchmiAlf, dedicated to the public domain under
/// CC0: https://commons.wikimedia.org/wiki/File:EAN_auf_einer_Teepackung.jpg
const _fixtureUri =
    'https://commons.wikimedia.org/wiki/Special:Redirect/file/'
    'EAN_auf_einer_Teepackung.jpg';
const _fixtureSha256 =
    'd1ddc7452ca5d77a7991aadcb1007795c149ca037bbbb22e2771279e5d5f7c79';
const _expectedGtin = '4012346278001';
// Open Food Facts currently serves "Pfefferminze" while BIL's deployed,
// provider-backed cache can still return the earlier verified spelling
// "Pfefferminz". The immutable product identity remains the GTIN + brand.
const _acceptedProductNames = <String>{'Pfefferminz', 'Pfefferminze'};
const _expectedBrand = 'Lebensbaum';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android photo decode resolves the real product through the live gateway',
    (tester) async {
      expect(
        Platform.isAndroid,
        isTrue,
        reason: 'MobileScannerController.analyzeImage is gated on Android.',
      );

      final fixture = await _loadVerifiedFixture();
      if (fixture.deleteAfterUse) {
        addTearDown(() async {
          if (await fixture.file.exists()) await fixture.file.delete();
        });
      }

      final scanner = MobileScannerController(autoStart: false);
      addTearDown(scanner.dispose);
      final capture = await scanner.analyzeImage(
        fixture.file.path,
        formats: const <BarcodeFormat>[BarcodeFormat.ean13],
      );
      final rawValue = barcodeRawValueFromCapture(capture);

      expect(rawValue, _expectedGtin);
      final identity = BarcodeIdentity.parse(rawValue!);
      expect(identity.isValid, isTrue);
      expect(identity.digits, _expectedGtin);

      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const publicKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      const email = String.fromEnvironment('BIL_BARCODE_GATE_EMAIL');
      const password = String.fromEnvironment('BIL_BARCODE_GATE_PASSWORD');
      expect(supabaseUrl, isNotEmpty, reason: 'Missing SUPABASE_URL define.');
      expect(publicKey, isNotEmpty, reason: 'Missing public key define.');
      expect(email, isNotEmpty, reason: 'Missing transient email define.');
      expect(
        password,
        isNotEmpty,
        reason: 'Missing transient password define.',
      );
      await Supabase.initialize(url: supabaseUrl, publishableKey: publicKey);
      final client = Supabase.instance.client;
      await client.auth.signInWithPassword(email: email, password: password);
      addTearDown(() => client.auth.signOut());

      // The release gate must prove the deployed lookup, never a value left by
      // an earlier emulator session. Clear only BIL's two barcode cache folders
      // inside this integration-test app sandbox before resolving the photo.
      final support = await getApplicationSupportDirectory();
      for (final folder in const <String>[
        'regional_barcode_cache',
        'regional_product_cache',
      ]) {
        final cache = Directory(p.join(support.path, folder));
        if (await cache.exists()) await cache.delete(recursive: true);
      }

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = FoodRepository(database);
      final authority = FoodRuntimeSearchAuthority(
        repository,
        catalogResolver: () async => null,
      );
      final lookup = await authority.lookupBarcodeJourney(rawValue);

      expect(lookup.normalizedBarcode, identity.digits);
      expect(lookup.status, FoodRuntimeBarcodeStatus.found);
      expect(lookup.source, FoodRuntimeSearchSource.catalogAndLocal);
      final product = lookup.foods.single;
      expect(_acceptedProductNames, contains(product.name));
      expect(product.source, 'Open Food Facts');
      expect(
        product.keywords
            .split(',')
            .map((keyword) => keyword.trim().toLowerCase()),
        contains(_expectedBrand.toLowerCase()),
      );
    },
  );
}

Future<({File file, bool deleteAfterUse})> _loadVerifiedFixture() async {
  const injectedPath = String.fromEnvironment('BIL_BARCODE_PHOTO_PATH');
  final File file;
  final deleteAfterUse = injectedPath.isEmpty;
  if (injectedPath.isNotEmpty) {
    file = File(injectedPath);
    if (!await file.exists()) {
      throw StateError('BIL_BARCODE_PHOTO_PATH does not exist: $injectedPath');
    }
  } else {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_fixtureUri));
      request.followRedirects = true;
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'CC0 barcode fixture returned HTTP ${response.statusCode}',
          uri: Uri.parse(_fixtureUri),
        );
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      final directory = await getTemporaryDirectory();
      file = File(p.join(directory.path, 'ean_tea_package_cc0.jpg'));
      await file.writeAsBytes(builder.takeBytes(), flush: true);
    } finally {
      client.close(force: true);
    }
  }

  final digest = sha256.convert(await file.readAsBytes()).toString();
  if (digest != _fixtureSha256) {
    if (deleteAfterUse && await file.exists()) await file.delete();
    throw StateError(
      'CC0 barcode fixture SHA-256 mismatch: expected $_fixtureSha256, '
      'received $digest',
    );
  }
  return (file: file, deleteAfterUse: deleteAfterUse);
}
