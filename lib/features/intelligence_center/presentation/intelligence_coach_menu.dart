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

extension _CoachQuickPromptMenu on _IntelligenceCenterPageState {
  Widget _buildCoachQuickPromptMenu() => IconButton(
    key: const Key('ai-coach-quick-prompts'),
    tooltip: tr('Ask your Coach', 'اسأل مدربك'),
    onPressed: !conversationReady || sending
        ? null
        : () => unawaited(_showCoachQuickPrompts()),
    constraints: const BoxConstraints.tightFor(width: 42, height: 42),
    padding: EdgeInsets.zero,
    icon: Container(
      width: 42,
      height: 42,
      decoration: BilPearlFinish.panel(
        context,
        radius: BorderRadius.circular(21),
        shadow: false,
      ),
      child: Icon(
        Icons.add_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 25,
      ),
    ),
  );

  Future<void> _showCoachQuickPrompts() async {
    final prompts = <({IconData icon, String title, String prompt})>[
      (
        icon: Icons.monitor_weight_outlined,
        title: tr('Analyze my weight', 'حلّل وزني'),
        prompt: tr(
          'Analyze my recorded weight trend from saved BIL measurements. Use their actual dates and values, and do not infer missing measurements.',
          'حلّل اتجاه وزني من القياسات المحفوظة في BIL. استخدم تواريخها وقيمها الفعلية ولا تستنتج قياسات غير موجودة.',
        ),
      ),
      (
        icon: Icons.restaurant_menu_rounded,
        title: tr('What should I eat today?', 'ماذا آكل اليوم؟'),
        prompt: tr(
          'Based on my saved BIL nutrition and goals, suggest what I could eat today. Do not log or add food; tell me if required data is missing.',
          'استنادًا إلى التغذية والأهداف المحفوظة في BIL، اقترح ما يمكنني تناوله اليوم. لا تسجّل طعامًا، وأخبرني إذا كانت البيانات اللازمة غير متوفرة.',
        ),
      ),
      (
        icon: Icons.egg_alt_outlined,
        title: tr('How much protein remains?', 'كم بروتين بقي؟'),
        prompt: tr(
          'How much protein remains for today based on my saved BIL intake and goal? If either value is unavailable, say so instead of estimating.',
          'كم تبقى لي من البروتين اليوم حسب ما سجلته وهدفي في BIL؟ إذا لم تتوفر إحدى القيمتين فأخبرني بدلًا من التخمين.',
        ),
      ),
      (
        icon: Icons.today_rounded,
        title: tr('Review my day', 'حلّل يومي'),
        prompt: tr(
          'Review my day from my saved BIL data and tell me the most useful next step. Do not invent missing values.',
          'حلّل يومي من بيانات BIL المحفوظة وأخبرني بأكثر خطوة مفيدة الآن، دون اختراع قيم غير موجودة.',
        ),
      ),
      (
        icon: Icons.water_drop_outlined,
        title: tr('How much water remains?', 'كم ماء بقي؟'),
        prompt: tr(
          'How much water remains for today based on my saved BIL intake and goal? If the intake or goal is unavailable, say so.',
          'كم تبقى لي من الماء اليوم حسب ما سجلته وهدفي في BIL؟ إذا لم يتوفر المدخول أو الهدف فأخبرني.',
        ),
      ),
      (
        icon: Icons.flag_outlined,
        title: tr('My next step today', 'خطوتي التالية اليوم'),
        prompt: tr(
          'Based on the BIL context selected for my Coach, what is one useful next step today and why? Do not create or save anything.',
          'استنادًا إلى سياق BIL المتاح للمدرب، ما خطوة واحدة مفيدة اليوم ولماذا؟ لا تنشئ شيئًا ولا تحفظه.',
        ),
      ),
      (
        icon: Icons.date_range_rounded,
        title: tr('Review my week', 'راجع أسبوعي'),
        prompt: tr(
          'Review the available saved BIL records from this week, describe what is supported by the data, and identify missing days without filling them in.',
          'راجع سجلات BIL المحفوظة والمتاحة لهذا الأسبوع، واشرح ما تدعمه البيانات وحدد الأيام الناقصة دون تعويضها بتخمينات.',
        ),
      ),
    ];
    final prompt = await showBilPearlBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BilFrostedPanel(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                  child: Text(
                    tr('Ask your Coach', 'اسأل مدربك'),
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: Text(
                    tr(
                      'Shortcuts use only the BIL data available to your Coach. They do not log food or make changes.',
                      'تستخدم الاختصارات بيانات BIL المتاحة للمدرب فقط، ولا تسجّل طعامًا أو تُجري تغييرات.',
                    ),
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: Theme.of(
                            sheetContext,
                          ).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                for (var index = 0; index < prompts.length; index++)
                  ListTile(
                    key: Key('ai-coach-prompt-$index'),
                    leading: BilGlassPressFeedback(
                      child: Icon(
                        prompts[index].icon,
                        color: Theme.of(
                          sheetContext,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(prompts[index].title),
                    onTap: () =>
                        Navigator.of(sheetContext).pop(prompts[index].prompt),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || prompt == null) return;
    usePrompt(prompt);
  }
}
