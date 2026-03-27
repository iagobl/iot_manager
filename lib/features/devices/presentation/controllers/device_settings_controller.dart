import 'package:flutter/material.dart';
import 'package:iot_manager/core/constants/devices_panel_strings.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceSettingsController extends ChangeNotifier {
  DeviceSettingsController({
    required this.deviceId,
    required this.host,
    required this.remoteDatasource,
  });

  final String deviceId;
  final String host;
  final DevicesRemoteDatasource remoteDatasource;

  final SupabaseClient _supabase = Supabase.instance.client;

  bool loading = false;
  bool canFactoryReset = false;
  bool canManageDevice = false;

  bool nightModeSupported = false;
  bool nightModeEnabled = false;
  double nightBrightness = 25;
  String nightStart = '23:00';
  String nightEnd = '07:00';
  bool savingNightMode = false;

  String? timezone;
  double? lat;
  double? lon;
  bool loadingLocation = false;

  bool savingName = false;

  bool checkingUpdate = false;
  bool updatingFirmware = false;
  String? availableVersion;
  String? availableBuildId;
  String? updateMessage;

  bool rebooting = false;
  bool unlinking = false;
  bool factoryResetting = false;

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final rpc = ShellyRpcClient(host: host);

    try {
      await _loadOwnership();

      final sysConfig = await rpc.getSysConfig();
      final location = _mapFrom(sysConfig['location']);
      timezone = _stringOrNull(location['tz']);
      lat = _doubleOrNull(location['lat']);
      lon = _doubleOrNull(location['lon']);

      try {
        final update = await rpc.checkForUpdate();
        final stable = _mapFrom(update['stable']);
        availableVersion = _stringOrNull(stable['version']);
        availableBuildId = _stringOrNull(stable['build_id']);
        updateMessage = availableVersion == null
            ? DevicesPanelStrings.deviceIsUpdate
            : DevicesPanelStrings.avaliableUpdate;
      } catch (error) {
        final failure = ErrorMapper.mapFailure(error);
        updateMessage = failure.message;
      }

      try {
        final plugsUi = await rpc.getPlugsUiConfig();
        final leds = _mapFrom(plugsUi['leds']);
        final night = _mapFrom(leds['night_mode']);

        nightModeSupported = night.isNotEmpty;
        nightModeEnabled = night['enable'] == true;
        nightBrightness =
            (_doubleOrNull(night['brightness']) ?? 25).clamp(0, 100).toDouble();

        final between = night['active_between'];
        if (between is List && between.length == 2) {
          nightStart = between[0].toString();
          nightEnd = between[1].toString();
        }
      } catch (_) {
        nightModeSupported = false;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadOwnership() async {
    try {
      final row = await _supabase
          .from('devices')
          .select('owner_id')
          .eq('id', deviceId)
          .maybeSingle();

      final ownerId = (row?['owner_id'] ?? '').toString();
      final currentUserId = _supabase.auth.currentUser?.id ?? '';

      canManageDevice =
          ownerId.isNotEmpty &&
              currentUserId.isNotEmpty &&
              ownerId == currentUserId;
      canFactoryReset = canManageDevice;
    } catch (_) {
      canFactoryReset = false;
    }
  }

  Future<void> saveNightMode() async {
    if (!nightModeSupported || savingNightMode) return;

    savingNightMode = true;
    notifyListeners();

    try {
      final rpc = ShellyRpcClient(host: host);
      await rpc.setPlugsUiConfig(
        config: {
          'leds': {
            'night_mode': {
              'enable': nightModeEnabled,
              'brightness': nightBrightness.round(),
              'active_between': [nightStart, nightEnd],
            },
          },
        },
      );
    } finally {
      savingNightMode = false;
      notifyListeners();
    }
  }

  void setNightModeEnabled(bool value) {
    nightModeEnabled = value;
    notifyListeners();
  }

  void setNightBrightness(double value) {
    nightBrightness = value;
    notifyListeners();
  }

  void setNightStart(String value) {
    nightStart = value;
    notifyListeners();
  }

  void setNightEnd(String value) {
    nightEnd = value;
    notifyListeners();
  }

  Future<void> detectLocation() async {
    if (loadingLocation) return;

    loadingLocation = true;
    notifyListeners();

    try {
      final rpc = ShellyRpcClient(host: host);
      final detected = await rpc.detectLocation();

      final tz = _stringOrNull(detected['tz']);
      final la = _doubleOrNull(detected['lat']);
      final lo = _doubleOrNull(detected['lon']);

      if (tz != null || la != null || lo != null) {
        await rpc.setSysConfig(
          config: {
            'location': {
              'tz': tz,
              'lat': la,
              'lon': lo,
            },
          },
        );

        timezone = tz;
        lat = la;
        lon = lo;
      }
    } finally {
      loadingLocation = false;
      notifyListeners();
    }
  }

  Future<void> saveName(String name) async {
    if (name.trim().isEmpty || savingName) return;

    if (name.length > 18) {
      throw Exception(DevicesPanelStrings.notValidName);
    }

    savingName = true;
    notifyListeners();

    try {
      final cleanName = name.trim();
      final rpc = ShellyRpcClient(host: host);

      await rpc.setSysConfig(config: {'device': {'name': cleanName}});

      await remoteDatasource.renameDevice(
        deviceId: deviceId,
        name: cleanName,
      );
    } finally {
      savingName = false;
      notifyListeners();
    }
  }

  Future<void> checkUpdate() async {
    if (checkingUpdate) return;

    checkingUpdate = true;
    notifyListeners();

    try {
      final rpc = ShellyRpcClient(host: host);
      final result = await rpc.checkForUpdate();
      final stable = _mapFrom(result['stable']);

      availableVersion = _stringOrNull(stable['version']);
      availableBuildId = _stringOrNull(stable['build_id']);
      updateMessage = availableVersion == null
          ? DevicesPanelStrings.notAvaliableUpdateStable
          : '${DevicesPanelStrings.pedingUpdate}: $availableVersion';
    } finally {
      checkingUpdate = false;
      notifyListeners();
    }
  }

  Future<void> runUpdate() async {
    if (availableVersion == null || updatingFirmware) return;

    updatingFirmware = true;
    notifyListeners();

    try {
      await remoteDatasource.setDeviceUpdating(
        deviceId: deviceId,
        isUpdating: true,
      );

      final rpc = ShellyRpcClient(host: host);
      await rpc.updateFirmware();
    } finally {
      updatingFirmware = false;
      notifyListeners();
    }
  }

  Future<void> rebootDevice() async {
    if (rebooting) return;

    rebooting = true;
    notifyListeners();

    try {
      final rpc = ShellyRpcClient(host: host);
      await rpc.reboot();
    } finally {
      rebooting = false;
      notifyListeners();
    }
  }

  Future<void> unlinkDevice() async {
    if (!canManageDevice) {
      throw Exception('Solo el propietario puede eliminar el dispositivo.');
    }

    if (unlinking) return;

    unlinking = true;
    notifyListeners();

    try {
      await remoteDatasource.unlinkDevice(deviceId);
    } finally {
      unlinking = false;
      notifyListeners();
    }
  }

  Future<void> factoryReset() async {
    if (!canFactoryReset) {
      throw Exception(DevicesPanelStrings.notFactoryReset);
    }

    if (factoryResetting) return;

    factoryResetting = true;
    notifyListeners();

    try {
      final rpc = ShellyRpcClient(host: host);
      await rpc.factoryReset();
      await remoteDatasource.deleteDevice(deviceId);
    } finally {
      factoryResetting = false;
      notifyListeners();
    }
  }

  static Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String? _stringOrNull(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  static double? _doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static String formatTimeOfDay(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}