part of 'coach_reference_workspace.dart';

class _DarkCard extends StatelessWidget {
  const _DarkCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(13),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF20364C), Color(0xFF0C1725)],
      ),
      border: Border.all(color: const Color(0xFF3E5168), width: .6),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2013263C),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _NutrientTile extends StatelessWidget {
  const _NutrientTile({
    required this.label,
    required this.amount,
    required this.target,
    required this.accent,
    required this.progress,
    required this.locked,
    required this.onTap,
  });
  final String label, amount, target;
  final Color accent;
  final double progress;
  final bool locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _DarkCard(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (locked)
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 11,
                    color: Colors.white60,
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '$amount / $target',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: const Color(0xFF35485A),
                color: accent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String label, detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8F2FF),
            ),
            child: Icon(icon, size: 17, color: Color(0xFF1677FF)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF101D2D),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF738196),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 15,
            color: Color(0xFF9DACC0),
          ),
        ],
      ),
    ),
  );
}
