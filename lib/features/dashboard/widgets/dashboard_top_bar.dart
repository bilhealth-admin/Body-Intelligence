import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/bil_wordmark.dart';

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.arabic,
    this.now,
    required this.displayName,
    required this.onProfile,
    this.profilePhoto,
  });

  final bool arabic;
  final DateTime? now;
  final String? displayName;
  final VoidCallback onProfile;
  final Uint8List? profilePhoto;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode.toLowerCase();
    final copy =
        _dashboardTopBarCopy[language] ??
        _dashboardTopBarCopy['en']!.map(
          (key, value) => MapEntry(key, context.strings.text(value)),
        );
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(now ?? DateTime.now());
    final unifiedDesktopNavigation = MediaQuery.sizeOf(context).width >= 900;

    final greeting = Text(
      displayName == null
          ? copy['welcome']!
          : '${copy['welcomeName']} $displayName',
      key: const Key('dashboard-greeting'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
    final dateText = Text(
      date,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );

    if (!unifiedDesktopNavigation) {
      return _ReferenceMobileTopBar(
        copy: copy,
        date: dateText,
        greeting: greeting,
        onProfile: onProfile,
        profilePhoto: profilePhoto,
      );
    }

    if (unifiedDesktopNavigation) {
      return Row(
        children: [
          Expanded(child: greeting),
          const SizedBox(width: 16),
          dateText,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [greeting, const SizedBox(height: 4), dateText],
          ),
        ),
        const SizedBox(width: 12),
        const Directionality(
          textDirection: TextDirection.ltr,
          child: DashboardBrand(compact: true),
        ),
        const SizedBox(width: 12),
        _RoundGlassButton(
          tooltip: copy['profile']!,
          icon: Icons.person_rounded,
          onTap: onProfile,
          imageBytes: profilePhoto,
        ),
      ],
    );
  }
}

class _ReferenceMobileTopBar extends StatelessWidget {
  const _ReferenceMobileTopBar({
    required this.copy,
    required this.date,
    required this.greeting,
    required this.onProfile,
    required this.profilePhoto,
  });

  final Map<String, String> copy;
  final Widget date;
  final Widget greeting;
  final VoidCallback onProfile;
  final Uint8List? profilePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _RoundGlassButton(
              tooltip: copy['profile']!,
              icon: Icons.person_rounded,
              onTap: onProfile,
              imageBytes: profilePhoto,
            ),
            const SizedBox(width: 14),
            const Expanded(child: BilFullWordmark(height: 40)),
            const SizedBox(width: 8),
            IconButton(
              tooltip: copy['notifications']!,
              onPressed: () => context.push('/notification-settings'),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy['today']!,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  date,
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('dashboard-edit-today'),
                  onPressed: () => context.push('/dashboard/preferences'),
                  child: Text(copy['edit']!),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: greeting,
                ),
              ],
            ),
          ],
        ),
      ],
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
    'welcome': 'أهلًا بك',
    'welcomeName': 'أهلًا،',
    'profile': 'الملف الشخصي',
    'notifications': 'الإشعارات',
    'today': 'اليوم',
    'edit': 'تعديل',
  },
  'en': {
    'welcome': 'Welcome',
    'welcomeName': 'Welcome,',
    'profile': 'Profile',
    'notifications': 'Notifications',
    'today': 'Today',
    'edit': 'Edit',
  },
  'fr': {
    'welcome': 'Bienvenue',
    'welcomeName': 'Bienvenue,',
    'profile': 'Profil',
    'notifications': 'Notifications',
    'today': 'Aujourd’hui',
    'edit': 'Modifier',
  },
  'es': {
    'welcome': 'Bienvenido',
    'welcomeName': 'Bienvenido,',
    'profile': 'Perfil',
    'notifications': 'Notificaciones',
    'today': 'Hoy',
    'edit': 'Editar',
  },
  'tr': {
    'welcome': 'Hoş geldiniz',
    'welcomeName': 'Hoş geldin,',
    'profile': 'Profil',
    'notifications': 'Bildirimler',
    'today': 'Bugün',
    'edit': 'Düzenle',
  },
};

class _RoundGlassButton extends StatefulWidget {
  const _RoundGlassButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.imageBytes,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Uint8List? imageBytes;

  @override
  State<_RoundGlassButton> createState() => _RoundGlassButtonState();
}

class _RoundGlassButtonState extends State<_RoundGlassButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: hovered
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: IconButton(
            onPressed: widget.onTap,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: widget.imageBytes == null
                  ? DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF111827), Color(0xFF2563EB)],
                        ),
                      ),
                      child: Icon(widget.icon, size: 22, color: Colors.white),
                    )
                  : ClipOval(
                      child: Image.memory(
                        widget.imageBytes!,
                        fit: BoxFit.cover,
                        width: 36,
                        height: 36,
                        gaplessPlayback: true,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
