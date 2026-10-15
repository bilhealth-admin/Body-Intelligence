part of 'native_feature_splashes_test.dart';

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
  Directory output,
) async {
  if (!isNativeCaptureName(name)) {
    throw StateError('Unexpected native screenshot label');
  }
  binding.reportData ??= <String, dynamic>{};
  final previous = binding.reportData![nativeCaptureManifestKey];
  final captures = previous == null
      ? <NativeCaptureManifest>[]
      : readNativeCaptureManifest(previous);
  if (captures.any((capture) => capture.name == name)) {
    throw StateError('Duplicate native screenshot label');
  }
  // Preserve fresh compositor frames, original resolution, and original bytes.
  // These frames remain outside the separately measured welcome timer.
  for (var frame = 0; frame < 3; frame++) {
    binding.scheduleFrame();
    await binding.pump(const Duration(milliseconds: 16));
  }
  final bytes = await binding.takeScreenshot(name);
  final file = File('${output.absolute.path}/$name.png');
  final capture = NativeCaptureManifest.fromPng(
    name: name,
    platform: Platform.operatingSystem,
    nativePath: file.path,
    bytes: bytes,
  );
  await file.writeAsBytes(bytes, flush: true);
  capture.verify(await file.readAsBytes());
  final manifest = <String, Object?>{
    'schema': 1,
    'captures': [...captures.map((entry) => entry.toJson()), capture.toJson()],
  };
  // Each successful capture leaves a recoverable cumulative manifest even if
  // a later test/driver fails. Only this fixture's files are collected on exit.
  final manifestFile = File('${output.path}/$nativeCaptureManifestFilename');
  final staging = File('${manifestFile.path}.tmp');
  await staging.writeAsString(jsonEncode(manifest), flush: true);
  await staging.rename(manifestFile.path);
  binding.reportData![nativeCaptureManifestKey] = manifest;
  detachPersistedNativeCapture(binding.reportData!, capture);
}
