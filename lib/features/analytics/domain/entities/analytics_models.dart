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

enum AnalyticsMetric { energy, power, voltage, current }

enum AnalyticsRangePreset { today, last7Days, last30Days, custom }

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
  });

  final DateTime timestamp;
  final double powerW;
  final double voltageV;
  final double currentA;
  final double energyWh;
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
    final grouped = <int, List<AnalyticsSample>>{};

    for (final sample in sorted) {
      final key = DateTime(
        sample.timestamp.year,
        sample.timestamp.month,
        sample.timestamp.day,
        sample.timestamp.hour,
        sample.timestamp.minute,
      ).millisecondsSinceEpoch;
      grouped.putIfAbsent(key, () => <AnalyticsSample>[]).add(sample);
    }

    final points = grouped.entries.map((entry) {
      final bucket = entry.value;
      final count = bucket.length;
      final ts = DateTime.fromMillisecondsSinceEpoch(entry.key);

      double sumPower = 0;
      double sumVoltage = 0;
      double sumCurrent = 0;
      double sumEnergy = 0;

      for (final sample in bucket) {
        sumPower += sample.powerW;
        sumVoltage += sample.voltageV;
        sumCurrent += sample.currentA;
        sumEnergy += sample.energyWh;
      }

      return AnalyticsPoint(
        timestamp: ts,
        powerW: sumPower / count,
        voltageV: sumVoltage / count,
        currentA: sumCurrent / count,
        energyWh: sumEnergy,
      );
    }).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double totalEnergyWh = 0;
    double powerSum = 0;
    double voltageSum = 0;
    double currentSum = 0;
    double maxPower = double.negativeInfinity;
    double maxVoltage = double.negativeInfinity;
    double maxCurrent = double.negativeInfinity;
    double minPower = double.infinity;
    double minVoltage = double.infinity;
    double minCurrent = double.infinity;

    for (final point in points) {
      totalEnergyWh += point.energyWh;
      powerSum += point.powerW;
      voltageSum += point.voltageV;
      currentSum += point.currentA;
      maxPower = math.max(maxPower, point.powerW);
      maxVoltage = math.max(maxVoltage, point.voltageV);
      maxCurrent = math.max(maxCurrent, point.currentA);
      minPower = math.min(minPower, point.powerW);
      minVoltage = math.min(minVoltage, point.voltageV);
      minCurrent = math.min(minCurrent, point.currentA);
    }

    return AnalyticsSeries(
      points: points,
      totalEnergyWh: totalEnergyWh,
      averagePowerW: powerSum / points.length,
      averageVoltageV: voltageSum / points.length,
      averageCurrentA: currentSum / points.length,
      maxPowerW: maxPower.isFinite ? maxPower : 0,
      maxVoltageV: maxVoltage.isFinite ? maxVoltage : 0,
      maxCurrentA: maxCurrent.isFinite ? maxCurrent : 0,
      minPowerW: minPower.isFinite ? minPower : 0,
      minVoltageV: minVoltage.isFinite ? minVoltage : 0,
      minCurrentA: minCurrent.isFinite ? minCurrent : 0,
    );
  }
}

class AnalyticsBreakdownItem {
  const AnalyticsBreakdownItem({
    required this.id,
    required this.label,
    required this.scopeType,
    required this.totalEnergyWh,
    required this.averagePowerW,
    required this.averageVoltageV,
    required this.averageCurrentA,
    required this.samples,
  });

  final String id;
  final String label;
  final AnalyticsScopeType scopeType;
  final double totalEnergyWh;
  final double averagePowerW;
  final double averageVoltageV;
  final double averageCurrentA;
  final int samples;
}

class AnalyticsQuery {
  const AnalyticsQuery({
    required this.scope,
    required this.from,
    required this.to,
  });

  final AnalyticsScopeOption scope;
  final DateTime from;
  final DateTime to;
}
