import 'package:body_intelligence_log/features/community/services/community_composer_voice_input_service.dart';
import 'package:body_intelligence_log/features/nutrition/services/bil_speech_to_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String _repeat(String value, int times) => List.filled(times, value).join();

final class _SpeechFixture extends SpeechToText {
  _SpeechFixture(this.transcript)
    : super(
        methods: const MethodChannel('bil/community/unicode-voice/test'),
        events: const EventChannel('bil/community/unicode-voice/test/events'),
      );

  final String transcript;

  @override
  bool get isListening => false;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError error)? onError,
  }) async => true;

  @override
  Future<List<LocaleName>> locales() async => const [LocaleName('en-US')];

  @override
  Future<void> listen({
    required void Function(SpeechRecognitionResult result) onResult,
    required SpeechListenOptions listenOptions,
  }) async {
    onResult(
      SpeechRecognitionResult(transcript, isFinal: true, localeId: 'en-US'),
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  final boundaries = {
    'astral emoji': _repeat('😀', 1200),
    'joined emoji': '${_repeat('a', 1197)}👩‍💻',
    'combining accent': '${_repeat('a', 1198)}e\u0301',
  };

  for (final boundary in boundaries.entries) {
    testWidgets(
      '${boundary.key} voice overflow stays editable and exact reviewed text is returned',
      (tester) async {
        final acceptedBody = boundary.value;
        final tooLong = '${acceptedBody}a';
        final service = CommunityComposerVoiceInputService(
          _SpeechFixture(tooLong),
          permissionGate: (_) async => true,
        );
        String? accepted;
        var returned = false;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const Key('begin-unicode-voice'),
                  onPressed: () async {
                    accepted = await service.capture(context);
                    returned = true;
                  },
                  child: const Text('Record'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('begin-unicode-voice')));
        await tester.pumpAndSettle();

        final editor = find.byKey(const Key('community-voice-transcript'));
        final useText = find.byKey(const Key('community-use-voice-transcript'));
        expect(tester.widget<TextField>(editor).controller!.text, tooLong);
        expect(find.text('1201 / 1200'), findsOneWidget);
        expect(tester.widget<FilledButton>(useText).onPressed, isNull);
        expect(returned, isFalse);

        // Exercise Flutter's actual editing path as well as the native speech
        // result. Neither default grapheme enforcement nor UTF-16 slicing may
        // discard a pasted sequence before the user can correct it.
        final pasted = '$tooLong👨‍👩‍👧‍👦';
        await tester.enterText(editor, pasted);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(editor).controller!.text, pasted);
        expect(find.text('1208 / 1200'), findsOneWidget);
        expect(tester.widget<FilledButton>(useText).onPressed, isNull);
        expect(
          find.text('Keep the text within 1200 characters. Your text is kept.'),
          findsOneWidget,
        );

        await tester.enterText(editor, acceptedBody);
        await tester.pumpAndSettle();
        final controller = tester.widget<TextField>(editor).controller!;
        expect(controller.text, acceptedBody);
        expect(controller.selection.baseOffset, acceptedBody.length);
        expect(find.text('1200 / 1200'), findsOneWidget);
        expect(tester.widget<FilledButton>(useText).onPressed, isNotNull);
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.tap(useText);
        await tester.pumpAndSettle();

        expect(returned, isTrue);
        expect(accepted, acceptedBody);
        expect(editor, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
