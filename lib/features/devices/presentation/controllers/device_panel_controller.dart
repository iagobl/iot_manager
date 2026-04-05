import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';

class DevicePanelController extends ChangeNotifier {
  DevicePanelController({
    required this.device,
    DevicesRemoteDatasource? remoteDatasource,
    ShellyRpcClient? rpcClient,
  })  : remoteDatasource = remoteDatasource ?? DevicesRemoteDatasource(),
        rpcClient = rpcClient ?? ShellyRpcClient(host: device.identifier);

  final DeviceItem device;
  final DevicesRemoteDatasource remoteDatasource;
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

  double _lastOnPowerW = 0;
  double _lastOnVoltageV = 0;
  double _lastOnCurrentA = 0;

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
  DateTime? _lastReadingSampleAt;
  double? _lastDeviceEnergyTotalWh;

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

  String get signalQuality {
    if (_rssi == 0) return DevicesPanelStrings.notData;
    if (_rssi >= -60) return DevicesPanelStrings.excellent;
    if (_rssi >= -70) return DevicesPanelStrings.good;
    if (_rssi >= -80) return DevicesPanelStrings.regular;
    return DevicesPanelStrings.bad;
  }

  String get uptimeLabel {
    if (_uptimeSeconds <= 0) return '-';

    final totalMinutes = _uptimeSeconds ~/ 60;
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes % (24 * 60)) ~/ 60;
    final minutes = totalMinutes % 60;

    if (days > 0) {
      if (hours > 0) return '${days}d ${hours}h';
      return '${days}d';
    }

    if (hours > 0) {
      if (minutes > 0) return '${hours}h ${minutes}min';
      return '${hours}h';
    }

    return '${minutes}min';
  }

  Future<void> initialize() async {
    await refresh();
    startPolling();
  }

  Future<void> refresh() async {
    if (_loading) return;

    setLoading(true);
    clearError(notify: false);

    try {
      final switchStatus = await rpcClient.getSwitchStatus();
      final deviceInfo = await rpcClient.getDeviceInfo();
      final wifiStatus = await rpcClient.getWifiStatus();
      final systemStatus = await rpcClient.getSystemStatus();

      applySwitchStatus(switchStatus);
      applyDeviceInfo(deviceInfo);
      applyWifiStatus(wifiStatus);
      applySystemStatus(systemStatus);

      if (_energyTodayWh <= 0) {
        _energyTodayWh = device.energyTodayWh;
      }

      await persistReadingSample(switchStatus: switchStatus, force: true);

      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      final failure = ErrorMapper.mapFailure(error);
      _errorMessage = failure.message;
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  Future<void> togglePower() async {
    if (_busyPowerAction) return;

    _busyPowerAction = true;
    notifyListeners();

    final nextValue = !_isOn;

    try {
      if (nextValue) {
        final blockedFailure = await getCurrentSafetyBlockFailure();
        if (blockedFailure != null) {
          _errorMessage = blockedFailure.message;
          notifyListeners();
          return;
        }

        final activeIncident =
        await remoteDatasource.getLatestActiveIncident(device.id);

        if (activeIncident != null && isSpecificBlockingIncident(activeIncident)) {
          final failure = ErrorMapper.mapFailure(
            Exception(mapIncidentTypeToErrorKey(activeIncident)),
          );
          _errorMessage = failure.message;
          notifyListeners();
          return;
        }

        _autoShutdownIncidentRecorded = false;
        _lastAutoShutdownKey = null;
      } else {
        _manualPowerOffInProgress = true;
      }

      await rpcClient.setSwitch(on: nextValue);
      await remoteDatasource.updateDeviceState(device.id, nextValue);

      _isOn = nextValue;
      _errorMessage = null;
      notifyListeners();

      await refresh();
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

  Future<SafetyBlockResult?> getCurrentSafetyBlockFailure() async {
    try {
      final switchStatus = await rpcClient.getSwitchStatus();
      final config = await rpcClient.call('Switch.GetConfig', params: {'id': 0});

      final currentVoltage = readDouble(switchStatus, const ['voltage']);
      final currentPower = readDouble(switchStatus, const ['apower', 'power']);
      final currentCurrent = readDouble(switchStatus, const ['current']);

      final voltageLimit = _toDouble(config['voltage_limit']);
      final powerLimit = _toDouble(config['power_limit']);
      final currentLimit = _toDouble(config['current_limit']);

      if (voltageLimit != null &&
          voltageLimit > 0 &&
          currentVoltage > 0 &&
          currentVoltage > voltageLimit) {
        return SafetyBlockResult(
          type: 'overvoltage',
          message: ErrorMapper.mapFailure(Exception('overvoltage')).message,
        );
      }

      if (powerLimit != null &&
          powerLimit > 0 &&
          currentPower > 0 &&
          currentPower > powerLimit) {
        return SafetyBlockResult(
          type: 'overpower',
          message: ErrorMapper.mapFailure(Exception('overpower')).message,
        );
      }

      if (currentLimit != null &&
          currentLimit > 0 &&
          currentCurrent > 0 &&
          currentCurrent > currentLimit) {
        return SafetyBlockResult(
          type: 'overcurrent',
          message: ErrorMapper.mapFailure(Exception('overcurrent')).message,
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  bool isSpecificBlockingIncident(Map<String, dynamic> incident) {
    final type = (incident['type'] ?? '').toString().toLowerCase().trim();

    return type.contains('overvoltage') ||
        type.contains('voltage') ||
        type.contains('overpower') ||
        type.contains('power') ||
        type.contains('overcurrent') ||
        type.contains('current') ||
        type.contains('overtemperature') ||
        type.contains('temperature');
  }

  void startPolling() {
    pollTimer?.cancel();
    pollTimer = Timer.periodic(
      const Duration(seconds: 5), (_) => unawaited(refreshSilently()),
    );
  }

  Future<void> refreshSilently() async {
    if (_loading || _busyPowerAction) return;

    try {
      final switchStatus = await rpcClient.getSwitchStatus();
      final deviceInfo = await rpcClient.getDeviceInfo();
      final wifiStatus = await rpcClient.getWifiStatus();
      final systemStatus = await rpcClient.getSystemStatus();

      applySwitchStatus(switchStatus);
      applyDeviceInfo(deviceInfo);
      applyWifiStatus(wifiStatus);
      applySystemStatus(systemStatus);

      await persistReadingSample(switchStatus: switchStatus);

      if (_errorMessage != null) {
        _errorMessage = null;
      }

      notifyListeners();
    } catch (error) {
      final failure = ErrorMapper.mapFailure(error);
      if (_errorMessage == null) {
        _errorMessage = failure.message;
        notifyListeners();
      }
    }
  }

  Future<void> persistReadingSample({
    required Map<String, dynamic> switchStatus,
    bool force = false,
  }) async {
    final now = DateTime.now().toUtc();

    if (!force && _lastReadingSampleAt != null) {
      final elapsed = now.difference(_lastReadingSampleAt!);
      if (elapsed.inSeconds < 10) return;
    }

    try {
      final deviceEnergyTotalWh = readDouble(
        switchStatus,
        const ['aenergy.total', 'energy.total'],
      );

      double energySampleWh = 0;
      if (_lastReadingSampleAt != null) {
        final elapsedSeconds = now.difference(_lastReadingSampleAt!).inSeconds;

        if (elapsedSeconds > 0) {
          if (deviceEnergyTotalWh > 0 &&
              _lastDeviceEnergyTotalWh != null &&
              deviceEnergyTotalWh >= _lastDeviceEnergyTotalWh!) {
            energySampleWh = deviceEnergyTotalWh - _lastDeviceEnergyTotalWh!;
          } else {
            energySampleWh = _powerW * (elapsedSeconds / 3600.0);
          }
        }
      }

      await remoteDatasource.insertReadingSample(
        deviceId: device.id,
        timestamp: now,
        powerW: _powerW,
        voltageV: _voltageV,
        energyWh: energySampleWh < 0 ? 0 : energySampleWh,
      );

      _lastReadingSampleAt = now;
      if (deviceEnergyTotalWh > 0) {
        _lastDeviceEnergyTotalWh = deviceEnergyTotalWh;
      }
    } catch (_) {
    }
  }

  void applySwitchStatus(Map<String, dynamic> switchStatus) {
    final wasOn = _isOn;

    _isOn = readBool(switchStatus, const ['output']);
    _powerW = readDouble(switchStatus, const ['apower', 'power']);
    _voltageV = readDouble(switchStatus, const ['voltage']);
    _currentA = readDouble(switchStatus, const ['current']);
    _temperatureC = readTemperatureC(switchStatus);

    final parsedEnergy = readDouble(
      switchStatus,
      const ['aenergy.total', 'energy.total', 'aenergy.by_minute'],
    );
    if (parsedEnergy > 0) {
      _energyTodayWh = parsedEnergy;
    }

    _frequencyHz = readDouble(switchStatus, const ['freq', 'frequency']);

    if (_isOn) {
      _lastOnPowerW = _powerW;
      _lastOnVoltageV = _voltageV;
      _lastOnCurrentA = _currentA;
      _autoShutdownIncidentRecorded = false;
      _lastAutoShutdownKey = null;
    }

    if (wasOn && !_isOn && !_manualPowerOffInProgress) {
      unawaited(recordAutomaticShutdownIncidentIfNeeded());
    }
  }

  Future<void> recordAutomaticShutdownIncidentIfNeeded() async {
    if (_autoShutdownIncidentRecorded) return;

    try {
      final config = await rpcClient.call(
        'Switch.GetConfig',
        params: {'id': 0},
      );

      final incident = buildAutomaticShutdownIncident(config);
      final incidentKey = incident['key']?.toString();

      if (incidentKey == null || incidentKey.isEmpty) return;
      if (_lastAutoShutdownKey == incidentKey) return;

      await remoteDatasource.insertIncident(
        deviceId: device.id,
        type: incident['type']!.toString(),
        message: incident['message']!.toString(),
        severity: incident['severity'] as int? ?? 3,
      );

      _autoShutdownIncidentRecorded = true;
      _lastAutoShutdownKey = incidentKey;
    } catch (error) {
      final failure = ErrorMapper.mapFailure(error);
      _errorMessage = failure.message;
      notifyListeners();
    }
  }

  Map<String, Object> buildAutomaticShutdownIncident(
      Map<String, dynamic> config,
      ) {
    final voltageLimit = _toDouble(config['voltage_limit']);
    final powerLimit = _toDouble(config['power_limit']);
    final currentLimit = _toDouble(config['current_limit']);

    if (voltageLimit != null &&
        voltageLimit > 0 &&
        _lastOnVoltageV > voltageLimit) {
      return {
        'key':
        'overvoltage:${_formatNumber(_lastOnVoltageV)}:${_formatNumber(voltageLimit)}',
        'type': 'overvoltage',
        'message':
        'El dispositivo se apagó automáticamente porque la tensión alcanzó ${_formatNumber(_lastOnVoltageV)} V y superó el límite configurado de ${_formatNumber(voltageLimit)} V.',
        'severity': 3,
      };
    }

    if (powerLimit != null && powerLimit > 0 && _lastOnPowerW > powerLimit) {
      return {
        'key':
        'overpower:${_formatNumber(_lastOnPowerW)}:${_formatNumber(powerLimit)}',
        'type': 'overpower',
        'message':
        'El dispositivo se apagó automáticamente porque la potencia alcanzó ${_formatNumber(_lastOnPowerW)} W y superó el límite configurado de ${_formatNumber(powerLimit)} W.',
        'severity': 3,
      };
    }

    if (currentLimit != null &&
        currentLimit > 0 &&
        _lastOnCurrentA > currentLimit) {
      return {
        'key':
        'overcurrent:${_formatNumber(_lastOnCurrentA)}:${_formatNumber(currentLimit)}',
        'type': 'overcurrent',
        'message':
        'El dispositivo se apagó automáticamente porque la corriente alcanzó ${_formatNumber(_lastOnCurrentA)} A y superó el límite configurado de ${_formatNumber(currentLimit)} A.',
        'severity': 3,
      };
    }

    return {
      'key': 'safety_shutdown',
      'type': 'safety_shutdown',
      'message':
      'El dispositivo se apagó automáticamente por una condición de seguridad.',
      'severity': 3,
    };
  }

  String mapIncidentTypeToErrorKey(Map<String, dynamic> incident) {
    final type = (incident['type'] ?? '').toString().toLowerCase().trim();

    if (type.contains('overvoltage') || type.contains('voltage')) {
      return 'overvoltage';
    }

    if (type.contains('overpower') || type.contains('power')) {
      return 'overpower';
    }

    if (type.contains('overcurrent') || type.contains('current')) {
      return 'overcurrent';
    }

    if (type.contains('temperature')) {
      return 'overtemperature';
    }

    return 'device_blocked_by_incidents';
  }

  void applyDeviceInfo(Map<String, dynamic> deviceInfo) {
    _deviceHost = device.identifier.trim().isEmpty ? '-' : device.identifier;

    _deviceIp = readString(
      deviceInfo,
      const ['ip', 'ipv4', 'wifi.sta_ip', 'wifi.ip'],
    );

    _macAddress = readString(
      deviceInfo,
      const ['mac', 'mac_address'],
    );

    _firmwareVersion = readString(
      deviceInfo,
      const ['ver', 'version', 'fw_id', 'fw'],
    );

    _deviceModel = readString(
      deviceInfo,
      const ['model', 'name', 'type'],
    );

    _hasPendingUpdate = readBool(
      deviceInfo,
      const [
        'update.available',
        'update.has_update',
        'updates.available',
        'has_update',
      ],
    );

    _needsReboot = readBool(
      deviceInfo,
      const [
        'reboot_required',
        'restart_required',
        'update.needs_reboot',
      ],
    );
  }

  void applyWifiStatus(Map<String, dynamic> wifiStatus) {
    final parsedSsid = readString(
      wifiStatus,
      const [
        'sta.ssid',
        'wifi.sta.ssid',
        'ssid',
      ],
    );
    _ssid = parsedSsid == '-' ? 'Sin datos' : parsedSsid;

    final parsedRssi = readInt(
      wifiStatus,
      const [
        'sta.rssi',
        'wifi.sta.rssi',
        'rssi',
      ],
    );
    _rssi = parsedRssi;
  }

  void applySystemStatus(Map<String, dynamic> systemStatus) {
    _uptimeSeconds = 0;

    final uptime = readNestedValue(systemStatus, 'uptime');
    if (uptime is num) {
      _uptimeSeconds = uptime.toInt();
      return;
    }

    final nestedUptime = readNestedValue(systemStatus, 'sys.uptime');
    if (nestedUptime is num) {
      _uptimeSeconds = nestedUptime.toInt();
    }
  }

  String readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = readNestedValue(source, key);

      if (value == null) continue;

      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return '-';
  }

  bool readBool(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = readNestedValue(source, key);

      if (value is bool) return value;
      if (value is num) return value != 0;

      if (value is String) {
        final normalized = value.toLowerCase().trim();
        if (normalized == 'true' || normalized == 'on') return true;
        if (normalized == 'false' || normalized == 'off') return false;
      }
    }
    return false;
  }

  double readDouble(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = readNestedValue(source, key);

      if (value is num) return value.toDouble();

      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is num) return first.toDouble();
      }

      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  int readInt(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = readNestedValue(source, key);

      if (value is int) return value;
      if (value is num) return value.toInt();

      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  double readTemperatureC(Map<String, dynamic> source) {
    final nested = readNestedValue(source, 'temperature.tC');
    if (nested is num) return nested.toDouble();

    final single = readNestedValue(source, 'temperature');
    if (single is num) return single.toDouble();

    return 0;
  }

  dynamic readNestedValue(Map<String, dynamic> source, String path) {
    dynamic current = source;

    for (final part in path.split('.')) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }

    return null;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void clearError({bool notify = true}) {
    _errorMessage = null;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }
}

class SafetyBlockResult {
  const SafetyBlockResult({
    required this.type,
    required this.message,
  });

  final String type;
  final String message;
}