import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';

class DeviceSafetyController extends ChangeNotifier {
  DeviceSafetyController({
    required this.host,
  }) : rpc = ShellyRpcClient(host: host);

  final String host;
  final ShellyRpcClient rpc;

  bool loading = false;
  bool savingPower = false;
  bool savingVoltage = false;
  bool savingCurrent = false;

  double? powerLimit;
  double? voltageLimit;
  double? currentLimit;

  String? error;

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

  static double? toDouble(dynamic v) {
    if (v is num) return v.toDouble();
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