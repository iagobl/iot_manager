import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/devices/domain/usecases/get_latest_active_incident.dart';
import 'package:iot_manager/features/devices/domain/usecases/insert_incident.dart';
import 'package:iot_manager/features/devices/domain/usecases/update_device_state.dart';

class DevicePanelController extends ChangeNotifier {
  DevicePanelController({
    required this.device,
    DevicesRemoteDatasource? remoteDatasource,
    ShellyRpcClient? rpcClient,
  })  : getLatestActiveIncident = GetLatestActiveIncident(
    DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
  ),
        updateDeviceStateUseCase = UpdateDeviceState(
          DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
        ),
        insertIncidentUseCase = InsertIncident(
          DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
        ),
        rpcClient = rpcClient ?? ShellyRpcClient(host: device.identifier);

  final DeviceItem device;
  final GetLatestActiveIncident getLatestActiveIncident;
  final UpdateDeviceState updateDeviceStateUseCase;
  final InsertIncident insertIncidentUseCase;
  final ShellyRpcClient rpcClient;

  bool _loading = false;
  bool _busyPowerAction = false;
  String? _errorMessage;

  bool _isOn = false;
  double _powerW = 0;
  double _voltageV = 0;
  double _currentA = 0;
  double _temperatureC = 0;
  double _energyTodayWh = 0;
  double _frequencyHz = 0;


  bool _manualPowerOffInProgress = false;
  bool _autoShutdownIncidentRecorded = false;
  String? _lastAutoShutdownKey;

  String _deviceHost = '-';
  String _deviceIp = '-';
  String _macAddress = '-';
  String _firmwareVersion = '-';
  String _deviceModel = '-';
  bool _hasPendingUpdate = false;
  bool _needsReboot = false;

  String _ssid = DevicesPanelStrings.notData;
  int _rssi = 0;
  int _uptimeSeconds = 0;

  Timer? pollTimer;

  bool get loading => _loading;
  bool get busyPowerAction => _busyPowerAction;
  String? get errorMessage => _errorMessage;

  bool get isOn => _isOn;
  double get powerW => _powerW;
  double get voltageV => _voltageV;
  double get currentA => _currentA;
  double get temperatureC => _temperatureC;
  double get energyTodayWh => _energyTodayWh;
  double get frequencyHz => _frequencyHz;

  String get deviceHost => _deviceHost;
  String get deviceIp => _deviceIp;
  String get macAddress => _macAddress;
  String get firmwareVersion => _firmwareVersion;
  String get deviceModel => _deviceModel;
  bool get hasPendingUpdate => _hasPendingUpdate;
  bool get needsReboot => _needsReboot;

  String get ssid => _ssid;
  int get rssi => _rssi;
  int get uptimeSeconds => _uptimeSeconds;

  Future<void> initialize() async {
    await init();
  }

  Future<void> init() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _refresh();
      startPolling();
    } catch (error) {
      final failure = ErrorMapper.mapFailure(error);
      _errorMessage = failure.message;
      notifyListeners();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _refresh();
  }

  Future<void> refreshNow() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _refresh();
    } catch (error) {
      final failure = ErrorMapper.mapFailure(error);
      _errorMessage = failure.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _refresh() async {
    final switchStatus = await rpcClient.getSwitchStatus();
    final sysStatus = await rpcClient.call('Sys.GetStatus');
    final wifiStatus = await rpcClient.call('WiFi.GetStatus');
    final switchConfig = await rpcClient.call('Switch.GetConfig', params: {'id': 0});

    final output = switchStatus['output'] == true;
    final power = toDouble(switchStatus['apower']) ?? 0;
    final voltage = toDouble(switchStatus['voltage']) ?? 0;
    final current = toDouble(switchStatus['current']) ?? 0;
    final temperature = toDouble(
      (switchStatus['temperature'] is Map)
          ? switchStatus['temperature']['tC']
          : null,
    ) ??
        0;
    final energyToday = toDouble(
      (switchStatus['aenergy'] is Map)
          ? switchStatus['aenergy']['total']
          : null,
    ) ??
        0;
    final freq = toDouble(switchStatus['freq']) ?? 0;

    _isOn = output;
    _powerW = power;
    _voltageV = voltage;
    _currentA = current;
    _temperatureC = temperature;
    _energyTodayWh = energyToday;
    _frequencyHz = freq;

    if (output) {
    }

    _deviceHost = device.identifier;
    _deviceIp = (wifiStatus['sta_ip'] ?? switchStatus['src'] ?? '-').toString();
    _macAddress = (sysStatus['mac'] ?? '-').toString();
    _firmwareVersion =
        (sysStatus['ver'] ?? sysStatus['fw_id'] ?? '-').toString();
    _deviceModel = (sysStatus['model'] ?? sysStatus['device'] ?? '-').toString();
    _hasPendingUpdate = sysStatus['available_updates'] != null;
    _needsReboot = sysStatus['restart_required'] == true;

    _ssid = (wifiStatus['ssid'] ?? DevicesPanelStrings.notData).toString();
    _rssi = toInt(wifiStatus['rssi']) ?? 0;
    _uptimeSeconds = toInt(sysStatus['uptime']) ?? 0;

    await _checkIfThereIsActiveIncident();
    await _handleSafetyAutoShutdownIfNeeded(
      switchConfig: switchConfig,
      output: output,
      power: power,
      voltage: voltage,
      current: current,
    );

    notifyListeners();
  }

  Future<void> _checkIfThereIsActiveIncident() async {
    try {
      final latestIncident = await getLatestActiveIncident(device.id);

      if (latestIncident == null) {
        _autoShutdownIncidentRecorded = false;
        _lastAutoShutdownKey = null;
        return;
      }

      final type = (latestIncident['type'] ?? '').toString();
      final status = (latestIncident['status'] ?? '').toString();

      if (status == 'active' &&
          (type == 'max_power_exceeded' ||
              type == 'max_voltage_exceeded' ||
              type == 'max_current_exceeded')) {
        _autoShutdownIncidentRecorded = true;
        _lastAutoShutdownKey = type;
      } else {
        _autoShutdownIncidentRecorded = false;
        _lastAutoShutdownKey = null;
      }
    } catch (_) {}
  }

  Future<void> togglePower() async {
    if (_busyPowerAction) return;

    _busyPowerAction = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextValue = !_isOn;

      await rpcClient.setSwitch(on: nextValue);
      await updateDeviceStateUseCase(device.id, nextValue);

      _isOn = nextValue;

      if (!nextValue) {
        _manualPowerOffInProgress = true;
        _powerW = 0;
        _voltageV = 0;
        _currentA = 0;
        _temperatureC = 0;
        _frequencyHz = 0;
      }

      notifyListeners();
      await _refresh();
    } catch (error) {
      final failure = ErrorMapper.mapFailure(error);
      _errorMessage = failure.message;
      notifyListeners();
    } finally {
      _manualPowerOffInProgress = false;
      _busyPowerAction = false;
      notifyListeners();
    }
  }

  Future<void> _handleSafetyAutoShutdownIfNeeded({
    required Map<String, dynamic> switchConfig,
    required bool output,
    required double power,
    required double voltage,
    required double current,
  }) async {
    if (!output) {
      if (_manualPowerOffInProgress) {
        _autoShutdownIncidentRecorded = false;
        _lastAutoShutdownKey = null;
      }
      return;
    }

    final powerLimit = toDouble(switchConfig['power_limit']);
    final voltageLimit = toDouble(switchConfig['voltage_limit']);
    final currentLimit = toDouble(switchConfig['current_limit']);

    String? incidentType;
    String? incidentMessage;
    double? triggerValue;

    if (powerLimit != null && powerLimit > 0 && power > powerLimit) {
      incidentType = 'max_power_exceeded';
      incidentMessage =
      'El dispositivo se apagó automáticamente por superar el límite de potencia.';
      triggerValue = power;
    } else if (voltageLimit != null &&
        voltageLimit > 0 &&
        voltage > voltageLimit) {
      incidentType = 'max_voltage_exceeded';
      incidentMessage =
      'El dispositivo se apagó automáticamente por superar el límite de voltaje.';
      triggerValue = voltage;
    } else if (currentLimit != null &&
        currentLimit > 0 &&
        current > currentLimit) {
      incidentType = 'max_current_exceeded';
      incidentMessage =
      'El dispositivo se apagó automáticamente por superar el límite de corriente.';
      triggerValue = current;
    }

    if (incidentType == null || incidentMessage == null || triggerValue == null) {
      return;
    }

    if (_autoShutdownIncidentRecorded &&
        _lastAutoShutdownKey == incidentType &&
        !_manualPowerOffInProgress) {
      return;
    }

    try {
      await rpcClient.setSwitch(on: false);

      await insertIncidentUseCase(
        deviceId: device.id,
        type: incidentType,
        message: incidentMessage,
        severity: 3,
      );

      await updateDeviceStateUseCase(device.id, false);

      _isOn = false;
      _powerW = 0;
      _voltageV = 0;
      _currentA = 0;
      _temperatureC = 0;
      _frequencyHz = 0;

      _autoShutdownIncidentRecorded = true;
      _lastAutoShutdownKey = incidentType;

      notifyListeners();
    } catch (_) {}
  }

  void startPolling() {
    pollTimer?.cancel();
    pollTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => unawaited(refreshSilently()),
    );
  }

  Future<void> refreshSilently() async {
    if (_loading || _busyPowerAction) return;

    try {
      await _refresh();
    } catch (_) {}
  }

  double? toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String get signalQuality {
    if (_rssi >= -55) return 'Excelente';
    if (_rssi >= -67) return 'Buena';
    if (_rssi >= -75) return 'Aceptable';
    if (_rssi >= -85) return 'Débil';
    return 'Muy débil';
  }

  String get uptimeLabel {
    final totalSeconds = _uptimeSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    if (hours <= 0) {
      return '$minutes min';
    }

    return '$hours h $minutes min';
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }
}
