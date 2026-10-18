part of 'food_log_page.dart';

extension _FoodLogActionTilePresentation on _FoodLogPageState {
  Widget _buildActionTile({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return BilPearlMaterialCard(
      key: key,
      margin: EdgeInsets.zero,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BilGlassPressFeedback(
                child: Icon(icon, size: 22, color: const Color(0xFF1677D2)),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _close(BuildContext context) {
    if (widget.preferNavigatorPop && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go(widget.returnPath ?? '/dashboard');
  }
}
