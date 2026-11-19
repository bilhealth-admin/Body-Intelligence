part of 'community_bil_code_page.dart';

class _OwnCodePrivacyGuidance extends StatefulWidget {
  const _OwnCodePrivacyGuidance({
    required this.repository,
    required this.ticket,
    super.key,
  });
  final CommunityRepository repository;
  final CommunityAccountTicket? ticket;
  @override
  State<_OwnCodePrivacyGuidance> createState() =>
      _OwnCodePrivacyGuidanceState();
}

class _OwnCodePrivacyGuidanceState extends State<_OwnCodePrivacyGuidance> {
  late Future<CommunityProfile?> _profile = _load();

  Future<CommunityProfile?> _load() async {
    final ticket = widget.ticket;
    if (ticket == null || !ticket.isCurrent) return null;
    try {
      final value = await ticket
          .run(widget.repository.loadMyProfile)
          .timeout(const Duration(seconds: 8));
      ticket.check();
      return value?.userId == ticket.owner ? value : null;
    } on Object {
      return null;
    }
  }

  Future<void> _openProfile() async {
    if (!mounted) return;
    final ticket = widget.ticket;
    if (ticket == null || !ticket.isCurrent) return;
    await context.push<void>('/community/profile');
    if (!mounted || !ticket.isCurrent) return;
    // Read the saved settings on return; never save, rotate the code or toggle
    // discovery/request permissions on the owner's behalf.
    setState(() {
      _profile = _load();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CommunityProfile?>(
    future: _profile,
    builder: (context, snapshot) {
      final current = widget.ticket?.isCurrent == true;
      final profile =
          current &&
              snapshot.connectionState == ConnectionState.done &&
              snapshot.data?.userId == widget.ticket?.owner
          ? snapshot.data
          : null;
      final blocked =
          profile != null &&
          (!profile.discoverable ||
              !profile.allowFriendRequests ||
              profile.visibility == CommunityProfileVisibility.private);
      final copy = CommunityCodePrivacyCopy.of(context);
      return Column(
        children: [
          Text(copy.intro, textAlign: TextAlign.center),
          if (blocked || profile == null) ...[
            const SizedBox(height: 12),
            BilPearlMaterialCard(
              key: Key(
                blocked
                    ? 'community-code-privacy-blocked'
                    : 'community-code-privacy-unknown',
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.privacy_tip_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(blocked ? copy.blocked : copy.check),
                        ),
                      ],
                    ),
                    if (profile != null && blocked) ...[
                      const SizedBox(height: 8),
                      if (!profile.discoverable)
                        Text(
                          '• ${communityText(context, 'Let people find me', 'السماح بالعثور عليّ')}',
                        ),
                      if (!profile.allowFriendRequests)
                        Text(
                          '• ${communityText(context, 'Allow friend requests', 'السماح بطلبات الصداقة')}',
                        ),
                      if (profile.visibility ==
                          CommunityProfileVisibility.private)
                        Text(
                          '• ${communityText(context, 'Who can see my profile', 'من يمكنه رؤية ملفي')}: ${communityText(context, 'Private', 'خاص')}',
                        ),
                    ],
                    TextButton.icon(
                      key: const Key('community-code-review-privacy'),
                      onPressed: current ? _openProfile : null,
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: Text(
                        communityText(
                          context,
                          'Open Community profile',
                          'فتح ملف المجتمع',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _BilQrPainter extends CustomPainter {
  _BilQrPainter(this.data)
    : image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
      );

  final String data;
  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final quietModules = image.moduleCount + 8;
    final cell = size.shortestSide / quietModules;
    final paint = Paint()..color = const Color(0xFF101828);
    for (var row = 0; row < image.moduleCount; row++) {
      for (var column = 0; column < image.moduleCount; column++) {
        if (!image.isDark(row, column)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (column + 4) * cell,
            (row + 4) * cell,
            cell + .1,
            cell + .1,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BilQrPainter oldDelegate) =>
      oldDelegate.data != data;
}
