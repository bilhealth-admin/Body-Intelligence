import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/community_repository.dart';
import '../../domain/community_circles.dart';
import '../../services/community_post_image_picker.dart';
import '../circle_management.dart';

part 'circle_create_sheet.dart';
part 'circle_invites_sheet.dart';
part 'circle_media_sheet.dart';
part 'circle_management_widgets.dart';

/// A factory is scoped to one captured account/repository/circle visit.
/// It permits offline widget fixtures without changing the existing repository.
typedef CircleManagementGatewayFactory =
    CircleManagementGateway Function(
      CommunityRepository repository,
      ValueGetter<bool> isCurrentVisit,
      Listenable ownerChanges,
      String? circleSlug,
    );

/// This role currently supplies reviewed Arabic and English copy. Other app
/// languages intentionally use the English source; they are not translations.
String circleManagementText(BuildContext context, String en, String ar) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

enum _ManagementView { menu, create, invites, media }

/// Hosted inside the existing captured visit's guard and modal route.
/// Capability discovery is read-only and starts only on explicit entry.
class CircleManagementPanel extends StatefulWidget {
  const CircleManagementPanel({
    required this.controller,
    required this.isCurrent,
    required this.onChanged,
    this.circle,
    this.imagePicker,
    this.onEnableServerSearch,
    super.key,
  });

  final CircleManagementController controller;
  final ValueGetter<bool> isCurrent;
  final Future<void> Function() onChanged;
  final CommunityCircle? circle;
  final CommunityPostImagePickerContract? imagePicker;
  final VoidCallback? onEnableServerSearch;

  @override
  State<CircleManagementPanel> createState() => _CircleManagementPanelState();
}

class _CircleManagementPanelState extends State<CircleManagementPanel> {
  _ManagementView _view = _ManagementView.menu;
  ModalRoute<dynamic>? _route;
  bool _closing = false;

  bool get _current =>
      mounted &&
      !_closing &&
      // A dropdown is a child popup route. The sheet remains active while its
      // privacy choices are open, but becomes inactive as soon as it is popped.
      (_route?.isActive ?? true) &&
      widget.isCurrent() &&
      widget.controller.isCurrent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current) unawaited(_initialize());
    });
  }

  Future<void> _initialize() async {
    try {
      await widget.controller.restorePendingOperations();
    } on Object {
      // The controller fails closed for writes and exposes a retryable notice.
    }
    if (!_current) return;
    if (widget.controller.capabilities == null &&
        !widget.controller.capabilitiesLoading) {
      await widget.controller.loadCapabilities();
    }
    final circle = widget.circle;
    if (_current &&
        circle != null &&
        widget.controller.capabilities?.available == true) {
      await widget.controller.loadCircle(circle.slug);
    }
  }

  void _show(_ManagementView view) {
    if (!_current) return;
    setState(() => _view = view);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      if (!_current) return const _ManagementOwnerChanged();
      final controller = widget.controller;
      final capabilities = controller.capabilities;
      final canUse = capabilities?.available == true;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (_view != _ManagementView.menu)
                        IconButton(
                          key: const Key('bil06-tools-back'),
                          tooltip: circleManagementText(
                            context,
                            'Back to circle management',
                            'العودة إلى إدارة الدوائر',
                          ),
                          onPressed: () => _show(_ManagementView.menu),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      Expanded(
                        child: Text(
                          circleManagementText(
                            context,
                            'Manage circles',
                            'إدارة الدوائر',
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        key: const Key('bil06-tools-close'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () {
                          if (!_current || _route?.isCurrent == false) return;
                          _closing = true;
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: !canUse || _view == _ManagementView.menu
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (controller.capabilitiesLoading)
                              const LinearProgressIndicator(),
                            if (controller.operationRecoveryError != null)
                              _ManagementNotice(
                                key: const Key(
                                  'bil06-operation-recovery-error',
                                ),
                                text: circleManagementText(
                                  context,
                                  'Pending circle actions could not be recovered safely. New changes are blocked until recovery succeeds.',
                                  'تعذر استعادة إجراءات الدوائر المعلّقة بأمان. تم إيقاف التغييرات الجديدة حتى تنجح الاستعادة.',
                                ),
                                action: controller.restorePendingOperations,
                              ),
                            if (capabilities == null || !canUse)
                              _ManagementNotice(
                                key: const Key('bil06-capability-unavailable'),
                                text: circleManagementText(
                                  context,
                                  'Circle management is unavailable until access can be verified. Existing circles remain available.',
                                  'إدارة الدوائر غير متاحة حتى يتم التحقق من الصلاحية. تبقى الدوائر الحالية متاحة.',
                                ),
                                action: controller.capabilitiesLoading
                                    ? null
                                    : controller.loadCapabilities,
                              ),
                            if (canUse) ...[
                              if (widget.circle == null)
                                ListTile(
                                  key: const Key('bil06-create-entry'),
                                  enabled: capabilities!.canCreate,
                                  leading: const Icon(Icons.add_circle_outline),
                                  title: Text(
                                    circleManagementText(
                                      context,
                                      'Create a circle',
                                      'إنشاء دائرة',
                                    ),
                                  ),
                                  subtitle: capabilities.canCreate
                                      ? null
                                      : Text(
                                          circleManagementText(
                                            context,
                                            'Your account does not have permission to create circles.',
                                            'لا يملك حسابك صلاحية إنشاء دوائر.',
                                          ),
                                        ),
                                  onTap: capabilities.canCreate
                                      ? () => _show(_ManagementView.create)
                                      : null,
                                ),
                              ListTile(
                                key: const Key('bil06-invites-entry'),
                                enabled: capabilities!.canReadInvites,
                                leading: const Icon(Icons.mail_outline_rounded),
                                title: Text(
                                  circleManagementText(
                                    context,
                                    'Invitations',
                                    'الدعوات',
                                  ),
                                ),
                                subtitle: Text(
                                  circleManagementText(
                                    context,
                                    'Opening an invitation does not accept it.',
                                    'فتح الدعوة لا يعني قبولها.',
                                  ),
                                ),
                                onTap: capabilities.canReadInvites
                                    ? () => _show(_ManagementView.invites)
                                    : null,
                              ),
                              if (widget.circle != null)
                                ListTile(
                                  key: const Key('bil06-media-entry'),
                                  enabled: capabilities.canManageMedia,
                                  leading: const Icon(Icons.image_outlined),
                                  title: Text(
                                    circleManagementText(
                                      context,
                                      'Circle image and cover',
                                      'صورة الدائرة وغلافها',
                                    ),
                                  ),
                                  subtitle: capabilities.canManageMedia
                                      ? null
                                      : Text(
                                          circleManagementText(
                                            context,
                                            'Only an authorized circle manager can change images.',
                                            'يمكن لمدير الدائرة المخوّل فقط تغيير الصور.',
                                          ),
                                        ),
                                  onTap: capabilities.canManageMedia
                                      ? () => _show(_ManagementView.media)
                                      : null,
                                ),
                              if (widget.onEnableServerSearch != null)
                                ListTile(
                                  key: const Key('bil06-server-search-entry'),
                                  enabled: capabilities.canSearch,
                                  leading: const Icon(Icons.search_rounded),
                                  title: Text(
                                    circleManagementText(
                                      context,
                                      'Search more circles',
                                      'البحث في مزيد من الدوائر',
                                    ),
                                  ),
                                  subtitle: Text(
                                    circleManagementText(
                                      context,
                                      'Search all circles available to you.',
                                      'ابحث في جميع الدوائر المتاحة لك.',
                                    ),
                                  ),
                                  onTap: capabilities.canSearch
                                      ? () {
                                          if (_current) {
                                            _closing = true;
                                            widget.onEnableServerSearch!();
                                          }
                                        }
                                      : null,
                                ),
                              TextButton.icon(
                                onPressed: controller.capabilitiesLoading
                                    ? null
                                    : controller.loadCapabilities,
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(
                                  circleManagementText(
                                    context,
                                    'Check permissions again',
                                    'التحقق من الصلاحيات مجددًا',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      : switch (_view) {
                          _ManagementView.create => _CircleCreateForm(
                            controller: controller,
                            isCurrent: () =>
                                _current && _view == _ManagementView.create,
                            onChanged: widget.onChanged,
                          ),
                          _ManagementView.invites => _CircleInvitesForm(
                            controller: controller,
                            isCurrent: () =>
                                _current && _view == _ManagementView.invites,
                            circle: widget.circle,
                            onChanged: widget.onChanged,
                          ),
                          _ManagementView.media => _CircleMediaForm(
                            controller: controller,
                            isCurrent: () =>
                                _current && _view == _ManagementView.media,
                            circle: widget.circle!,
                            imagePicker: widget.imagePicker,
                            onChanged: widget.onChanged,
                          ),
                          _ManagementView.menu => const SizedBox.shrink(),
                        },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
