import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play Integrity never blocks the first Flutter frame', () {
    final source = File('lib/main.dart').readAsStringSync();
    final mainBody = source.substring(
      source.indexOf('Future<void> main() async'),
      source.indexOf('class _BILBootstrap'),
    );

    expect(mainBody, contains('runApp(const ProviderScope'));
    expect(mainBody, isNot(contains('BilPlayIntegrityService.instance')));

    final readyIndex = source.indexOf('setState(() => ready = true);');
    final postFrameIndex = source.indexOf(
      'WidgetsBinding.instance.addPostFrameCallback',
      readyIndex,
    );
    final integrityIndex = source.indexOf(
      'BilPlayIntegrityService.instance.observe',
      readyIndex,
    );
    expect(readyIndex, greaterThan(-1));
    expect(postFrameIndex, greaterThan(readyIndex));
    expect(integrityIndex, greaterThan(postFrameIndex));
  });

  test('cloud plugins start only after the first Flutter frame', () {
    final source = File('lib/main.dart').readAsStringSync();
    final initStart = source.indexOf('void initState()');
    final initEnd = source.indexOf(
      'Future<void> _initializeCloud()',
      initStart,
    );
    final initBody = source.substring(initStart, initEnd);

    final postFrameIndex = initBody.indexOf(
      'WidgetsBinding.instance.addPostFrameCallback',
    );
    final initializeIndex = initBody.indexOf('_initializeCloud()');
    expect(postFrameIndex, greaterThan(-1));
    expect(initializeIndex, greaterThan(postFrameIndex));
    expect(
      initBody.substring(0, postFrameIndex),
      isNot(contains('_initializeCloud()')),
    );

    // BILLinkBootstrap owns AppLinks so Supabase must not register a second
    // initial-link listener during the startup-critical path.
    expect(source, contains('detectSessionInUri: false'));

    final cloudStart = source.indexOf('Future<void> _initializeCloud()');
    final cloudEnd = source.indexOf('void _dismissNativeLaunch()', cloudStart);
    final cloudBody = source.substring(cloudStart, cloudEnd);
    final localFirstReady = cloudBody.indexOf('setState(() => ready = true)');
    final cloudAwait = cloudBody.indexOf('await cloudInitialization');
    expect(localFirstReady, greaterThan(-1));
    expect(cloudAwait, greaterThan(localFirstReady));
  });
}
