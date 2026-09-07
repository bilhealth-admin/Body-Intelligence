import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/bil_wordmark.dart';
import '../../../shared/widgets/bil_account_avatar.dart';

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.onProfile,
    this.profilePhoto,
    this.profilePhotoUrl,
  });

  final VoidCallback onProfile;
  final Uint8List? profilePhoto;
  final String? profilePhotoUrl;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode.toLowerCase();
    final copy =
        _dashboardTopBarCopy[language] ??
        _dashboardTopBarCopy['en']!.map(
          (key, value) => MapEntry(key, context.strings.text(value)),
        );

    final profile = _RoundProfileButton(
      tooltip: copy['profile']!,
      onTap: onProfile,
      imageBytes: profilePhoto,
      imageUrl: profilePhotoUrl,
    );
    final notifications = IconButton(
      key: const Key('dashboard-notifications'),
      tooltip: copy['notifications']!,
      onPressed: () => context.push('/notification-settings'),
      icon: const Icon(Icons.notifications_none_rounded),
    );
    final edit = _DashboardEditButton(tooltip: copy['edit']!);
    const brand = Directionality(
      textDirection: TextDirection.ltr,
      child: BilFullWordmark(
        key: Key('dashboard-wordmark'),
        height: 44,
        alignment: Alignment.center,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keep equal physical rails around the wordmark. Centering the mark
          // in the space left by a Row would shift it toward Profile because
          // the notifications/edit cluster is wider. The symmetric rails
          // make the identity's centre equal the viewport/content centre on
          // phones, tablets and both text directions.
          // The right controls occupy 96dp. The extra 2dp per rail keeps the
          // rendered lockup from visually touching them on 320dp devices.
          const sideRailWidth = 98.0;
          final brandWidth = (constraints.maxWidth - sideRailWidth * 2)
              .clamp(0.0, double.infinity)
              .toDouble();
          return SizedBox(
            key: const Key('dashboard-identity-header'),
            height: 48,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Align(alignment: Alignment.centerLeft, child: profile),
                Center(
                  child: SizedBox(width: brandWidth, child: brand),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [notifications, edit],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardEditButton extends StatelessWidget {
  const _DashboardEditButton({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12394E), Color(0xFF2563EB)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF12394E).withValues(alpha: .18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: IconButton(
        key: const Key('dashboard-edit-today'),
        tooltip: tooltip,
        onPressed: () => context.push('/dashboard/preferences'),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(
          Icons.dashboard_customize_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

class DashboardBrand extends StatelessWidget {
  const DashboardBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BilFullWordmark(
      height: compact ? 38 : 46,
      alignment: Alignment.center,
    );
  }
}

const _dashboardTopBarCopy = <String, Map<String, String>>{
  'ar': {
    'profile': 'الملف الشخصي',
    'notifications': 'الإشعارات',
    'edit': 'تخصيص الداشبورد',
  },
  'en': {
    'profile': 'Profile',
    'notifications': 'Notifications',
    'edit': 'Customize dashboard',
  },
  'fr': {
    'profile': 'Profil',
    'notifications': 'Notifications',
    'edit': 'Personnaliser le tableau de bord',
  },
  'es': {
    'profile': 'Perfil',
    'notifications': 'Notificaciones',
    'edit': 'Personalizar el panel',
  },
  'tr': {
    'profile': 'Profil',
    'notifications': 'Bildirimler',
    'edit': 'Paneli özelleştir',
  },
};

class _RoundProfileButton extends StatefulWidget {
  const _RoundProfileButton({
    required this.tooltip,
    required this.onTap,
    required this.imageBytes,
    this.imageUrl,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Uint8List? imageBytes;
  final String? imageUrl;

  @override
  State<_RoundProfileButton> createState() => _RoundProfileButtonState();
}

class _RoundProfileButtonState extends State<_RoundProfileButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: widget.onTap,
            radius: 24,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              key: const Key('dashboard-profile-control'),
              dimension: 48,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF12394E), Color(0xFF2563EB)],
                    ),
                    border: Border.all(
                      color: hovered ? scheme.primary : const Color(0xFF8EC5FF),
                      width: hovered ? 2 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF071923).withValues(alpha: .1),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: BilAccountAvatar(
                    key:
                        widget.imageBytes == null &&
                            (widget.imageUrl?.trim().isEmpty ?? true)
                        ? const Key('dashboard-default-profile-avatar')
                        : const Key('dashboard-user-profile-avatar'),
                    radius: 19,
                    photoBytes: widget.imageBytes,
                    networkUrl: widget.imageUrl,
                    backgroundColor: const Color(0xFF12394E),
                    placeholderColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
