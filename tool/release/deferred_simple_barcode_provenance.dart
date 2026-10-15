part of 'defer_ios_simple_barcode_scanner.dart';

Map<String, FileSystemEntity> _barcodeTree(Directory root) {
  _assertDirectoryIsNotLink(root, 'Barcode package tree');
  final entries = <String, FileSystemEntity>{};
  final path = root.absolute.path;
  final prefix = path.endsWith(Platform.pathSeparator) || path.endsWith('/')
      ? path
      : '$path${Platform.pathSeparator}';
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File && entity is! Directory) {
      throw StateError(
        'Barcode package tree contains a link or special file: ${entity.path}',
      );
    }
    entries[entity.absolute.path
            .substring(prefix.length)
            .replaceAll('\\', '/')] =
        entity;
  }
  return entries;
}

bool _sameBarcodeBytes(List<int> first, List<int> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) {
      return false;
    }
  }
  return true;
}

// Exact output of the earlier owned Android/iOS exclusion. Retain its approved
// upgrade path without accepting arbitrary YAML which merely lacks native keys.
String _legacyEmptyBarcodePlugin(String iosOnly) {
  final lines = _lines(iosOnly);
  _removeMapping(
    lines,
    _directKey(lines, 'android', parent: _directKey(lines, 'platforms')),
  );
  final plugin = _directKey(
    lines,
    'plugin',
    parent: _directKey(lines, 'flutter'),
  );
  _removeMapping(
    lines,
    _directKey(
      lines,
      'android',
      parent: _directKey(lines, 'platforms', parent: plugin),
    ),
  );
  return '${lines.join(iosOnly.contains('\r\n') ? '\r\n' : '\n')}\n';
}

Map<String, Object?> _verifyOwnedBarcodeOverride(
  Directory destination, {
  Directory? expectedSource,
}) {
  // Inventory before reading even the marker, so a linked marker/pubspec cannot
  // redirect verification to an otherwise valid but unrelated package tree.
  final copied = _barcodeTree(destination);
  final marker = copied[_markerName];
  if (marker is! File) {
    throw StateError(
      'Existing simple_barcode_scanner override is missing its provenance marker.',
    );
  }
  final payload = _readJsonMap(marker, 'deferred override marker');
  const allowedKeys = {
    'status',
    'plugin',
    'version',
    'source_root_uri',
    'android_removed',
  };
  if (payload.keys.any((key) => !allowedKeys.contains(key)) ||
      payload['status'] != 'ios-native-platform-removed' ||
      payload['plugin'] != deferredIosSimpleBarcodeScannerPlugin ||
      payload['version'] != _expectedVersion ||
      (payload.containsKey('android_removed') &&
          payload['android_removed'] is! bool)) {
    throw StateError(
      'Existing simple_barcode_scanner override has invalid provenance.',
    );
  }
  final rawUri = payload['source_root_uri'];
  final uri = rawUri is String ? Uri.tryParse(rawUri) : null;
  if (uri == null ||
      uri.scheme != 'file' ||
      uri.hasQuery ||
      uri.hasFragment ||
      !uri.isAbsolute) {
    throw StateError(
      'Owned barcode source_root_uri must be a canonical local directory URI.',
    );
  }
  final upstream = Directory.fromUri(uri);
  if (!upstream.existsSync()) {
    throw StateError('Owned barcode upstream no longer exists.');
  }
  _assertDirectoryIsNotLink(upstream, 'Owned barcode upstream');
  final canonicalUri = Directory(
    upstream.resolveSymbolicLinksSync(),
  ).uri.toString();
  final recordedUri = rawUri as String;
  if ((Platform.isWindows ? recordedUri.toLowerCase() : recordedUri) !=
          (Platform.isWindows ? canonicalUri.toLowerCase() : canonicalUri) ||
      (expectedSource != null && !_sameDirectory(upstream, expectedSource))) {
    throw StateError(
      'Owned barcode source_root_uri does not match the exact canonical upstream.',
    );
  }
  if (_isWithin(_canonical(upstream), _canonical(destination)) ||
      _isWithin(_canonical(destination), _canonical(upstream))) {
    throw StateError(
      'Owned barcode upstream and override must not contain each other.',
    );
  }
  final original = _barcodeTree(upstream);
  if (original.containsKey(_markerName) ||
      copied.length != original.length + 1 ||
      original.keys.any((path) => !copied.containsKey(path)) ||
      copied.keys.any(
        (path) => path != _markerName && !original.containsKey(path),
      )) {
    throw StateError(
      'Owned barcode override has missing or unknown files/directories.',
    );
  }
  final sourcePubspec = original['pubspec.yaml'];
  if (sourcePubspec is! File) {
    throw StateError('Owned barcode upstream pubspec is missing.');
  }
  final iosOnly = removeIosPlatformFromSimpleBarcodeScannerPubspec(
    sourcePubspec.readAsStringSync(),
  );
  final androidRemoved = payload['android_removed'] == true;
  final mobile = androidRemoved
      ? removeAndroidPlatformFromDeferredBarcodePubspec(iosOnly)
      : null;
  final approvedPubspecs = <String>{
    if (!androidRemoved) iosOnly,
    ?mobile,
    // The existing early-empty-plugin upgrade emits LF on all hosts.
    if (mobile != null) mobile.replaceAll('\r\n', '\n'),
    if (androidRemoved) _legacyEmptyBarcodePlugin(iosOnly),
  };
  for (final entry in original.entries) {
    final target = copied[entry.key];
    if (entry.value is Directory && target is Directory) {
      continue;
    }
    if (entry.value is! File || target is! File) {
      throw StateError(
        'Owned barcode file type differs from upstream: ${entry.key}',
      );
    }
    final bytes = target.readAsBytesSync();
    final matches = entry.key == 'pubspec.yaml'
        ? approvedPubspecs.any(
            (text) => _sameBarcodeBytes(bytes, utf8.encode(text)),
          )
        : _sameBarcodeBytes(bytes, (entry.value as File).readAsBytesSync());
    if (!matches) {
      throw StateError(
        'Owned barcode bytes differ from upstream: ${entry.key}',
      );
    }
  }
  return payload;
}

void _bindDeferredBarcodeConfiguration(
  File configFile,
  Map<String, Object?> config,
  Map<String, Object?> entry,
  Directory destination,
) {
  entry['rootUri'] =
      '$_overrideDirectoryName/$deferredIosSimpleBarcodeScannerPlugin/';
  configFile.writeAsStringSync('${jsonEncode(config)}\n', flush: true);
  final written = _readJsonMap(configFile, 'package_config.json');
  if (!_sameDirectory(
    _entryRoot(configFile, _packageEntry(written)),
    destination,
  )) {
    throw StateError(
      'package_config.json did not resolve simple_barcode_scanner to the override.',
    );
  }
}
