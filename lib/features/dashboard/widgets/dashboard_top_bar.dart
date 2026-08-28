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

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 0, 2, 2),
      child: Row(
        children: [
          _RoundProfileButton(
            tooltip: copy['profile']!,
            onTap: onProfile,
            imageBytes: profilePhoto,
            imageUrl: profilePhotoUrl,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: BilFullWordmark(height: 32),
            ),
          ),
          IconButton(
            tooltip: copy['notifications']!,
            onPressed: () => context.push('/notification-settings'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          _DashboardEditButton(tooltip: copy['edit']!),
        ],
      ),
    );
  }
}

class _DashboardEditButton extends StatelessWidget {
  const _DashboardEditButton({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
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
          onPressed: () => context.push('/dashboard/preferences'),
          style: IconButton.styleFrom(
            minimumSize: const Size.square(40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(
            Icons.dashboard_customize_rounded,
            color: Colors.white,
            size: 20,
          ),
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
      alignment: AlignmentDirectional.centerStart,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFC8F3FF),
            border: Border.all(
              color: hovered ? scheme.primary : scheme.outlineVariant,
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
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: BilAccountAvatar(
                key:
                    widget.imageBytes == null &&
                        (widget.imageUrl?.trim().isEmpty ?? true)
                    ? const Key('dashboard-default-profile-avatar')
                    : const Key('dashboard-user-profile-avatar'),
                radius: 19,
                photoBytes: widget.imageBytes,
                networkUrl: widget.imageUrl,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
