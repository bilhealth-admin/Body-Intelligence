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
      backgroundColor: const Color(0xFF030405),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -.18),
                  radius: .86,
                  colors: [Color(0xFF173A62), Color(0xFF030405)],
                  stops: [0, 1],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF64D8FF), Color(0xFF7568FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF3C75FF,
                            ).withValues(alpha: .30),
                            blurRadius: 34,
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                      child: const ClipOval(
                        child: BilCoachPortrait(
                          width: 98,
                          height: 98,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      intelligenceText(
                        context,
                        'Welcome to AI Coach',
                        'مرحبًا بك في المدرب الذكي',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontFamily: displayFamily,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: locale == 'ar' ? 0 : -.45,
                            height: locale == 'ar' ? 1.28 : 1.12,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      intelligenceText(
                        context,
                        'Speak your language',
                        'أتكلم لغتك',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFC5D2E3),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        color: Color(0xFF7BDFFF),
                        strokeWidth: 2.4,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CoachUndoOperation {
  _CoachUndoOperation({required this.receipt, required this.undo});

  final BilActionReceipt receipt;
  final Future<void> Function() undo;
  bool completed = false;
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
                    Icon(
                      Icons.verified_outlined,
                      size: 15,
                      color: scheme.onSurfaceVariant,
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
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
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

class _CoachHero extends StatelessWidget {
  const _CoachHero({
    super.key,
    required this.onBack,
    required this.onHistory,
    required this.onMenu,
    this.interactionEnabled = true,
  });

  final VoidCallback onBack;
  final VoidCallback onHistory;
  final VoidCallback onMenu;
  final bool interactionEnabled;

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFC8F3FF);
    final coachName = intelligenceText(context, 'Your BIL Coach', 'مدربك BIL');
    final voiceTagline = intelligenceText(
      context,
      'Speak your language',
      'أتكلم لغتك',
    );
    final voiceDescription = intelligenceText(
      context,
      'Global multilingual voice',
      'صوت متعدد اللغات',
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12394E), Color(0xFF071923)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(27),
          topRight: Radius.circular(27),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: Semantics(
        container: true,
        label: '$coachName. $voiceDescription',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 480 ||
                MediaQuery.textScalerOf(context).scale(14) > 19;
            final identity = Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coachName,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    voiceTagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: light),
                  ),
                ],
              ),
            );
            return Row(
              children: [
                _CoachHeroControl(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const BackButtonIcon(),
                  onPressed: onBack,
                ),
                const SizedBox(width: 6),
                _CoachHeroPortrait(
                  size: 48,
                  onTap: interactionEnabled ? onHistory : null,
                ),
                const SizedBox(width: 8),
                identity,
                _CoachHeroControl(
                  tooltip: intelligenceText(
                    context,
                    'Coach controls',
                    'أدوات المدرب',
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: interactionEnabled ? onMenu : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CoachHeroControl extends StatelessWidget {
  const _CoachHeroControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: .08),
      minimumSize: const Size.square(48),
      tapTargetSize: MaterialTapTargetSize.padded,
    ),
    icon: icon,
  );
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
    return Semantics(
      button: onTap != null,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          key: const Key('ai-coach-conversation-history-button'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFC8F3FF),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .7),
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: .24),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                size: 38,
                color: Colors.white,
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
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
          _VoiceListeningWave(color: scheme.primary, compact: true),
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
                    color: transcript.trim().isEmpty
                        ? scheme.primary
                        : scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (transcript.trim().isNotEmpty)
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: scheme.primary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
