import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/community/presentation/community_surface.dart';
import 'package:body_intelligence_log/features/community/presentation/community_welcome.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('welcome remains reachable at 320x568 scale=$scale dark=$dark', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: child!),
          home: CommunitySurface(child: Scaffold(
            appBar: AppBar(leading: const BackButton(), title: const Text('BIL')),
            body: const CommunityWelcome())),
        ));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const Key('community-welcome-loading')), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        final progress = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
        expect(progress.value, isNull, reason: 'No invented completion percentage');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
