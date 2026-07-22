import 'package:flutter/material.dart';

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.arabic,
    required this.onProfile,
  });

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
              const DashboardBrand(),
              const SizedBox(height: 12),
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

class DashboardBrand extends StatelessWidget {
  const DashboardBrand({super.key});

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
