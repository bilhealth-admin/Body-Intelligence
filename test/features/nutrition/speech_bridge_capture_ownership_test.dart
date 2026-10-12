import 'package:body_intelligence_log/features/nutrition/services/bil_speech_to_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('bil/closure/speech'),
      events = EventChannel('bil/closure/speech/events');
  const options = SpeechListenOptions(
    localeId: 'ar-SA',
    listenFor: Duration(seconds: 30),
    pauseFor: Duration(seconds: 4),
    listenMode: ListenMode.confirmation,
    partialResults: true,
    cancelOnError: true,
  );
  test(
    'native event sink and microphone remain owned when a second voice surface closes',
    () async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call.method);
        return call.method == 'available' ? true : null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('bil/closure/speech/events'),
        (call) async {
          calls.add('events:${call.method}');
          return null;
        },
      );
      final first = SpeechToText(methods: methods, events: events),
          second = SpeechToText(methods: methods, events: events);
      final words = <String>[];
      try {
        await first.initialize();
        await second.initialize();
        await first.listen(
          onResult: (result) => words.add(result.recognizedWords),
          listenOptions: options,
        );
        await expectLater(
          second.listen(
            onResult: (_) => fail('second recognizer received a result'),
            listenOptions: options,
          ),
          throwsA(isA<PlatformException>()),
        );
        await second.dispose();
        expect(calls.where((call) => call == 'listen'), hasLength(1));
        expect(calls.where((call) => call == 'cancel'), isEmpty);
        expect(calls.where((call) => call == 'events:cancel'), isEmpty);
        ServicesBinding.instance.channelBuffers.push(
          events.name,
          const StandardMethodCodec().encodeSuccessEnvelope({
            'type': 'result',
            'words': 'فول',
            'final': false,
          }),
          (_) {},
        );
        await Future<void>.delayed(Duration.zero);
        expect(words, ['فول']);
        expect(first.isListening, isTrue);
        await first.cancel();
        ServicesBinding.instance.channelBuffers.push(
          events.name,
          const StandardMethodCodec().encodeSuccessEnvelope({
            'type': 'result',
            'words': 'late',
            'final': true,
          }),
          (_) {},
        );
        await Future<void>.delayed(Duration.zero);
        expect(words, ['فول']);
        expect(first.isListening, isFalse);
        await second.initialize();
        await second.listen(onResult: (_) {}, listenOptions: options);
        expect(second.isListening, isTrue);
      } finally {
        await second.dispose();
        await first.dispose();
        messenger.setMockMethodCallHandler(methods, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('bil/closure/speech/events'),
          null,
        );
      }
    },
  );
}
