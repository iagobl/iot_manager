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

    final options = <AnalyticsScopeOption>[
      const AnalyticsScopeOption(
        id: 'all_devices',
        label: 'Todos los dispositivos',
        subtitle: 'Vista global de toda la instalación',
        type: AnalyticsScopeType.allDevices,
      ),
    ];

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
        currentA: readDouble(row['current_a'] ?? meta['current_a'] ?? meta['current'] ?? meta['amps'] ?? meta['apower_current']),
        energyWh: readDouble(row['energy_wh']),
      );
    }).toList();
  }

  @override
  Future<List<AnalyticsBreakdownItem>> getBreakdown(AnalyticsQuery query) async {
    final samples = await getSamples(query);
    final grouped = <String, List<AnalyticsSample>>{};
    final labels = <String, String>{};
    final types = <String, AnalyticsScopeType>{};

    for (final sample in samples) {
      late final String key;
      late final String label;
      late final AnalyticsScopeType type;

      if (query.scope.type == AnalyticsScopeType.home) {
        key = sample.deviceId;
        label = sample.deviceName;
        type = AnalyticsScopeType.device;
      } else if (query.scope.type == AnalyticsScopeType.device) {
        key = sample.deviceId;
        label = sample.deviceName;
        type = AnalyticsScopeType.device;
      } else {
        key = sample.homeId ?? 'without_home';
        label = sample.homeName ?? 'Sin hogar';
        type = AnalyticsScopeType.home;
      }

      grouped.putIfAbsent(key, () => <AnalyticsSample>[]).add(sample);
      labels[key] = label;
      types[key] = type;
    }

    final items = grouped.entries.map((entry) {
      final bucket = entry.value;
      final count = math.max(bucket.length, 1);
      double energy = 0;
      double power = 0;
      double voltage = 0;
      double current = 0;

      for (final sample in bucket) {
        energy += sample.energyWh;
        power += sample.powerW;
        voltage += sample.voltageV;
        current += sample.currentA;
      }

      return AnalyticsBreakdownItem(
        id: entry.key,
        label: labels[entry.key] ?? 'Elemento',
        scopeType: types[entry.key] ?? AnalyticsScopeType.device,
        totalEnergyWh: energy,
        averagePowerW: power / count,
        averageVoltageV: voltage / count,
        averageCurrentA: current / count,
        samples: bucket.length,
      );
    }).toList()..sort((a, b) => b.totalEnergyWh.compareTo(a.totalEnergyWh));

    return items;
  }
}
