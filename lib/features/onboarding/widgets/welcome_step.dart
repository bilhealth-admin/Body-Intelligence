import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services/app_settings_provider.dart';
import '../../../shared/widgets/bil_wordmark.dart';
import '../onboarding_locale_copy.dart';

part 'welcome_step_brand_components.dart';
part 'welcome_step_copy_panel.dart';

class WelcomeStep extends ConsumerWidget {
  const WelcomeStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appSettingsProvider).localeCode;
    final ar = locale == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(.28, -.22),
                radius: 1.2,
                colors: [
                  Color(0x183B82F6),
                  Color(0x0D22C7B8),
                  Color(0x00F7F8FB),
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
                        LayoutBuilder(
                          builder: (context, headerConstraints) {
                            final stackHeader =
                                headerConstraints.maxWidth < 560;
                            final languageSwitch = _LanguageSwitch(
                              locale: locale,
                              onChanged: (value) => ref
                                  .read(appSettingsProvider.notifier)
                                  .setLocale(value),
                            );
                            final brand = _MasterBrand(
                              logoSize: wide ? 60 : 44,
                              compact: !wide,
                            );

                            if (stackHeader) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  brand,
                                  const SizedBox(height: 10),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: languageSwitch,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Flexible(
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: languageSwitch,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Flexible(
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: brand,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: compactHeight ? 10 : 18),
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
            value: onboardingText(context, '74 bpm', '٧٤ نبضة/د'),
            label: onboardingText(context, 'Heart rate', 'معدل نبض القلب'),
          ),
        ),
        Positioned(
          top: 205,
          right: 0,
          child: _MetricBadge(
            value: onboardingText(context, '-0.6 kg', '−٠٫٦ كغ'),
            label: onboardingText(context, '7-day trend', 'اتجاه ٧ أيام'),
          ),
        ),
        Positioned(
          bottom: 62,
          left: 28,
          child: _MetricBadge(
            value: onboardingText(context, '84%', '٨٤٪'),
            label: onboardingText(
              context,
              'Predicted energy',
              'الطاقة المتوقعة',
            ),
          ),
        ),
        Positioned(
          bottom: 42,
          right: 10,
          child: _MetricBadge(
            value: onboardingText(context, 'High', 'مرتفعة'),
            label: onboardingText(context, 'Data quality', 'جودة البيانات'),
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
                Colors.white.withValues(alpha: .96),
                const Color(0xFFF5F8FC),
                const Color(0xFFF8FAFC),
                Colors.white.withValues(alpha: .90),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180F172A),
                blurRadius: 24,
                spreadRadius: -10,
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
          Icon(icon, color: const Color(0xFF2563EB), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: _MasterMetalText(
              label,
              size: 14,
              weight: FontWeight.w700,
              maxLines: 2,
            ),
          ),
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
          Icon(icon, color: const Color(0xFF2563EB), size: 32),
          const SizedBox(height: 14),
          _MasterMetalText(title, size: 20, weight: FontWeight.w700),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: Color(0xFF526072), height: 1.42),
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
          _MasterMetalText(value, size: 22, weight: FontWeight.w700),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF526072), fontSize: 12),
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
                            Color(0xFF2563EB),
                            Color(0xFF0EA5E9),
                            Color(0xFF2563EB),
                          ],
                        ),
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 360;
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 14 : 22,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 16 : 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: compact ? 8 : 14),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFFE7EEF5),
                            ),
                          ],
                        ),
                      );
                    },
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
