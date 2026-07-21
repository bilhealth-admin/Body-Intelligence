import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/theme/premium_design_tokens.dart';
import '../../shared/widgets/premium_surface.dart';
import '../life_context/providers/life_context_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'providers/dashboard_provider.dart';
import 'widgets/dashboard_grid.dart';
import 'widgets/dashboard_header.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  Future<void> refresh(BuildContext context, WidgetRef ref) async {
    try {
      await Future.wait([
        ref.refresh(latestWeightProvider.future),
        ref.refresh(weightHistoryProvider.future),
        ref.refresh(userProfileProvider.future),
        ref.refresh(todayMealsProvider.future),
        ref.refresh(todayWaterProvider.future),
        ref.refresh(allMealsProvider.future),
        ref.refresh(allWaterProvider.future),
        ref.refresh(weightReminderSkippedTodayProvider.future),
        ref.refresh(todayLifeContextProvider.future),
      ]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('Today is up to date.'))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.text(
                'Some local Today data could not be refreshed.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final showFirstValue = ref.watch(firstValueHandoffProvider).value ?? false;

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
                center: Alignment(.12, -.18),
                radius: 1.2,
                colors: [
                  Color(0x301E87FF),
                  Color(0x1614C8D8),
                  Color(0x0001050D),
                ],
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => refresh(context, ref),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1180;
                  final compact = constraints.maxWidth < 700;
                  final horizontal = compact ? 16.0 : 28.0;

                  final hero = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DashboardTopBar(
                        arabic: arabic,
                        onProfile: () => context.go('/settings'),
                      ),
                      const SizedBox(height: 18),
                      if (showFirstValue) ...[
                        FirstValueHandoffCard(
                          onContinue: () async {
                            await ref
                                .read(preferencesRepositoryProvider)
                                .remove('firstValueHandoffPending');
                            if (context.mounted) {
                              context.go('/daily-check-in');
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                      ],
                      const DashboardHeader(),
                    ],
                  );

                  final content = wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: hero),
                            const SizedBox(width: 22),
                            const Expanded(flex: 7, child: DashboardGrid()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            hero,
                            const SizedBox(height: 22),
                            const DashboardGrid(),
                          ],
                        );

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      16,
                      horizontal,
                      120,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1380),
                        child: content,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FirstValueHandoffCard extends StatelessWidget {
  const FirstValueHandoffCard({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return PremiumSurface(
      emphasized: true,
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.strings.text('Your private starting point is ready'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFFE7EDF3),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            context.strings.text(
              'BIL saved your profile and starting targets on this device.',
            ),
            style: const TextStyle(color: Color(0xFFB8C5D1), height: 1.45),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: Color(0xFFDCE5EC),
              ),
              const SizedBox(width: PremiumDesignTokens.spaceXs),
              Expanded(
                child: Text(
                  context.strings.text(
                    'BIL does not have a comparable daily measurement yet, so it will not claim a trend.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFC1CCD6),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceMd),
          FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.monitor_weight_outlined),
            label: Text(context.strings.text('Record first check-in')),
          ),
        ],
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({required this.arabic, required this.onProfile});

  final bool arabic;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = MaterialLocalizations.of(context).formatMediumDate(now);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashboardBrand(),
              const SizedBox(height: 12),
              Text(
                date,
                style: const TextStyle(
                  color: Color(0xFFAEBBC7),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _RoundGlassButton(
          tooltip: arabic ? 'الملف الشخصي' : 'Profile',
          icon: Icons.account_circle_outlined,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _DashboardBrand extends StatelessWidget {
  const _DashboardBrand();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BIL®',
          style: TextStyle(
            color: Color(0xFFE9EFF4),
            fontSize: 56,
            height: .84,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.8,
            shadows: [Shadow(color: Color(0x704BD8FF), blurRadius: 28)],
          ),
        ),
        SizedBox(height: 7),
        Text(
          'BODY INTELLIGENCE LOG',
          style: TextStyle(
            color: Color(0xFFC2CDD7),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.0,
          ),
        ),
      ],
    );
  }
}

class _RoundGlassButton extends StatefulWidget {
  const _RoundGlassButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_RoundGlassButton> createState() => _RoundGlassButtonState();
}

class _RoundGlassButtonState extends State<_RoundGlassButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: hovered ? .16 : .10),
                const Color(0xFF50D9FF).withValues(alpha: .05),
                const Color(0xFF775FFF).withValues(alpha: .04),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF4CD8FF,
                ).withValues(alpha: hovered ? .22 : .11),
                blurRadius: hovered ? 26 : 18,
                spreadRadius: -7,
              ),
            ],
          ),
          child: IconButton(
            onPressed: widget.onTap,
            icon: Icon(widget.icon, color: const Color(0xFFE4EBF1)),
          ),
        ),
      ),
    );
  }
}
