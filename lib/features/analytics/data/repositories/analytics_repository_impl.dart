import 'package:iot_manager/features/analytics/data/datasources/analytics_remote_datasource.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:iot_manager/features/analytics/domain/repositories/analytics_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl(this.remoteDatasource);

  final AnalyticsRemoteDatasource remoteDatasource;

  @override
  Future<List<AnalyticsScopeOption>> getAvailableScopes() async {
    final homes = await remoteDatasource.getAccessibleHomes();
    final devices = await remoteDatasource.getAccessibleDevices();

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
          homeId: (device['home_id'] ?? '').toString().isEmpty ? null
              : (device['home_id'] ?? '').toString(),
        ),
      );
    }
    return options;
  }

  @override
  Future<List<AnalyticsSample>> getSamples(AnalyticsQuery query) async {
    final devices = await remoteDatasource.getAccessibleDevices();
    final homes = await remoteDatasource.getAccessibleHomes();

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

    final deviceIds = filteredDevices.map((device) => (device['id'] ?? '').toString())
        .where((id) => id.isNotEmpty).toList();

    final rows = await remoteDatasource.fetchReadings(
      deviceIds: deviceIds,
      from: query.from,
      to: query.to,
    );

    final deviceById = <String, Map<String, dynamic>>{
      for (final row in filteredDevices) (row['id'] ?? '').toString(): row,
    };

    double readDouble(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse((value ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    return rows.map((row) {
      final deviceId = (row['device_id'] ?? '').toString();
      final device = deviceById[deviceId] ?? const <String, dynamic>{};

      final meta = row['meta'] is Map ? Map<String, dynamic>.from(row['meta'] as Map)
          : <String, dynamic>{};

      final homeId = (device['home_id'] ?? '').toString();

      final power = readDouble(
        row['power_w'] ??
            meta['power_w'] ??
            meta['apower'] ??
            meta['power'],
      );

      final voltage = readDouble(
        row['voltage_v'] ??
            meta['voltage_v'] ??
            meta['voltage'],
      );

      final current = readDouble(
        row['current_a'] ??
            meta['current_a'] ??
            meta['current'] ??
            meta['amps'],
      );

      final energy = readDouble(
        row['energy_wh'] ??
            meta['energy_wh'] ??
            meta['aenergy_total'] ??
            meta['total_energy_wh'] ??
            meta['energy'],
      );

      return AnalyticsSample(
        deviceId: deviceId,
        deviceName: (device['name'] ?? 'Dispositivo').toString(),
        homeId: homeId.isEmpty ? null : homeId,
        homeName: homeId.isEmpty ? null : homeNameById[homeId],
        timestamp: DateTime.tryParse((row['ts'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        powerW: power,
        voltageV: voltage,
        currentA: current,
        energyWh: energy,
      );
    }).toList();
  }

  @override
  Future<AnalyticsNormalizationLimits> getDeviceNormalizationLimits(String deviceId) {
    return remoteDatasource.getDeviceNormalizationLimits(deviceId);
  }

  @override
  Future<Map<String, double>> getCurrentPowerByScope(AnalyticsScopeOption scope) async {
    final devices = await remoteDatasource.getAccessibleDevices();
    final filteredDeviceIds = devices.where((device) {
      switch (scope.type) {
        case AnalyticsScopeType.allDevices:
          return true;
        case AnalyticsScopeType.home:
          return (device['home_id'] ?? '').toString() == (scope.homeId ?? '');
        case AnalyticsScopeType.device:
          return (device['id'] ?? '').toString() == (scope.deviceId ?? '');
      }
    }).map((device) => (device['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();

    return remoteDatasource.getCurrentPowerByDeviceIds(filteredDeviceIds);
  }
}