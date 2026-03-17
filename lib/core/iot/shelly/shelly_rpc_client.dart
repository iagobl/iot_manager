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
    try {
      final body = <String, dynamic>{
        'id': 1,
        'src': 'tfg_iot_app',
        'method': method,
        if (params != null) 'params': params,
      };

      final res = await _client.post(
        Uri.parse('http://$host/rpc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ServerAppException(
          'Error HTTP ${res.statusCode} al comunicarse con el Shelly.',
        );
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ValidationAppException(IoTStrings.notValidRequest,);
      }

      if (decoded.containsKey('error')) {
        throw ServerAppException(IoTStrings.errorRPCDevice + decoded['error'].toString());
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

  Future<Map<String, dynamic>> getDeviceInfo() => call('Shelly.GetDeviceInfo');

  Future<Map<String, dynamic>> getSwitchStatus({int id = 0}) =>
      call('Switch.GetStatus', params: {'id': id});

  Future<void> setSwitch({required bool on, int id = 0,}) =>
      call('Switch.Set', params: {'id': id, 'on': on});
}