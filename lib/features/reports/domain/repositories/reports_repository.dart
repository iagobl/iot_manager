import 'dart:typed_data';

import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:iot_manager/features/reports/domain/entities/report_models.dart';

abstract class ReportsRepository {
  Future<ConsumptionReportData> buildReportData(AnalyticsQuery query, List<AnalyticsSample> samples);

  Future<Uint8List> generatePdf(ConsumptionReportData data);
}
