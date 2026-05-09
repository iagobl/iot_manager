import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';

class PvpcHourlyPrice {
  const PvpcHourlyPrice({
    required this.start,
    required this.end,
    required this.priceEurKwh,
    required this.source,
  });

  final DateTime start;
  final DateTime end;
  final double priceEurKwh;
  final String source;

  bool contains(DateTime value) =>
      !value.isBefore(start) && value.isBefore(end);
}

class ReportHourlyCost {
  const ReportHourlyCost({
    required this.hour,
    required this.energyWh,
    required this.priceEurKwh,
    required this.costEur,
  });

  final DateTime hour;
  final double energyWh;
  final double priceEurKwh;
  final double costEur;
}

class ReportDeviceInfo {
  const ReportDeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.identifier,
    required this.homeName,
    this.maxPowerW,
    this.maxVoltageV,
    this.maxCurrentA,
  });

  final String id;
  final String name;
  final String type;
  final String identifier;
  final String? homeName;
  final double? maxPowerW;
  final double? maxVoltageV;
  final double? maxCurrentA;
}

class ReportIncidentInfo {
  const ReportIncidentInfo({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String deviceId;
  final String deviceName;
  final String title;
  final String description;
  final DateTime createdAt;
}

class ConsumptionReportData {
  const ConsumptionReportData({
    required this.query,
    required this.scopeLabel,
    required this.samples,
    required this.devices,
    required this.incidents,
    required this.prices,
    required this.hourlyCosts,
    required this.generatedAt,
  });

  final AnalyticsQuery query;
  final String scopeLabel;
  final List<AnalyticsSample> samples;
  final List<ReportDeviceInfo> devices;
  final List<ReportIncidentInfo> incidents;
  final List<PvpcHourlyPrice> prices;
  final List<ReportHourlyCost> hourlyCosts;
  final DateTime generatedAt;

  double get totalEnergyWh => hourlyCosts.fold(0, (sum, item) => sum + item.energyWh);
  double get totalCostEur => hourlyCosts.fold(0, (sum, item) => sum + item.costEur);
  double get averagePriceEurKwh {
    if (hourlyCosts.isEmpty) return 0;
    final energyKwh = totalEnergyWh / 1000;
    if (energyKwh <= 0) return 0;
    return totalCostEur / energyKwh;
  }

  double get averagePowerW {
    if (samples.isEmpty) return 0;
    return samples.fold<double>(0, (sum, sample) => sum + sample.powerW) / samples.length;
  }

  double get peakPowerW => samples.fold<double>(0, (max, s) => s.powerW > max ? s.powerW : max);
  double get peakVoltageV => samples.fold<double>(0, (max, s) => s.voltageV > max ? s.voltageV : max);
  double get peakCurrentA => samples.fold<double>(0, (max, s) => s.currentA > max ? s.currentA : max);
}
