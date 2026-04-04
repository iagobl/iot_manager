import 'dart:async';

import 'package:iot_manager/core/constants/devices_strings.dart';
import 'package:iot_manager/core/constants/iot_strings.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/iot/shelly/shelly_lan_discovery.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/core/iot/wifi/shelly_ap_wifi_service.dart';

class ShellyApDeviceSession {
  const ShellyApDeviceSession({
    required this.accessPoint,
    required this.deviceInfo,
    required this.mac,
  });

  final ShellyApAccessPoint accessPoint;
  final Map<String, dynamic> deviceInfo;
  final String? mac;
}

class ShellyApProvisionResult {
  const ShellyApProvisionResult({
    required this.ip,
    required this.deviceInfo,
  });

  final String ip;
  final Map<String, dynamic> deviceInfo;
}

class ShellyApProvisionService {
  ShellyApProvisionService({
    ShellyApWifiService? wifiService,
    ShellyLanDiscovery? lanDiscovery,
  })  : wifiService = wifiService ?? ShellyApWifiService(),
        lanDiscovery = lanDiscovery ?? ShellyLanDiscovery();

  static const String shellyApHost = '192.168.33.1';

  final ShellyApWifiService wifiService;
  final ShellyLanDiscovery lanDiscovery;

  Future<ShellyApDeviceSession> connectAndReadDeviceInfo(ShellyApAccessPoint accessPoint)async {
    try {
      await wifiService.connectToShellyAp(accessPoint);
      await wifiService.enableDeviceWifiRouting();

      final currentSsid = await wifiService.getCurrentSsid();

      if (currentSsid == null || currentSsid.trim() != accessPoint.ssid.trim()) {
        throw const ValidationAppException('El móvil no quedó conectado a la red del Shelly seleccionada.');
      }

      final rpc = ShellyRpcClient(host: shellyApHost);
      final info = await rpc.getDeviceInfo().timeout(const Duration(seconds: 10));
      final mac = info['mac']?.toString();

      return ShellyApDeviceSession(accessPoint: accessPoint, deviceInfo: info, mac: mac);
    } on TimeoutException {
      throw const TimeoutAppException('Conectado al Shelly, pero no respondió a tiempo en modo AP.');
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownAppException(DevicesStrings.errorProvisioningAp);
    }
  }

  Future<ShellyApDeviceSession> readDeviceInfoFromCurrentAp(ShellyApAccessPoint accessPoint) async {
    try {
      final currentSsid = await wifiService.getCurrentSsid();

      if (currentSsid == null || currentSsid.trim() != accessPoint.ssid.trim()) {
        throw const ValidationAppException('El móvil no está conectado a la red del Shelly seleccionado.');
      }

      await wifiService.enableDeviceWifiRouting();

      final rpc = ShellyRpcClient(host: shellyApHost);
      final info = await rpc.getDeviceInfo().timeout(const Duration(seconds: 10));
      final mac = info['mac']?.toString();

      return ShellyApDeviceSession(accessPoint: accessPoint, deviceInfo: info, mac: mac);

    } on TimeoutException {
      throw const TimeoutAppException('Conectado al Shelly, pero no respondió a tiempo en modo AP.');
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownAppException(DevicesStrings.errorProvisioningAp);
    }
  }

  Future<void> sendWifiCredentials({required String ssid, required String password}) async {
    if (ssid.trim().isEmpty) {
      throw const ValidationAppException(IoTStrings.ssidRequiredWifi);
    }

    if (password.isEmpty) {
      throw const ValidationAppException(IoTStrings.passwordRequiredWIFI);
    }

    try {
      await wifiService.enableDeviceWifiRouting();
      final rpc = ShellyRpcClient(host: shellyApHost);

      await rpc.call('WiFi.SetConfig', params: {
          'config': {
            'sta': {
              'enable': true,
              'ssid': ssid.trim(),
              'pass': password,
            },
          },
        },
      ).timeout(const Duration(seconds: 10));

      await rpc.reboot(delayMs: 1500).timeout(const Duration(seconds: 8));
      await Future.delayed(const Duration(seconds: 2));
      await wifiService.disableDeviceWifiRouting();

    } on TimeoutException {
      throw const TimeoutAppException('El Shelly tardó demasiado en aplicar la configuración Wi-Fi.');
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownAppException(IoTStrings.errorSendingWifiCredentialsByAp);
    }
  }

  Future<ShellyApProvisionResult> discoverProvisionedDevice({String? expectedMac}) async {
    try {
      await wifiService.disableDeviceWifiRouting();

      final found = await lanDiscovery.discoverFirst(
        expectedMac: expectedMac,
        perHostTimeout: const Duration(milliseconds: 500),
        concurrency: 40,
      );

      if (found == null) {
        throw const DeviceAppException(DevicesStrings.notFoundDevice);
      }

      return ShellyApProvisionResult(ip: found.ip, deviceInfo: found.deviceInfo);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownAppException(DevicesStrings.errorProvisioningAp);
    }
  }
}