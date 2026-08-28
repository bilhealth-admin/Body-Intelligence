import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/services/store_review_prompt_service.dart';
import '../../core/units/measurement_units.dart';
import '../../data/database/date_keys.dart';
import '../../shared/widgets/actionable_error_state.dart';
import '../nutrition/services/bil_speech_to_text.dart';
import '../intelligence_center/services/coach_context_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import '../weight/services/weight_voice_input_service.dart';
import 'check_in_mutation_coordinator.dart';
import 'daily_check_in_locale_copy.dart';

class DailyCheckInPage extends ConsumerStatefulWidget {
  const DailyCheckInPage({super.key});

  @override
  ConsumerState<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends ConsumerState<DailyCheckInPage> {
  double? weightKg;
  bool weightEdited = false;
  String measurementContext = 'morning';
  bool initialized = false;
  late final CheckInMutationCoordinator mutations;

  bool get saving => mutations.active == CheckInMutationKind.save;
  bool get skipping => mutations.active == CheckInMutationKind.skip;

  @override
  void initState() {
    super.initState();
    mutations = CheckInMutationCoordinator(
      onStateChanged: (_) {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> enterWeight(MeasurementSystem system) async {
    if (saving || skipping) return;
    final current = weightKg == null
        ? null
        : UnitConverter.weightFromKg(weightKg!, system);
    final controller = TextEditingController(
      text: current?.toStringAsFixed(1) ?? '',
    );
    final entered = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dailyCheckInText(context, 'Enter weight')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: UnitConverter.weightUnit(system),
          ),
          onSubmitted: (value) => Navigator.pop(
            dialogContext,
            double.tryParse(value.replaceAll(',', '.')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: Text(dailyCheckInText(context, 'Apply')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (entered == null) return;
    final kilograms = UnitConverter.weightToKg(entered, system);
    if (!kilograms.isFinite || kilograms < 20 || kilograms > 500) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dailyCheckInText(context, 'Enter a valid weight.')),
        ),
      );
      return;
    }
    setState(() {
      weightEdited = true;
      weightKg = kilograms;
    });
  }

  Future<void> enterWeightByVoice(MeasurementSystem system) async {
    if (saving || skipping) return;
    final candidate = await WeightVoiceInputService(
      SpeechToText(),
    ).capture(context: context, fallbackSystem: system);
    if (!mounted || candidate == null) return;
    setState(() {
      weightEdited = true;
      weightKg = candidate.kilograms;
    });
  }

  Future<void> save() async {
    final value = weightKg;
    if (value == null || mutations.busy) return;
    final outcome = await mutations.run(CheckInMutationKind.save, () async {
      await ref
          .read(weightRepositoryProvider)
          .addWeight(value, measurementContext: measurementContext);
      // The choice is measurement evidence, not decoration. Rebuild the
      // bounded AI context immediately so the next local/remote Coach turn
      // receives both the value and the conditions under which it was taken.
      ref.invalidate(coachContextSnapshotProvider);
    });
    if (!mounted) return;
    if (outcome == CheckInMutationOutcome.success) {
      unawaited(
        ref
            .read(storeReviewPromptServiceProvider)
            .recordPositiveMoment(StoreReviewMoment.dailyCheckIn),
      );
      context.go('/dashboard');
    } else if (outcome == CheckInMutationOutcome.failure) {
      _showStorageFailure();
    }
  }

  Future<void> skipToday() async {
    if (mutations.busy) return;
    final outcome = await mutations.run(CheckInMutationKind.skip, () async {
      await ref
          .read(preferencesRepositoryProvider)
          .set('weightReminderSkippedDay', dayKeyFor(DateTime.now()));
    });
    if (!mounted) return;
    if (outcome == CheckInMutationOutcome.success) {
      context.go('/dashboard');
    } else if (outcome == CheckInMutationOutcome.failure) {
      _showStorageFailure();
    }
  }

  void _showStorageFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          dailyCheckInText(
            context,
            'The check-in could not be changed on this device. Try again.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayWeightProvider);
    final latest = ref.watch(latestWeightProvider);
    final profileState = ref.watch(userProfileProvider);
    final systemState = ref.watch(measurementSystemProvider);
    final loading =
        today.isLoading || profileState.isLoading || systemState.isLoading;
    final hasError =
        today.hasError || profileState.hasError || systemState.hasError;
    final profile = profileState.value;
    final system = systemState.value;
    final existing = today.value;
    if (!initialized && !loading && !hasError && system != null) {
      initialized = true;
      weightKg =
          existing?.weight ?? latest.value?.weight ?? profile?.currentWeight;
      measurementContext = existing?.measurementContext == 'afterFood'
          ? 'afterFood'
          : existing?.measurementContext == 'differentConditions'
          ? 'differentConditions'
          : 'morning';
    }
    if (initialized &&
        !weightEdited &&
        existing == null &&
        latest.value?.weight != null) {
      weightKg = latest.value!.weight;
    }
    final canonical =
        weightKg ?? latest.value?.weight ?? profile?.currentWeight;
    final display = canonical == null || system == null
        ? null
        : UnitConverter.weightFromKg(canonical, system);

    return PopScope(
      canPop: !saving && !skipping,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: dailyCheckInText(context, 'Not now'),
            // Closing the reminder is the same explicit choice as "Skip
            // today". Persist it before leaving so reopening the dashboard
            // cannot immediately present the same check-in again.
            onPressed: saving || skipping ? null : skipToday,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : hasError || system == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ActionableErrorState(
                      title: dailyCheckInText(
                        context,
                        'Weight data could not be loaded.',
                      ),
                      onRetry: () {
                        ref.invalidate(todayWeightProvider);
                        ref.invalidate(userProfileProvider);
                        ref.invalidate(measurementSystemProvider);
                      },
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: AspectRatio(
                              aspectRatio: 16 / 8.2,
                              child: Image.asset(
                                'assets/images/daily_context/daily_weight_checkin_hero_v1.png',
                                key: const Key('daily-check-in-hero'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            dailyCheckInText(
                              context,
                              'How much do you weigh today?',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 18),
                          _WeightEntryCard(
                            display: display,
                            system: system,
                            busy: saving || skipping,
                            onDecrease: weightKg == null
                                ? null
                                : () => setState(() {
                                    weightEdited = true;
                                    weightKg = (weightKg! - 0.1).clamp(20, 500);
                                  }),
                            onIncrease: weightKg == null
                                ? null
                                : () => setState(() {
                                    weightEdited = true;
                                    weightKg = (weightKg! + 0.1).clamp(20, 500);
                                  }),
                            onEnter: () => enterWeight(system),
                            onVoice: () => enterWeightByVoice(system),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            key: const Key(
                              'daily-check-in-measurement-context',
                            ),
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in const [
                                ('morning', 'Morning', Icons.wb_sunny_outlined),
                                (
                                  'afterFood',
                                  'After eating',
                                  Icons.restaurant_outlined,
                                ),
                                (
                                  'differentConditions',
                                  'Different time',
                                  Icons.schedule_rounded,
                                ),
                              ])
                                ChoiceChip(
                                  key: Key(
                                    'daily-check-in-context-${option.$1}',
                                  ),
                                  showCheckmark: false,
                                  selected: measurementContext == option.$1,
                                  avatar: Icon(option.$3, size: 18),
                                  label: Text(
                                    dailyCheckInText(context, option.$2),
                                  ),
                                  onSelected: saving || skipping
                                      ? null
                                      : (_) => setState(
                                          () => measurementContext = option.$1,
                                        ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 56,
                            child: FilledButton(
                              key: const ValueKey('daily-check-in-save'),
                              onPressed: saving || skipping || weightKg == null
                                  ? null
                                  : save,
                              child: saving
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(context.strings.text('Save')),
                            ),
                          ),
                          TextButton(
                            onPressed: saving || skipping ? null : skipToday,
                            child: skipping
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(dailyCheckInText(context, 'Skip today')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _WeightEntryCard extends StatelessWidget {
  const _WeightEntryCard({
    required this.display,
    required this.system,
    required this.busy,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEnter,
    required this.onVoice,
  });

  final double? display;
  final MeasurementSystem system;
  final bool busy;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback onEnter;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _RepeatWeightButton(
              key: const Key('daily-check-in-weight-decrease'),
              tooltip: '− 0.1 ${UnitConverter.weightUnit(system)}',
              onPressed: busy ? null : onDecrease,
              icon: Icons.remove_rounded,
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: busy ? null : onEnter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          display?.toStringAsFixed(1) ?? '—',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        UnitConverter.weightUnit(system),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _RepeatWeightButton(
              key: const Key('daily-check-in-weight-increase'),
              tooltip: '+ 0.1 ${UnitConverter.weightUnit(system)}',
              onPressed: busy ? null : onIncrease,
              icon: Icons.add_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: Tooltip(
            message: dailyCheckInText(context, 'Voice input'),
            child: FilledButton.tonalIcon(
              key: const Key('daily-check-in-weight-voice'),
              onPressed: busy ? null : onVoice,
              icon: const Icon(Icons.mic_rounded),
              label: Text(dailyCheckInText(context, 'Voice input')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(168, 48),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A 100 g stepper that behaves like a real scale control: one short press is
/// one step, while holding continues at a bounded repeat rate until release.
class _RepeatWeightButton extends StatefulWidget {
  const _RepeatWeightButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<_RepeatWeightButton> createState() => _RepeatWeightButtonState();
}

class _RepeatWeightButtonState extends State<_RepeatWeightButton> {
  Timer? _repeatDelay;
  Timer? _repeatTimer;
  bool _pressed = false;

  void _begin() {
    final action = widget.onPressed;
    if (action == null) return;
    _stop();
    setState(() => _pressed = true);
    action();
    _repeatDelay = Timer(const Duration(milliseconds: 340), () {
      if (!mounted || !_pressed || widget.onPressed == null) return;
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 75), (_) {
        if (mounted && _pressed) widget.onPressed?.call();
      });
    });
  }

  void _stop() {
    _repeatDelay?.cancel();
    _repeatTimer?.cancel();
    _repeatDelay = null;
    _repeatTimer = null;
    if (_pressed && mounted) setState(() => _pressed = false);
  }

  @override
  void didUpdateWidget(covariant _RepeatWeightButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) _stop();
  }

  @override
  void dispose() {
    _repeatDelay?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.tooltip,
        onTap: enabled ? widget.onPressed : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _begin() : null,
          onTapUp: enabled ? (_) => _stop() : null,
          onTapCancel: enabled ? _stop : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _pressed
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerLowest,
              border: Border.all(
                color: enabled
                    ? scheme.outlineVariant
                    : scheme.outlineVariant.withValues(alpha: .45),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
