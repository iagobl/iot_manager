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

    double? readFirstNumeric(Map<String, dynamic> row, List<String> keys) {
      for (final key in keys) {
        if (!row.containsKey(key) || row[key] == null) continue;
        return readDouble(row[key]);
      }
      return null;
    }

    double? readFromMeta(Map<String, dynamic> meta, List<String> keys) {
      for (final key in keys) {
        if (!meta.containsKey(key) || meta[key] == null) continue;
        return readDouble(meta[key]);
      }
      return null;
    }

    double extractMetric(
        Map<String, dynamic> row,
        Map<String, dynamic> meta,
        List<String> keys,
        ) {
      return readFirstNumeric(row, keys) ?? readFromMeta(meta, keys) ?? 0.0;
    }

    double extractEnergy(Map<String, dynamic> row, Map<String, dynamic> meta) {
      final rowValue = readFirstNumeric(row, const [
        'energy_wh',
        'total_energy_wh',
        'aenergy_total',
        'energy',
        'total_wh',
        'consumption_wh',
      ]);
      if (rowValue != null) return rowValue;

      final metaValue = readFromMeta(meta, const [
        'energy_wh',
        'total_energy_wh',
        'aenergy_total',
        'energy',
        'total_wh',
        'consumption_wh',
      ]);
      if (metaValue != null) return metaValue;

      final aenergy = meta['aenergy'];
      if (aenergy is Map<String, dynamic>) {
        final nested = readFromMeta(aenergy, const ['total', 'total_wh', 'energy_wh']);
        if (nested != null) return nested;
      } else if (aenergy is Map) {
        final nested = readFromMeta(
          Map<String, dynamic>.from(aenergy),
          const ['total', 'total_wh', 'energy_wh'],
        );
        if (nested != null) return nested;
      }

      return 0.0;
    }

    final samples = <AnalyticsSample>[];

    for (final row in rows) {
      final deviceId = (row['device_id'] ?? '').toString();
      final device = deviceById[deviceId] ?? const <String, dynamic>{};

      final rawMeta = row['meta'];
      final meta = rawMeta is Map
          ? Map<String, dynamic>.from(rawMeta)
          : <String, dynamic>{};

      final timestamp = remoteDatasource.extractTimestamp(row);
      if (timestamp == null) {
        continue;
      }

      final homeId = (device['home_id'] ?? '').toString();

      final power = extractMetric(row, meta, const ['power_w', 'apower', 'power']);
      final voltage = extractMetric(row, meta, const ['voltage_v', 'voltage']);
      final current = extractMetric(row, meta, const ['current_a', 'current', 'amps']);
      final energy = extractEnergy(row, meta);

      samples.add(
        AnalyticsSample(
          deviceId: deviceId,
          deviceName: (device['name'] ?? 'Dispositivo').toString(),
          homeId: homeId.isEmpty ? null : homeId,
          homeName: homeId.isEmpty ? null : homeNameById[homeId],
          timestamp: timestamp,
          powerW: power,
          voltageV: voltage,
          currentA: current,
          energyWh: energy,
        ),
      );
    }

    samples.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return samples;
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
