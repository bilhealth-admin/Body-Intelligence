import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/nutrition/services/bundled_core_catalog_installer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'same-size installed corruption is repaired from the real verified asset',
    () async {
      final root = await Directory.systemTemp.createTemp('bil_core_integrity_');
      addTearDown(() => root.delete(recursive: true));
      final bytes = await File(
        BundledCoreCatalogInstaller.assetPath,
      ).readAsBytes();
      final bundle = _Asset(bytes);
      final installer = BundledCoreCatalogInstaller(bundle: bundle);
      final file = await installer.ensureInstalled(root);
      final handle = await file.open(mode: FileMode.append);
      await handle.setPosition(0);
      await handle.writeByte(bytes.first ^ 1);
      await handle.close();
      expect(
        await file.length(),
        BundledCoreCatalogInstaller.expectedSizeBytes,
      );
      expect(
        (await sha256.bind(file.openRead()).first).toString(),
        isNot(BundledCoreCatalogInstaller.expectedSha256.toLowerCase()),
      );
      await installer.ensureInstalled(root);
      expect(
        (await sha256.bind(file.openRead()).first).toString(),
        BundledCoreCatalogInstaller.expectedSha256.toLowerCase(),
      );
      expect(bundle.loads, 2);
      await installer.ensureInstalled(root);
      expect(
        bundle.loads,
        2,
        reason: 'A verified existing asset must not be reinstalled.',
      );
      final registry =
          jsonDecode(
                await File('${root.path}/catalog_registry.json').readAsString(),
              )
              as Map<String, dynamic>;
      expect(
        (registry['active'] as Map)['sha256'],
        BundledCoreCatalogInstaller.expectedSha256,
      );
    },
  );

  test(
    'same-size corrupt bundle is rejected without deleting the existing file',
    () async {
      final root = await Directory.systemTemp.createTemp('bil_core_integrity_');
      addTearDown(() => root.delete(recursive: true));
      final bytes = await File(
        BundledCoreCatalogInstaller.assetPath,
      ).readAsBytes();
      bytes[0] ^= 1;
      final installed = File(
        '${root.path}/catalogs/${BundledCoreCatalogInstaller.catalogVersion}/bil_food_core.sqlite',
      );
      await installed.parent.create(recursive: true);
      await installed.writeAsBytes([7, 8, 9]);
      await expectLater(
        BundledCoreCatalogInstaller(
          bundle: _Asset(bytes),
        ).ensureInstalled(root),
        throwsStateError,
      );
      expect(await installed.readAsBytes(), [7, 8, 9]);
      expect(
        await File('${root.path}/catalog_registry.json').exists(),
        isFalse,
      );
      expect(await File('${installed.path}.installing').exists(), isFalse);
    },
  );
}

class _Asset extends CachingAssetBundle {
  _Asset(this.bytes);
  final Uint8List bytes;
  int loads = 0;
  @override
  Future<ByteData> load(String key) async {
    expect(key, BundledCoreCatalogInstaller.assetPath);
    loads++;
    return ByteData.sublistView(bytes);
  }
}
