import 'dart:typed_data';

import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:iot_manager/features/reports/data/datasources/pvpc_remote_datasource.dart';
import 'package:iot_manager/features/reports/data/datasources/report_pdf_datasource.dart';
import 'package:iot_manager/features/reports/data/datasources/reports_remote_datasource.dart';
import 'package:iot_manager/features/reports/domain/entities/report_models.dart';
import 'package:iot_manager/features/reports/domain/repositories/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl({
    ReportsRemoteDatasource? remoteDatasource,
    PvpcRemoteDatasource? pvpcDatasource,
    ReportPdfDatasource? pdfDatasource,
  })  : remoteDatasource = remoteDatasource ?? ReportsRemoteDatasource(),
        pvpcDatasource = pvpcDatasource ?? PvpcRemoteDatasource(),
        pdfDatasource = pdfDatasource ?? ReportPdfDatasource();

  final ReportsRemoteDatasource remoteDatasource;
  final PvpcRemoteDatasource pvpcDatasource;
  final ReportPdfDatasource pdfDatasource;

  @override
  Future<ConsumptionReportData> buildReportData(AnalyticsQuery query, List<AnalyticsSample> samples) async {
    final devices = await remoteDatasource.fetchDevicesForScope(query.scope);
    final incidents = await remoteDatasource.fetchIncidents(devices: devices, from: query.from, to: query.to);
    final prices = await pvpcDatasource.fetchPrices(query.from, query.to);
    final hourlyCosts = buildHourlyCosts(samples, prices, query.from, query.to);

    return ConsumptionReportData(
      query: query,
      scopeLabel: query.scope.label,
      samples: samples,
      devices: devices,
      incidents: incidents,
      prices: prices,
      hourlyCosts: hourlyCosts,
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<Uint8List> generatePdf(ConsumptionReportData data) {
    return pdfDatasource.buildPdf(data);
  }

  List<ReportHourlyCost> buildHourlyCosts(
      List<AnalyticsSample> samples,
      List<PvpcHourlyPrice> prices,
      DateTime from,
      DateTime to,
      ) {
    final consumptionByHour = calculateHourlyConsumption(samples, from, to);
    final hours = <DateTime>{...consumptionByHour.keys, ...prices.map((price) => hourStart(price.start)),}.toList()
      ..sort();

    return hours.where((hour) => hour.isBefore(to) && hour.add(const Duration(hours: 1)).isAfter(from)).map((hour) {
      final energyWh = consumptionByHour[hour] ?? 0.0;
      final price = prices.where((item) => item.contains(hour)).firstOrNull;
      final priceEurKwh = price?.priceEurKwh ?? 0.0;
      final costEur = (energyWh / 1000) * priceEurKwh;

      return ReportHourlyCost(hour: hour, energyWh: energyWh, priceEurKwh: priceEurKwh, costEur: costEur);
    }).toList();
  }

  Map<DateTime, double> calculateHourlyConsumption(List<AnalyticsSample> samples, DateTime from, DateTime to) {
    final byDevice = <String, List<AnalyticsSample>>{};
    for (final sample in samples) {
      byDevice.putIfAbsent(sample.deviceId, () => <AnalyticsSample>[]).add(sample);
    }

    final result = <DateTime, double>{};
    for (final entries in byDevice.values) {
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (var i = 1; i < entries.length; i++) {
        final previous = entries[i - 1];
        final current = entries[i];
        final deltaWh = current.energyWh - previous.energyWh;

        if (!deltaWh.isFinite || deltaWh <= 0) continue;
        if (current.timestamp.isBefore(from) || current.timestamp.isAfter(to)) {
          continue;
        }

        final hour = hourStart(current.timestamp);

        result.update(hour, (value) => value + deltaWh,
          ifAbsent: () => deltaWh,
        );
      }
    }
    return result;
  }

  DateTime hourStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      date.hour,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
