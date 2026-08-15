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

  String tr(BuildContext context, String en, String ar) =>
      onboardingText(context, en, ar);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = _WelcomeContent(
          isArabic: isArabic,
          onContinue: onContinue,
        );

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth >= 920 ? 42 : 20,
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
                          tr(context, 'Sign in', 'تسجيل الدخول'),
                          style: const TextStyle(color: Color(0xFF344054)),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Expanded(child: ListView(children: [content])),
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

  String tr(BuildContext context, String en, String ar) =>
      onboardingText(context, en, ar);

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
                tr(
                  context,
                  'WELCOME TO BODY CALIBRATION',
                  'مرحبًا بك في معايرة الجسم',
                ),
                style: const TextStyle(
                  color: _BilColors.emerald,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tr(
                  context,
                  'Let’s build your body model.',
                  'لنَبْنِ نموذج جسمك.',
                ),
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 32,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.3,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tr(
                  context,
                  'A focused calibration that turns a few trusted measurements into your first personal energy and nutrition plan.',
                  'معايرة مركزة تحول عددًا قليلًا من القياسات الموثوقة إلى أول خطة شخصية للطاقة والتغذية.',
                ),
                style: const TextStyle(
                  color: _BilColors.textMuted,
                  fontSize: 18,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              _WhyCard(isArabic: isArabic),
              const SizedBox(height: 22),
              _PrimaryButton(
                label: tr(context, 'Begin calibration', 'ابدأ المعايرة'),
                onPressed: onContinue,
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  context,
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
              onboardingText(
                context,
                'Every answer has a clear purpose: energy calculation, goal personalization, or better model accuracy.',
                'نطلب كل معلومة لسبب واضح: حساب الطاقة، تخصيص الهدف، أو تحسين دقة النموذج.',
              ),
              style: const TextStyle(color: _BilColors.textMuted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
