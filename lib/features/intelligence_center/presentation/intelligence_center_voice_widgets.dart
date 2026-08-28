part of 'intelligence_center_page.dart';

class _LiveVoiceTranscript extends StatelessWidget {
  const _LiveVoiceTranscript({required this.text, required this.liveCall});

  final String text;
  final bool liveCall;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsetsDirectional.fromSTEB(15, 11, 15, 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer,
              scheme.tertiaryContainer.withValues(alpha: .72),
            ],
          ),
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(22),
            topEnd: Radius.circular(22),
            bottomStart: Radius.circular(22),
            bottomEnd: Radius.circular(7),
          ),
          border: Border.all(color: scheme.primary.withValues(alpha: .24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _VoiceListeningWave(color: scheme.primary, compact: true),
                const SizedBox(width: 7),
                Text(
                  liveCall
                      ? intelligenceText(
                          context,
                          'Live call transcript · pause to send',
                          'نص المكالمة · اسكت للإرسال',
                        )
                      : intelligenceText(
                          context,
                          'Writing your words · pause to send',
                          'أكتب كلامك · اسكت للإرسال',
                        ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachReplyProgress extends StatelessWidget {
  const _CoachReplyProgress({
    required this.phase,
    required this.onCancel,
    required this.onRetry,
  });

  final _CoachReplyPhase phase;
  final VoidCallback onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = phase == _CoachReplyPhase.failed;
    final searching = phase == _CoachReplyPhase.searching;
    final label = failed
        ? intelligenceText(
            context,
            'The reply did not complete. Try again.',
            'لم يكتمل الرد. حاول مرة أخرى.',
          )
        : searching
        ? intelligenceText(
            context,
            'Searching your BIL context…',
            'أبحث في سياق BIL الخاص بك…',
          )
        : intelligenceText(context, 'Preparing your answer…', 'أجهز إجابتك…');
    return Semantics(
      liveRegion: true,
      label: label,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          key: const Key('ai-coach-reply-progress'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 8),
          decoration: BoxDecoration(
            color: failed
                ? scheme.errorContainer.withValues(alpha: .42)
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!failed)
                SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: searching ? 2.5 : 1.8,
                  ),
                )
              else
                Icon(
                  Icons.error_outline_rounded,
                  color: scheme.error,
                  size: 19,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: searching || failed
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
              if (failed && onRetry != null)
                TextButton(
                  key: const Key('ai-coach-retry'),
                  onPressed: onRetry,
                  child: Text(
                    intelligenceText(context, 'Retry', 'إعادة المحاولة'),
                  ),
                )
              else
                IconButton(
                  key: const Key('ai-coach-cancel-request'),
                  tooltip: intelligenceText(
                    context,
                    'Cancel waiting',
                    'إلغاء الانتظار',
                  ),
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceListeningWave extends StatefulWidget {
  const _VoiceListeningWave({required this.color, this.compact = false});

  final Color color;
  final bool compact;

  @override
  State<_VoiceListeningWave> createState() => _VoiceListeningWaveState();
}

class _VoiceListeningWaveState extends State<_VoiceListeningWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.compact ? 22 : 34,
      height: widget.compact ? 20 : 28,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(4, (index) {
              final phase = (controller.value + index * .19) % 1;
              final height =
                  5 + (1 - (phase * 2 - 1).abs()) * (8 + index % 2 * 4);
              return Container(
                width: widget.compact ? 3 : 4,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
