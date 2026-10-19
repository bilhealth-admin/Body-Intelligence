part of 'meal_vision_premium_review.dart';

const _bgBottom = Color(0xFF021614);
const _mint = Color(0xFF56F3B3);
const _muted = Color(0xFFADC4C8);
const _outline = Color(0x334BD9BA);

bool _light(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;
Color _foreground(BuildContext context) =>
    _light(context) ? const Color(0xFF102B32) : Colors.white;
Color _secondary(BuildContext context) =>
    _light(context) ? const Color(0xFF46636B) : _muted;
Color _accent(BuildContext context) =>
    _light(context) ? const Color(0xFF087A5D) : _mint;

BoxDecoration _glassDecoration(BuildContext context, {bool active = false}) {
  final panel = BilPearlFinish.panel(
    context,
    radius: BorderRadius.circular(16),
  );
  return active
      ? panel.copyWith(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        )
      : panel;
}

Widget _glassShell(BuildContext context, Widget child) {
  return RepaintBoundary(
    key: const Key('premium-vision-render-surface'),
    child: Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: BilPearlFinish.background(context)),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: SizedBox(width: double.infinity, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
