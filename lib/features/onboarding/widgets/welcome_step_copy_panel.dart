part of 'welcome_step.dart';

class _CopyPanel extends StatelessWidget {
  const _CopyPanel({
    required this.ar,
    required this.onContinue,
    required this.compactHeight,
  });

  final bool ar;
  final VoidCallback onContinue;
  final bool compactHeight;

  @override
  Widget build(BuildContext context) {
    String t(String en, String arText) => onboardingText(context, en, arText);
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MasterMetalText(
            t('PRIVATE BODY INTELLIGENCE', 'ذكاء شخصي لفهم الجسم'),
            size: 14,
            weight: FontWeight.w700,
          ),
          SizedBox(height: compactHeight ? 10 : 18),
          _MasterMetalText(
            t('Welcome', 'مرحبًا بك'),
            size: compactHeight ? 34 : 40,
            weight: FontWeight.w700,
          ),
          SizedBox(height: compactHeight ? 9 : 14),
          _MasterMetalText(
            t(
              'Start your journey toward a healthier, stronger and smarter body with a personal model that learns from your data.',
              'ابدأ رحلتك نحو جسم أكثر صحة وقوة وذكاء مع نموذج شخصي يتعلم من بياناتك.',
            ),
            size: compactHeight ? 17 : 19,
            weight: FontWeight.w600,
          ),
          SizedBox(height: compactHeight ? 14 : 18),
          _InfoCard(
            icon: Icons.shield_outlined,
            title: t('Private and explainable', 'خصوصية ووضوح'),
            body: t(
              'Your data stays on this device unless you choose to sync it. Evidence remains visible.',
              'تبقى بياناتك على هذا الجهاز ما لم تختر مزامنتها، وتظل الأدلة واضحة.',
            ),
          ),
          SizedBox(height: compactHeight ? 14 : 18),
          _MasterGlassButton(
            label: t('Start your journey', 'ابدأ رحلتك'),
            onTap: onContinue,
          ),
          const SizedBox(height: 12),
          Text(
            t(
              'No account required. Nothing is uploaded.',
              'لا يلزم إنشاء حساب. تبقى بيانات ملفك الصحي على هذا الجهاز أثناء هذه الخطوة.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF475467), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
