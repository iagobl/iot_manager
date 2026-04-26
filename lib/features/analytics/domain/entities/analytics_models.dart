import 'dart:math' as math;

class AnalyticsScopeOption {
  const AnalyticsScopeOption({
    required this.id,
    required this.label,
    required this.type,
    this.homeId,
    this.deviceId,
    this.subtitle,
  });

  final String id;
  final String label;
  final AnalyticsScopeType type;
  final String? homeId;
  final String? deviceId;
  final String? subtitle;

  bool get isAll => type == AnalyticsScopeType.allDevices;
  bool get isHome => type == AnalyticsScopeType.home;
  bool get isDevice => type == AnalyticsScopeType.device;
}

enum AnalyticsScopeType { allDevices, home, device }

enum AnalyticsScopeGroup { global, device }

enum AnalyticsMetric { energy, power, voltage, current }

enum AnalyticsRangePreset { today, last7Days, custom }

class AnalyticsSample {
  const AnalyticsSample({
    required this.deviceId,
    required this.deviceName,
    required this.homeId,
    required this.homeName,
    required this.timestamp,
    required this.powerW,
    required this.voltageV,
    required this.currentA,
    required this.energyWh,
  });

  final String deviceId;
  final String deviceName;
  final String? homeId;
  final String? homeName;
  final DateTime timestamp;
  final double powerW;
  final double voltageV;
  final double currentA;
  final double energyWh;
}

class AnalyticsPoint {
  const AnalyticsPoint({
    required this.timestamp,
    required this.powerW,
    required this.voltageV,
    required this.currentA,
    required this.energyWh,
    this.deviceId,
  });

  final DateTime timestamp;
  final double powerW;
  final double voltageV;
  final double currentA;
  final double energyWh;
  final String? deviceId;
}

class AnalyticsSeries {
  const AnalyticsSeries({
    required this.points,
    required this.totalEnergyWh,
    required this.averagePowerW,
    required this.averageVoltageV,
    required this.averageCurrentA,
    required this.maxPowerW,
    required this.maxVoltageV,
    required this.maxCurrentA,
    required this.minPowerW,
    required this.minVoltageV,
    required this.minCurrentA,
  });

  final List<AnalyticsPoint> points;
  final double totalEnergyWh;
  final double averagePowerW;
  final double averageVoltageV;
  final double averageCurrentA;
  final double maxPowerW;
  final double maxVoltageV;
  final double maxCurrentA;
  final double minPowerW;
  final double minVoltageV;
  final double minCurrentA;

  bool get isEmpty => points.isEmpty;

  static AnalyticsSeries fromSamples(List<AnalyticsSample> samples) {
    if (samples.isEmpty) {
      return const AnalyticsSeries(
        points: [],
        totalEnergyWh: 0,
        averagePowerW: 0,
        averageVoltageV: 0,
        averageCurrentA: 0,
        maxPowerW: 0,
        maxVoltageV: 0,
        maxCurrentA: 0,
        minPowerW: 0,
        minVoltageV: 0,
        minCurrentA: 0,
      );
    }

    final sorted = [...samples]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final points = sorted
        .map(
          (sample) => AnalyticsPoint(
        timestamp: sample.timestamp,
        powerW: sample.powerW,
        voltageV: sample.voltageV,
        currentA: sample.currentA,
        energyWh: sample.energyWh,
        deviceId: sample.deviceId,
      ),
    )
        .toList();

    final totalEnergy =
    sorted.fold<double>(0, (sum, sample) => sum + sample.energyWh);
    final avgPower =
        sorted.fold<double>(0, (sum, sample) => sum + sample.powerW) /
            sorted.length;
    final avgVoltage =
        sorted.fold<double>(0, (sum, sample) => sum + sample.voltageV) /
            sorted.length;
    final avgCurrent =
        sorted.fold<double>(0, (sum, sample) => sum + sample.currentA) /
            sorted.length;

    final powerValues = sorted.map((sample) => sample.powerW).toList();
    final voltageValues = sorted.map((sample) => sample.voltageV).toList();
    final currentValues = sorted.map((sample) => sample.currentA).toList();

    return AnalyticsSeries(
      points: points,
      totalEnergyWh: totalEnergy,
      averagePowerW: avgPower,
      averageVoltageV: avgVoltage,
      averageCurrentA: avgCurrent,
      maxPowerW: powerValues.reduce(math.max),
      maxVoltageV: voltageValues.reduce(math.max),
      maxCurrentA: currentValues.reduce(math.max),
      minPowerW: powerValues.reduce(math.min),
      minVoltageV: voltageValues.reduce(math.min),
      minCurrentA: currentValues.reduce(math.min),
    );
  }
}

class AnalyticsQuery {
  const AnalyticsQuery({
    required this.scope,
    required this.rangePreset,
    required this.from,
    required this.to,
  });

  final AnalyticsScopeOption scope;
  final AnalyticsRangePreset rangePreset;
  final DateTime from;
  final DateTime to;

  AnalyticsQuery copyWith({
    AnalyticsScopeOption? scope,
    AnalyticsRangePreset? rangePreset,
    DateTime? from,
    DateTime? to,
  }) {
    return AnalyticsQuery(
      scope: scope ?? this.scope,
      rangePreset: rangePreset ?? this.rangePreset,
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalEnergyWh,
    required this.averagePowerW,
    required this.averageVoltageV,
    required this.averageCurrentA,
    required this.peakPowerW,
    required this.peakVoltageV,
    required this.peakCurrentA,
    required this.activeDevices,
    required this.samples,
  });

  final double totalEnergyWh;
  final double averagePowerW;
  final double averageVoltageV;
  final double averageCurrentA;
  final double peakPowerW;
  final double peakVoltageV;
  final double peakCurrentA;
  final int activeDevices;
  final int samples;
}

class AnalyticsNormalizationLimits {
  const AnalyticsNormalizationLimits({
    required this.powerW,
    required this.voltageV,
    required this.currentA,
    required this.usesDeviceLimits,
  });

  final double powerW;
  final double voltageV;
  final double currentA;
  final bool usesDeviceLimits;

  static const empty = AnalyticsNormalizationLimits(
    powerW: 0,
    voltageV: 0,
    currentA: 0,
    usesDeviceLimits: false,
  );

  bool get hasUsefulLimits => powerW > 0 || voltageV > 0 || currentA > 0;
}

class AnalyticsState {

  factory AnalyticsState.initial() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    return AnalyticsState(
      loading: true,
      exporting: false,
      scopes: const [],
      selectedScope: null,
      selectedGroup: AnalyticsScopeGroup.global,
      rangePreset: AnalyticsRangePreset.today,
      from: start,
      to: now,
      series: const AnalyticsSeries(
        points: [],
        totalEnergyWh: 0,
        averagePowerW: 0,
        averageVoltageV: 0,
        averageCurrentA: 0,
        maxPowerW: 0,
        maxVoltageV: 0,
        maxCurrentA: 0,
        minPowerW: 0,
        minVoltageV: 0,
        minCurrentA: 0,
      ),
      summary: const AnalyticsSummary(
        totalEnergyWh: 0,
        averagePowerW: 0,
        averageVoltageV: 0,
        averageCurrentA: 0,
        peakPowerW: 0,
        peakVoltageV: 0,
        peakCurrentA: 0,
        activeDevices: 0,
        samples: 0,
      ),
      normalizationLimits: AnalyticsNormalizationLimits.empty,
    );
  }
  const AnalyticsState({
    required this.loading,
    required this.exporting,
    required this.scopes,
    required this.selectedScope,
    required this.selectedGroup,
    required this.rangePreset,
    required this.from,
    required this.to,
    required this.series,
    required this.summary,
    required this.normalizationLimits,
    this.errorMessage,
  });

  final bool loading;
  final bool exporting;
  final List<AnalyticsScopeOption> scopes;
  final AnalyticsScopeOption? selectedScope;
  final AnalyticsScopeGroup selectedGroup;
  final AnalyticsRangePreset rangePreset;
  final DateTime from;
  final DateTime to;
  final AnalyticsSeries series;
  final AnalyticsSummary summary;
  final AnalyticsNormalizationLimits normalizationLimits;
  final String? errorMessage;

  AnalyticsState copyWith({
    bool? loading,
    bool? exporting,
    List<AnalyticsScopeOption>? scopes,
    AnalyticsScopeOption? selectedScope,
    AnalyticsScopeGroup? selectedGroup,
    AnalyticsRangePreset? rangePreset,
    DateTime? from,
    DateTime? to,
    AnalyticsSeries? series,
    AnalyticsSummary? summary,
    AnalyticsNormalizationLimits? normalizationLimits,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AnalyticsState(
      loading: loading ?? this.loading,
      exporting: exporting ?? this.exporting,
      scopes: scopes ?? this.scopes,
      selectedScope: selectedScope ?? this.selectedScope,
      selectedGroup: selectedGroup ?? this.selectedGroup,
      rangePreset: rangePreset ?? this.rangePreset,
      from: from ?? this.from,
      to: to ?? this.to,
      series: series ?? this.series,
      summary: summary ?? this.summary,
      normalizationLimits: normalizationLimits ?? this.normalizationLimits,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
