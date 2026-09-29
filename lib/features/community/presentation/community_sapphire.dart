import 'package:flutter/material.dart';

/// Community-only design tokens: never installed on dashboard/watch surfaces.
abstract final class CommunitySapphire {
  static const blue = Color(0xFF155EEF);
  static const navy = Color(0xFF14243A);
  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF101824)
      : const Color(0xFFF5F7FB);
  static Color paper(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1B283A)
      : Colors.white;
  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFBAC7D9)
      : const Color(0xFF5E6E83);
  static Color ink(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFF3F6FC)
      : navy;
}

class CommunityMessageBubble extends StatelessWidget {
  const CommunityMessageBubble({
    required this.mine,
    required this.child,
    super.key,
  });
  final bool mine;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => ConstrainedBox(
      constraints: BoxConstraints(maxWidth: bounds.maxWidth * .82),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: mine
              ? CommunitySapphire.blue
              : CommunitySapphire.paper(context),
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(20),
            topEnd: const Radius.circular(20),
            bottomStart: Radius.circular(mine ? 20 : 6),
            bottomEnd: Radius.circular(mine ? 6 : 20),
          ),
          border: mine
              ? null
              : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
