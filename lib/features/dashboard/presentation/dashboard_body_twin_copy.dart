import '../../../engine/body_twin_engine.dart';
import '../domain/dashboard_trusted_body_twin_adapter.dart';

typedef DashboardBodyTwinTranslate = String Function(String, String);

class DashboardBodyTwinCopy {
  const DashboardBodyTwinCopy({required this.summary, required this.evidence});

  final String summary;
  final String evidence;

  factory DashboardBodyTwinCopy.compose({
    required DashboardTrustedBodyTwinSnapshot trusted,
    required BodyTwinReport report,
    required bool firstReading,
    required DashboardBodyTwinTranslate tr,
  }) {
    final summary = switch (trusted.status) {
      DashboardBodyTwinTrustStatus.trusted => tr(
        firstReading
            ? 'Initial Body Twin baseline · ${trusted.weightKg!.toStringAsFixed(1)} kg'
            : 'Trusted local Body Twin · ${trusted.weightKg!.toStringAsFixed(1)} kg',
        firstReading
            ? 'خط أساس توأم الجسم · ${trusted.weightKg!.toStringAsFixed(1)} كجم'
            : 'توأم جسدي محلي موثوق · ${trusted.weightKg!.toStringAsFixed(1)} كجم',
      ),
      DashboardBodyTwinTrustStatus.stale => tr(
        'Body Twin paused · latest weight is stale',
        'تم إيقاف التوأم الجسدي · آخر وزن قديم',
      ),
      DashboardBodyTwinTrustStatus.inconsistent => tr(
        'Body Twin blocked · local measurement is inconsistent',
        'تم حجب التوأم الجسدي · القياس المحلي غير متسق',
      ),
      DashboardBodyTwinTrustStatus.unavailable => tr(
        'Body Twin is waiting for a trusted local weight',
        'ينتظر التوأم الجسدي وزنًا محليًا موثوقًا',
      ),
    };
    final evidence = trusted.canExposeBodyTwin
        ? firstReading
              ? tr(
                  'Day-one reading accepted after integrity, freshness, and consistency checks. It is a baseline, not a trend.',
                  'تم قبول قراءة اليوم الأول بعد فحص النزاهة والحداثة والاتساق. هذه نقطة أساس وليست اتجاهًا بعد.',
                )
              : report.scenario == null
              ? tr(
                  report.requiredData.join(' · '),
                  'نحتاج أيام ملاحظة ووزن وتغذية أكثر.',
                )
              : tr(
                  'Cautious range ${report.scenario!.cautiousLowKg.toStringAsFixed(1)} to ${report.scenario!.cautiousHighKg.toStringAsFixed(1)} kg/week · ${trusted.engineVersion}',
                  'النطاق الحذر ${report.scenario!.cautiousLowKg.toStringAsFixed(1)} إلى ${report.scenario!.cautiousHighKg.toStringAsFixed(1)} كجم/أسبوع · ${trusted.engineVersion}',
                )
        : trusted.reasons.join(' · ');
    return DashboardBodyTwinCopy(summary: summary, evidence: evidence);
  }
}
