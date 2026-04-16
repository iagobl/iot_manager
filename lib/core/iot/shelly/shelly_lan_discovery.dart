import 'dart:async';
import 'dart:collection';

import 'package:http/http.dart' as http;
import 'package:iot_manager/core/constants/iot_strings.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/iot/models/discovered_iot_device.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/core/iot/wifi/wifi_info_service.dart';

class ShellyLanDiscoveryResult {
  ShellyLanDiscoveryResult({
    required this.ip,
    required this.deviceInfo,
  });

  final String ip;
  final Map<String, dynamic> deviceInfo;
}

class ShellyLanDiscovery {
  ShellyLanDiscovery({
    WifiInfoService? wifi,
    http.Client? client,
  })  : wifiInfoService = wifi ?? WifiInfoService(),
        _client = client ?? http.Client();

  final WifiInfoService wifiInfoService;
  final http.Client _client;

  Future<ShellyLanDiscoveryResult?> discoverFirst({
    String? expectedMac,
    Duration perHostTimeout = const Duration(milliseconds: 450),
    int concurrency = 40,
    bool includeHotspotFallbacks = true,
    List<String>? scanPrefixes,
  }) async {
    try {
      final prefixes = await _resolveScanPrefixes(
        includeHotspotFallbacks: includeHotspotFallbacks,
        scanPrefixes: scanPrefixes,
      );

      if (prefixes.isEmpty) {
        throw const NetworkAppException(IoTStrings.notConnectingWiFi);
      }

      final normalizedExpectedMac = normMac(expectedMac);
      ShellyLanDiscoveryResult? firstFound;

      for (final prefix in prefixes) {
        final scan = await _scanSinglePrefix(
          prefix,
          expectedMac: normalizedExpectedMac,
          perHostTimeout: perHostTimeout,
          concurrency: concurrency,
        );

        if (scan.exactMacFound != null) {
          return scan.exactMacFound;
        }

        firstFound ??= scan.firstFound;

        if (normalizedExpectedMac == null && firstFound != null) {
          return firstFound;
        }
      }

      return firstFound;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownAppException(IoTStrings.notFoundErrorWiFi);
    }
  }

  Future<List<DiscoveredIotDevice>> discoverAll({
    Duration perHostTimeout = const Duration(milliseconds: 450),
    int concurrency = 40,
    int? maxResults,
    bool includeHotspotFallbacks = true,
    List<String>? scanPrefixes,
  }) async {
    try {
      final prefixes = await _resolveScanPrefixes(
        includeHotspotFallbacks: includeHotspotFallbacks,
        scanPrefixes: scanPrefixes,
      );

      if (prefixes.isEmpty) {
        throw const NetworkAppException(IoTStrings.notFoundInSubnetDevice);
      }

      final results = <DiscoveredIotDevice>[];
      final seenKeys = <String>{};

      for (final prefix in prefixes) {
        final prefixResults = await _discoverAllInPrefix(
          prefix,
          perHostTimeout: perHostTimeout,
          concurrency: concurrency,
          maxResults: maxResults,
        );

        for (final result in prefixResults) {
          final macKey = normMac(result.deviceInfo['mac']?.toString());
          final dedupeKey = macKey ?? result.ip;
          if (seenKeys.add(dedupeKey)) {
            results.add(result);
          }
        }

        if (maxResults != null && results.length >= maxResults) {
          break;
        }
      }

      results.sort((a, b) => a.ip.compareTo(b.ip));

      if (maxResults != null && results.length > maxResults) {
        return results.take(maxResults).toList(growable: false);
      }

      return results;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const UnknownAppException(IoTStrings.notFoundDeviceinWiFi);
    }
  }

  Future<Map<String, dynamic>?> tryGetDeviceInfo(
      String ip,
      Duration timeout,
      ) async {
    try {
      final rpc = ShellyRpcClient(host: ip, client: _client);
      final info = await rpc.getDeviceInfo().timeout(timeout);
      if (info.isEmpty) return null;
      return info;
    } catch (_) {
      return null;
    }
  }

  String inferType(Map<String, dynamic> info) {
    final model = (info['model'] ?? info['name'] ?? '').toString().toLowerCase();
    if (model.contains('bulb') ||
        model.contains('duo') ||
        model.contains('rgbw') ||
        model.contains('light')) {
      return 'light';
    }
    return 'plug';
  }

  String? normMac(String? mac) {
    if (mac == null) return null;
    final cleaned = mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<List<String>> _resolveScanPrefixes({
    required bool includeHotspotFallbacks,
    List<String>? scanPrefixes,
  }) async {
    if (scanPrefixes != null && scanPrefixes.isNotEmpty) {
      return scanPrefixes.toSet().toList(growable: false);
    }

    return wifiInfoService.getCandidateSubnetPrefixes24(
      includeHotspotFallbacks: includeHotspotFallbacks,
    );
  }

  Future<_PrefixScanResult> _scanSinglePrefix(
      String prefix, {
        required String? expectedMac,
        required Duration perHostTimeout,
        required int concurrency,
      }) async {
    final ips = List<String>.generate(254, (i) => '$prefix.${i + 1}');
    final sem = Semaphore(concurrency);

    ShellyLanDiscoveryResult? firstFound;
    ShellyLanDiscoveryResult? exactMacFound;

    final futures = <Future<void>>[];

    for (final ip in ips) {
      futures.add(() async {
        await sem.acquire();
        try {
          if (exactMacFound != null) return;

          final info = await tryGetDeviceInfo(ip, perHostTimeout);
          if (info == null) return;

          final result = ShellyLanDiscoveryResult(ip: ip, deviceInfo: info);
          final mac = normMac(info['mac']?.toString());

          if (expectedMac != null && mac != null && mac == expectedMac) {
            exactMacFound = result;
            return;
          }

          firstFound ??= result;
        } finally {
          sem.release();
        }
      }());
    }

    await Future.wait(futures);
    return _PrefixScanResult(
      firstFound: firstFound,
      exactMacFound: exactMacFound,
    );
  }

  Future<List<DiscoveredIotDevice>> _discoverAllInPrefix(
      String prefix, {
        required Duration perHostTimeout,
        required int concurrency,
        required int? maxResults,
      }) async {
    final ips = List<String>.generate(254, (i) => '$prefix.${i + 1}');
    final sem = Semaphore(concurrency);
    final results = <DiscoveredIotDevice>[];

    bool reachedLimit() => maxResults != null && results.length >= maxResults;

    final futures = <Future<void>>[];

    for (final ip in ips) {
      futures.add(() async {
        await sem.acquire();
        try {
          if (reachedLimit()) return;

          final info = await tryGetDeviceInfo(ip, perHostTimeout);
          if (info == null) return;

          final type = inferType(info);
          final name = (info['model'] ?? info['name'] ?? 'Shelly').toString();

          if (!results.any((r) => r.ip == ip)) {
            results.add(
              DiscoveredIotDevice(
                ip: ip,
                name: name,
                type: type,
                deviceInfo: info,
              ),
            );
          }
        } finally {
          sem.release();
        }
      }());
    }

    await Future.wait(futures);
    return results;
  }
}

class _PrefixScanResult {
  const _PrefixScanResult({
    required this.firstFound,
    required this.exactMacFound,
  });

  final ShellyLanDiscoveryResult? firstFound;
  final ShellyLanDiscoveryResult? exactMacFound;
}

class Semaphore {
  Semaphore(this.permits);

  int permits;
  final Queue<Completer<void>> waiters = Queue();

  Future<void> acquire() {
    if (permits > 0) {
      permits--;
      return Future.value();
    }
    final c = Completer<void>();
    waiters.add(c);
    return c.future;
  }

  void release() {
    if (waiters.isNotEmpty) {
      waiters.removeFirst().complete();
      return;
    }
    permits++;
  }
}