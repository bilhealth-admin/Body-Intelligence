part of 'dashboard_grid.dart';

Future<void> _addDashboardWater({
  required BuildContext context,
  required DashboardHydrationCommand command,
  required String Function(String, String) tr,
  required int amountMl,
}) async {
  await command.addWater(amountMl);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        tr('$amountMl ml added to today.', 'تمت إضافة $amountMl مل إلى اليوم.'),
      ),
    ),
  );
}

void _openDashboardCanonicalAction(BuildContext context, String? actionId) {
  switch (actionId) {
    case 'continue-plan':
      context.push('/plan?origin=dashboard');
    case 'increase-protein':
    case 'rebalance-electrolytes':
      context.go('/daily-log?meal=breakfast&focus=meal&from=%2Fdashboard');
    case 'protect-sleep':
    case 'increase-activity':
      context.go('/daily-log?from=%2Fdashboard');
    case 'audit-plateau-inputs':
      context.go('/analytics');
    case null:
      break;
    default:
      context.push('/intelligence-center');
  }
}
