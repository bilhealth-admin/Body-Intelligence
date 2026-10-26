import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../integration_test/native_feature_splashes_test.dart'
    as native_qa;
import '../../../test_driver/native_capture_transport.dart';
import 'native_capture_manifest.dart';

const _device = '12345678-1234-1234-1234-123456789abc';
const _container = 'abcdefab-1234-1234-1234-123456789abc';
const _name = 'bil39-community-en-light-1x-sent';
const _external =
    '/storage/emulated/0/Android/data/com.bilhealth.bodyintelligencelog/files';
const _documents =
    '/Users/qa/Library/Developer/CoreSimulator/Devices/$_device/data/'
    'Containers/Data/Application/$_container/Documents';

class _Paths extends PathProviderPlatform {
  String? external = _external;
  String documents = _documents;
  int externalReads = 0;
  int documentReads = 0;

  @override
  Future<String?> getExternalStoragePath() async {
    externalReads++;
    return external;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    documentReads++;
    return documents;
  }
}

NativeCaptureManifest capture(Directory output, String platform) =>
    NativeCaptureManifest.fromPng(
      name: _name,
      platform: platform,
      nativePath: '${output.path}/$_name.png',
      bytes: image.encodePng(image.Image(width: 3, height: 2)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PathProviderPlatform previous;
  late _Paths paths;
  setUp(() {
    previous = PathProviderPlatform.instance;
    paths = _Paths();
    PathProviderPlatform.instance = paths;
  });
  tearDown(() => PathProviderPlatform.instance = previous);

  test(
    'Android producer selects the root accepted by the unchanged collector',
    () async {
      paths.documents =
          '/data/user/0/com.bilhealth.bodyintelligencelog/app_flutter';
      final output = await native_qa.nativeQaCaptureDirectory(
        android: true,
        create: false,
      );
      expect(output.path, '$_external/feature-splashes-native');
      expect(paths.externalReads, 1);
      expect(paths.documentReads, 0);
      validateNativeCapturePath(
        capture(output, 'android'),
        deviceId: 'emulator-5554',
      );
    },
  );

  test(
    'iOS producer retains its selected simulator Documents directory',
    () async {
      final output = await native_qa.nativeQaCaptureDirectory(
        android: false,
        create: false,
      );
      expect(paths.documentReads, 1);
      expect(paths.externalReads, 0);
      validateNativeCapturePath(capture(output, 'ios'), deviceId: _device);
    },
  );

  test(
    'unavailable Android storage fails without private-directory fallback',
    () async {
      paths.external = null;
      await expectLater(
        native_qa.nativeQaCaptureDirectory(android: true, create: false),
        throwsStateError,
      );
      expect(paths.documentReads, 0);
    },
  );

  test(
    'foreign Android provider output remains rejected before collection',
    () async {
      paths.external = '/storage/emulated/0/Android/data/other.app/files';
      final output = await native_qa.nativeQaCaptureDirectory(
        android: true,
        create: false,
      );
      expect(
        () => validateNativeCapturePath(
          capture(output, 'android'),
          deviceId: 'emulator-5554',
        ),
        throwsStateError,
      );
    },
  );

  test(
    'normal creation writes only the owned QA output subdirectory',
    () async {
      final root = await Directory.systemTemp.createTemp('bil-native-output-');
      paths.documents = root.path;
      try {
        final output = await native_qa.nativeQaCaptureDirectory(android: false);
        expect(output.parent.path, root.path);
        expect(output.path, '${root.path}/feature-splashes-native');
        expect(await output.exists(), isTrue);
        expect(paths.externalReads, 0);
      } finally {
        final temporaryPrefix =
            '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}';
        if (!root.absolute.path.startsWith(temporaryPrefix)) {
          throw StateError(
            'Native QA cleanup escaped its owned temporary root',
          );
        }
        await root.delete(recursive: true);
      }
    },
  );
}
