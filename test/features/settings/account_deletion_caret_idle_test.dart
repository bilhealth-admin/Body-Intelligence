import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/settings/account_deletion_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final arabic in [false, true]) {
    for (final brightness in Brightness.values) {
      testWidgets('iOS deletion confirmation rests between visible caret blinks '
          'arabic=$arabic brightness=$brightness', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(430, 932);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        // The widget runner has no native clipboard. Keep the actual
        // EditableText copy action and observe its platform-channel payload.
        String? clipboardText;
        var clipboardWrites = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            switch (call.method) {
              case 'Clipboard.setData':
                clipboardText = (call.arguments as Map)['text'] as String?;
                clipboardWrites++;
                return null;
              case 'Clipboard.getData':
                return {'text': clipboardText};
              case 'Clipboard.hasStrings':
                return {'value': clipboardText?.isNotEmpty ?? false};
              default:
                return null;
            }
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                platform: TargetPlatform.iOS,
                brightness: brightness,
              ),
              locale: Locale(arabic ? 'ar' : 'en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const AccountDeletionPage(),
            ),
          );
          await tester.pumpAndSettle();
          final originalCopy = tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data ?? '')
              .toList();
          expect(
            originalCopy,
            contains(arabic ? 'حذف الحساب' : 'Delete account'),
          );
          expect(originalCopy.join(' '), contains('App Store'));
          expect(originalCopy.join(' '), isNot(contains('Google Play')));
          final field = find.byType(TextField);
          expect(field, findsOneWidget);
          await tester.ensureVisible(field);
          await tester.tap(field);
          await tester.enterText(field, 'DELETE');
          final editable = find.descendant(
            of: field,
            matching: find.byType(EditableText),
          );
          final input = tester.widget<EditableText>(editable);
          final state = tester.state<EditableTextState>(editable);
          expect(input.controller.text, 'DELETE');
          expect(input.focusNode.hasFocus, isTrue);

          // Exercise the real EditableText copy action. Selecting/typing the
          // confirmation is preparation only; neither action submits deletion.
          input.controller.selection = const TextSelection(
            baseOffset: 0,
            extentOffset: 6,
          );
          await tester.pump();
          state.copySelection(SelectionChangedCause.keyboard);
          await tester.pump();
          expect(clipboardWrites, 1);
          expect(
            (await Clipboard.getData(Clipboard.kTextPlain))?.text,
            'DELETE',
          );
          input.controller.selection = const TextSelection.collapsed(offset: 6);
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 250));
          }

          final visibility = <bool>{state.cursorCurrentlyVisible};
          var scheduledFrames = 0;
          var maximumActiveTickers = 0;
          // Observe demand from the actual mounted page. Explicit test pumps
          // are not counted as production requests; timer blink stays enabled.
          for (var frame = 0; frame < 125; frame++) {
            if (tester.binding.hasScheduledFrame) scheduledFrames++;
            final tickers = tester.binding.transientCallbackCount;
            if (tickers > maximumActiveTickers) maximumActiveTickers = tickers;
            await tester.pump(const Duration(milliseconds: 16));
            visibility.add(state.cursorCurrentlyVisible);
          }
          debugPrint(
            'BIL_DELETE_FIELD_IDLE arabic=$arabic brightness=$brightness '
            'scheduled=$scheduledFrames/125 maxTickers=$maximumActiveTickers '
            'caretStates=$visibility',
          );

          expect(input.controller.text, 'DELETE');
          expect(input.focusNode.hasFocus, isTrue);
          expect(
            input.controller.selection,
            const TextSelection.collapsed(offset: 6),
          );
          expect(visibility, {false, true}, reason: 'The caret still blinks.');
          expect(
            tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data ?? '')
                .toList(),
            originalCopy,
            reason:
                'Focusing/editing must preserve all deletion and billing copy.',
          );
          expect(find.byType(SnackBar), findsNothing);
          expect(find.byType(AlertDialog), findsNothing);
          final submit = tester.widget<FilledButton>(find.byType(FilledButton));
          expect(submit.onPressed, isNotNull);
          expect(find.byType(AccountDeletionPage), findsOneWidget);

          // Keyboard Done dismisses editing, rather than requesting deletion.
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(input.focusNode.hasFocus, isFalse);
          expect(input.controller.text, 'DELETE');
          expect(find.byType(SnackBar), findsNothing);
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
          expect(
            scheduledFrames,
            lessThanOrEqualTo(8),
            reason:
                'A static focused confirmation should rest between caret phases.',
          );
          expect(maximumActiveTickers, 0);
        } finally {
          try {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        }
      });
    }
  }
}
