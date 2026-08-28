import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local splash MP4 is immutable, silent, portrait, and fast-started', () {
    final file = File('assets/branding/bil_splash_motion.mp4');
    final bytes = file.readAsBytesSync();
    final manifest =
        jsonDecode(
              File(
                'videos/bil-splash-motion/render-manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    expect(bytes.length, manifest['output_bytes']);
    expect(sha256.convert(bytes).toString(), manifest['output_sha256']);
    expect(bytes.length, lessThan(512 * 1024));
    expect(manifest['canonical_background_rgb'], '#0877F9');
    expect(manifest['decoded_background_rgb'], '#0876F8');
    expect(manifest['decoded_background_max_channel_delta'], 1);

    final topLevel = _readBoxes(bytes, 0, bytes.length).toList();
    expect(
      topLevel.indexWhere((box) => box.type == 'moov'),
      lessThan(topLevel.indexWhere((box) => box.type == 'mdat')),
      reason:
          'The app asset must be fast-started for local first-frame decode.',
    );

    final boxes = _walkBoxes(bytes, 0, bytes.length).toList();
    final handlers = boxes
        .where((box) => box.type == 'hdlr')
        .map((box) => _handlerType(bytes, box))
        .toList(growable: false);
    expect(handlers, contains('vide'));
    expect(handlers, isNot(contains('soun')));

    final trackHeader = boxes.singleWhere((box) => box.type == 'tkhd');
    final size = _trackSize(bytes, trackHeader);
    expect(size.$1, 1080);
    expect(size.$2, 2400);

    final movieHeader = boxes.singleWhere((box) => box.type == 'mvhd');
    expect(_movieDuration(bytes, movieHeader), closeTo(2, 0.001));
    final sampleTable = boxes.singleWhere((box) => box.type == 'stsz');
    expect(_sampleCount(bytes, sampleTable), 60);

    final signatures = latin1.decode(bytes, allowInvalid: true);
    expect(signatures, contains('avc1'));
  });

  test(
    'Flutter playback is local-only and preserves the fallback contract',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final flutterSource = File(
        'lib/features/startup/premium_splash_experience.dart',
      ).readAsStringSync();
      final startupSource = File(
        'lib/features/startup/startup_page.dart',
      ).readAsStringSync();
      final composition = File(
        'videos/bil-splash-motion/index.html',
      ).readAsStringSync();

      expect(pubspec, contains('assets/branding/bil_splash_motion.mp4'));
      expect(flutterSource, contains('VideoPlayerController.asset('));
      expect(flutterSource, contains('VideoViewType.textureView'));
      expect(flutterSource, contains('controller.value.position'));
      expect(
        flutterSource,
        contains('const bilLaunchBlue = Color(0xFF0877F9)'),
      );
      expect(
        flutterSource,
        contains('const bilSplashMotionDuration = Duration(seconds: 2);'),
      );
      expect(
        flutterSource,
        contains(
          'const bilSplashMinimumDisplayDuration = '
          'Duration(milliseconds: 2300);',
        ),
      );
      expect(
        flutterSource,
        contains('Timer(\n      bilSplashPlaybackSafetyTimeout,'),
      );
      expect(
        flutterSource,
        contains('MediaQuery.disableAnimationsOf(context)'),
      );
      expect(flutterSource, isNot(contains('VideoPlayerController.network')));
      expect(flutterSource, contains("ValueKey('premium-splash-progress')"));
      expect(flutterSource, contains('Curves.easeInOutCubicEmphasized'));
      expect(flutterSource, isNot(contains('CircularProgressIndicator(')));
      expect(flutterSource, isNot(contains('Download')));
      expect(
        startupSource,
        contains(
          'static const splashDuration = bilSplashMinimumDisplayDuration;',
        ),
      );
      expect(startupSource, isNot(contains('await controller.play()')));
      expect(composition.toLowerCase(), contains('#0877f9'));
      expect(composition, isNot(contains('<audio')));
      expect(composition, isNot(contains('<video')));
    },
  );
}

const _containerTypes = <String>{
  'moov',
  'trak',
  'mdia',
  'minf',
  'stbl',
  'dinf',
  'edts',
  'udta',
  'meta',
};

Iterable<_Mp4Box> _walkBoxes(Uint8List bytes, int start, int end) sync* {
  for (final box in _readBoxes(bytes, start, end)) {
    yield box;
    if (_containerTypes.contains(box.type)) {
      final childStart = box.payloadStart + (box.type == 'meta' ? 4 : 0);
      yield* _walkBoxes(bytes, childStart, box.end);
    }
  }
}

Iterable<_Mp4Box> _readBoxes(Uint8List bytes, int start, int end) sync* {
  final data = ByteData.sublistView(bytes);
  var offset = start;
  while (offset + 8 <= end) {
    final compactSize = data.getUint32(offset);
    final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
    var headerSize = 8;
    final int size;
    if (compactSize == 1) {
      if (offset + 16 > end) return;
      size = data.getUint64(offset + 8);
      headerSize = 16;
    } else if (compactSize == 0) {
      size = end - offset;
    } else {
      size = compactSize;
    }
    if (size < headerSize || offset + size > end) return;
    yield _Mp4Box(
      type: type,
      payloadStart: offset + headerSize,
      end: offset + size,
    );
    offset += size;
  }
}

String _handlerType(Uint8List bytes, _Mp4Box box) =>
    ascii.decode(bytes.sublist(box.payloadStart + 8, box.payloadStart + 12));

(int, int) _trackSize(Uint8List bytes, _Mp4Box box) {
  final data = ByteData.sublistView(bytes);
  final version = bytes[box.payloadStart];
  final widthOffset = box.payloadStart + (version == 1 ? 88 : 76);
  final width = data.getUint32(widthOffset) >> 16;
  final height = data.getUint32(widthOffset + 4) >> 16;
  return (width, height);
}

double _movieDuration(Uint8List bytes, _Mp4Box box) {
  final data = ByteData.sublistView(bytes);
  final version = bytes[box.payloadStart];
  if (version == 1) {
    final timescale = data.getUint32(box.payloadStart + 20);
    final duration = data.getUint64(box.payloadStart + 24);
    return duration / timescale;
  }
  final timescale = data.getUint32(box.payloadStart + 12);
  final duration = data.getUint32(box.payloadStart + 16);
  return duration / timescale;
}

int _sampleCount(Uint8List bytes, _Mp4Box box) =>
    ByteData.sublistView(bytes).getUint32(box.payloadStart + 8);

class _Mp4Box {
  const _Mp4Box({
    required this.type,
    required this.payloadStart,
    required this.end,
  });

  final String type;
  final int payloadStart;
  final int end;
}
