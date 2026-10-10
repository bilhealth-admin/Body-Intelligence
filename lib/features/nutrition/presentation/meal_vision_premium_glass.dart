part of 'meal_vision_premium_review.dart';

const _bgTop = Color(0xFF071820);
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
  final light = _light(context);
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: light
          ? (active
                ? const [Color(0xFFF3FFF8), Color(0xFFDDF4E9)]
                : const [Color(0xFFFFFFFF), Color(0xFFEDF6F5)])
          : (active
                ? const [Color(0xE51A453C), Color(0xEE06231F)]
                : const [Color(0xE51C3740), Color(0xEE071D25)]),
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: light
          ? (active ? const Color(0xFF43AA81) : const Color(0x22546A70))
          : (active ? const Color(0xAA56F3B3) : const Color(0x555B7D87)),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: light ? .04 : .18),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

Widget _glassShell(BuildContext context, Widget child) {
  final light = _light(context);
  return RepaintBoundary(
    key: const Key('premium-vision-render-surface'),
    child: Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: light
                ? const [Color(0xFFF3FCF8), Color(0xFFE7F4F0), Colors.white]
                : const [_bgTop, Color(0xFF06272A), _bgBottom],
          ),
        ),
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
