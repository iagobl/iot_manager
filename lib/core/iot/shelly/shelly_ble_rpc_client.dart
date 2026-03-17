import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:iot_manager/core/constants/iot_strings.dart';

import 'package:iot_manager/core/error/app_exception.dart';

class ShellyBleRpcClient {

  ShellyBleRpcClient(this.device);
  static final Guid shellyServiceUuid = Guid('5f6d4f53-5f52-5043-5f53-56435f49445f');
  static final Guid rpcDataUuid = Guid('5f6d4f53-5f52-5043-5f64-6174615f5f5f');
  static final Guid rpcTxCtlUuid = Guid('5f6d4f53-5f52-5043-5f74-785f63746c5f');
  static final Guid rpcRxCtlUuid = Guid('5f6d4f53-5f52-5043-5f72-785f63746c5f');

  final BluetoothDevice device;

  BluetoothCharacteristic? data;
  BluetoothCharacteristic? txCtl;
  BluetoothCharacteristic? rxCtl;

  int nextId = 1;
  int mtu = 23;

  StreamSubscription<List<int>>? rxCtlSub;
  int lastNotifiedLen = 0;

  Future<void> connect({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      try {
        await device.disconnect();
      } catch (_) {}

      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          await device.connect(
            timeout: timeout,
            autoConnect: false,
          );
          break;
        } catch (error) {
          if (attempt == 1) {
            throw const NetworkAppException(IoTStrings.notConnectingWithBluetooth);
          }
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }

      final services = await device.discoverServices();

      final shellySvc = services.firstWhere(
            (s) => s.uuid == shellyServiceUuid,
        orElse: () => throw const ValidationAppException(IoTStrings.notFoundRPC),
      );

      data = shellySvc.characteristics.firstWhere(
            (c) => c.uuid == rpcDataUuid,
        orElse: () => throw const ValidationAppException(IoTStrings.notFoundCharacteristicRPC),
      );

      txCtl = shellySvc.characteristics.firstWhere(
            (c) => c.uuid == rpcTxCtlUuid,
        orElse: () => throw const ValidationAppException(IoTStrings.notFoundTXCTL),
      );

      rxCtl = shellySvc.characteristics.firstWhere(
            (c) => c.uuid == rpcRxCtlUuid,
        orElse: () => throw const ValidationAppException(IoTStrings.notFoundRXCTL),
      );

      try {
        final negotiated = await device.requestMtu(247);
        mtu = negotiated;
      } catch (_) {
        mtu = 23;
      }

      lastNotifiedLen = 0;
      await rxCtl!.setNotifyValue(true);

      await rxCtlSub?.cancel();
      rxCtlSub = rxCtl!.lastValueStream.listen((bytes) {
        if (bytes.length >= 4) {
          final len = ByteData.sublistView(
            Uint8List.fromList(bytes),
          ).getUint32(0, Endian.big);

          if (len > 0) {
            lastNotifiedLen = len;
          }
        }
      });
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const TimeoutAppException(IoTStrings.timeOutConnectingBLE);
    } catch (_) {
      throw const UnknownAppException(IoTStrings.errorCommunicatingBLE);
    }
  }

  Future<void> disconnect() async {
    await rxCtlSub?.cancel();
    rxCtlSub = null;
    lastNotifiedLen = 0;

    try {
      await device.disconnect();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> call(
      String method, {
        Map<String, dynamic>? params,
        String src = 'tfg_iot_app',
        Duration timeout = const Duration(seconds: 15),
      }) async {
    try {
      assertConnected();

      final id = nextId++;
      final payload = <String, dynamic>{
        'id': id,
        'src': src,
        'method': method,
        if (params != null) 'params': params,
      };

      final bytes = utf8.encode(jsonEncode(payload));

      lastNotifiedLen = 0;
      await writeRpcRequest(bytes);

      final sw = Stopwatch()..start();
      while (lastNotifiedLen == 0) {
        if (sw.elapsed > timeout) {
          throw TimeoutException(IoTStrings.waitingResponseRXCTL + method);
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final respLen = lastNotifiedLen;
      lastNotifiedLen = 0;

      await Future.delayed(const Duration(milliseconds: 100));

      final respBytes = await _readDataChunks(respLen, timeout);
      final respStr = utf8.decode(respBytes);
      final decoded = jsonDecode(respStr);

      if (decoded is! Map<String, dynamic>) {
        throw const ValidationAppException(IoTStrings.invalidRequestBLE);
      }

      if (decoded['id'] != id) {
        throw const ValidationAppException(IoTStrings.errorReceivedBLE);
      }

      if (decoded.containsKey('error')) {
        final err = decoded['error'];
        final msg = err is Map ? err['message'] : err.toString();
        throw ServerAppException(IoTStrings.errorRPCBLE + msg);
      }

      final result = decoded['result'];
      if (result is Map<String, dynamic>) return result;
      return {'value': result};
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const TimeoutAppException(IoTStrings.timeOutConnectingBluetooth);
    } catch (_) {
      throw const UnknownAppException(IoTStrings.notCompletedOperationBLE);
    }
  }

  Future<List<int>> _readDataChunks(int totalLen, Duration timeout) async {
    final buffer = <int>[];
    final sw = Stopwatch()..start();

    while (buffer.length < totalLen) {
      if (sw.elapsed > timeout) {
        throw const TimeoutAppException(IoTStrings.timeOutRedingData);
      }

      try {
        final chunk = await data!.read();
        if (chunk.isNotEmpty) {
          buffer.addAll(chunk);
        } else {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    return buffer.take(totalLen).toList();
  }

  Future<String?> getRealMac() async {
    try {
      final info = await call(
        'Shelly.GetDeviceInfo',
        timeout: const Duration(seconds: 10),
      );
      return info['mac']?.toString();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownAppException(IoTStrings.errorGettingMac);
    }
  }

  Future<void> setWifiSta({
    required String ssid,
    required String pass,
  }) async {
    if (ssid.trim().isEmpty) {
      throw const ValidationAppException(IoTStrings.ssidRequiredWifi);
    }

    if (pass.isEmpty) {
      throw const ValidationAppException(IoTStrings.passwordRequiredWIFI);
    }

    await call(
      'WiFi.SetConfig',
      params: {'config': {'sta': {'enable': true, 'ssid': ssid, 'pass': pass,}}},
      timeout: const Duration(seconds: 15),
    );
  }

  Future<void> reboot({int delayMs = 3000}) async {
    try {
      await call(
        'Shelly.Reboot',
        params: {'delay_ms': delayMs},
        timeout: const Duration(seconds: 15),
      );
    } catch (_) {
      throw const UnknownAppException(IoTStrings.notRebootingDevice);
    }
  }

  Future<void> writeRpcRequest(List<int> rpcJsonBytes) async {
    final data = this.data!;
    final txCtl = this.txCtl!;
    final lenBytes = ByteData(4)..setUint32(0, rpcJsonBytes.length, Endian.big);

    await txCtl.write(
      lenBytes.buffer.asUint8List(),
      withoutResponse: false,
    );
    await Future.delayed(const Duration(milliseconds: 150));

    final maxPayload = max(20, mtu - 3);
    final chunkSize = min(200, maxPayload);

    int offset = 0;
    while (offset < rpcJsonBytes.length) {
      final end = min(offset + chunkSize, rpcJsonBytes.length);

      await data.write(
        rpcJsonBytes.sublist(offset, end),
        withoutResponse: false,
      );

      offset = end;

      if (offset < rpcJsonBytes.length) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  }

  void assertConnected() {
    if (data == null || txCtl == null || rxCtl == null) {
      throw const ValidationAppException(IoTStrings.notConnectingBLE);
    }
  }
}