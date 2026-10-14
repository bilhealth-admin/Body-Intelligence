import '../../../shared/widgets/bil_glass_press_feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr/qr.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../shared/widgets/bil_account_avatar.dart';
import '../data/community_public_code_failure.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'community_copy.dart';
import 'community_account_visit.dart';
import 'community_return_button.dart';
import 'community_member_share.dart';
import '../../notifications/domain/community_deep_link.dart';

part 'community_code_failure_widgets.dart';

CommunityRepository? _productionCodeRepository() {
  if (!AppEnvironment.communityConfigured) return null;
  try {
    final supabase = Supabase.instance;
    if (!supabase.isInitialized || supabase.client.auth.currentUser == null) {
      return null;
    }
    return CommunityRepository(supabase.client);
  } on Object {
    return null;
  }
}

class CommunityBilCodePage extends StatefulWidget {
  const CommunityBilCodePage({this.repository, super.key});

  final CommunityRepository? repository;

  @override
  State<CommunityBilCodePage> createState() => _CommunityBilCodePageState();
}

class _CommunityBilCodePageState extends State<CommunityBilCodePage> {
  CommunityRepository? _repository;
  CommunityAccountVisit? _visit;
  Future<CommunityPublicCode>? _code;

  @override
  void initState() {
    super.initState();
    _bindAccount();
  }

  void _bindAccount() {
    _rotating = false;
    _rotationSubmitted = false;
    _repository = widget.repository ?? _productionCodeRepository();
    _visit = CommunityAccountVisit(
      repository: _repository,
      client: _repository?.communitySocialClient,
      onChanged: () {
        if (!mounted) return;
        setState(() {
          _rotating = false;
          _rotationSubmitted = false;
          _code = _loadCode();
        });
      },
    );
    _code = _loadCode();
  }

  Future<CommunityPublicCode>? _loadCode() {
    final ticket = _visit?.capture();
    final repository = _repository;
    final pending = ticket == null || repository == null
        ? null
        : ticket.run(repository.loadPublicCode);
    // An A -> B -> A boundary can retire B before FutureBuilder attaches.
    // Observe that discarded future while keeping its original error available
    // to the active FutureBuilder, which still renders the failure and Retry.
    pending?.ignore();
    return pending;
  }

  @override
  void didUpdateWidget(covariant CommunityBilCodePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _visit?.dispose();
      _bindAccount();
    }
  }

  @override
  void dispose() {
    _visit?.dispose();
    super.dispose();
  }

  bool _rotating = false;
  bool _rotationSubmitted = false;
  bool _sharing = false;

  void _retry() => setState(() {
    _code = _loadCode();
  });

  Future<void> _share(
    CommunityPublicCode code,
    BuildContext anchorContext,
    CommunityAccountTicket? ticket,
    Future<CommunityPublicCode>? displayedCodeFuture,
  ) async {
    if (_sharing ||
        _rotating ||
        ticket == null ||
        !ticket.isCurrent ||
        displayedCodeFuture == null ||
        !identical(displayedCodeFuture, _code)) {
      return;
    }
    setState(() => _sharing = true);
    try {
      final box = anchorContext.findRenderObject() as RenderBox?;
      ticket.check();
      if (_rotating || !identical(displayedCodeFuture, _code)) {
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          text: CommunityMemberShare.messageFor(
            code,
            locale: Localizations.localeOf(context).toLanguageTag(),
          ),
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted && ticket.isCurrent) _showFailure();
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _rotate(CommunityAccountTicket? ticket) async {
    final repository = _repository;
    if (_rotating ||
        repository == null ||
        ticket == null ||
        !ticket.isCurrent) {
      return;
    }
    setState(() => _rotating = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ListenableBuilder(
          listenable: ticket.visit,
          builder: (_, _) => AlertDialog(
            title: Text(
              communityText(
                dialogContext,
                'Replace your BIL Code?',
                'استبدال رمز BIL؟',
              ),
            ),
            content: Text(
              communityText(
                dialogContext,
                ticket.isCurrent
                    ? 'Your old code will stop working. Friends will need the new one.'
                    : 'Your account changed. Return to Community to continue.',
                ticket.isCurrent
                    ? 'سيتوقف الرمز القديم عن العمل وسيحتاج الأصدقاء إلى الرمز الجديد.'
                    : 'تغير حسابك. ارجع إلى المجتمع للمتابعة.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(communityText(dialogContext, 'Cancel', 'إلغاء')),
              ),
              FilledButton(
                onPressed: ticket.isCurrent
                    ? () {
                        if (ticket.isCurrent) {
                          Navigator.pop(dialogContext, true);
                        }
                      }
                    : null,
                child: Text(
                  communityText(dialogContext, 'Replace code', 'استبدال الرمز'),
                ),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted || !ticket.isCurrent) return;
      setState(() => _rotationSubmitted = true);
      final next = await ticket.run(repository.rotatePublicCode);
      if (mounted && ticket.isCurrent) {
        setState(() {
          _code = Future.value(next);
        });
      }
    } catch (_) {
      if (mounted && ticket.isCurrent) {
        if (_rotationSubmitted) {
          setState(() {
            _code = _loadCode();
          });
          _showFailure(checkingCurrentCode: true);
        } else {
          _showFailure();
        }
      }
    } finally {
      if (mounted && ticket.isCurrent) {
        setState(() {
          _rotating = false;
          _rotationSubmitted = false;
        });
      }
    }
  }

  void _showFailure({bool checkingCurrentCode = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          communityText(
            context,
            checkingCurrentCode
                ? 'Rotation could not be confirmed. Checking your current BIL Code before sharing.'
                : 'Your BIL Code is unavailable right now. Try again.',
            checkingCurrentCode
                ? 'لم يتأكد تغيير الرمز. نتحقق من رمز BIL الحالي قبل مشاركته.'
                : 'رمز BIL غير متاح الآن. حاول مجددًا.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const CommunityReturnButton(),
      title: Text(communityText(context, 'My BIL Code', 'رمز BIL الخاص بي')),
    ),
    body: _repository == null || _code == null
        ? const _CodeUnavailable(
            failure: CommunityPublicCodeFailure.authenticationRequired(),
            onRetry: null,
            forOwnCode: true,
          )
        : FutureBuilder<CommunityPublicCode>(
            key: ValueKey(_visit?.epoch),
            future: _code,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final code = snapshot.data;
              if (snapshot.hasError || code == null) {
                final error = snapshot.error;
                final failure = error is Object
                    ? CommunityPublicCodeFailure.fromError(error)
                    : const CommunityPublicCodeFailure.unavailable();
                return _CodeUnavailable(
                  failure: failure,
                  onRetry: _retry,
                  forOwnCode: true,
                  onOpenProfile: () => context.push('/community/profile'),
                );
              }
              final displayedTicket = _visit?.capture();
              final displayedCodeFuture = _code;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    communityText(
                      context,
                      'Let a friend scan this code. It only identifies your public Community profile; it cannot sign anyone in.',
                      'دع صديقًا يمسح هذا الرمز. فهو يعرّف بملفك العام في المجتمع فقط ولا يمكنه تسجيل دخول أي شخص.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: RepaintBoundary(
                      key: const Key('community-bil-code-qr'),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: CustomPaint(
                            size: const Size.square(232),
                            painter: _BilQrPainter(code.uri.toString()),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    '@${code.handle}',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  Builder(
                    builder: (shareContext) => FilledButton.icon(
                      key: const Key('community-bil-code-share'),
                      onPressed: _sharing || _rotating
                          ? null
                          : () => _share(
                              code,
                              shareContext,
                              displayedTicket,
                              displayedCodeFuture,
                            ),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(
                        communityText(context, 'Share code', 'مشاركة الرمز'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('community-bil-code-rotate'),
                    onPressed: _rotating
                        ? null
                        : () => _rotate(displayedTicket),
                    icon: _rotationSubmitted
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const BilGlassPressFeedback(
                            child: Icon(Icons.refresh_rounded),
                          ),
                    label: Text(
                      communityText(
                        context,
                        'Replace this code',
                        'استبدال هذا الرمز',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
  );
}

class CommunityCodeScannerPage extends StatefulWidget {
  const CommunityCodeScannerPage({this.scannerEnabled = true, super.key});

  final bool scannerEnabled;

  static String? codeFromPayload(String? rawValue) {
    final uri = rawValue == null ? null : Uri.tryParse(rawValue.trim());
    if (uri?.scheme.toLowerCase() == 'https') {
      final route = CommunityDeepLink.routeFor(uri!);
      const prefix = '/community/member/';
      return route != null && route.startsWith(prefix)
          ? route.substring(prefix.length)
          : null;
    }
    if (uri == null ||
        uri.scheme != 'bil' ||
        uri.host != 'community' ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'member' ||
        uri.queryParameters.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final code = uri.pathSegments.last.toLowerCase();
    return CommunityPublicCode.codePattern.hasMatch(code) ? code : null;
  }

  @override
  State<CommunityCodeScannerPage> createState() =>
      _CommunityCodeScannerPageState();
}

class _CommunityCodeScannerPageState extends State<CommunityCodeScannerPage> {
  late final MobileScannerController _controller = MobileScannerController(
    autoStart: widget.scannerEnabled,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;
  String? _message;

  bool get _supported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    String? code;
    for (final barcode in capture.barcodes) {
      code = CommunityCodeScannerPage.codeFromPayload(barcode.rawValue);
      if (code != null) break;
    }
    if (code == null) {
      if (mounted) {
        setState(() {
          _message = communityText(
            context,
            'This is not a current BIL friend code.',
            'هذا ليس رمز صديق BIL حاليًا.',
          );
        });
      }
      return;
    }
    _handled = true;
    await _controller.stop();
    if (mounted) context.pushReplacement('/community/member/$code');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const CommunityReturnButton(fallbackLocation: '/community/code'),
      title: Text(communityText(context, 'Scan Friend Code', 'مسح رمز صديق')),
    ),
    body: !widget.scannerEnabled || !_supported
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                communityText(
                  context,
                  'Code scanning needs an iOS or Android camera.',
                  'يتطلب مسح الرمز كاميرا iOS أو Android.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) =>
                    _CodeScannerFailure(onRetry: _controller.start),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _message ??
                          communityText(
                            context,
                            'Point the camera at a BIL friend code. Nothing is uploaded.',
                            'وجّه الكاميرا إلى رمز صديق BIL. لا يتم رفع أي شيء.',
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}

class CommunityMemberCodePage extends StatefulWidget {
  const CommunityMemberCodePage({
    required this.code,
    this.repository,
    super.key,
  });

  final String code;
  final CommunityRepository? repository;

  @override
  State<CommunityMemberCodePage> createState() =>
      _CommunityMemberCodePageState();
}

class _CommunityMemberCodePageState extends State<CommunityMemberCodePage> {
  CommunityRepository? _repository;
  CommunityAccountVisit? _visit;
  Future<CommunityResolvedMember?>? _member;

  @override
  void initState() {
    super.initState();
    _bindAccount();
  }

  void _bindAccount() {
    _repository = widget.repository ?? _productionCodeRepository();
    _visit = CommunityAccountVisit(
      repository: _repository,
      client: _repository?.communitySocialClient,
      onChanged: () {
        if (!mounted) return;
        setState(() {
          _relationship = null;
          _requesting = false;
          _member = _loadMember();
        });
      },
    );
    _member = _loadMember();
  }

  Future<CommunityResolvedMember?>? _loadMember() {
    final ticket = _visit?.capture();
    final repository = _repository;
    return ticket == null || repository == null
        ? null
        : ticket.run(() => repository.resolvePublicCode(widget.code));
  }

  @override
  void didUpdateWidget(covariant CommunityMemberCodePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.code != widget.code) {
      _visit?.dispose();
      _relationship = null;
      _requesting = false;
      _bindAccount();
    }
  }

  @override
  void dispose() {
    _visit?.dispose();
    super.dispose();
  }

  CommunityRelationshipStatus? _relationship;
  bool _requesting = false;

  void _retry() => setState(() {
    _relationship = null;
    _member = _loadMember();
  });

  Future<void> _request(
    CommunityResolvedMember member,
    CommunityAccountTicket? ticket,
  ) async {
    final repository = _repository;
    if (_requesting ||
        repository == null ||
        ticket == null ||
        !ticket.isCurrent) {
      return;
    }
    setState(() => _requesting = true);
    try {
      final result = await ticket.run(
        () => repository.requestFriend(member.userId),
      );
      if (!mounted || !ticket.isCurrent) return;
      setState(() {
        _relationship = switch (result) {
          CommunityFriendRequestStatus.pending =>
            CommunityRelationshipStatus.pending,
          CommunityFriendRequestStatus.incoming =>
            CommunityRelationshipStatus.incoming,
          CommunityFriendRequestStatus.accepted =>
            CommunityRelationshipStatus.accepted,
          CommunityFriendRequestStatus.declined =>
            CommunityRelationshipStatus.none,
        };
      });
    } catch (_) {
      if (mounted && ticket.isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              communityText(
                context,
                'Friend request could not be sent. Try again.',
                'تعذر إرسال طلب الصداقة. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted && ticket.isCurrent) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const CommunityReturnButton(),
      title: Text(communityText(context, 'BIL member', 'عضو BIL')),
    ),
    body: _repository == null || _member == null
        ? const _CodeUnavailable(
            failure: CommunityPublicCodeFailure.unavailable(),
            onRetry: null,
          )
        : FutureBuilder<CommunityResolvedMember?>(
            key: ValueKey(_visit?.epoch),
            future: _member,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _CodeUnavailable(
                  failure: CommunityPublicCodeFailure.fromError(
                    snapshot.error!,
                  ),
                  onRetry: _retry,
                );
              }
              final member = snapshot.data;
              if (member == null) return const _MemberCodeUnavailable();
              final displayedTicket = _visit?.capture();
              final relationship = _relationship ?? member.relationship;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BilAccountAvatar(
                            radius: 42,
                            networkUrl: member.avatarUrl,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            member.displayName,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            '@${member.handle}',
                            textDirection: TextDirection.ltr,
                          ),
                          const SizedBox(height: 24),
                          _MemberRelationshipAction(
                            relationship: relationship,
                            requesting: _requesting,
                            onAdd: () => _request(member, displayedTicket),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () {
                              if (displayedTicket?.isCurrent != true) return;
                              context.push(
                                '/community/profile/${member.userId}',
                              );
                            },
                            icon: const Icon(Icons.account_circle_outlined),
                            label: Text(
                              communityText(
                                context,
                                'View profile',
                                'عرض الملف',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
  );
}

class _MemberRelationshipAction extends StatelessWidget {
  const _MemberRelationshipAction({
    required this.relationship,
    required this.requesting,
    required this.onAdd,
  });

  final CommunityRelationshipStatus relationship;
  final bool requesting;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => switch (relationship) {
    CommunityRelationshipStatus.none => FilledButton.icon(
      key: const Key('community-code-add-friend'),
      onPressed: requesting ? null : onAdd,
      icon: requesting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.person_add_alt_1_rounded),
      label: Text(communityText(context, 'Add Friend', 'إضافة صديق')),
    ),
    CommunityRelationshipStatus.incoming => FilledButton.tonalIcon(
      onPressed: () => context.push('/community/connections'),
      icon: const Icon(Icons.mark_email_unread_outlined),
      label: Text(communityText(context, 'Review request', 'مراجعة الطلب')),
    ),
    CommunityRelationshipStatus.pending => Chip(
      avatar: const Icon(Icons.schedule_rounded),
      label: Text(
        communityText(context, 'Request pending', 'الطلب قيد الانتظار'),
      ),
    ),
    CommunityRelationshipStatus.accepted => Chip(
      avatar: const Icon(Icons.people_rounded),
      label: Text(communityText(context, 'Friends', 'الأصدقاء')),
    ),
    CommunityRelationshipStatus.self => Chip(
      avatar: const Icon(Icons.person_rounded),
      label: Text(communityText(context, 'This is you', 'هذا أنت')),
    ),
  };
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
