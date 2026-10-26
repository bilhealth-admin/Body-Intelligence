import 'package:flutter/material.dart';
import '../../../app/theme/bil_pearl_finish.dart';

/// Community-only design tokens: never installed on dashboard/watch surfaces.
abstract final class CommunitySapphire {
  static const blue = Color(0xFF155EEF);
  static const navy = Color(0xFF14243A);

  /// Every stop maintains at least 4.5:1 contrast against white text.
  static LinearGradient messageGradient(BuildContext context) => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: Theme.of(context).brightness == Brightness.dark
        ? const [Color(0xFF2B609B), Color(0xFF224F83), Color(0xFF1D416F)]
        : const [Color(0xFF1D5FBC), Color(0xFF1854A7), Color(0xFF174786)],
  );
  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? BilPearlFinish.darkCanvas
      : BilPearlFinish.lightCanvas;
  static Color paper(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? BilPearlFinish.darkSurface
      : BilPearlFinish.lightSurface;
  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? BilPearlFinish.darkSecondary
      : BilPearlFinish.lightSecondary;
  static Color ink(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFF3F6FC)
      : navy;
}

class CommunityMessageBubble extends StatelessWidget {
  const CommunityMessageBubble({
    required this.mine,
    required this.child,
    this.nativeCanvas = false,
    super.key,
  });
  final bool mine;
  final Widget child;
  final bool nativeCanvas;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: nativeCanvas ? bounds.maxWidth : bounds.maxWidth * .82,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: nativeCanvas
            ? null
            : BoxDecoration(
                color: mine
                    ? CommunitySapphire.blue
                    : CommunitySapphire.paper(context),
                gradient: mine
                    ? CommunitySapphire.messageGradient(context)
                    : BilPearlFinish.panel(context, shadow: false).gradient,
                boxShadow: MediaQuery.highContrastOf(context)
                    ? const []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                borderRadius: BorderRadiusDirectional.only(
                  topStart: const Radius.circular(20),
                  topEnd: const Radius.circular(20),
                  bottomStart: Radius.circular(mine ? 20 : 6),
                  bottomEnd: Radius.circular(mine ? 6 : 20),
                ),
                border: Border.all(
                  color: MediaQuery.highContrastOf(context)
                      ? (mine ? Colors.white : CommunitySapphire.ink(context))
                      : mine
                      ? Colors.white.withValues(alpha: .18)
                      : Theme.of(context).brightness == Brightness.dark
                      ? BilPearlFinish.darkEdge
                      : BilPearlFinish.lightEdge,
                  width: MediaQuery.highContrastOf(context) ? 1.5 : .8,
                ),
              ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: mine ? Colors.white : CommunitySapphire.ink(context),
            height: 1.5,
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Group by peer identity, not a shared name. Preserve the stored subject/body.
List<Map<String, dynamic>> communityThreadPreviewRows(
  List<Map<String, dynamic>> rows, {
  required bool incoming,
}) {
  final ordered = List<Map<String, dynamic>>.of(rows)
    ..sort((a, b) {
      final left = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final right = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (left != null && right != null) {
        final time = right.compareTo(left);
        if (time != 0) return time;
      }
      return '${b['id']}'.compareTo('${a['id']}');
    });
  final peers = <String>{};
  return [
    for (final row in ordered)
      if (row[incoming ? 'sender_id' : 'recipient_id'] is String &&
          (row[incoming ? 'sender_id' : 'recipient_id'] as String).isNotEmpty &&
          peers.add(row[incoming ? 'sender_id' : 'recipient_id'] as String))
        row,
  ];
}

int communityThreadUnreadCount(
  String peer,
  List<Map<String, dynamic>> rows, {
  Map<String, int>? authoritative,
}) => authoritative != null
    ? (authoritative[peer] ?? 0)
    : rows.where((r) => r['sender_id'] == peer && r['read_at'] == null).length;
