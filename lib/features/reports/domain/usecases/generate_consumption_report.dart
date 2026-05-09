import 'dart:typed_data';

import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:iot_manager/features/reports/domain/repositories/reports_repository.dart';

class GenerateConsumptionReport {
  const GenerateConsumptionReport(this.repository);

  final ReportsRepository repository;

  Future<Uint8List> call({
    required AnalyticsQuery query,
    required List<AnalyticsSample> samples,
  }) async {
    final data = await repository.buildReportData(query, samples);
    return repository.generatePdf(data);
  }
}
