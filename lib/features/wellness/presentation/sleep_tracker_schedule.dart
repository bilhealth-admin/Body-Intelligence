part of 'wellness_tools_pages.dart';

extension _SleepTrackerScheduleCard on _SleepTrackerPageState {
  Widget _sleepScheduleCard() {
    final material = MaterialLocalizations.of(context);
    final scheduleLabels = bilSleepScheduleLabels(
      Localizations.localeOf(context).toLanguageTag(),
    );
    String formatTime(int hour, int minute) =>
        material.formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
    final goalHours = sleepSchedule.goalMinutes / 60;
    final windowHours = sleepSchedule.scheduledWindowMinutes ~/ 60;
    final windowMinutes = sleepSchedule.scheduledWindowMinutes % 60;
    final windowLabel = windowMinutes == 0
        ? tr('$windowHours h', '$windowHours س')
        : tr(
            '$windowHours h $windowMinutes min',
            '$windowHours س $windowMinutes د',
          );
    return Card(
      key: const Key('sleep-schedule-card'),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            key: const Key('sleep-schedule-toggle'),
            horizontalTitleGap: 12,
            secondary: const BilSemanticIconBadge(
              kind: BilSemanticIconKind.notifications,
            ),
            title: Text(
              '${tr('Sleep', 'النوم')} · ${tr('Daily reminders', 'التذكيرات اليومية')}',
            ),
            value: sleepSchedule.enabled,
            onChanged: scheduleLoading || scheduleSaving
                ? null
                : _setSleepScheduleEnabled,
          ),
          const Divider(height: 1),
          ListTile(
            enabled: !scheduleLoading && !scheduleSaving,
            horizontalTitleGap: 12,
            leading: const BilSemanticIconBadge(
              kind: BilSemanticIconKind.sleep,
            ),
            title: Text(scheduleLabels.$1),
            trailing: Text(
              formatTime(sleepSchedule.bedHour, sleepSchedule.bedMinute),
            ),
            onTap: () => _chooseSleepTime(wake: false),
          ),
          ListTile(
            enabled: !scheduleLoading && !scheduleSaving,
            horizontalTitleGap: 12,
            leading: const BilSemanticIconBadge(kind: BilSemanticIconKind.time),
            title: Text(scheduleLabels.$2),
            trailing: Text(
              formatTime(sleepSchedule.wakeHour, sleepSchedule.wakeMinute),
            ),
            onTap: () => _chooseSleepTime(wake: true),
          ),
          ListTile(
            key: const Key('sleep-scheduled-window'),
            horizontalTitleGap: 12,
            leading: const BilSemanticIconBadge(kind: BilSemanticIconKind.time),
            title: Text(tr('Scheduled window', 'نافذة النوم المجدولة')),
            subtitle: Text(
              tr(
                '$windowLabel · local time; the phone adjusts reminders for timezone and daylight-saving changes.',
                '$windowLabel · بالتوقيت المحلي؛ يضبط الهاتف التذكيرات عند تغيّر المنطقة الزمنية والتوقيت الصيفي.',
              ),
            ),
          ),
          ListTile(
            horizontalTitleGap: 12,
            leading: const BilSemanticIconBadge(
              kind: BilSemanticIconKind.goals,
            ),
            title: Text('${tr('Sleep', 'النوم')} · ${tr('Goal', 'الهدف')}'),
            subtitle: Text(
              '${goalHours.toStringAsFixed(goalHours % 1 == 0 ? 0 : 1)} ${tr('hours', 'ساعة')}',
            ),
            trailing: PopupMenuButton<int>(
              enabled: !scheduleLoading && !scheduleSaving,
              tooltip: tr('Goal', 'الهدف'),
              onSelected: (minutes) => _saveSleepSchedule(
                sleepSchedule.copyWith(goalMinutes: minutes),
              ),
              itemBuilder: (_) => [
                for (final minutes in const [420, 450, 480, 540])
                  PopupMenuItem(
                    value: minutes,
                    child: Text(
                      '${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)} ${tr('hours', 'ساعة')}',
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            horizontalTitleGap: 12,
            leading: const BilSemanticIconBadge(
              kind: BilSemanticIconKind.notifications,
            ),
            title: Text('${tr('Sleep', 'النوم')} · ${tr('Reminder', 'تذكير')}'),
            subtitle: Text(
              tr(
                '${sleepSchedule.windDownMinutes} min',
                '${sleepSchedule.windDownMinutes} د',
              ),
            ),
            trailing: PopupMenuButton<int>(
              enabled: !scheduleLoading && !scheduleSaving,
              tooltip: tr('Time', 'الوقت'),
              onSelected: (minutes) => _saveSleepSchedule(
                sleepSchedule.copyWith(windDownMinutes: minutes),
              ),
              itemBuilder: (_) => [
                for (final minutes in const [15, 30, 45, 60])
                  PopupMenuItem(
                    value: minutes,
                    child: Text(tr('$minutes min', '$minutes د')),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              tr(
                'For adults, planning goals start at 7 hours. The schedule is guidance; your recorded sleep remains the actual value and is never rewritten to match the goal.',
                'للبالغين تبدأ أهداف التخطيط من 7 ساعات. الجدول إرشادي؛ ويبقى نومك المسجل هو القيمة الفعلية ولا يُعدّل ليتوافق مع الهدف.',
              ),
            ),
          ),
          if (scheduleError != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  scheduleError!,
                  key: const Key('sleep-schedule-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (scheduleSaving)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
