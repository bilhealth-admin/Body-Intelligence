import 'package:flutter/material.dart';

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.arabic,
    required this.displayName,
    required this.onProfile,
  });

  final bool arabic;
  final String? displayName;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = MaterialLocalizations.of(context).formatMediumDate(now);
    final unifiedDesktopNavigation = MediaQuery.sizeOf(context).width >= 900;

    final greeting = Text(
      displayName == null
          ? (arabic ? 'أهلًا بك' : 'Welcome')
          : (arabic ? 'أهلًا، $displayName' : 'Welcome, $displayName'),
      key: const Key('dashboard-greeting'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );
    final dateText = Text(
      date,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );

    if (unifiedDesktopNavigation) {
      return Row(
        children: [
          Expanded(child: greeting),
          const SizedBox(width: 16),
          dateText,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: arabic
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: const Directionality(
                  textDirection: TextDirection.ltr,
                  child: DashboardBrand(),
                ),
              ),
              const SizedBox(height: 12),
              greeting,
              const SizedBox(height: 6),
              dateText,
            ],
          ),
        ),
        _RoundGlassButton(
          tooltip: arabic ? 'الملف الشخصي' : 'Profile',
          icon: Icons.person_rounded,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class DashboardBrand extends StatelessWidget {
  const DashboardBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BIL®',
          style: TextStyle(
            color: scheme.onSurface,
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
            color: scheme.onSurfaceVariant,
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
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF8CEAFF).withValues(alpha: .30),
                    const Color(0xFF7668FF).withValues(alpha: .18),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .22)),
              ),
              child: Icon(
                widget.icon,
                size: 23,
                color: const Color(0xFF8D99A6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
