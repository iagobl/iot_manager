import 'dart:math' as math;

import 'package:iot_manager/features/analytics/data/datasources/analytics_remote_datasource.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:iot_manager/features/analytics/domain/repositories/analytics_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl(this._remoteDatasource);

  final AnalyticsRemoteDatasource _remoteDatasource;

  @override
  Future<List<AnalyticsScopeOption>> getAvailableScopes() async {
    final homes = await _remoteDatasource.getAccessibleHomes();
    final devices = await _remoteDatasource.getAccessibleDevices();

    final options = <AnalyticsScopeOption>[];

    for (final home in homes) {
      final id = (home['id'] ?? '').toString();
      if (id.isEmpty) continue;

      options.add(
        AnalyticsScopeOption(
          id: 'home_$id',
          label: (home['name'] ?? 'Hogar').toString(),
          subtitle: 'Agrupación por hogar',
          type: AnalyticsScopeType.home,
          homeId: id,
        ),
      );
    }

    for (final device in devices) {
      final id = (device['id'] ?? '').toString();
      if (id.isEmpty) continue;
      options.add(
        AnalyticsScopeOption(
          id: 'device_$id',
          label: (device['name'] ?? 'Dispositivo').toString(),
          subtitle: (device['device_type'] ?? 'Dispositivo').toString(),
          type: AnalyticsScopeType.device,
          deviceId: id,
          homeId: (device['home_id'] ?? '').toString().isEmpty
              ? null
              : (device['home_id'] ?? '').toString(),
        ),
      );
    }

    return options;
  }

  @override
  Future<List<AnalyticsSample>> getSamples(AnalyticsQuery query) async {
    final devices = await _remoteDatasource.getAccessibleDevices();
    final homes = await _remoteDatasource.getAccessibleHomes();

    final homeNameById = <String, String>{
      for (final home in homes)
        (home['id'] ?? '').toString(): (home['name'] ?? 'Hogar').toString(),
    };

    final filteredDevices = devices.where((device) {
      switch (query.scope.type) {
        case AnalyticsScopeType.allDevices:
          return true;
        case AnalyticsScopeType.home:
          return (device['home_id'] ?? '').toString() == (query.scope.homeId ?? '');
        case AnalyticsScopeType.device:
          return (device['id'] ?? '').toString() == (query.scope.deviceId ?? '');
      }
    }).toList();

    final deviceIds = filteredDevices
        .map((device) => (device['id'] ?? '').toString())
        .where((id) => id.isNotEmpty).toList();

    final rows = await _remoteDatasource.fetchReadings(
      deviceIds: deviceIds,
      from: query.from,
      to: query.to,
    );

    final deviceById = <String, Map<String, dynamic>>{
      for (final row in filteredDevices) (row['id'] ?? '').toString(): row,
    };

    return rows.map((row) {
      final deviceId = (row['device_id'] ?? '').toString();
      final device = deviceById[deviceId] ?? const <String, dynamic>{};
      final meta = row['meta'] is Map ? Map<String, dynamic>.from(row['meta'] as Map) : <String, dynamic>{};

      double readDouble(Object? value) {
        if (value is num) return value.toDouble();
        return double.tryParse((value ?? '').toString()) ?? 0;
      }

      final homeId = (device['home_id'] ?? '').toString();

      return AnalyticsSample(
        deviceId: deviceId,
        deviceName: (device['name'] ?? 'Dispositivo').toString(),
        homeId: homeId.isEmpty ? null : homeId,
        homeName: homeId.isEmpty ? null : homeNameById[homeId],
        timestamp: DateTime.tryParse((row['ts'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        powerW: readDouble(row['power_w']),
        voltageV: readDouble(row['voltage_v']),
        currentA: readDouble(row['current_a']),
        energyWh: readDouble(row['energy_wh']) != 0
            ? readDouble(row['energy_wh'])
            : readDouble(meta['energy_wh']),
      );
    }).toList();
  }

  @override
  Future<AnalyticsNormalizationLimits> getDeviceNormalizationLimits(
      String deviceId,
      ) {
    return _remoteDatasource.getDeviceNormalizationLimits(deviceId);
  }

  AnalyticsSummary buildSummary(List<AnalyticsSample> samples) {
    if (samples.isEmpty) {
      return const AnalyticsSummary(
        totalEnergyWh: 0,
        averagePowerW: 0,
        averageVoltageV: 0,
        averageCurrentA: 0,
        peakPowerW: 0,
        peakVoltageV: 0,
        peakCurrentA: 0,
        activeDevices: 0,
        samples: 0,
      );
    }

    final totalEnergyWh =
    samples.fold<double>(0, (sum, item) => sum + item.energyWh);
    final averagePowerW =
        samples.fold<double>(0, (sum, item) => sum + item.powerW) /
            samples.length;
    final averageVoltageV =
        samples.fold<double>(0, (sum, item) => sum + item.voltageV) /
            samples.length;
    final averageCurrentA =
        samples.fold<double>(0, (sum, item) => sum + item.currentA) /
            samples.length;

    final peakPowerW = samples
        .map((sample) => sample.powerW)
        .fold<double>(0, (max, value) => math.max(max, value));
    final peakVoltageV = samples
        .map((sample) => sample.voltageV)
        .fold<double>(0, (max, value) => math.max(max, value));
    final peakCurrentA = samples
        .map((sample) => sample.currentA)
        .fold<double>(0, (max, value) => math.max(max, value));

    final activeDevices = samples
        .where((sample) => sample.powerW > 0)
        .map((sample) => sample.deviceId)
        .toSet()
        .length;

    return AnalyticsSummary(
      totalEnergyWh: totalEnergyWh,
      averagePowerW: averagePowerW,
      averageVoltageV: averageVoltageV,
      averageCurrentA: averageCurrentA,
      peakPowerW: peakPowerW,
      peakVoltageV: peakVoltageV,
      peakCurrentA: peakCurrentA,
      activeDevices: activeDevices,
      samples: samples.length,
    );
  }
}