part of '../bil_flagship_onboarding.dart';

class _CalibrationWelcome extends StatelessWidget {
  const _CalibrationWelcome({
    required this.isArabic,
    required this.onContinue,
    this.onSkip,
  });

  final bool isArabic;
  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  String tr(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;

        final content = _WelcomeContent(
          isArabic: isArabic,
          onContinue: onContinue,
        );
        const visual = _HologramPanel();

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 42 : 20,
            vertical: 20,
          ),
          child: Column(
            children: [
              _TopBar(
                trailing: onSkip == null
                    ? null
                    : TextButton(
                        onPressed: onSkip,
                        child: Text(
                          tr('Sign in', 'تسجيل الدخول'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(flex: 11, child: content),
                          const SizedBox(width: 28),
                          const Expanded(flex: 9, child: visual),
                        ],
                      )
                    : ListView(
                        children: [
                          const SizedBox(height: 340, child: visual),
                          const SizedBox(height: 24),
                          content,
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.isArabic, required this.onContinue});

  final bool isArabic;
  final VoidCallback onContinue;

  String tr(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('WELCOME TO BODY CALIBRATION', 'مرحبًا بك في معايرة الجسم'),
                style: const TextStyle(
                  color: _BilColors.emerald,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tr('Let’s build your\nbody model.', 'لنَبْنِ نموذج\nجسمك.'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.3,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tr(
                  'A focused calibration that turns a few trusted measurements into your first personal energy and nutrition plan.',
                  'معايرة مركزة تحول عددًا قليلًا من القياسات الموثوقة إلى أول خطة شخصية للطاقة والتغذية.',
                ),
                style: const TextStyle(
                  color: _BilColors.textMuted,
                  fontSize: 18,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              const _CalibrationCard(),
              const SizedBox(height: 18),
              _WhyCard(isArabic: isArabic),
              const SizedBox(height: 22),
              _PrimaryButton(
                label: tr('Begin calibration', 'ابدأ المعايرة'),
                onPressed: onContinue,
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  'Private by default. Your profile is created on this device.',
                  'خصوصيتك أولًا. يُنشأ ملفك على هذا الجهاز.',
                ),
                style: const TextStyle(color: _BilColors.textDim, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard();

  @override
  Widget build(BuildContext context) {
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    return _GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: CustomPaint(
              painter: _RingPainter(
                progress: .71,
                color: _BilColors.emerald,
                track: _BilColors.stroke,
              ),
              child: const Center(
                child: Text(
                  '71%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'معايرة BIL' : 'BIL Calibration',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic
                      ? 'نموذج أولي جيد — ستزيد الدقة مع كل إجابة.'
                      : 'A strong starting model — accuracy improves with every answer.',
                  style: const TextStyle(
                    color: _BilColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: _BilColors.emerald,
                      size: 18,
                    ),
                    SizedBox(width: 7),
                    Text(
                      '8 focused steps',
                      style: TextStyle(
                        color: _BilColors.emerald,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const _IconOrb(icon: Icons.shield_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isArabic
                  ? 'نطلب كل معلومة لسبب واضح: حساب الطاقة، تخصيص الهدف، أو تحسين دقة النموذج.'
                  : 'Every answer has a clear purpose: energy calculation, goal personalization, or better model accuracy.',
              style: const TextStyle(color: _BilColors.textMuted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
