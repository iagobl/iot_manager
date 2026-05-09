import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:iot_manager/features/reports/domain/entities/report_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsRemoteDatasource {
  ReportsRemoteDatasource({SupabaseClient? client}) : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<List<ReportDeviceInfo>> fetchDevicesForScope(AnalyticsScopeOption scope) async {
    try {
      var query = client.from('devices').select('id, name, device_type, identifier, home_id, homes(name)');
      if (scope.type == AnalyticsScopeType.device && scope.deviceId != null) {
        query = query.eq('id', scope.deviceId!);
      } else if (scope.type == AnalyticsScopeType.home && scope.homeId != null) {
        query = query.eq('home_id', scope.homeId!);
      }

      final response = await query;
      final rows = (response as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
      final result = <ReportDeviceInfo>[];

      for (final row in rows) {
        final host = (row['identifier'] ?? '').toString();
        final limits = await fetchShellyLimits(host);
        final home = row['homes'];
        final homeName = home is Map ? (home['name'] ?? '').toString() : null;

        result.add(
          ReportDeviceInfo(
            id: (row['id'] ?? '').toString(),
            name: (row['name'] ?? 'Dispositivo').toString(),
            type: (row['device_type'] ?? 'Dispositivo').toString(),
            identifier: host,
            homeName: homeName != null && homeName.isNotEmpty ? homeName : null,
            maxPowerW: limits.$1,
            maxVoltageV: limits.$2,
            maxCurrentA: limits.$3,
          ),
        );
      }

      return result;
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<ReportIncidentInfo>> fetchIncidents({
    required List<ReportDeviceInfo> devices,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final deviceIds = devices.map((d) => d.id).where((id) => id.isNotEmpty).toList();
      if (deviceIds.isEmpty) return <ReportIncidentInfo>[];

      final response = await client
          .from('incidents')
          .select('*')
          .inFilter('device_id', deviceIds)
          .gte('created_at', from.toUtc().toIso8601String())
          .lte('created_at', to.toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final deviceNameById = {for (final device in devices) device.id: device.name};
      return (response as List).map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        final deviceId = (row['device_id'] ?? '').toString();
        final title = (row['title'] ?? row['type'] ?? row['incident_type'] ?? 'Incidencia').toString();
        final description = (row['description'] ?? row['message'] ?? row['details'] ?? '').toString();
        final createdAt = DateTime.tryParse((row['created_at'] ?? '').toString())?.toLocal() ?? DateTime.now();
        return ReportIncidentInfo(
          id: (row['id'] ?? '').toString(),
          deviceId: deviceId,
          deviceName: deviceNameById[deviceId] ?? 'Dispositivo',
          title: title,
          description: description,
          createdAt: createdAt,
        );
      }).toList();
    } catch (_) {
      return <ReportIncidentInfo>[];
    }
  }

  Future<(double?, double?, double?)> fetchShellyLimits(String host) async {
    if (host.trim().isEmpty) return (null, null, null);
    try {
      final rpc = ShellyRpcClient(host: host.trim());
      final config = await rpc.call('Switch.GetConfig', params: {'id': 0});
      return (_num(config['power_limit']), _num(config['voltage_limit']), _num(config['current_limit']));
    } catch (_) {
      return (null, null, null);
    }
  }

  double? _num(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }
}
