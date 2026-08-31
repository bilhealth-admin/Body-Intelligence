import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real barcode photo and live product gates remain source-closed', () {
    final native = File(
      'integration_test/real_barcode_photo_integration_test.dart',
    ).readAsStringSync();
    final live = File(
      'tool/nutrition/run_live_real_barcode_photo_product_e2e.ps1',
    ).readAsStringSync();

    expect(native, contains('MobileScannerController'));
    expect(native, contains('.analyzeImage('));
    expect(
      native,
      contains(
        'd1ddc7452ca5d77a7991aadcb1007795c149ca037bbbb22e2771279e5d5f7c79',
      ),
    );
    expect(native, contains("const _expectedGtin = '4012346278001'"));
    expect(
      native,
      contains(
        "const _acceptedProductNames = <String>{'Pfefferminz', 'Pfefferminze'}",
      ),
    );
    expect(
      native,
      contains('expect(_acceptedProductNames, contains(product.name))'),
    );
    expect(native, contains('BarcodeIdentity.parse(rawValue!)'));
    expect(native, contains('lookupBarcodeJourney(rawValue)'));
    expect(native, contains('AppDatabase.forTesting(NativeDatabase.memory())'));
    expect(native, contains('catalogResolver: () async => null'));
    expect(native, isNot(contains('_expectedProductName')));
    expect(native, isNot(contains('expect(product.name,')));
    expect(native, contains("expect(product.source, 'Open Food Facts')"));
    expect(native, contains('contains(_expectedBrand.toLowerCase())'));
    expect(native, contains('await Supabase.initialize('));
    expect(native, isNot(contains('.addFood(')));

    expect(live, contains("[string]\$SupabaseCli = 'G:\\BIL_Toolchains\\"));
    expect(
      live,
      contains(
        "[string]\$FlutterExe = 'G:\\BIL_Toolchains\\Flutter\\flutter\\bin\\flutter.bat'",
      ),
    );
    expect(
      live,
      contains('integration_test/real_barcode_photo_integration_test.dart'),
    );
    expect(live, contains('--dart-define-from-file=\$definePath'));
    expect(live, contains("SUPABASE_URL = \$baseUrl"));
    expect(live, contains('BIL_BARCODE_GATE_EMAIL = \$email'));
    expect(live, contains('BIL_BARCODE_GATE_PASSWORD = \$password'));
    expect(live, contains('\$password = "Bil!\$('));
    expect(live, contains('Set-StrictMode -Version Latest'));
    expect(live, contains("'plan:premium'"));
    expect(live, contains('insert into public.bil_entitlements'));
    expect(live, contains('delete from public.bil_entitlements'));
    expect(live, contains('/auth/v1/admin/users/\$userId'));
    expect(
      live,
      contains('Remove-Item -LiteralPath \$resolvedCleanup -Recurse -Force'),
    );
    expect(live, contains("SetEnvironmentVariable('TEMP', \$tempDirectory"));
    expect(live, contains("SetEnvironmentVariable('TMP', \$tempDirectory"));
    expect(live, contains("SetEnvironmentVariable('TEMP', \$originalTemp"));
    expect(live, contains("SetEnvironmentVariable('TMP', \$originalTmp"));
    expect(live, isNot(contains("gtin = '4012346278001'")));
    expect(live, isNot(contains('npx --yes')));
    expect(live, isNot(contains('bil_put_cached_barcode')));
    expect(live, isNot(contains('BIL controlled barcode fixture')));
  });
}
