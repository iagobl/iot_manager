import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:iot_manager/features/reports/domain/entities/report_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsRemoteDatasource {
  ReportsRemoteDatasource({SupabaseClient? client}) : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  final Map<String, String> _homeIdByDeviceId = <String, String>{};

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
      _homeIdByDeviceId.clear();

      for (final row in rows) {
        final id = (row['id'] ?? '').toString();
        final host = (row['identifier'] ?? '').toString();
        final homeId = (row['home_id'] ?? '').toString();
        if (id.isNotEmpty && homeId.isNotEmpty) {
          _homeIdByDeviceId[id] = homeId;
        }

        final limits = await fetchShellyLimits(host);
        final home = row['homes'];
        final homeName = home is Map ? (home['name'] ?? '').toString() : null;

        result.add(
          ReportDeviceInfo(
            id: id,
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
    final deviceIds = devices.map((d) => d.id).where((id) => id.isNotEmpty).toSet();
    if (deviceIds.isEmpty) return <ReportIncidentInfo>[];

    final deviceNameById = {for (final device in devices) device.id: device.name};
    final deviceIdentifiers = devices
        .map((d) => d.identifier.trim())
        .where((identifier) => identifier.isNotEmpty)
        .toSet();
    final deviceNames = devices
        .map((d) => d.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final homeIds = deviceIds
        .map((id) => _homeIdByDeviceId[id])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final rows = await _fetchIncidentRows(
      deviceIds: deviceIds,
      deviceIdentifiers: deviceIdentifiers,
      deviceNames: deviceNames,
      homeIds: homeIds,
    );

    final fromLocal = from.toLocal();
    final toLocal = to.toLocal();
    final incidents = <ReportIncidentInfo>[];
    final seenIds = <String>{};

    for (final row in rows) {
      if (!_belongsToSelectedScope(
        row,
        deviceIds: deviceIds,
        deviceIdentifiers: deviceIdentifiers,
        deviceNames: deviceNames,
        homeIds: homeIds,
      )) {
        continue;
      }

      final createdAt = _incidentDate(row)?.toLocal();
      if (createdAt == null) continue;
      if (createdAt.isBefore(fromLocal) || createdAt.isAfter(toLocal)) continue;

      final id = (row['id'] ?? row['incident_id'] ?? row['incidentId'] ?? '').toString();
      if (id.isNotEmpty && !seenIds.add(id)) continue;

      final deviceId = _firstText(row, const [
        'device_id',
        'deviceId',
        'device',
        'device_uuid',
        'deviceUuid',
      ]) ??
          _findDeviceIdByIdentifier(row, devices) ??
          '';

      incidents.add(
        ReportIncidentInfo(
          id: id,
          deviceId: deviceId,
          deviceName: _incidentDeviceName(row, deviceId, deviceNameById, devices),
          title: _incidentTitle(row),
          description: _incidentDescription(row),
          createdAt: createdAt,
        ),
      );
    }

    incidents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return incidents;
  }

  Future<List<Map<String, dynamic>>> _fetchIncidentRows({
    required Set<String> deviceIds,
    required Set<String> deviceIdentifiers,
    required Set<String> deviceNames,
    required Set<String> homeIds,
  }) async {
    final rows = <Map<String, dynamic>>[];

    for (final table in const [
      'incidents',
      'incidences',
      'incidentes',
      'device_incidents',
      'device_incident',
    ]) {
      rows.addAll(await _fetchAllRowsFromTable(table));

      for (final field in const [
        'device_id',
        'deviceId',
        'device_uuid',
        'deviceUuid',
      ]) {
        rows.addAll(await _fetchRowsByValues(table, field, deviceIds));
      }

      for (final field in const [
        'device_identifier',
        'deviceIdentifier',
        'identifier',
        'host',
        'ip',
        'ip_address',
        'ipAddress',
      ]) {
        rows.addAll(await _fetchRowsByValues(table, field, deviceIdentifiers));
      }

      for (final field in const ['device_name', 'deviceName', 'name']) {
        rows.addAll(await _fetchRowsByValues(table, field, deviceNames));
      }

      for (final field in const ['home_id', 'homeId']) {
        rows.addAll(await _fetchRowsByValues(table, field, homeIds));
      }
    }

    return rows;
  }

  Future<List<Map<String, dynamic>>> _fetchAllRowsFromTable(String table) async {
    try {
      final response = await client.from(table).select('*');
      return _mapRows(response);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRowsByValues(
      String table,
      String field,
      Set<String> values,
      ) async {
    if (values.isEmpty) return <Map<String, dynamic>>[];

    try {
      final response = await client.from(table).select('*').inFilter(field, values.toList());
      return _mapRows(response);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  bool _belongsToSelectedScope(
      Map<String, dynamic> row, {
        required Set<String> deviceIds,
        required Set<String> deviceIdentifiers,
        required Set<String> deviceNames,
        required Set<String> homeIds,
      }) {
    if (_containsAny(row, const [
      'device_id',
      'deviceId',
      'device',
      'device_uuid',
      'deviceUuid',
    ], deviceIds)) {
      return true;
    }

    if (_containsAny(row, const [
      'device_identifier',
      'deviceIdentifier',
      'identifier',
      'host',
      'ip',
      'ip_address',
      'ipAddress',
    ], deviceIdentifiers)) {
      return true;
    }

    if (_containsAny(row, const ['device_name', 'deviceName', 'name'], deviceNames)) {
      return true;
    }

    if (_containsAny(row, const ['home_id', 'homeId'], homeIds)) {
      return true;
    }

    return false;
  }

  bool _containsAny(Map<String, dynamic> row, List<String> fields, Set<String> acceptedValues) {
    if (acceptedValues.isEmpty) return false;

    for (final field in fields) {
      final value = row[field];
      if (value == null) continue;

      if (value is Map) {
        if (_containsAny(value.cast<String, dynamic>(), fields, acceptedValues)) {
          return true;
        }
        continue;
      }

      final text = value.toString().trim();
      if (acceptedValues.contains(text)) return true;
    }

    return false;
  }

  String? _findDeviceIdByIdentifier(Map<String, dynamic> row, List<ReportDeviceInfo> devices) {
    final identifier = _firstText(row, const [
      'device_identifier',
      'deviceIdentifier',
      'identifier',
      'host',
      'ip',
      'ip_address',
      'ipAddress',
    ]);
    if (identifier == null) return null;

    for (final device in devices) {
      if (device.identifier == identifier) return device.id;
    }
    return null;
  }

  List<Map<String, dynamic>> _mapRows(Object? response) {
    if (response is! List) return <Map<String, dynamic>>[];
    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  DateTime? _incidentDate(Map<String, dynamic> row) {
    for (final field in const [
      'ts',
      'created_at',
      'createdAt',
      'triggered_at',
      'triggeredAt',
      'timestamp',
      'date',
      'detected_at',
      'detectedAt',
      'updated_at',
      'updatedAt',
      'resolved_at',
      'resolvedAt',
    ]) {
      final parsed = DateTime.tryParse((row[field] ?? '').toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _incidentDeviceName(
      Map<String, dynamic> row,
      String deviceId,
      Map<String, String> deviceNameById,
      List<ReportDeviceInfo> devices,
      ) {
    final explicitName = _firstText(row, const ['device_name', 'deviceName']);
    if (explicitName != null) return explicitName;

    final nameById = deviceNameById[deviceId];
    if (nameById != null && nameById.isNotEmpty) return nameById;

    final identifier = _firstText(row, const [
      'device_identifier',
      'deviceIdentifier',
      'identifier',
      'host',
      'ip',
      'ip_address',
      'ipAddress',
    ]);
    if (identifier != null) {
      for (final device in devices) {
        if (device.identifier == identifier) return device.name;
      }
    }

    return 'Dispositivo';
  }

  String _incidentTitle(Map<String, dynamic> row) {
    return _firstText(row, const [
      'title',
      'type',
      'incident_type',
      'incidentType',
      'metric',
      'category',
      'reason',
      'severity',
    ]) ??
        'Incidencia';
  }

  String _incidentDescription(Map<String, dynamic> row) {
    final explicitDescription = _firstText(row, const [
      'description',
      'message',
      'details',
      'detail',
      'body',
      'summary',
    ]);

    final metric = _firstText(row, const ['metric', 'type', 'incident_type']);
    final value = _firstText(row, const ['value', 'current_value', 'currentValue', 'measured_value', 'measuredValue']);
    final threshold = _firstText(row, const ['threshold', 'limit_value', 'limitValue', 'configured_limit', 'configuredLimit']);
    final severity = _firstText(row, const ['severity']);
    final acknowledged = _firstText(row, const ['is_acknowledged', 'isAcknowledged']);
    final resolved = _firstText(row, const ['is_resolved', 'isResolved']);

    final parts = <String>[];
    if (explicitDescription != null) parts.add(explicitDescription);
    if (metric != null) parts.add('Tipo: $metric');
    if (value != null) parts.add('Valor: $value');
    if (threshold != null) parts.add('Límite: $threshold');
    if (severity != null) parts.add('Severidad: $severity');
    if (acknowledged != null) parts.add('Reconocida: ${_boolLabel(acknowledged)}');
    if (resolved != null) parts.add('Resuelta: ${_boolLabel(resolved)}');

    return parts.isEmpty ? '-' : parts.join(' · ');
  }

  String? _firstText(Map<String, dynamic> row, List<String> fields) {
    for (final field in fields) {
      final value = row[field];
      if (value == null) continue;

      if (value is Map) {
        final nested = _firstText(value.cast<String, dynamic>(), fields);
        if (nested != null) return nested;
        continue;
      }

      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return null;
  }


  String _boolLabel(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return 'sí';
    if (normalized == 'false' || normalized == '0') return 'no';
    return value;
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
