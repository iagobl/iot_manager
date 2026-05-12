import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:iot_manager/core/error/app_exception.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

class ShellyApAccessPoint {
  const ShellyApAccessPoint({
    required this.ssid,
    this.bssid,
    this.level,
    this.capabilities,
  });

  final String ssid;
  final String? bssid;
  final int? level;
  final String? capabilities;

  bool get isOpenNetwork {
    final caps = (capabilities ?? '').toUpperCase();
    return !caps.contains('WEP') &&
        !caps.contains('WPA') &&
        !caps.contains('PSK') &&
        !caps.contains('EAP');
  }
}

class ShellyApWifiService {
  Future<void> ensurePermissions() async {
    final location = await Permission.locationWhenInUse.request();

    PermissionStatus? nearbyWifi;
    try {
      nearbyWifi = await Permission.nearbyWifiDevices.request();
    } catch (e) {
      nearbyWifi = null;
    }

    final locationGranted = location.isGranted;
    final nearbyGranted = nearbyWifi == null || nearbyWifi.isGranted || nearbyWifi.isRestricted;

    if (locationGranted && nearbyGranted) return;

    final blocked = location.isPermanentlyDenied || (nearbyWifi?.isPermanentlyDenied ?? false);

    if (blocked) {
      throw const ValidationAppException('Los permisos de Wi-Fi o ubicación están bloqueados. Ve a Ajustes y habilítalos para buscar y conectar redes Shelly.');
    }

    throw const ValidationAppException('La app necesita permisos de Wi-Fi y ubicación para trabajar con el modo AP.',);
  }

  Future<void> enableDeviceWifiRouting() async {
    try {
      await WiFiForIoTPlugin.forceWifiUsage(true);
    } catch (e) {
      debugPrint('AP_WIFI forceWifiUsage(true) error: $e');
    }
  }

  Future<void> disableDeviceWifiRouting() async {
    try {
      await WiFiForIoTPlugin.forceWifiUsage(false);
    } catch (e) {
      debugPrint('AP_WIFI forceWifiUsage(false) error: $e');
    }
  }

  Future<List<ShellyApAccessPoint>> scanShellyAccessPoints() async {
    try {
      await ensurePermissions();
      // ignore: deprecated_member_use
      final results = await WiFiForIoTPlugin.loadWifiList();

      final mapped = results.map((network) => ShellyApAccessPoint(
          ssid: normalizeSsid(network.ssid),
          bssid: network.bssid,
          level: network.level,
          capabilities: network.capabilities,
        ),
      ).where((ap) => ap.ssid.isNotEmpty && looksLikeShelly(ap.ssid)).toList();

      final deduped = <String, ShellyApAccessPoint>{};

      for (final ap in mapped) {
        final existing = deduped[ap.ssid];
        if (existing == null) {
          deduped[ap.ssid] = ap;
          continue;
        }

        final currentLevel = ap.level ?? -999;
        final existingLevel = existing.level ?? -999;
        if (currentLevel > existingLevel) {
          deduped[ap.ssid] = ap;
        }
      }

      final list = deduped.values.toList()
        ..sort((a, b) => (b.level ?? -999).compareTo(a.level ?? -999));

      return list;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownAppException('No se pudieron escanear las redes Wi-Fi Shelly cercanas.');
    }
  }

  Future<String?> getCurrentSsid() async {
    try {
      await ensurePermissions();
      final ssid = await WiFiForIoTPlugin.getSSID();
      final normalized = normalizeSsid(ssid);

      return normalized.isEmpty ? null : normalized;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownAppException('No se pudo obtener la red Wi-Fi actual del móvil.');
    }
  }

  Future<bool> isConnectedToSsid(String ssid) async {
    final current = await getCurrentSsid();
    if (current == null) return false;
    return current.trim() == ssid.trim();
  }

  Future<void> connectToShellyAp(ShellyApAccessPoint accessPoint, {
        Duration timeout = const Duration(seconds: 20),
      }) async {
    try {
      await ensurePermissions();
      await getCurrentSsid();

      final alreadyConnected = await isConnectedToSsid(accessPoint.ssid);
      if (alreadyConnected) {
        await enableDeviceWifiRouting();
        return;
      }

      final success = await WiFiForIoTPlugin.connect(
        accessPoint.ssid,
        password: '',
        joinOnce: true,
        security: accessPoint.isOpenNetwork ? NetworkSecurity.NONE : NetworkSecurity.WPA,
      );

      if (!success) {
        throw const NetworkAppException('No se pudo conectar automáticamente a la red del Shelly.');
      }

      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        final current = await getCurrentSsid();

        if (current != null && current.trim() == accessPoint.ssid.trim()) {
          await enableDeviceWifiRouting();
          return;
        }

        await Future.delayed(const Duration(milliseconds: 800));
      }

      throw const TimeoutAppException('Se agotó el tiempo al intentar conectarse a la red del Shelly.');
    } on AppException {
      rethrow;
    } catch (e) {
      throw const UnknownAppException('No se pudo conectar automáticamente a la red del Shelly.');
    }
  }

  bool looksLikeShellySsid(String ssid) {
    return looksLikeShelly(ssid);
  }

  String normalizeSsid(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll('"', '').trim();
  }

  bool looksLikeShelly(String ssid) {
    final value = ssid.toLowerCase();
    return value.contains('shelly') || value.contains('addshelly');
  }
}
