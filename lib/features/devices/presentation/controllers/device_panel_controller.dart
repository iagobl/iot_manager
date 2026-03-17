import 'dart:async';

import 'package:flutter/foundation.dart';

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

      applySwitchStatus(switchStatus);

      if (_energyTodayWh <= 0) {
        _energyTodayWh = device.energyTodayWh;
      }

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

    try {
      final nextValue = !_isOn;

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
      _busyPowerAction = false;
      notifyListeners();
    }
  }

  void startPolling() {
    pollTimer?.cancel();
    pollTimer = Timer.periodic(const Duration(seconds: 5),
          (_) => unawaited(refreshSilently())
    );
  }

  Future<void> refreshSilently() async {
    if (_loading || _busyPowerAction) return;

    try {
      final switchStatus = await rpcClient.getSwitchStatus();
      applySwitchStatus(switchStatus);

      if (_errorMessage != null) {_errorMessage = null;}

      notifyListeners();
    } catch (_) {}
  }

  void applySwitchStatus(Map<String, dynamic> switchStatus) {
    _isOn = readBool(switchStatus, const ['output']);
    _powerW = readDouble(switchStatus, const ['apower', 'power']);
    _voltageV = readDouble(switchStatus, const ['voltage']);
    _currentA = readDouble(switchStatus, const ['current']);
    _temperatureC = readTemperatureC(switchStatus);

    final parsedEnergy = readDouble(switchStatus,
      const ['aenergy.total', 'energy.total', 'aenergy.by_minute'],
    );
    if (parsedEnergy > 0) {
      _energyTodayWh = parsedEnergy;
    }

    _frequencyHz = readDouble(switchStatus, const ['freq', 'frequency']);
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

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void clearError({bool notify = true}) {
    _errorMessage = null;
    if (notify) {notifyListeners();}
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }
}