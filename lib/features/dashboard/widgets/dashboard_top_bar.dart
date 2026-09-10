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
      icon: const Icon(Icons.notifications_none_rounded),
    );
    final edit = _DashboardEditButton(
      label: copy['action']!,
      tooltip: copy['edit']!,
    );
    const brand = Directionality(
      textDirection: TextDirection.ltr,
      child: BilFullWordmark(
        key: Key('dashboard-wordmark'),
        height: 48,
        alignment: Alignment.center,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          if (compact) {
            // A full-width identity row gives the long BIL lockup enough room
            // on phones. Keeping the controls on their own row avoids making
            // the centered mark tiny or letting either physical rail overlap
            // it in RTL and at large text scales.
            return SizedBox(
              key: const Key('dashboard-identity-header'),
              height: 102,
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

          // Keep equal physical rails around the wordmark. Centering the mark
          // in the space left by a Row would shift it toward Profile because
          // the notifications/edit cluster is wider. The symmetric rails
          // make the identity's centre equal the viewport/content centre on
          // phones, tablets and both text directions.
          // The right controls occupy the notification button plus the Today
          // action. Equal rails keep the wordmark centred despite that wider
          // text action; narrower windows use the two-row branch above.
          const sideRailWidth = 152.0;
          final brandWidth = (constraints.maxWidth - sideRailWidth * 2)
              .clamp(0.0, double.infinity)
              .toDouble();
          return SizedBox(
            key: const Key('dashboard-identity-header'),
            height: 56,
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
  const _DashboardEditButton({required this.label, required this.tooltip});

  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
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
        child: SizedBox(
          width: 84,
          height: 48,
          child: TextButton(
            key: const Key('dashboard-edit-today'),
            onPressed: () => context.push('/dashboard/preferences'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(84, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
