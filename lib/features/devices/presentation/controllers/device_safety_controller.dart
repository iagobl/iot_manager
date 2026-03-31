import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';

class DeviceSafetyController extends ChangeNotifier {
  DeviceSafetyController({
    required this.host,
    DevicesRemoteDatasource? remoteDatasource,
  })  : rpc = ShellyRpcClient(host: host),
        remoteDatasource = remoteDatasource ?? DevicesRemoteDatasource();

  final String host;
  final ShellyRpcClient rpc;
  final DevicesRemoteDatasource remoteDatasource;

  bool loading = false;
  bool savingPower = false;
  bool savingVoltage = false;
  bool savingCurrent = false;

  double? powerLimit;
  double? voltageLimit;
  double? currentLimit;

  String? error;

  String? deviceIdCache;

  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      final cfg = await rpc.call('Switch.GetConfig', params: {'id': 0});

      powerLimit = toDouble(cfg['power_limit']);
      voltageLimit = toDouble(cfg['voltage_limit']);
      currentLimit = toDouble(cfg['current_limit']);

      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> savePowerLimit(double? value) async {
    savingPower = true;
    notifyListeners();

    try {
      await saveField('power_limit', value);
      powerLimit = value;
      await resolveIncidentsIfNeeded(changedKey: 'power_limit', newLimit: value);
      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      savingPower = false;
      notifyListeners();
    }
  }

  Future<void> saveVoltageLimit(double? value) async {
    savingVoltage = true;
    notifyListeners();

    try {
      await saveField('voltage_limit', value);
      voltageLimit = value;
      await resolveIncidentsIfNeeded(changedKey: 'voltage_limit', newLimit: value);
      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      savingVoltage = false;
      notifyListeners();
    }
  }

  Future<void> saveCurrentLimit(double? value) async {
    savingCurrent = true;
    notifyListeners();

    try {
      await saveField('current_limit', value);
      currentLimit = value;
      await resolveIncidentsIfNeeded(changedKey: 'current_limit', newLimit: value);
      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      savingCurrent = false;
      notifyListeners();
    }
  }

  Future<void> saveField(String key, double? value) async {
    await rpc.call('Switch.SetConfig', params: {
        'id': 0,
        'config': {
          'power_limit': key == 'power_limit' ? value : powerLimit,
          'voltage_limit': key == 'voltage_limit' ? value : voltageLimit,
          'current_limit': key == 'current_limit' ? value : currentLimit,
        },
      },
    );
  }

  Future<void> resolveIncidentsIfNeeded({
    required String changedKey,
    required double? newLimit,
  }) async {
    if (newLimit == null || newLimit <= 0) return;

    final deviceId = await getDeviceId();
    if (deviceId == null || deviceId.isEmpty) return;

    final targetType = targetIncidentTypeForKey(changedKey);
    if (targetType == null) return;

    final activeIncidents = await remoteDatasource.getActiveIncidentsByTypes(
      deviceId: deviceId,
      types: [targetType, 'safety_shutdown'],
    );

    if (activeIncidents.isEmpty) return;

    final idsToResolve = <String>{};
    var resolvedSpecific = false;

    for (final incident in activeIncidents) {
      final id = (incident['id'] ?? '').toString();
      final type = (incident['type'] ?? '').toString().toLowerCase().trim();

      if (id.isEmpty) continue;

      if (type == targetType) {
        final measuredValue = extractMeasuredValueFromIncident(
          incident['message']?.toString() ?? '',
          targetType,
        );

        if (measuredValue != null && measuredValue <= newLimit) {
          idsToResolve.add(id);
          resolvedSpecific = true;
        }
      }
    }

    if (resolvedSpecific) {
      for (final incident in activeIncidents) {
        final id = (incident['id'] ?? '').toString();
        final type = (incident['type'] ?? '').toString().toLowerCase().trim();

        if (id.isEmpty) continue;
        if (type == 'safety_shutdown') {
          idsToResolve.add(id);
        }
      }
    }

    if (idsToResolve.isNotEmpty) {
      await remoteDatasource.resolveIncidents(idsToResolve.toList());
    }
  }

  Future<String?> getDeviceId() async {
    if (deviceIdCache != null && deviceIdCache!.isNotEmpty) {
      return deviceIdCache;
    }

    deviceIdCache = await remoteDatasource.getDeviceIdByIdentifier(host);
    return deviceIdCache;
  }

  String? targetIncidentTypeForKey(String key) {
    switch (key) {
      case 'voltage_limit':
        return 'overvoltage';
      case 'power_limit':
        return 'overpower';
      case 'current_limit':
        return 'overcurrent';
      default:
        return null;
    }
  }

  double? extractMeasuredValueFromIncident(String message, String type) {
    if (message.trim().isEmpty) return null;

    RegExp? regex;
    switch (type) {
      case 'overvoltage':
        regex = RegExp(r'alcanzó\s+([\d.,]+)\s*V', caseSensitive: false);
        break;
      case 'overpower':
        regex = RegExp(r'alcanzó\s+([\d.,]+)\s*W', caseSensitive: false);
        break;
      case 'overcurrent':
        regex = RegExp(r'alcanzó\s+([\d.,]+)\s*A', caseSensitive: false);
        break;
      default:
        return null;
    }

    final match = regex.firstMatch(message);
    if (match == null) return null;

    final raw = (match.group(1) ?? '').replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;

    return double.tryParse(raw);
  }

  static double? toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(',', '.'));
    }
    return null;
  }

  static String formatNumber(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  static double? parseValue(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}