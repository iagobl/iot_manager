import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/usecases/get_active_incidents_by_types.dart';
import 'package:iot_manager/features/devices/domain/usecases/get_device_id_by_identifier.dart';
import 'package:iot_manager/features/devices/domain/usecases/resolve_incidents.dart';

class DeviceSafetyController extends ChangeNotifier {
  DeviceSafetyController({
    required this.host,
    DevicesRemoteDatasource? remoteDatasource,
  })  : rpc = ShellyRpcClient(host: host),
        getActiveIncidentsByTypes = GetActiveIncidentsByTypes(
          DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
        ),
        getDeviceIdByIdentifier = GetDeviceIdByIdentifier(
          DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
        ),
        resolveIncidentsUseCase = ResolveIncidents(
          DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
        );

  final String host;
  final ShellyRpcClient rpc;
  final GetActiveIncidentsByTypes getActiveIncidentsByTypes;
  final GetDeviceIdByIdentifier getDeviceIdByIdentifier;
  final ResolveIncidents resolveIncidentsUseCase;

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
        'config': {key: value},
      },
    );
  }

  Future<void> resolveIncidentsIfNeeded({
    required String changedKey,
    required double? newLimit,
  }) async {
    if (newLimit == null) return;

    final deviceId = await getDeviceId();
    if (deviceId == null || deviceId.isEmpty) return;

    final incidentTypes = typesForConfigKey(changedKey);
    if (incidentTypes.isEmpty) return;

    final activeIncidents = await getActiveIncidentsByTypes(
      deviceId: deviceId,
      types: incidentTypes,
    );

    if (activeIncidents.isEmpty) return;

    final idsToResolve = <String>{};

    for (final incident in activeIncidents) {
      final metricValue = toDouble(
        incident['trigger_value'] ?? incident['value'],
      );

      if (metricValue == null) continue;

      final shouldResolve = metricValue <= newLimit;
      if (!shouldResolve) continue;

      final incidentId = (incident['id'] ?? '').toString();
      if (incidentId.isEmpty) continue;

      idsToResolve.add(incidentId);
    }

    if (idsToResolve.isEmpty) return;

    await resolveIncidentsUseCase(idsToResolve.toList());
  }

  Future<String?> getDeviceId() async {
    if (deviceIdCache != null && deviceIdCache!.isNotEmpty) {
      return deviceIdCache;
    }

    deviceIdCache = await getDeviceIdByIdentifier(host);
    return deviceIdCache;
  }

  List<String> typesForConfigKey(String key) {
    switch (key) {
      case 'power_limit':
        return ['max_power_exceeded', 'power_limit_exceeded'];
      case 'voltage_limit':
        return ['max_voltage_exceeded', 'voltage_limit_exceeded'];
      case 'current_limit':
        return ['max_current_exceeded', 'current_limit_exceeded'];
      default:
        return const [];
    }
  }

  double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String formatNumber(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static double? parseValue(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}
