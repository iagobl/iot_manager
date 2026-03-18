import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:iot_manager/core/constants/iot_strings.dart';
import 'package:iot_manager/core/error/app_exception.dart';

class ShellyRpcClient {
  ShellyRpcClient({
    required this.host,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String host;
  final http.Client _client;

  Future<Map<String, dynamic>> call(
      String method, {
        Map<String, dynamic>? params,
        Duration timeout = const Duration(seconds: 4),
      }) async {
    if (host.trim().isEmpty) {
      throw const ValidationAppException(
        'La dirección del dispositivo no es válida.',
      );
    }

    try {
      final body = <String, dynamic>{
        'id': 1,
        'src': 'tfg_iot_app',
        'method': method,
        if (params != null) 'params': params,
      };

      final res = await _client
          .post(
        Uri.parse('http://$host/rpc'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )
          .timeout(timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ServerAppException(
          'Error HTTP ${res.statusCode} al comunicarse con el Shelly.',
        );
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ValidationAppException(IoTStrings.notValidResponseFormat);
      }

      if (decoded['error'] != null) {
        throw DeviceAppException(
          '${IoTStrings.errorRPCDevice}${decoded['error']}',
        );
      }

      if (!decoded.containsKey('result')) {
        throw const ValidationAppException(IoTStrings.notValidResponseFormat);
      }

      final result = decoded['result'];
      if (result is Map<String, dynamic>) return result;
      return {'value': result};
    } on AppException {
      rethrow;
    } on http.ClientException {
      throw const NetworkAppException(IoTStrings.cannotConnectLocalNetwork);
    } on TimeoutException {
      throw const TimeoutAppException(IoTStrings.tooLongResponseTime);
    } on FormatException {
      throw const ValidationAppException(IoTStrings.notValidResponseFormat);
    } catch (_) {
      throw const UnknownAppException(IoTStrings.notFoundErrorWithDevice);
    }
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    return call('Shelly.GetDeviceInfo');
  }

  Future<Map<String, dynamic>> getSwitchStatus({int id = 0}) async {
    return call('Switch.GetStatus', params: {'id': id});
  }

  Future<Map<String, dynamic>> getWifiStatus() async {
    return call('Wifi.GetStatus');
  }

  Future<Map<String, dynamic>> getSystemStatus() async {
    return call('Sys.GetStatus');
  }

  Future<void> setSwitch({required bool on, int id = 0,}) async {
    await call('Switch.Set', params: {'id': id, 'on': on});
  }

  Future<Map<String, dynamic>> getSysConfig() async {
    return call('Sys.GetConfig');
  }

  Future<void> setSysConfig({
    required Map<String, dynamic> config,
  }) async {
    await call('Sys.SetConfig', params: {'config': config});
  }

  Future<Map<String, dynamic>> detectLocation() async {
    return call('Shelly.DetectLocation');
  }

  Future<Map<String, dynamic>> checkForUpdate() async {
    return call('Shelly.CheckForUpdate');
  }

  Future<void> updateFirmware({String stage = 'stable'}) async {
    await call('Shelly.Update',
      params: {'stage': stage},
      timeout: const Duration(seconds: 8),
    );
  }

  Future<void> reboot({int delayMs = 1000}) async {
    await call('Shelly.Reboot', params: {'delay_ms': delayMs});
  }

  Future<void> factoryReset() async {
    await call('Shelly.FactoryReset');
  }

  Future<Map<String, dynamic>> getPlugsUiConfig() async {
    return call('PLUGS_UI.GetConfig');
  }

  Future<void> setPlugsUiConfig({
    required Map<String, dynamic> config,
  }) async {
    await call('PLUGS_UI.SetConfig', params: {'config': config});
  }
}