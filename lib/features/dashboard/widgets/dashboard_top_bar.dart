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
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final copy =
        _dashboardTopBarCopy[language] ??
        _dashboardTopBarCopy['en']!.map(
          (key, value) => MapEntry(key, localizations?.text(value) ?? value),
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
      iconSize: 19,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        maximumSize: const Size.square(44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.notifications_none_rounded),
    );
    final edit = _DashboardEditButton(tooltip: copy['edit']!);
    const brand = Directionality(
      textDirection: TextDirection.ltr,
      child: BilFullWordmark(
        key: Key('dashboard-wordmark'),
        height: 36,
        alignment: Alignment.center,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.35;
          if (compact) {
            // Only narrow screens and accessibility text need a second row;
            // ordinary phones use the compact, centred reference layout.
            return SizedBox(
              key: const Key('dashboard-identity-header'),
              height: 78,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: brand,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: Row(
                      textDirection: TextDirection.ltr,
                      children: [profile, const Spacer(), notifications, edit],
                    ),
                  ),
                ],
              ),
            );
          }

          // Keep the mark at the physical centre, independently of the three
          // controls. Equal rails reserve only the two 44-wide right actions
          // plus a 2-point gap; the shell gives this header the full safe width.
          const sideRailWidth = 90.0;
          return SizedBox(
            key: const Key('dashboard-identity-header'),
            height: 48,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Align(alignment: Alignment.centerLeft, child: profile),
                Center(
                  child: SizedBox(
                    width: constraints.maxWidth - sideRailWidth * 2,
                    child: brand,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    textDirection: TextDirection.ltr,
                    mainAxisSize: MainAxisSize.min,
                    children: [notifications, edit],
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
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 8,
            bottom: 8,
            left: 8,
            right: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
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
            ),
          ),
          IconButton(
            key: const Key('dashboard-edit-today'),
            tooltip: tooltip,
            onPressed: () => context.push('/dashboard/preferences'),
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 44),
              maximumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.settings_outlined, size: 18),
          ),
        ],
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
      height: compact ? 42 : 50,
      alignment: Alignment.center,
    );
  }
}

const _dashboardTopBarCopy = <String, Map<String, String>>{
  'ar': {
    'profile': 'الملف الشخصي',
    'notifications': 'الإشعارات',
    'edit': 'تخصيص الداشبورد',
    'action': 'تعديل',
    'today': 'اليوم',
  },
  'en': {
    'profile': 'Profile',
    'notifications': 'Notifications',
    'edit': 'Customize dashboard',
    'action': 'Edit',
    'today': 'Today',
  },
  'fr': {
    'profile': 'Profil',
    'notifications': 'Notifications',
    'edit': 'Personnaliser le tableau de bord',
    'action': 'Modifier',
    'today': "Aujourd’hui",
  },
  'es': {
    'profile': 'Perfil',
    'notifications': 'Notificaciones',
    'edit': 'Personalizar el panel',
    'action': 'Editar',
    'today': 'Hoy',
  },
  'tr': {
    'profile': 'Profil',
    'notifications': 'Bildirimler',
    'edit': 'Paneli özelleştir',
    'action': 'Düzenle',
    'today': 'Bugün',
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
                  width: 32,
                  height: 32,
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
                    radius: 14,
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
