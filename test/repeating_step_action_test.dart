import 'dart:async';
import 'dart:ui' show SemanticsAction;
import 'package:body_intelligence_log/features/profile/providers/profile_auth_identity_provider.dart';
import 'package:body_intelligence_log/shared/widgets/repeating_step_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _plus = Key('repeat-fixture-plus');
const _minus = Key('repeat-fixture-minus');

class _Fixture extends StatefulWidget {
  const _Fixture();
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  double value = 70;
  double maximum = 100;
  bool enabled = true;
  String unit = 'kg';
  final signal = ValueNotifier<int>(0);
  int calls = 0;
  void change(VoidCallback action) => setState(action);
  void step(int direction) {
    calls++;
    setState(
      () => value = decimalStep(
        value: value,
        step: .1,
        direction: direction,
        decimalPlaces: 1,
        minimum: 20,
        maximum: maximum,
      ),
    );
  }

  @override
  void dispose() {
    signal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final direction in [-1, 1])
        RepeatingStepAction(
          cancelScope: unit,
          cancelSignal: signal,
          canStep: () =>
              enabled && (direction > 0 ? value < maximum : value > 20),
          onPressed:
              !enabled ||
                  direction < 0 && value <= 20 ||
                  direction > 0 && value >= maximum
              ? null
              : () => step(direction),
          builder: (_, action, _) => IconButton.outlined(
            key: direction == 1 ? _plus : _minus,
            tooltip: direction == 1 ? 'Increase weight' : 'Decrease weight',
            onPressed: action,
            icon: Icon(direction == 1 ? Icons.add : Icons.remove),
          ),
        ),
      Text(value.toStringAsFixed(1)),
    ],
  );
}

Future<_FixtureState> _pump(
  WidgetTester tester, {
  Stream<ProfileAuthIdentity>? owners,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (owners != null)
          profileAuthIdentityProvider.overrideWith((_) => owners),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [_Fixture(), SizedBox(height: 1200)]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<_FixtureState>(find.byType(_Fixture));
}

void main() {
  test('decimal draft steps preserve precision and boundaries', () {
    var value = 20.0;
    for (var i = 0; i < 700; i++) {
      value = decimalStep(
        value: value,
        step: .1,
        direction: 1,
        decimalPlaces: 1,
        minimum: 20,
        maximum: 500,
      );
    }
    expect(value, 90);
    for (var i = 0; i < 700; i++) {
      value = decimalStep(
        value: value,
        step: .1,
        direction: -1,
        decimalPlaces: 1,
        minimum: 20,
        maximum: 500,
      );
    }
    expect(value, 20);
    expect(
      decimalStep(
        value: 20.05,
        step: .1,
        direction: 1,
        decimalPlaces: 1,
        minimum: 20,
        maximum: 500,
      ),
      20.15,
    );
    expect(
      decimalStep(
        value: 20,
        step: .1,
        direction: -1,
        decimalPlaces: 1,
        minimum: 20,
        maximum: 500,
      ),
      20,
    );
    expect(
      () => decimalStep(
        value: double.nan,
        step: .1,
        direction: 1,
        decimalPlaces: 1,
        minimum: 20,
        maximum: 500,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('short tap changes exactly one step', (tester) async {
    final state = await _pump(tester);
    await tester.tap(find.byKey(_plus));
    await tester.pump();
    expect(state.value, 70.1);
    await tester.pump(const Duration(seconds: 1));
    expect(state.value, 70.1);
  });

  testWidgets(
    'hold starts after delay, repeats same step and stops on release',
    (tester) async {
      final state = await _pump(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_plus)),
      );
      await tester.pump(const Duration(milliseconds: 339));
      expect(state.value, 70);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state.value, 70.1);
      await tester.pump(const Duration(milliseconds: 225));
      expect(state.value, 70.4);
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));
      expect(state.value, 70.4);
    },
  );

  for (final cancel in [
    'cancel',
    'exit',
    'scroll',
    'disabled',
    'unit',
    'background',
    'dispose',
    'focus',
    'route',
    'limit',
    'two fingers',
    'signal',
    'outside pointer',
  ]) {
    testWidgets('repeat cancels on $cancel', (tester) async {
      final state = await _pump(tester);
      final point = tester.getCenter(find.byKey(_plus));
      final gesture = await tester.startGesture(point);
      if (cancel == 'scroll') {
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 500));
        expect(state.value, 70);
      } else {
        await tester.pump(const Duration(milliseconds: 340));
        expect(state.value, 70.1);
        switch (cancel) {
          case 'cancel':
            await gesture.cancel();
          case 'exit':
            await gesture.moveBy(const Offset(90, 0));
          case 'disabled':
            state.change(() => state.enabled = false);
          case 'unit':
            state.change(() => state.unit = 'lb');
          case 'background':
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
          case 'dispose':
            await tester.pumpWidget(const SizedBox.shrink());
            await gesture.moveBy(const Offset(4, 0));
          case 'focus':
            FocusManager.instance.primaryFocus?.unfocus();
          case 'route':
            Navigator.of(
              tester.element(find.byType(_Fixture)),
            ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
          case 'limit':
            state.change(() => state.maximum = state.value);
          case 'two fingers':
            final second = await tester.startGesture(
              tester.getCenter(find.byKey(_minus)),
              pointer: 2,
            );
            await tester.pump(const Duration(milliseconds: 400));
            await second.up();
          case 'signal':
            state.signal.value++;
          case 'outside pointer':
            final second = await tester.startGesture(
              const Offset(500, 300),
              pointer: 2,
            );
            await tester.pump(const Duration(milliseconds: 400));
            await second.up();
        }
      }
      await tester.pump();
      final stopped = state.value;
      await tester.pump(const Duration(seconds: 1));
      expect(state.value, stopped);
      if (cancel != 'cancel') await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(state.value, stopped);
      if (cancel == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(state.value, stopped);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('A to B to A cancels the original held gesture', (tester) async {
    final owners = StreamController<ProfileAuthIdentity>();
    addTearDown(owners.close);
    final state = await _pump(tester, owners: owners.stream);
    owners.add(const ProfileAuthIdentity(ownerId: 'A', email: null));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_plus)),
    );
    await tester.pump(const Duration(milliseconds: 340));
    expect(state.value, 70.1);
    owners.add(const ProfileAuthIdentity(ownerId: 'B', email: null));
    owners.add(const ProfileAuthIdentity(ownerId: 'A', email: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(state.value, 70.1);
    await gesture.up();
  });

  testWidgets('keyboard activates one step with normal focus', (tester) async {
    final state = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(state.value, 69.9);
  });

  testWidgets('a limit reached by a tick stops before another callback', (
    tester,
  ) async {
    final state = await _pump(tester);
    state.change(() => state.maximum = 70.1);
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_plus)),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(state.value, 70.1);
    expect(state.calls, 1);
    await gesture.up();
  });

  testWidgets('screen reader tap changes one configured step', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final state = await _pump(tester);
      final node = tester.getSemantics(find.byKey(_plus));
      expect(node.getSemanticsData().tooltip, 'Increase weight');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(state.value, 70.1);
      expect(state.calls, 1);
    } finally {
      handle.dispose();
    }
  });
}
