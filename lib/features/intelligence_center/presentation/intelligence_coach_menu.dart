part of 'intelligence_center_page.dart';

@visibleForTesting
Widget buildCoachMenuEvidenceSurface() =>
    const _CoachMenuSheet(currentTitle: 'خطة التغذية 🥗', canRename: true);

class _CoachMenuSheet extends StatelessWidget {
  const _CoachMenuSheet({this.currentTitle, this.canRename = false});
  final String? currentTitle;
  final bool canRename;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          2,
          18,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              intelligenceText(context, 'Your BIL Coach', 'مدرب BIL الخاص بك'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              intelligenceText(
                context,
                'Conversations, context, privacy and usage.',
                'المحادثات والسياق والخصوصية والاستخدام.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (currentTitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  currentTitle!,
                  key: const Key('ai-coach-current-conversation-title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 16),
            _CoachMenuTile(
              icon: Icons.dashboard_outlined,
              title: intelligenceText(context, 'Overview', 'نظرة عامة'),
              subtitle: intelligenceText(
                context,
                'Your Health Timeline',
                'تسلسل يومك الصحي',
              ),
              onTap: () => Navigator.of(context).pop('overview'),
            ),
            const SizedBox(height: 9),
            _CoachMenuTile(
              icon: Icons.forum_outlined,
              title: intelligenceText(
                context,
                'Conversation history',
                'سجل المحادثات',
              ),
              subtitle: intelligenceText(
                context,
                'Open an earlier chat or start a new one',
                'افتح محادثة سابقة أو ابدأ محادثة جديدة',
              ),
              onTap: () => Navigator.of(context).pop('history'),
            ),
            const SizedBox(height: 9),
            _CoachMenuTile(
              icon: Icons.psychology_alt_rounded,
              title: intelligenceText(
                context,
                'What BIL remembers',
                'ماذا يتذكر BIL عني',
              ),
              subtitle: intelligenceText(
                context,
                'Review the context behind your decisions',
                'راجع السياق الذي يبني عليه قراراتك',
              ),
              onTap: () => Navigator.of(context).pop('memory'),
            ),
            const SizedBox(height: 9),
            _CoachMenuTile(
              icon: Icons.tune_rounded,
              title: intelligenceText(
                context,
                'Coach settings',
                'إعدادات المدرب',
              ),
              subtitle: intelligenceText(
                context,
                'Context, privacy and balance',
                'السياق والخصوصية والرصيد',
              ),
              onTap: () => Navigator.of(context).pop('settings'),
            ),
            const SizedBox(height: 9),
            if (canRename)
              _CoachMenuTile(
                icon: Icons.edit_outlined,
                title: intelligenceText(
                  context,
                  'Rename conversation',
                  'إعادة تسمية المحادثة',
                ),
                subtitle: intelligenceText(
                  context,
                  'Change this conversation’s name',
                  'غيّر اسم هذه المحادثة',
                ),
                onTap: () => Navigator.of(context).pop('rename'),
              ),
            const Divider(height: 24),
            _CoachMenuTile(
              icon: Icons.delete_sweep_outlined,
              title: intelligenceText(
                context,
                'Clear conversation',
                'مسح المحادثة',
              ),
              subtitle: intelligenceText(
                context,
                'Choose the conversation to delete',
                'اختر المحادثة التي تريد حذفها',
              ),
              onTap: () => Navigator.of(context).pop('clear'),
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachMenuTile extends StatelessWidget {
  const _CoachMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      minLeadingWidth: 24,
      leading: BilGlassPressFeedback(
        child: Icon(
          icon,
          color: destructive ? scheme.error : scheme.onSurfaceVariant,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: destructive ? scheme.error : scheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: BilGlassPressFeedback(
        child: Icon(
          Icons.chevron_right_rounded,
          color: scheme.outline,
          size: 20,
        ),
      ),
      onTap: onTap,
    );
  }
}

extension _CoachPermissionMenu on _IntelligenceCenterPageState {
  Widget _buildCoachPermissionMenu() {
    return PopupMenuButton<CoachActionPermissionMode>(
      key: const Key('ai-coach-permission-mode'),
      tooltip: tr('Coach action permissions', 'صلاحيات إجراءات المدرب'),
      initialValue: ref.watch(coachActionPermissionModeProvider),
      onSelected: (mode) =>
          ref.read(coachActionPermissionModeProvider.notifier).state = mode,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: CoachActionPermissionMode.readOnly,
          child: Text(tr('Read only', 'قراءة فقط')),
        ),
        PopupMenuItem(
          value: CoachActionPermissionMode.askBeforeWrite,
          child: Text(tr('Ask before write', 'اسأل قبل الكتابة')),
        ),
        PopupMenuItem(
          value: CoachActionPermissionMode.writeAllowed,
          child: Text(tr('Write allowed', 'الكتابة مسموحة')),
        ),
      ],
      icon: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: .8,
          ),
        ),
        child: Icon(
          Icons.add_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 25,
        ),
      ),
    );
  }
}
