part of 'intelligence_center_page.dart';

class _AiCoachEntryWelcome extends StatelessWidget {
  const _AiCoachEntryWelcome();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final displayFamily = switch (locale) {
      'ar' || 'fa' || 'ur' => 'BILArabic',
      'en' ||
      'fr' ||
      'es' ||
      'tr' ||
      'de' ||
      'it' ||
      'pt' ||
      'id' ||
      'ms' ||
      'vi' ||
      'pl' ||
      'nl' => 'BILDisplay',
      _ => null,
    };
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BilPearlFeatureWelcome(
        key: const Key('ai-coach-entry-welcome'),
        title: intelligenceText(
          context,
          'Welcome to AI Coach',
          'مرحبًا بك في المدرب الذكي',
        ),
        subtitle: intelligenceText(
          context,
          'Speak your language',
          'أتكلم لغتك',
        ),
        displayFontFamily: displayFamily,
        statusLabel: intelligenceText(context, 'Preparing…', 'جارٍ التحضير…'),
        artworkWidth: 216,
        artwork: const BilCoachPortrait(fit: BoxFit.cover, cacheWidth: 512),
      ),
    );
  }
}

final class _CoachUndoPermissionDenied implements Exception {
  const _CoachUndoPermissionDenied();
}

final class _CoachUndoOperation {
  _CoachUndoOperation({
    required this.receipt,
    this.undo,
    this.undoReadback,
    this.mealCommit,
  });

  final BilActionReceipt receipt;
  final CoachMealCommit? mealCommit;
  final Future<void> Function()? undo;
  final Future<BilActionReceipt> Function(void Function() checkWritePermission)?
  undoReadback;
  bool completed = false;
  bool running = false;
}

class _InlineCoachDecision extends StatelessWidget {
  const _InlineCoachDecision({required this.brief, required this.onAction});

  final CoachDailyBrief brief;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 28, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BilResponseMark(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intelligenceText(context, 'FOR TODAY', 'لليوم'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  brief.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  brief.message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.48),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      key: Key('ai-coach-day-one-guidance-evidence'),
                      size: 16,
                      color: Color(0xFF56C878),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        brief.evidenceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 40),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const BilNavigationFeedback(
                    child: Icon(Icons.arrow_forward_rounded, size: 17),
                  ),
                  label: Text(brief.actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachHeroPortrait extends StatelessWidget {
  const _CoachHeroPortrait({this.size = 62, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = intelligenceText(
      context,
      'Open conversation history',
      'افتح سجل المحادثات',
    );
    return SizedBox.square(
      dimension: size < 48 ? 48 : size,
      child: Semantics(
        button: onTap != null,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            key: const Key('ai-coach-conversation-history-button'),
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: const BilCoachPortrait(
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BilResponseMark extends StatelessWidget {
  const _BilResponseMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: intelligenceText(context, 'BIL Coach', 'مدرب BIL'),
      child: Container(
        key: const ValueKey('bil-coach-response-avatar'),
        width: 32,
        height: 32,
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.primary.withValues(alpha: .32)),
        ),
        child: ClipOval(
          child: const BilCoachPortrait(
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class _CoachEmptyState extends StatelessWidget {
  const _CoachEmptyState({required this.onVoice, required this.onCamera});

  final VoidCallback onVoice;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BilPearlFinish.panel(
                context,
                radius: BorderRadius.circular(41),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                size: 38,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              intelligenceText(
                context,
                'Speak, type, or show me.',
                'تحدث، اكتب، أو أرني.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            Text(
              intelligenceText(
                context,
                'Voice stays voice. Typing stays text. Your camera opens directly for a photo.',
                'الصوت يبقى صوتًا، والكتابة تبقى نصًا، والكاميرا تفتح مباشرة للتصوير.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onVoice,
                  icon: const Icon(Icons.graphic_eq_rounded),
                  label: Text(intelligenceText(context, 'Talk', 'تحدث')),
                ),
                OutlinedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(intelligenceText(context, 'Photo', 'صورة')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachStarterPrompts extends StatelessWidget {
  const _CoachStarterPrompts({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prompts = <({IconData icon, String label, String prompt})>[
      (
        icon: Icons.today_rounded,
        label: intelligenceText(context, 'Review my day', 'راجع يومي'),
        prompt: intelligenceText(
          context,
          'Review my day from my saved BIL data and tell me the most useful next step.',
          'راجع يومي من بيانات BIL المحفوظة وأخبرني بأكثر خطوة مفيدة الآن.',
        ),
      ),
      (
        icon: Icons.restaurant_menu_rounded,
        label: intelligenceText(context, 'Check nutrition', 'راجع التغذية'),
        prompt: intelligenceText(
          context,
          'Review today’s nutrition from my saved BIL data. What stands out and what should I focus on next?',
          'راجع تغذية اليوم من بيانات BIL المحفوظة. ما الأبرز وما الذي أركز عليه الآن؟',
        ),
      ),
      (
        icon: Icons.bedtime_outlined,
        label: intelligenceText(context, 'Explain sleep', 'اشرح نومي'),
        prompt: intelligenceText(
          context,
          'Explain my recorded sleep trend and what it may mean for today, without inventing missing data.',
          'اشرح اتجاه نومي المسجل وما قد يعنيه لليوم، من دون اختراع بيانات مفقودة.',
        ),
      ),
      (
        icon: Icons.track_changes_rounded,
        label: intelligenceText(context, 'Next best focus', 'أفضل تركيز تالٍ'),
        prompt: intelligenceText(
          context,
          'Based on my selected BIL context, what is the single best thing to focus on next and why?',
          'بناءً على سياق BIL الذي اخترته، ما أفضل شيء واحد أركز عليه الآن ولماذا؟',
        ),
      ),
    ];

    return Padding(
      key: const ValueKey('ai-coach-starter-prompts'),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF64D8FF).withValues(alpha: .22),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                intelligenceText(
                  context,
                  'Start with your real BIL data',
                  'ابدأ من بيانات BIL الحقيقية',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                intelligenceText(
                  context,
                  'Choose a starting point. The Coach uses only the context available to it.',
                  'اختر نقطة بداية. يستخدم المدرب فقط السياق المتاح له.',
                ),
                style: _coachConversationBodyStyle(
                  context,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in prompts)
                    ActionChip(
                      avatar: BilNavigationFeedback(
                        child: Icon(item.icon, size: 17),
                      ),
                      label: Text(item.label),
                      onPressed: () => onPrompt(item.prompt),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListeningComposerLabel extends StatelessWidget {
  const _ListeningComposerLabel({
    required this.label,
    required this.transcript,
  });
  final String label;
  final String transcript;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _VoiceListeningWave(color: scheme.onSurface, compact: true),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transcript.trim().isEmpty ? label : transcript.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (transcript.trim().isNotEmpty)
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
