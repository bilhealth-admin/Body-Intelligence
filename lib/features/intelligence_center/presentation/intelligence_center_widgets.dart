part of 'intelligence_center_page.dart';

const _bilMaleSmartCoachAsset =
    'assets/images/ai_coach/bil_male_smart_coach_v1.png';
const _bilMaleCoachFallbackAsset =
    'assets/images/flagship/bil_body_intelligence_journey_v1.png';

class _CoachMenuSheet extends StatelessWidget {
  const _CoachMenuSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              intelligenceText(context, 'Your BIL Coach', 'مدرب BIL الخاص بك'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              intelligenceText(
                context,
                'Memory and preferences stay one tap away.',
                'ذاكرتك وتفضيلاتك على بُعد لمسة.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _CoachMenuTile(
              icon: Icons.psychology_alt_rounded,
              title: intelligenceText(
                context,
                'What BIL remembers',
                'ماذا يتذكر BIL عني',
              ),
              subtitle: intelligenceText(
                context,
                'Review the context behind your decisions',
                'راجع السياق الذي يبني عليه قراراتك',
              ),
              onTap: () => Navigator.of(context).pop('memory'),
            ),
            const SizedBox(height: 9),
            _CoachMenuTile(
              icon: Icons.tune_rounded,
              title: intelligenceText(
                context,
                'Coach preferences',
                'تفضيلات المدرب',
              ),
              subtitle: intelligenceText(
                context,
                'Personal AI, voice, and response style',
                'الذكاء الشخصي والصوت وأسلوب الرد',
              ),
              onTap: () => Navigator.of(context).pop('settings'),
            ),
            const SizedBox(height: 9),
            _CoachMenuTile(
              icon: Icons.delete_sweep_outlined,
              title: intelligenceText(
                context,
                'Clear conversation',
                'مسح المحادثة',
              ),
              subtitle: intelligenceText(
                context,
                'Start a clean coaching session',
                'ابدأ جلسة تدريب جديدة',
              ),
              onTap: () => Navigator.of(context).pop('clear'),
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachMenuTile extends StatelessWidget {
  const _CoachMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = destructive ? scheme.error : const Color(0xFF12394E);
    return Material(
      color: destructive
          ? scheme.errorContainer.withValues(alpha: .22)
          : const Color(0xFFF2F7FA),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
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
    required this.onStart,
    required this.onStop,
    required this.onBack,
    required this.onMenu,
    required this.active,
    required this.status,
    required this.liveCallActive,
    required this.liveCallPaused,
  });

  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final bool active;
  final String status;
  final bool liveCallActive;
  final bool liveCallPaused;

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFC8F3FF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 13),
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
      child: Column(
        children: [
          Row(
            children: [
              _CoachHeroControl(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const BackButtonIcon(),
                onPressed: onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Row(
                    key: ValueKey(status),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (active) ...[
                        const _VoiceListeningWave(color: light, compact: true),
                        const SizedBox(width: 6),
                      ] else ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF65D59A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: light,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CoachHeroControl(
                tooltip: intelligenceText(
                  context,
                  'Coach controls',
                  'أدوات المدرب',
                ),
                icon: const Icon(Icons.tune_rounded, size: 19),
                onPressed: onMenu,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const _CoachHeroPortrait(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intelligenceText(context, 'Your BIL Coach', 'مدربك BIL'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      intelligenceText(
                        context,
                        'I speak every language and turn your body data into the next clear decision.',
                        'أتحدث كل اللغات، وأحوّل بيانات جسمك إلى قرارك التالي بوضوح.',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: .82),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextButton.icon(
                      key: const Key('ai-coach-hero-start'),
                      onPressed: onStart,
                      style: TextButton.styleFrom(
                        foregroundColor: light,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        liveCallActive && !liveCallPaused
                            ? Icons.pause_rounded
                            : Icons.graphic_eq_rounded,
                        size: 18,
                      ),
                      label: Text(
                        liveCallActive && !liveCallPaused
                            ? intelligenceText(
                                context,
                                'Pause live call',
                                'إيقاف المكالمة مؤقتًا',
                              )
                            : liveCallPaused
                            ? intelligenceText(
                                context,
                                'Resume live call',
                                'متابعة المكالمة',
                              )
                            : intelligenceText(
                                context,
                                'Start live call',
                                'ابدأ مكالمة مباشرة',
                              ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (liveCallActive)
                      TextButton.icon(
                        key: const Key('ai-coach-live-call-stop'),
                        onPressed: onStop,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.call_end_rounded, size: 17),
                        label: Text(
                          intelligenceText(
                            context,
                            'End call',
                            'إنهاء المكالمة',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: .08),
      minimumSize: const Size.square(36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: icon,
  );
}

class _CoachHeroPortrait extends StatelessWidget {
  const _CoachHeroPortrait();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFC8F3FF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: .7), width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          _bilMaleSmartCoachAsset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => Image.asset(
            _bilMaleCoachFallbackAsset,
            fit: BoxFit.cover,
            alignment: const Alignment(.18, -.72),
            excludeFromSemantics: true,
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
          child: Image.asset(
            _bilMaleSmartCoachAsset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => Image.asset(
              _bilMaleCoachFallbackAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(.18, -.72),
              excludeFromSemantics: true,
            ),
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
