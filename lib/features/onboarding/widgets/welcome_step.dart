import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services/app_settings_provider.dart';

class WelcomeStep extends ConsumerWidget {
  const WelcomeStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appSettingsProvider).localeCode;
    final ar = locale == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFF01050D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/v10_master/bil_hdr_starfield_master.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(.28, -.22),
                radius: 1.2,
                colors: [
                  Color(0x301F86FF),
                  Color(0x1615D4DE),
                  Color(0x0001050D),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 930;
                final compactHeight = constraints.maxHeight < 720;
                final horizontal = wide ? 44.0 : 18.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    compactHeight ? 12 : 22,
                    horizontal,
                    24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight - (compactHeight ? 36 : 54),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _LanguageSwitch(
                              locale: locale,
                              onChanged: (value) => ref
                                  .read(appSettingsProvider.notifier)
                                  .setLocale(value),
                            ),
                            const Spacer(),
                            _MasterBrand(
                              logoSize: wide ? 82 : 62,
                              compact: !wide,
                            ),
                          ],
                        ),
                        SizedBox(height: compactHeight ? 12 : 28),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: compactHeight ? 470 : 610,
                                  child: _HeroVisual(ar: ar),
                                ),
                              ),
                              const SizedBox(width: 44),
                              Expanded(
                                child: _CopyPanel(
                                  ar: ar,
                                  onContinue: onContinue,
                                  compactHeight: compactHeight,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _CopyPanel(
                            ar: ar,
                            onContinue: onContinue,
                            compactHeight: compactHeight,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(height: 470, child: _HeroVisual(ar: ar)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterBrand extends StatelessWidget {
  const _MasterBrand({this.logoSize = 72, this.compact = false});

  final double logoSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFE7EDF4),
              Color(0xFF98A7B6),
              Color(0xFFF7FBFF),
            ],
            stops: [0, .35, .72, 1],
          ).createShader(rect),
          child: Text(
            'BIL®',
            style: TextStyle(
              color: Colors.white,
              fontSize: logoSize,
              height: .86,
              fontWeight: FontWeight.w900,
              letterSpacing: -3,
              shadows: const [
                Shadow(color: Color(0x705ACBFF), blurRadius: 28),
                Shadow(color: Color(0x40785CFF), blurRadius: 42),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 5 : 9),
        Text(
          'BODY INTELLIGENCE LOG',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFD5DFE8),
            fontSize: compact ? 8 : 11,
            fontWeight: FontWeight.w700,
            letterSpacing: compact ? 2.2 : 4.2,
            shadows: const [Shadow(color: Color(0x4055CFFF), blurRadius: 12)],
          ),
        ),
      ],
    );
  }
}

class _MasterMetalText extends StatelessWidget {
  const _MasterMetalText(
    this.text, {
    required this.size,
    this.weight = FontWeight.w700,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final double size;
  final FontWeight weight;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFD8E1E9),
          Color(0xFF8F9EAD),
          Color(0xFFF8FBFF),
        ],
      ).createShader(rect),
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: size,
          height: 1.22,
          fontWeight: weight,
        ),
      ),
    );
  }
}

class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch({required this.locale, required this.onChanged});

  final String locale;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _MasterGlass(
      radius: 28,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LanguageItem(
            label: 'العربية',
            selected: locale == 'ar',
            onTap: () => onChanged('ar'),
          ),
          _LanguageItem(
            label: 'English',
            selected: locale == 'en',
            onTap: () => onChanged('en'),
          ),
        ],
      ),
    );
  }
}

class _LanguageItem extends StatelessWidget {
  const _LanguageItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0x4736D9FF), Color(0x264F5EFF)],
                )
              : null,
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x454CD7FF),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFF4F8FC) : const Color(0xFF98A8B8),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CopyPanel extends StatelessWidget {
  const _CopyPanel({
    required this.ar,
    required this.onContinue,
    required this.compactHeight,
  });

  final bool ar;
  final VoidCallback onContinue;
  final bool compactHeight;

  String t(String en, String arText) => ar ? arText : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MasterMetalText(
            t('PRIVATE BODY INTELLIGENCE', 'ذكاء شخصي لفهم الجسم'),
            size: 14,
            weight: FontWeight.w900,
          ),
          SizedBox(height: compactHeight ? 10 : 18),
          _MasterMetalText(
            t('Welcome', 'مرحبًا بك'),
            size: compactHeight ? 40 : 52,
            weight: FontWeight.w900,
          ),
          SizedBox(height: compactHeight ? 9 : 14),
          _MasterMetalText(
            t(
              'Start your journey toward a healthier, stronger and smarter body with a personal model that learns from your data.',
              'ابدأ رحلتك نحو جسم أكثر صحة وقوة وذكاء مع نموذج شخصي يتعلم من بياناتك.',
            ),
            size: compactHeight ? 20 : 24,
            weight: FontWeight.w700,
          ),
          SizedBox(height: compactHeight ? 14 : 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _WelcomeChip(
                Icons.lock_outline_rounded,
                t('Private', 'خصوصية تامة'),
              ),
              _WelcomeChip(
                Icons.wifi_off_rounded,
                t('Offline', 'يعمل دون إنترنت'),
              ),
              _WelcomeChip(
                Icons.lightbulb_outline_rounded,
                t('Explainable', 'نتائج قابلة للتفسير'),
              ),
            ],
          ),
          SizedBox(height: compactHeight ? 14 : 22),
          LayoutBuilder(
            builder: (context, c) {
              final stack = c.maxWidth < 570;
              final first = _InfoCard(
                icon: Icons.shield_outlined,
                title: t('Understand every insight', 'افهم كل استنتاج'),
                body: t(
                  'Evidence and confidence stay visible.',
                  'تبقى الأدلة ودرجة الثقة واضحة أمامك.',
                ),
              );
              final second = _InfoCard(
                icon: Icons.science_outlined,
                title: t('Science first', 'العلم قبل الادعاء'),
                body: t(
                  'Measured facts remain separate from estimates.',
                  'يفصل BIL بوضوح بين الحقائق والتقديرات.',
                ),
              );
              return stack
                  ? Column(
                      children: [first, const SizedBox(height: 10), second],
                    )
                  : Row(
                      children: [
                        Expanded(child: first),
                        const SizedBox(width: 12),
                        Expanded(child: second),
                      ],
                    );
            },
          ),
          SizedBox(height: compactHeight ? 14 : 22),
          _MasterGlassButton(
            label: t('Start your journey', 'ابدأ رحلتك'),
            onTap: onContinue,
          ),
          const SizedBox(height: 12),
          Text(
            t(
              'No account required. Nothing is uploaded.',
              'لا يلزم إنشاء حساب، ولا يتم رفع أي بيانات.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFAAB7C4), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual({required this.ar});

  final bool ar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 520,
          height: 520,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF2DDCFF).withValues(alpha: .17),
                const Color(0xFF795EFF).withValues(alpha: .07),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: Image.asset(
            'assets/images/v10_master/bil_hologram_master.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        Positioned(
          top: 82,
          left: 18,
          child: _MetricBadge(
            value: ar ? '٧٤ نبضة/د' : '74 bpm',
            label: ar ? 'معدل نبض القلب' : 'Heart rate',
          ),
        ),
        Positioned(
          top: 205,
          right: 0,
          child: _MetricBadge(
            value: ar ? '−٠٫٦ كغ' : '-0.6 kg',
            label: ar ? 'اتجاه ٧ أيام' : '7-day trend',
          ),
        ),
        Positioned(
          bottom: 62,
          left: 28,
          child: _MetricBadge(
            value: ar ? '٨٤٪' : '84%',
            label: ar ? 'الطاقة المتوقعة' : 'Predicted energy',
          ),
        ),
        Positioned(
          bottom: 42,
          right: 10,
          child: _MetricBadge(
            value: ar ? 'مرتفعة' : 'High',
            label: ar ? 'جودة البيانات' : 'Data quality',
          ),
        ),
      ],
    );
  }
}

class _MasterGlass extends StatelessWidget {
  const _MasterGlass({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .105),
                const Color(0xFF50C9FF).withValues(alpha: .042),
                const Color(0xFF765CFF).withValues(alpha: .034),
                Colors.white.withValues(alpha: .018),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x251B8BFF),
                blurRadius: 34,
                spreadRadius: -12,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _WelcomeChip extends StatelessWidget {
  const _WelcomeChip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _MasterGlass(
      radius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFCFD9E3), size: 18),
          const SizedBox(width: 8),
          _MasterMetalText(label, size: 14, weight: FontWeight.w800),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _MasterGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFC8D7E5), size: 32),
          const SizedBox(height: 14),
          _MasterMetalText(title, size: 20, weight: FontWeight.w900),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: Color(0xFFC0CBD6), height: 1.42),
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _MasterGlass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MasterMetalText(value, size: 22, weight: FontWeight.w900),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFB7C4D0), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MasterGlassButton extends StatefulWidget {
  const _MasterGlassButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_MasterGlassButton> createState() => _MasterGlassButtonState();
}

class _MasterGlassButtonState extends State<_MasterGlassButton> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() {
        hovered = false;
        pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onTapUp: (_) {
          setState(() => pressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: pressed ? .982 : (hovered ? 1.012 : 1),
          duration: const Duration(milliseconds: 160),
          child: _MasterGlass(
            radius: 24,
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 66,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    opacity: hovered ? 1 : .55,
                    duration: const Duration(milliseconds: 180),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x2448E6FF),
                            Color(0x18775EFF),
                            Color(0x1248E6FF),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MasterMetalText(
                        widget.label,
                        size: 18,
                        weight: FontWeight.w900,
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFFE7EEF5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
